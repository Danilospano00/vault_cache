/// Snapshot of cache performance metrics.
///
/// Obtain via [VaultCache.stats].
class CacheStats {
  /// Creates a [CacheStats] snapshot.
  const CacheStats({
    this.hits = 0,
    this.misses = 0,
    this.evictions = 0,
    this.revalidations = 0,
  });

  /// Number of times a valid (non-expired) entry was returned from the cache.
  final int hits;

  /// Number of times a key was requested but no valid entry was found.
  final int misses;

  /// Number of entries that were evicted due to capacity limits.
  final int evictions;

  /// Number of background revalidations triggered by stale-while-revalidate.
  final int revalidations;

  /// Total number of get requests (hits + misses).
  int get total => hits + misses;

  /// Fraction of requests that were cache hits. Returns 0.0 if no requests yet.
  double get hitRate => total == 0 ? 0.0 : hits / total;

  /// Fraction of requests that were cache misses. Returns 0.0 if no requests yet.
  double get missRate => total == 0 ? 0.0 : misses / total;

  @override
  String toString() =>
      'CacheStats(hits: $hits, misses: $misses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
      'evictions: $evictions, revalidations: $revalidations)';
}
