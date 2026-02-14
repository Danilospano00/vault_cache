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
  group('LfuStrategy', () {
    late LfuStrategy<String> strategy;

    setUp(() => strategy = LfuStrategy<String>());

    test('evict returns least-frequently-used key first', () {
      strategy.onWrite('a');
      strategy.onWrite('b');
      strategy.onWrite('c');
      // Access 'a' twice, 'b' once, 'c' never
      strategy.onAccess('a');
      strategy.onAccess('a');
      strategy.onAccess('b');
      final evicted = strategy.evict(_fakeEntries(['a', 'b', 'c']));
      expect(evicted.first, equals('c')); // 0 accesses
    });

    test('ties broken by insertion order (oldest first)', () {
      strategy.onWrite('a'); // inserted first
      strategy.onWrite('b');
      // Neither accessed — tie on frequency
      final evicted = strategy.evict(_fakeEntries(['a', 'b']));
      expect(evicted.first, equals('a'));
    });

    test('onRemove cleans up tracking', () {
      strategy.onWrite('a');
      strategy.onRemove('a');
      final evicted = strategy.evict(_fakeEntries(['a']));
      expect(evicted, isEmpty);
    });

    test('single key eviction', () {
      strategy.onWrite('only');
      strategy.onAccess('only');
      final evicted = strategy.evict(_fakeEntries(['only']));
      expect(evicted, equals(['only']));
    });
  });
}
