import '../cache/cache_entry.dart';
import 'eviction_strategy.dart';

/// Least Frequently Used eviction strategy.
///
/// Tracks how many times each key has been accessed. When eviction is
/// triggered, the key with the lowest access count is removed first. Ties are
/// broken by insertion order (oldest key wins).
class LfuStrategy<K> extends EvictionStrategy<K> {
  final Map<K, int> _counts = {};
  final List<K> _insertionOrder = [];

  @override
  void onWrite(K key) {
    _counts.putIfAbsent(key, () => 0);
    if (!_insertionOrder.contains(key)) {
      _insertionOrder.add(key);
    }
  }

  @override
  void onAccess(K key) {
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  @override
  void onRemove(K key) {
    _counts.remove(key);
    _insertionOrder.remove(key);
  }

  @override
  List<K> evict(Map<K, CacheEntry<Object?>> entries) {
    // Build a sorted list: ascending by access count, then by insertion order.
    final candidates = _insertionOrder
        .where((k) => entries.containsKey(k))
        .toList()
      ..sort((a, b) {
        final diff = (_counts[a] ?? 0).compareTo(_counts[b] ?? 0);
        if (diff != 0) return diff;
        return _insertionOrder.indexOf(a).compareTo(_insertionOrder.indexOf(b));
      });
    return candidates;
  }
}
