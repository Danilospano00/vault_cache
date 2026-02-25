// ignore_for_file: avoid_print
//
// vault_cache — comprehensive example.
//
// Covers: basic get/set, getOrFetch, stale-while-revalidate, tag invalidation,
// multi-layer cache (L1 + L2), and cache statistics.
//
// Run with: dart run example/example.dart

import 'package:vault_cache/vault_cache.dart';

Future<void> main() async {
  await _basicGetSet();
  await _getOrFetch();
  await _staleWhileRevalidate();
  await _tagInvalidation();
  await _multiLayer();
}

// ── 1. Basic get / set ────────────────────────────────────────────────────────

Future<void> _basicGetSet() async {
  print('=== 1. Basic get / set ===');

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

  await cache.set('greeting', 'Hello, vault_cache!');
  print('get: ${await cache.get("greeting")}'); // Hello, vault_cache!

  await cache.invalidate('greeting');
  print('after invalidate: ${await cache.get("greeting")}'); // null

  print('stats: ${cache.stats}\n');
  await cache.dispose();
}

// ── 2. getOrFetch: fetch once, serve from cache afterwards ───────────────────

Future<void> _getOrFetch() async {
  print('=== 2. getOrFetch ===');

  final cache = VaultCache<String, String>(
    policy: const CachePolicy(ttl: Duration(minutes: 5)),
    l1: MemoryStore<String, String>(),
  );

  var fetchCount = 0;
  Future<String> fetcher() async {
    fetchCount++;
    return 'data from server (call #$fetchCount)';
  }

  final first = await cache.getOrFetch('key', fetcher: fetcher);
  final second = await cache.getOrFetch('key', fetcher: fetcher);
  print('first:  $first');
  print('second: $second (from cache)');
  print('fetcher called $fetchCount time(s)\n'); // 1

  await cache.dispose();
}

// ── 3. Stale-while-revalidate ─────────────────────────────────────────────────

Future<void> _staleWhileRevalidate() async {
  print('=== 3. Stale-while-revalidate ===');

  // TTL = 100ms (fresh window), staleTtl = 500ms (stale window).
  final cache = VaultCache<String, String>(
    policy: const CachePolicy(
      ttl: Duration(milliseconds: 100),
      staleTtl: Duration(milliseconds: 500),
    ),
    l1: MemoryStore<String, String>(),
  );

  var generation = 0;
  Future<String> fetcher() async {
    generation++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return 'v$generation';
  }

  // Cold cache: blocks until fetcher returns.
  final cold = await cache.getOrFetch('item', fetcher: fetcher);
  print('cold: $cold'); // v1

  // Wait until entry is stale (> 100ms TTL).
  await Future<void>.delayed(const Duration(milliseconds: 150));

  // Stale hit: returns immediately, revalidation runs in background.
  final stale = await cache.getOrFetch('item', fetcher: fetcher);
  print('stale (returned immediately): $stale'); // v1

  // Drain the revalidation queue.
  await cache.dispose();
  final updated = await cache.get('item');
  print('after background revalidation: $updated\n'); // v2
}

// ── 4. Tag-based invalidation ─────────────────────────────────────────────────

Future<void> _tagInvalidation() async {
  print('=== 4. Tag invalidation ===');

  final cache = VaultCache<String, String>(
    policy: const CachePolicy(ttl: Duration(minutes: 10)),
    l1: MemoryStore<String, String>(),
  );

  await cache.set('user_1', 'Alice', tags: {'users'});
  await cache.set('user_2', 'Bob', tags: {'users'});
  await cache.set('config', 'v1.0', tags: {'config'});

  // Invalidate all 'users' entries at once.
  await cache.invalidateTag('users');

  print('user_1: ${await cache.get("user_1")}'); // null
  print('user_2: ${await cache.get("user_2")}'); // null
  print('config: ${await cache.get("config")}\n'); // v1.0

  await cache.dispose();
}

// ── 5. Multi-layer cache (L1 memory + L2 persistent) ─────────────────────────

Future<void> _multiLayer() async {
  print('=== 5. Multi-layer cache (L1 + L2) ===');

  final l1 = MemoryStore<String, String>();
  final l2 = MemoryStore<String, String>(); // replace with HiveStore in production

  final cache = VaultCache<String, String>(
    policy: const CachePolicy(ttl: Duration(minutes: 5)),
    l1: l1,
    l2: l2,
  );

  // Write-through: stored in both L1 and L2.
  await cache.set('profile', 'Alice');

  // Simulate app restart: wipe L1, L2 persists.
  await l1.clear();

  // Read: L1 miss → promotes from L2 back into L1.
  final value = await cache.get('profile');
  print('after L1 eviction, read from L2: $value'); // Alice
  print('stats: ${cache.stats}');

  await cache.dispose();
}
