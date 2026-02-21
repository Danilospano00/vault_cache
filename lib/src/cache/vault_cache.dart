import 'cache_entry.dart';
import 'cache_policy.dart';
import 'cache_stats.dart';
import 'cache_store.dart';
import 'layered_cache.dart';
import '../invalidation/tag_registry.dart';
import '../revalidation/revalidation_queue.dart';

/// The main entry point for vault_cache.
///
/// [VaultCache] orchestrates all sub-components:
/// - [LayeredCache] for multi-layer storage (L1 memory + optional L2 disk).
/// - [TagRegistry] for group invalidation.
/// - [RevalidationQueue] for stale-while-revalidate background refresh.
/// - [CacheStats] for performance metrics.
///
/// ### Minimal example
/// ```dart
/// final cache = VaultCache<String, UserModel>(
///   policy: CachePolicy(ttl: Duration(minutes: 5)),
///   l1: MemoryStore(),
/// );
///
/// final user = await cache.getOrFetch(
///   'user_1',
///   fetcher: () => api.getUser('1'),
///   tags: {'users'},
/// );
/// ```
class VaultCache<K, V> {
  /// Creates a [VaultCache].
  ///
  /// - [policy]: TTL, stale window, capacity, and eviction configuration.
  /// - [l1]: the primary (fast) cache layer, e.g. [MemoryStore].
  /// - [l2]: optional secondary (persistent) layer; pass null to use only L1.
  VaultCache({
    required this.policy,
    required CacheStore<K, V> l1,
    CacheStore<K, V>? l2,
  })  : _store = LayeredCache<K, V>(l1: l1, l2: l2),
        _tags = TagRegistry<K>(),
        _queue = RevalidationQueue<K, V>();

  /// The active cache policy.
  final CachePolicy policy;

  final LayeredCache<K, V> _store;
  final TagRegistry<K> _tags;
  final RevalidationQueue<K, V> _queue;

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _revalidations = 0;

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Returns a snapshot of current performance metrics.
  CacheStats get stats => CacheStats(
        hits: _hits,
        misses: _misses,
        evictions: _evictions,
        revalidations: _revalidations,
      );

  /// Returns the cached value for [key], or `null` if not present or expired.
  ///
  /// Stale entries are **not** returned by this method — use [getOrFetch] for
  /// stale-while-revalidate behaviour.
  Future<V?> get(K key) async {
    final entry = await _store.get(key);
    if (entry == null || entry.isExpired) {
      if (entry != null && entry.isExpired) {
        await _removeEntry(key);
      }
      _misses++;
      return null;
    }
    _hits++;
    return entry.value;
  }

  /// Returns the cached value for [key], or fetches it using [fetcher] if
  /// absent or expired.
  ///
  /// ### Stale-while-revalidate
  /// When [CachePolicy.staleTtl] is set and the entry is stale (past TTL but
  /// within the stale window):
  /// 1. The stale value is returned **immediately**.
  /// 2. A background [fetcher] call is scheduled to refresh the entry.
  ///
  /// This minimises latency at the cost of occasional briefly stale data.
  ///
  /// - [key]: the cache key.
  /// - [fetcher]: async callback that produces a fresh value.
  /// - [tags]: optional tags to associate with the stored entry.
  Future<V> getOrFetch(
    K key, {
    required Future<V> Function() fetcher,
    Set<String> tags = const {},
  }) async {
    final entry = await _store.get(key);

    if (entry != null && !entry.isExpired) {
      _hits++;
      if (entry.isStale) {
        // Serve stale value immediately; refresh in background.
        _revalidations++;
        _queue.schedule(
          key: key,
          fetcher: fetcher,
          onResult: (value) => _storeValue(key, value, tags),
        );
      }
      return entry.value;
    }

    // Total miss or fully expired: block on the fetcher.
    if (entry != null) await _removeEntry(key);
    _misses++;

    final value = await fetcher();
    await _storeValue(key, value, tags);
    return value;
  }

  /// Stores [value] under [key] with optional [tags].
  ///
  /// The TTL and stale window are determined by [policy].
  Future<void> set(K key, V value, {Set<String> tags = const {}}) =>
      _storeValue(key, value, tags);

  /// Removes the entry for [key] from all layers and the tag registry.
  Future<void> invalidate(K key) => _removeEntry(key);

  /// Removes all entries associated with [tag] across all layers.
  ///
  /// No-op if [tag] is unknown.
  Future<void> invalidateTag(String tag) async {
    final keys = _tags.keysForTag(tag);
    for (final key in keys) {
      await _store.delete(key);
    }
    _tags.removeTag(tag);
  }

  /// Removes all entries from all layers and clears the tag registry.
  Future<void> clear() async {
    await _store.clear();
    _tags.clear();
  }

  /// Waits for all in-flight background revalidations to complete and releases
  /// internal resources.
  ///
  /// Call this when the cache is no longer needed (e.g., on app shutdown or in
  /// tests after `tearDown`).
  Future<void> dispose() async {
    await _queue.drain();
    _queue.dispose();
  }

  // --------------------------------------------------------------------------
  // Private helpers
  // --------------------------------------------------------------------------

  Future<void> _storeValue(K key, V value, Set<String> tags) async {
    final now = DateTime.now();
    final entry = CacheEntry<V>(
      value: value,
      createdAt: now,
      expiresAt: policy.fullExpiresAt(now),
      staleAt: policy.staleAt(now),
      tags: tags,
    );
    await _store.set(key, entry);
    if (tags.isNotEmpty) {
      _tags.removeKey(key); // clean up old tag associations
      _tags.register(key, tags);
    }
  }

  Future<void> _removeEntry(K key) async {
    await _store.delete(key);
    _tags.removeKey(key);
  }
}
