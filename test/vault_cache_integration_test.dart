import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

void main() {
  group('VaultCache integration', () {
    late VaultCache<String, String> cache;

    setUp(() {
      cache = VaultCache<String, String>(
        policy: CachePolicy(
          ttl: const Duration(minutes: 5),
          maxSize: 3,
          eviction: LruStrategy<Object?>(),
        ),
        l1: MemoryStore<String, String>(
          maxSize: 3,
          eviction: LruStrategy<String>(),
        ),
      );
    });

    tearDown(() async => cache.dispose());

    test('get returns null for missing key', () async {
      expect(await cache.get('missing'), isNull);
    });

    test('set and get round-trip', () async {
      await cache.set('k', 'v');
      expect(await cache.get('k'), equals('v'));
    });

    test('invalidate removes entry', () async {
      await cache.set('k', 'v');
      await cache.invalidate('k');
      expect(await cache.get('k'), isNull);
    });

    test('clear removes all entries', () async {
      await cache.set('a', '1');
      await cache.set('b', '2');
      await cache.clear();
      expect(await cache.get('a'), isNull);
      expect(await cache.get('b'), isNull);
    });

    test('getOrFetch stores result and returns it', () async {
      final value = await cache.getOrFetch('k', fetcher: () async => 'fetched');
      expect(value, equals('fetched'));
      expect(await cache.get('k'), equals('fetched'));
    });

    test('getOrFetch returns cached value on subsequent calls', () async {
      await cache.set('k', 'cached');
      var calls = 0;
      final value = await cache.getOrFetch('k', fetcher: () async {
        calls++;
        return 'new';
      });
      expect(value, equals('cached'));
      expect(calls, 0);
    });

    test('expired entry is refetched on getOrFetch', () async {
      final shortCache = VaultCache<String, String>(
        policy: const CachePolicy(ttl: Duration(milliseconds: 1)),
        l1: MemoryStore<String, String>(),
      );
      await shortCache.set('k', 'old');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final value =
          await shortCache.getOrFetch('k', fetcher: () async => 'new');
      expect(value, equals('new'));
      await shortCache.dispose();
    });

    test('stats: hits and misses are tracked', () async {
      await cache.set('k', 'v');
      await cache.get('k'); // hit
      await cache.get('missing'); // miss
      expect(cache.stats.hits, equals(1));
      expect(cache.stats.misses, equals(1));
      expect(cache.stats.hitRate, closeTo(0.5, 0.01));
    });

    test('stats: initial state is all zeros with hitRate 0.0', () {
      expect(cache.stats.hits, 0);
      expect(cache.stats.misses, 0);
      expect(cache.stats.hitRate, 0.0);
    });
  });

  group('VaultCache with L1 + L2', () {
    test('miss in L1 is served from L2 and promoted', () async {
      final l1 = MemoryStore<String, String>();
      final l2 = MemoryStore<String, String>();
      final cache = VaultCache<String, String>(
        policy: const CachePolicy(ttl: Duration(minutes: 5)),
        l1: l1,
        l2: l2,
      );
      // Manually put something in L2 only
      final entry = CacheEntry<String>(
        value: 'from_l2',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      await l2.set('k', entry);

      final result = await cache.get('k');
      expect(result, equals('from_l2'));
      // Promoted to L1
      expect((await l1.get('k'))?.value, equals('from_l2'));
      await cache.dispose();
    });
  });
}
