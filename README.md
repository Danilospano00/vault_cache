# vault_cache

A **pure Dart** cache library with multi-layer storage, stale-while-revalidate,
tag-based invalidation, and swappable storage adapters.

Zero Flutter dependencies — works in Flutter apps, Dart servers, and CLI tools.

---

## Why vault_cache?

| Feature | vault_cache | flutter_cache_manager | flutter_memory_cache_plus | cached |
|---|:---:|:---:|:---:|:---:|
| Multi-layer (L1 + L2) | ✅ | ❌ | ❌ | ❌ |
| Stale-while-revalidate | ✅ | ❌ | ❌ | ❌ |
| Tag-based invalidation | ✅ | ❌ | ❌ | ❌ |
| Swappable storage adapter | ✅ | ❌ | ❌ | ❌ |
| Type-safe (no `dynamic`) | ✅ | ❌ | ✅ | ✅ |
| Pure Dart (no Flutter dep) | ✅ | ❌ | ✅ | ✅ |
| No code generation | ✅ | ✅ | ✅ | ❌ |

---

## Quick start

```dart
import 'package:vault_cache/vault_cache.dart';

final cache = VaultCache<String, UserModel>(
  policy: CachePolicy(
    ttl: Duration(minutes: 5),
    staleTtl: Duration(minutes: 10),
    maxSize: 100,
    eviction: LruStrategy(),
  ),
  l1: MemoryStore(maxSize: 100, eviction: LruStrategy()),
);

// Fetch once, cache automatically
final user = await cache.getOrFetch(
  'user_123',
  fetcher: () => api.getUser('123'),
  tags: {'users'},
);

// Invalidate a group by tag
await cache.invalidateTag('users');
```

---

## Features

### Multi-layer cache (L1 + L2)

```dart
final cache = VaultCache<String, String>(
  policy: CachePolicy(ttl: Duration(minutes: 5)),
  l1: MemoryStore(),   // fast in-memory layer
  l2: myHiveStore,    // persistent layer (inject your own adapter)
);
```

On read: L1 hit → return immediately. L1 miss → check L2 → promote to L1.
On write: both layers are written simultaneously (write-through).

### Stale-while-revalidate

```dart
final cache = VaultCache<String, String>(
  policy: CachePolicy(
    ttl: Duration(minutes: 5),      // fresh window
    staleTtl: Duration(minutes: 10), // stale window (serve + background refresh)
  ),
  l1: MemoryStore(),
);

// Returns stale value instantly; refreshes in background
final value = await cache.getOrFetch('key', fetcher: () => fetch());
```

### Tag-based invalidation

```dart
await cache.set('user_1', alice,   tags: {'users'});
await cache.set('user_2', bob,     tags: {'users'});
await cache.set('config', cfg,     tags: {'config'});

// Invalidate all 'users' entries at once
await cache.invalidateTag('users');
```

### Eviction strategies

```dart
// Least Recently Used (default)
CachePolicy(ttl: ..., maxSize: 100, eviction: LruStrategy())

// Least Frequently Used
CachePolicy(ttl: ..., maxSize: 100, eviction: LfuStrategy())

// First In First Out
CachePolicy(ttl: ..., maxSize: 100, eviction: FifoStrategy())
```

### Custom storage adapter

Implement `CacheStore<K, V>` to plug in any backend:

```dart
class HiveStore<K, V> implements CacheStore<K, V> {
  @override
  Future<CacheEntry<V>?> get(K key) async { /* Hive read */ }

  @override
  Future<void> set(K key, CacheEntry<V> entry) async { /* Hive write */ }

  @override
  Future<void> delete(K key) async { /* Hive delete */ }

  @override
  Future<void> clear() async { /* Hive clear */ }

  @override
  Future<List<K>> keys() async { /* Hive keys */ }
}
```

---

## API reference

### VaultCache

| Method | Description |
|---|---|
| `get(key)` | Returns cached value or `null` if absent/expired |
| `set(key, value, {tags})` | Stores value with optional tags |
| `getOrFetch(key, {fetcher, tags})` | Returns cached or fetches; supports SWR |
| `invalidate(key)` | Removes a single entry |
| `invalidateTag(tag)` | Removes all entries with a tag |
| `clear()` | Removes all entries |
| `stats` | Returns `CacheStats` (hits, misses, evictions, revalidations) |
| `dispose()` | Drains background queue and releases resources |

### CacheEntry

```dart
CacheEntry<V> {
  V value
  DateTime createdAt
  DateTime expiresAt
  DateTime? staleAt     // null = no stale-while-revalidate
  Set<String> tags

  bool get isFresh      // before staleAt (or expiresAt if no staleAt)
  bool get isStale      // past staleAt, before expiresAt
  bool get isExpired    // past expiresAt
}
```

---

## Installation

```yaml
dependencies:
  vault_cache: ^0.1.0
```

---

## Examples

See the [`example/`](example/) directory:

- [`basic_usage.dart`](example/basic_usage.dart) — set, get, invalidate, stats
- [`stale_while_revalidate_example.dart`](example/stale_while_revalidate_example.dart) — SWR in action
- [`tag_invalidation_example.dart`](example/tag_invalidation_example.dart) — group invalidation
- [`custom_store_example.dart`](example/custom_store_example.dart) — building a custom adapter
