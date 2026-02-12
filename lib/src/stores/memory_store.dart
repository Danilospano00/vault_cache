import '../cache/cache_entry.dart';
import '../cache/cache_store.dart';
import '../eviction/eviction_strategy.dart';

/// An in-memory [CacheStore] implementation backed by a [Map].
///
/// Supports capacity-based eviction via any [EvictionStrategy]. When
/// [maxSize] is 0 (default), no eviction is performed and the store grows
/// without bound.
///
/// All operations are synchronous internally, exposed as [Future]s to satisfy
/// the [CacheStore] interface.
class MemoryStore<K, V> implements CacheStore<K, V> {
  /// Creates a [MemoryStore].
  ///
  /// - [maxSize]: maximum number of entries. 0 means unlimited.
  /// - [eviction]: strategy used when [maxSize] is exceeded. Ignored when
  ///   [maxSize] is 0.
  MemoryStore({this.maxSize = 0, EvictionStrategy<K>? eviction})
      : _eviction = eviction;

  /// Maximum entries allowed. 0 means no limit.
  final int maxSize;

  final EvictionStrategy<K>? _eviction;
  final Map<K, CacheEntry<V>> _data = {};

  /// Returns the number of entries currently stored.
  int get length => _data.length;

  @override
  Future<CacheEntry<V>?> get(K key) {
    final entry = _data[key];
    if (entry != null) {
      _eviction?.onAccess(key);
    }
    return Future.value(entry);
  }

  @override
  Future<void> set(K key, CacheEntry<V> entry) {
    final isNew = !_data.containsKey(key);
    _data[key] = entry;

    if (isNew) {
      _eviction?.onWrite(key);
      _maybeEvict();
    }

    return Future.value();
  }

  @override
  Future<void> delete(K key) {
    if (_data.remove(key) != null) {
      _eviction?.onRemove(key);
    }
    return Future.value();
  }

  @override
  Future<void> clear() {
    final keys = List<K>.from(_data.keys);
    _data.clear();
    for (final k in keys) {
      _eviction?.onRemove(k);
    }
    return Future.value();
  }

  @override
  Future<List<K>> keys() => Future.value(List<K>.unmodifiable(_data.keys));

  // --------------------------------------------------------------------------
  // Private helpers
  // --------------------------------------------------------------------------

  void _maybeEvict() {
    if (maxSize <= 0 || _data.length <= maxSize) return;
    if (_eviction == null) return;

    final snapshot = Map<K, CacheEntry<Object?>>.fromEntries(
      _data.entries.map((e) => MapEntry(e.key, e.value as CacheEntry<Object?>)),
    );
    final toRemove = _eviction.evict(snapshot);
    for (final key in toRemove) {
      if (_data.remove(key) != null) {
        _eviction.onRemove(key);
      }
      // Stop once we're back within capacity
      if (_data.length <= maxSize) break;
    }
  }
}
