import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

CacheEntry<String> _entry(String value) => CacheEntry<String>(
      value: value,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

void main() {
  group('MemoryStore', () {
    late MemoryStore<String, String> store;

    setUp(() => store = MemoryStore<String, String>());

    test('get returns null for missing key', () async {
      expect(await store.get('missing'), isNull);
    });

    test('set and get round-trip', () async {
      final e = _entry('world');
      await store.set('hello', e);
      final result = await store.get('hello');
      expect(result?.value, equals('world'));
    });

    test('delete removes entry', () async {
      await store.set('k', _entry('v'));
      await store.delete('k');
      expect(await store.get('k'), isNull);
    });

    test('delete is no-op for unknown key', () async {
      await expectLater(store.delete('nonexistent'), completes);
    });

    test('clear removes all entries', () async {
      await store.set('a', _entry('1'));
      await store.set('b', _entry('2'));
      await store.clear();
      expect(await store.get('a'), isNull);
      expect(await store.get('b'), isNull);
      expect(store.length, 0);
    });

    test('keys returns all stored keys', () async {
      await store.set('x', _entry('1'));
      await store.set('y', _entry('2'));
      final keys = await store.keys();
      expect(keys, containsAll(['x', 'y']));
    });

    test('overwrites existing entry without changing length', () async {
      await store.set('k', _entry('v1'));
      await store.set('k', _entry('v2'));
      expect(store.length, 1);
      expect((await store.get('k'))?.value, equals('v2'));
    });

    group('eviction with LRU', () {
      test('evicts LRU entry when maxSize exceeded', () async {
        final s = MemoryStore<String, String>(
          maxSize: 2,
          eviction: LruStrategy<String>(),
        );
        await s.set('a', _entry('1'));
        await s.set('b', _entry('2'));
        await s.get('a'); // access 'a' so 'b' becomes LRU
        await s.set('c', _entry('3')); // should evict 'b'
        expect(await s.get('b'), isNull);
        expect(await s.get('a'), isNotNull);
        expect(await s.get('c'), isNotNull);
      });

      test('maxSize 1 always keeps only the most recent', () async {
        final s = MemoryStore<String, String>(
          maxSize: 1,
          eviction: LruStrategy<String>(),
        );
        await s.set('a', _entry('1'));
        await s.set('b', _entry('2'));
        expect(s.length, 1);
        expect(await s.get('b'), isNotNull);
        expect(await s.get('a'), isNull);
      });
    });
  });
}
