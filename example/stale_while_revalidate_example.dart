// ignore_for_file: avoid_print
import 'package:vault_cache/vault_cache.dart';

/// Simulates an API call that takes 50ms.
Future<String> fetchUserName(String id) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return 'User #$id (refreshed at ${DateTime.now().millisecondsSinceEpoch})';
}

Future<void> main() async {
  // TTL = 200ms → fresh window.
  // staleTtl = 800ms → stale window extends up to 200+800 = 1000ms after write.
  final cache = VaultCache<String, String>(
    policy: const CachePolicy(
      ttl: Duration(milliseconds: 200),
      staleTtl: Duration(milliseconds: 800),
    ),
    l1: MemoryStore<String, String>(),
  );

  // 1. First fetch — cold cache, blocks until fetcher returns.
  print('--- First call (cold cache) ---');
  final t0 = DateTime.now();
  final v1 =
      await cache.getOrFetch('user_1', fetcher: () => fetchUserName('1'));
  print('value: $v1');
  print('latency: ${DateTime.now().difference(t0).inMilliseconds}ms (blocked)');

  // 2. Second call — fresh entry, returns instantly.
  print('\n--- Second call (fresh) ---');
  final t1 = DateTime.now();
  final v2 =
      await cache.getOrFetch('user_1', fetcher: () => fetchUserName('1'));
  print('value: $v2');
  print('latency: ${DateTime.now().difference(t1).inMilliseconds}ms (~0ms)');

  // 3. Wait until entry is stale (300ms > 200ms TTL).
  await Future<void>.delayed(const Duration(milliseconds: 300));

  print('\n--- Third call (stale-while-revalidate) ---');
  final t2 = DateTime.now();
  final v3 =
      await cache.getOrFetch('user_1', fetcher: () => fetchUserName('1'));
  print('value: $v3  ← stale value returned immediately');
  print('latency: ${DateTime.now().difference(t2).inMilliseconds}ms (~0ms)');
  print('background revalidation scheduled...');

  // 4. Drain the revalidation queue and check the updated value.
  await cache.dispose();
  final updated = await cache.get('user_1');
  print('\n--- After background revalidation ---');
  print('updated value: $updated');
  print('stats: ${cache.stats}');
}
