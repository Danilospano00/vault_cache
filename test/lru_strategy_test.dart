import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

Map<String, CacheEntry<Object?>> _fakeEntries(List<String> keys) => {
      for (final k in keys)
        k: CacheEntry<Object?>(
          value: null,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
    };

void main() {
  group('LruStrategy', () {
    late LruStrategy<String> strategy;

    setUp(() => strategy = LruStrategy<String>());

    test('evict returns keys in LRU order', () {
      strategy.onWrite('a');
      strategy.onWrite('b');
      strategy.onWrite('c');
      // Access 'a' and 'c' to make 'b' the LRU
      strategy.onAccess('a');
      strategy.onAccess('c');
      final evicted = strategy.evict(_fakeEntries(['a', 'b', 'c']));
      expect(evicted.first, equals('b'));
    });

    test('onRemove cleans up tracking', () {
      strategy.onWrite('a');
      strategy.onWrite('b');
      strategy.onRemove('a');
      final evicted = strategy.evict(_fakeEntries(['b']));
      expect(evicted, isNot(contains('a')));
    });

    test('evict with empty map returns empty list', () {
      strategy.onWrite('a');
      expect(strategy.evict({}), isEmpty);
    });

    test('keys not in entries are excluded from eviction result', () {
      strategy.onWrite('a');
      strategy.onWrite('b');
      // Only pass 'a' in entries
      final evicted = strategy.evict(_fakeEntries(['a']));
      expect(evicted, equals(['a']));
    });

    test('most recently accessed key is last in eviction list', () {
      strategy.onWrite('a');
      strategy.onWrite('b');
      strategy.onWrite('c');
      strategy.onAccess('a'); // 'a' now most recent
      final evicted = strategy.evict(_fakeEntries(['a', 'b', 'c']));
      expect(evicted.last, equals('a'));
    });
  });
}
