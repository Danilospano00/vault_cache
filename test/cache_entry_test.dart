import 'package:test/test.dart';
import 'package:vault_cache/vault_cache.dart';

void main() {
  group('CacheEntry', () {
    DateTime now() => DateTime.now();

    test('isFresh when within TTL and no staleAt', () {
      final entry = CacheEntry<String>(
        value: 'hello',
        createdAt: now(),
        expiresAt: now().add(const Duration(minutes: 5)),
      );
      expect(entry.isFresh, isTrue);
      expect(entry.isStale, isFalse);
      expect(entry.isExpired, isFalse);
    });

    test('isExpired when past expiresAt', () {
      final entry = CacheEntry<String>(
        value: 'hello',
        createdAt: now().subtract(const Duration(minutes: 10)),
        expiresAt: now().subtract(const Duration(minutes: 1)),
      );
      expect(entry.isExpired, isTrue);
      expect(entry.isFresh, isFalse);
      expect(entry.isStale, isFalse);
    });

    test('isStale when past staleAt but before expiresAt', () {
      final entry = CacheEntry<String>(
        value: 'hello',
        createdAt: now().subtract(const Duration(minutes: 6)),
        expiresAt: now().add(const Duration(minutes: 4)),
        staleAt: now().subtract(const Duration(minutes: 1)),
      );
      expect(entry.isStale, isTrue);
      expect(entry.isFresh, isFalse);
      expect(entry.isExpired, isFalse);
    });

    test('isFresh when before staleAt', () {
      final entry = CacheEntry<String>(
        value: 'hello',
        createdAt: now(),
        expiresAt: now().add(const Duration(minutes: 10)),
        staleAt: now().add(const Duration(minutes: 5)),
      );
      expect(entry.isFresh, isTrue);
      expect(entry.isStale, isFalse);
      expect(entry.isExpired, isFalse);
    });

    test('isStale is false when staleAt is null even if past TTL-equivalent',
        () {
      final entry = CacheEntry<String>(
        value: 'hello',
        createdAt: now(),
        expiresAt: now().add(const Duration(minutes: 5)),
        staleAt: null,
      );
      expect(entry.isStale, isFalse);
    });

    test('tags are stored correctly', () {
      final entry = CacheEntry<String>(
        value: 'hello',
        createdAt: now(),
        expiresAt: now().add(const Duration(minutes: 5)),
        tags: {'user', 'admin'},
      );
      expect(entry.tags, containsAll(['user', 'admin']));
    });

    test('copyWith updates specified fields', () {
      final original = CacheEntry<int>(
        value: 1,
        createdAt: now(),
        expiresAt: now().add(const Duration(hours: 1)),
        tags: {'a'},
      );
      final copy = original.copyWith(value: 42, tags: {'b', 'c'});
      expect(copy.value, equals(42));
      expect(copy.tags, containsAll(['b', 'c']));
      expect(copy.createdAt, equals(original.createdAt));
      expect(copy.expiresAt, equals(original.expiresAt));
    });
  });
}
