import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

void main() {
  group('TagRegistry', () {
    late TagRegistry<String> registry;

    setUp(() => registry = TagRegistry<String>());

    test('keysForTag returns empty set for unknown tag', () {
      expect(registry.keysForTag('unknown'), isEmpty);
    });

    test('register associates key with tags', () {
      registry.register('k1', {'users', 'admin'});
      expect(registry.keysForTag('users'), contains('k1'));
      expect(registry.keysForTag('admin'), contains('k1'));
    });

    test('register multiple keys under the same tag', () {
      registry.register('k1', {'users'});
      registry.register('k2', {'users'});
      expect(registry.keysForTag('users'), containsAll(['k1', 'k2']));
    });

    test('removeKey removes from all tags', () {
      registry.register('k1', {'users', 'admin'});
      registry.removeKey('k1');
      expect(registry.keysForTag('users'), isNot(contains('k1')));
      expect(registry.keysForTag('admin'), isNot(contains('k1')));
    });

    test('removeKey cleans up empty tag sets', () {
      registry.register('k1', {'solo'});
      registry.removeKey('k1');
      expect(registry.tags, isNot(contains('solo')));
    });

    test('removeTag removes tag and all its associations', () {
      registry.register('k1', {'grp'});
      registry.register('k2', {'grp'});
      registry.removeTag('grp');
      expect(registry.keysForTag('grp'), isEmpty);
      expect(registry.tags, isNot(contains('grp')));
    });

    test('clear removes everything', () {
      registry.register('k1', {'t1'});
      registry.register('k2', {'t2'});
      registry.clear();
      expect(registry.tags, isEmpty);
    });

    test('removeKey is no-op when key not registered', () {
      expect(() => registry.removeKey('ghost'), returnsNormally);
    });
  });

  group('VaultCache tag invalidation integration', () {
    late VaultCache<String, String> cache;

    setUp(() {
      cache = VaultCache<String, String>(
        policy: const CachePolicy(ttl: Duration(minutes: 5)),
        l1: MemoryStore<String, String>(),
      );
    });

    tearDown(() async => cache.dispose());

    test('invalidateTag removes all entries with that tag', () async {
      await cache.set('k1', 'v1', tags: {'users'});
      await cache.set('k2', 'v2', tags: {'users'});
      await cache.set('k3', 'v3', tags: {'other'});

      await cache.invalidateTag('users');

      expect(await cache.get('k1'), isNull);
      expect(await cache.get('k2'), isNull);
      expect(await cache.get('k3'), equals('v3'));
    });

    test('invalidateTag is no-op for unknown tag', () async {
      await cache.set('k1', 'v1');
      await expectLater(cache.invalidateTag('nonexistent'), completes);
      expect(await cache.get('k1'), equals('v1'));
    });

    test('invalidate single key also cleans tag registry', () async {
      await cache.set('k1', 'v1', tags: {'t1'});
      await cache.invalidate('k1');
      // Invalidating the tag should be a no-op now (no keys left)
      await expectLater(cache.invalidateTag('t1'), completes);
    });

    test('entry with multiple tags: invalidating one tag removes entry',
        () async {
      await cache.set('k1', 'v1', tags: {'a', 'b'});
      await cache.invalidateTag('a');
      expect(await cache.get('k1'), isNull);
    });
  });
}
