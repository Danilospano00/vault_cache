// ignore_for_file: avoid_print
import 'package:vault_cache/vault_cache.dart';

Future<void> main() async {
  final cache = VaultCache<String, String>(
    policy: CachePolicy(ttl: const Duration(minutes: 10)),
    l1: MemoryStore<String, String>(),
  );

  // Store several entries, some sharing a common tag.
  await cache.set('user_1', 'Alice',   tags: {'users'});
  await cache.set('user_2', 'Bob',     tags: {'users'});
  await cache.set('user_3', 'Charlie', tags: {'users', 'admins'});
  await cache.set('config', 'v1.0',    tags: {'config'});

  print('Before invalidation:');
  print('  user_1 = ${await cache.get("user_1")}');  // Alice
  print('  user_2 = ${await cache.get("user_2")}');  // Bob
  print('  user_3 = ${await cache.get("user_3")}');  // Charlie
  print('  config = ${await cache.get("config")}');  // v1.0

  // Invalidate all entries tagged 'users' in one call.
  await cache.invalidateTag('users');

  print('\nAfter invalidateTag("users"):');
  print('  user_1 = ${await cache.get("user_1")}');  // null
  print('  user_2 = ${await cache.get("user_2")}');  // null
  print('  user_3 = ${await cache.get("user_3")}');  // null (was also 'users')
  print('  config = ${await cache.get("config")}');  // v1.0 (untouched)

  await cache.dispose();
}
