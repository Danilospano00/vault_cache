import '../cache/cache_entry.dart';
import 'eviction_strategy.dart';

/// Least Recently Used eviction strategy.
///
/// Tracks the access order of keys. When eviction is triggered, the key that
/// was least recently accessed (or written, if never read) is removed first.
class LruStrategy<K> extends EvictionStrategy<K> {
  // Maintains insertion-order with efficient move-to-back on access.
  final _order = <K>[];

  @override
  void onWrite(K key) {
    _order.remove(key);
    _order.add(key);
  }

  @override
  void onAccess(K key) {
    _order.remove(key);
    _order.add(key);
  }

  @override
  void onRemove(K key) {
    _order.remove(key);
  }

  @override
  List<K> evict(Map<K, CacheEntry<Object?>> entries) {
    // Return candidates from oldest to newest; caller removes as many as needed.
    return _order.where((k) => entries.containsKey(k)).toList();
  }
}
