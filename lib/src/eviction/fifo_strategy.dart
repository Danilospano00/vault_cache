import '../cache/cache_entry.dart';
import 'eviction_strategy.dart';

/// First In First Out eviction strategy.
///
/// Removes the oldest-written entry first, regardless of how frequently or
/// recently it was accessed.
class FifoStrategy<K> extends EvictionStrategy<K> {
  final List<K> _insertionOrder = [];

  @override
  void onWrite(K key) {
    if (!_insertionOrder.contains(key)) {
      _insertionOrder.add(key);
    }
  }

  @override
  void onRemove(K key) {
    _insertionOrder.remove(key);
  }

  @override
  List<K> evict(Map<K, CacheEntry<Object?>> entries) {
    return _insertionOrder.where((k) => entries.containsKey(k)).toList();
  }
}
