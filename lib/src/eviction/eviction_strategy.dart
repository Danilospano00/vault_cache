import '../cache/cache_entry.dart';

/// Defines how a cache store removes entries when capacity is exceeded.
///
/// Extend this class to provide a custom eviction policy. Built-in
/// implementations: [LruStrategy], [LfuStrategy], [FifoStrategy].
abstract class EvictionStrategy<K> {
  /// Creates an [EvictionStrategy] instance.
  const EvictionStrategy();
  /// Given the current [entries] map, returns the list of keys that should be
  /// removed to bring the store back within capacity.
  ///
  /// [entries] maps each key to its [CacheEntry]. Implementations must NOT
  /// mutate the map; they only return the keys to evict.
  List<K> evict(Map<K, CacheEntry<Object?>> entries);

  /// Called by the store when a key is accessed (cache hit).
  ///
  /// Override this to track access patterns (e.g., LRU order, access count).
  void onAccess(K key) {}

  /// Called by the store when a new entry is written.
  ///
  /// Override this to track insertion order or initialize counters.
  void onWrite(K key) {}

  /// Called by the store when an entry is removed (eviction or explicit delete).
  ///
  /// Override this to clean up internal tracking state.
  void onRemove(K key) {}
}
