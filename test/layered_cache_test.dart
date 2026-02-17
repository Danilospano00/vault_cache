import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

CacheEntry<String> _entry(String value) => CacheEntry<String>(
      value: value,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

void main() {
  group('LayeredCache', () {
    late MemoryStore<String, String> l1;
    late MemoryStore<String, String> l2;
    late LayeredCache<String, String> cache;

    setUp(() {
      l1 = MemoryStore<String, String>();
      l2 = MemoryStore<String, String>();
      cache = LayeredCache<String, String>(l1: l1, l2: l2);
    });

    test('total miss returns null', () async {
      expect(await cache.get('missing'), isNull);
    });

    test('write-through: set writes to both L1 and L2', () async {
      await cache.set('k', _entry('v'));
      expect((await l1.get('k'))?.value, equals('v'));
      expect((await l2.get('k'))?.value, equals('v'));
    });

    test('L1 hit: returns from L1 without consulting L2', () async {
      await l1.set('k', _entry('l1_value'));
      await l2.set('k', _entry('l2_value'));
      final result = await cache.get('k');
      expect(result?.value, equals('l1_value'));
    });

    test('L2 hit: promotes entry to L1', () async {
      await l2.set('k', _entry('from_l2'));
      final result = await cache.get('k');
      expect(result?.value, equals('from_l2'));
      // Verify promotion
      expect((await l1.get('k'))?.value, equals('from_l2'));
    });

    test('delete removes from both layers', () async {
      await cache.set('k', _entry('v'));
      await cache.delete('k');
      expect(await l1.get('k'), isNull);
      expect(await l2.get('k'), isNull);
    });

    test('clear removes from both layers', () async {
      await cache.set('a', _entry('1'));
      await cache.set('b', _entry('2'));
      await cache.clear();
      expect(await l1.get('a'), isNull);
      expect(await l2.get('a'), isNull);
    });

    test('keys returns union of L1 and L2 keys', () async {
      await l1.set('x', _entry('1'));
      await l2.set('y', _entry('2'));
      final keys = await cache.keys();
      expect(keys, containsAll(['x', 'y']));
    });

    group('without L2', () {
      setUp(() {
        cache = LayeredCache<String, String>(l1: l1);
      });

      test('set only goes to L1', () async {
        await cache.set('k', _entry('v'));
        expect((await l1.get('k'))?.value, equals('v'));
      });

      test('get returns L1 value', () async {
        await l1.set('k', _entry('v'));
        expect((await cache.get('k'))?.value, equals('v'));
      });

      test('keys returns only L1 keys', () async {
        await l1.set('only', _entry('v'));
        expect(await cache.keys(), equals(['only']));
      });
    });
  });
}
