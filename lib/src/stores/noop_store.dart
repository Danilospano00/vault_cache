import '../cache/cache_entry.dart';
import '../cache/cache_store.dart';

/// A no-operation [CacheStore] that never stores anything.
///
/// Useful as a placeholder for the L2 layer when you only need in-memory
/// caching, or in tests where you want to isolate L1 behaviour without a real
/// L2 backing store.
class NoopStore<K, V> implements CacheStore<K, V> {
  /// Creates a [NoopStore].
  const NoopStore();

  @override
  Future<CacheEntry<V>?> get(K key) => Future.value(null);

  @override
  Future<void> set(K key, CacheEntry<V> entry) => Future.value();

  @override
  Future<void> delete(K key) => Future.value();

  @override
  Future<void> clear() => Future.value();

  @override
  Future<List<K>> keys() => Future.value(const []);
}
