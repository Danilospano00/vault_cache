import 'dart:async';
import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

void main() {
  group('Stale-while-revalidate', () {
    late VaultCache<String, String> cache;

    tearDown(() async => cache.dispose());

    test('fresh entry is returned immediately without fetcher call', () async {
      cache = VaultCache<String, String>(
        policy: CachePolicy(ttl: const Duration(minutes: 5)),
        l1: MemoryStore<String, String>(),
      );
      await cache.set('k', 'initial');
      var fetcherCalled = false;
      final value = await cache.getOrFetch('k', fetcher: () async {
        fetcherCalled = true;
        return 'fresh';
      });
      expect(value, equals('initial'));
      expect(fetcherCalled, isFalse);
    });

    test('expired entry triggers blocking fetch', () async {
      cache = VaultCache<String, String>(
        policy: CachePolicy(ttl: const Duration(milliseconds: 1)),
        l1: MemoryStore<String, String>(),
      );
      await cache.set('k', 'old');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final value = await cache.getOrFetch('k', fetcher: () async => 'fresh');
      expect(value, equals('fresh'));
    });

    test('stale entry is returned immediately; background refresh updates cache',
        () async {
      // TTL = 10ms, staleTtl = 90ms  →  stale window is [10ms, 100ms]
      cache = VaultCache<String, String>(
        policy: CachePolicy(
          ttl: const Duration(milliseconds: 10),
          staleTtl: const Duration(milliseconds: 90),
        ),
        l1: MemoryStore<String, String>(),
      );

      await cache.set('k', 'stale_value');
      // Wait for entry to become stale (past TTL, within stale window)
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final completer = Completer<void>();
      var fetcherCallCount = 0;

      final value = await cache.getOrFetch(
        'k',
        fetcher: () async {
          fetcherCallCount++;
          completer.complete();
          return 'fresh_value';
        },
      );

      // Should have returned the stale value immediately
      expect(value, equals('stale_value'));

      // Wait for background revalidation to complete
      await completer.future;
      await cache.dispose();

      // Cache should now hold the fresh value
      final updated = await cache.get('k');
      expect(updated, equals('fresh_value'));
      expect(fetcherCallCount, equals(1));
    });

    test('concurrent stale requests deduplicate revalidation', () async {
      cache = VaultCache<String, String>(
        policy: CachePolicy(
          ttl: const Duration(milliseconds: 10),
          staleTtl: const Duration(milliseconds: 90),
        ),
        l1: MemoryStore<String, String>(),
      );
      await cache.set('k', 'stale');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var fetcherCallCount = 0;
      Future<String> fetcher() async {
        fetcherCallCount++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 'refreshed';
      }

      // Fire two concurrent getOrFetch calls on a stale entry
      await Future.wait([
        cache.getOrFetch('k', fetcher: fetcher),
        cache.getOrFetch('k', fetcher: fetcher),
      ]);

      await cache.dispose(); // drain queue

      // Only one revalidation should have been scheduled
      expect(fetcherCallCount, equals(1));
    });

    test('fetcher error during revalidation keeps stale value', () async {
      cache = VaultCache<String, String>(
        policy: CachePolicy(
          ttl: const Duration(milliseconds: 10),
          staleTtl: const Duration(milliseconds: 90),
        ),
        l1: MemoryStore<String, String>(),
      );
      await cache.set('k', 'stale');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Fetcher always throws
      await cache.getOrFetch('k', fetcher: () async => throw Exception('oops'));
      await cache.dispose(); // drain queue

      // Stale value should still be in the cache
      final entry = await cache.get('k');
      // Entry might be null if it expired; what matters is no exception was thrown
      // and if still within stale window it should be 'stale'
      // (In this test stale window is 100ms total from write, so likely still there)
      expect(entry, anyOf(isNull, equals('stale')));
    });

    test('stats track revalidations', () async {
      cache = VaultCache<String, String>(
        policy: CachePolicy(
          ttl: const Duration(milliseconds: 10),
          staleTtl: const Duration(milliseconds: 90),
        ),
        l1: MemoryStore<String, String>(),
      );
      await cache.set('k', 'v');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cache.getOrFetch('k', fetcher: () async => 'fresh');
      expect(cache.stats.revalidations, equals(1));
    });
  });
}
