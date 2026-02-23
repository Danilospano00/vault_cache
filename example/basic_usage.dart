// ignore_for_file: avoid_print
import 'package:vault_cache/vault_cache.dart';

Future<void> main() async {
  // Create a cache with a 5-minute TTL and LRU eviction for up to 100 entries.
  final cache = VaultCache<String, String>(
    policy: CachePolicy(
      ttl: const Duration(minutes: 5),
      maxSize: 100,
      eviction: LruStrategy<Object?>(),
    ),
    l1: MemoryStore<String, String>(
      maxSize: 100,
      eviction: LruStrategy<String>(),
    ),
  );

  // ── Manual set / get ──────────────────────────────────────────────────────

  await cache.set('greeting', 'Hello, vault_cache!');
  final greeting = await cache.get('greeting');
  print('get: $greeting'); // Hello, vault_cache!

  // ── getOrFetch: fetch once, cache forever (within TTL) ───────────────────

  var fetchCount = 0;
  Future<String> fakeFetch() async {
    fetchCount++;
    print('  → fetching from remote (call #$fetchCount)');
    return 'data from server';
  }

  final first = await cache.getOrFetch('data', fetcher: fakeFetch);
  final second = await cache.getOrFetch('data', fetcher: fakeFetch);
  print('first:  $first');  // data from server
  print('second: $second'); // data from server (served from cache)
  print('fetch calls: $fetchCount'); // 1

  // ── Invalidation ──────────────────────────────────────────────────────────

  await cache.invalidate('greeting');
  print('after invalidate: ${await cache.get("greeting")}'); // null

  // ── Stats ─────────────────────────────────────────────────────────────────

  print('stats: ${cache.stats}');

  await cache.dispose();
}
