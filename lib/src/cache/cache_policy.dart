import '../eviction/eviction_strategy.dart';
import '../eviction/lru_strategy.dart';

/// Configures the behaviour of the cache for a specific use-case.
///
/// Pass a [CachePolicy] to [VaultCache] (or directly to [LayeredCache] /
/// [MemoryStore]) to control TTL, stale window, capacity, and eviction.
class CachePolicy {
  /// Creates a [CachePolicy].
  ///
  /// - [ttl]: how long an entry is considered fully valid. After this the
  ///   entry is expired and will not be returned unless refreshed.
  /// - [staleTtl]: how long an entry remains *stale-but-usable* **after**
  ///   [ttl] expires. During the stale window the old value is returned
  ///   immediately while a background fetch updates it. If null, there is no
  ///   stale window and entries are dropped on expiry.
  /// - [maxSize]: maximum number of entries in the store. When exceeded, the
  ///   [eviction] strategy decides which keys to remove. 0 means unlimited.
  /// - [eviction]: strategy used when [maxSize] is exceeded. Defaults to LRU.
  const CachePolicy({
    required this.ttl,
    this.staleTtl,
    this.maxSize = 0,
    EvictionStrategy<Object?>? eviction,
  }) : _eviction = eviction;

  /// How long an entry is fully fresh.
  final Duration ttl;

  /// How long after [ttl] an entry can still be served as stale while
  /// revalidation happens in the background. Null disables stale-while-revalidate.
  final Duration? staleTtl;

  /// Maximum number of entries allowed. 0 means no limit.
  final int maxSize;

  final EvictionStrategy<Object?>? _eviction;

  /// The eviction strategy to use when [maxSize] is exceeded.
  EvictionStrategy<Object?> get eviction => _eviction ?? LruStrategy<Object?>();

  /// Returns `true` if this policy has a finite capacity.
  bool get hasSizeLimit => maxSize > 0;

  /// Computes [expiresAt] from a given [createdAt].
  DateTime expiresAt(DateTime createdAt) => createdAt.add(ttl);

  /// Computes [staleAt] from a given [createdAt]. Returns null when [staleTtl]
  /// is not set.
  DateTime? staleAt(DateTime createdAt) {
    if (staleTtl == null) return null;
    return createdAt.add(ttl);
  }

  /// Computes the full expiry (stale window end) from a given [createdAt].
  DateTime fullExpiresAt(DateTime createdAt) {
    if (staleTtl == null) return expiresAt(createdAt);
    return createdAt.add(ttl + staleTtl!);
  }

  @override
  String toString() =>
      'CachePolicy(ttl: $ttl, staleTtl: $staleTtl, maxSize: $maxSize)';
}
