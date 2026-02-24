// ignore_for_file: avoid_print
//
// This example shows how to implement a custom [CacheStore] adapter.
// Here we build a trivial "file-simulating" store backed by a plain Map
// with simulated async I/O delays — the same pattern you would use for
// a real Hive, SharedPreferences, or SQLite adapter.
//
// To create a real Hive adapter, publish a companion package (e.g.
// `vault_cache_hive`) that depends on both `vault_cache` and `hive`, and
// implement `CacheStore<K, V>` using a `Box<Map>`.

import 'dart:convert';
import 'package:vault_cache/vault_cache.dart';

// ---------------------------------------------------------------------------
// Fake persistent store (simulates async disk I/O)
// ---------------------------------------------------------------------------

class FakePersistentStore<K, V> implements CacheStore<K, V> {
  // Backing map simulates serialised storage (JSON string → raw bytes).
  final Map<String, String> _disk = {};

  CacheEntry<V> _deserialize(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return CacheEntry<V>(
      value: map['value'] as V,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      staleAt: map['staleAt'] != null
          ? DateTime.parse(map['staleAt'] as String)
          : null,
      tags: (map['tags'] as List<dynamic>).cast<String>().toSet(),
    );
  }

  String _serialize(CacheEntry<V> entry) => jsonEncode({
        'value': entry.value,
        'createdAt': entry.createdAt.toIso8601String(),
        'expiresAt': entry.expiresAt.toIso8601String(),
        'staleAt': entry.staleAt?.toIso8601String(),
        'tags': entry.tags.toList(),
      });

  @override
  Future<CacheEntry<V>?> get(K key) async {
    await Future<void>.delayed(const Duration(milliseconds: 2)); // simulate I/O
    final raw = _disk['$key'];
    if (raw == null) return null;
    return _deserialize(raw);
  }

  @override
  Future<void> set(K key, CacheEntry<V> entry) async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    _disk['$key'] = _serialize(entry);
  }

  @override
  Future<void> delete(K key) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    _disk.remove('$key');
  }

  @override
  Future<void> clear() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    _disk.clear();
  }

  @override
  Future<List<K>> keys() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    // Key type is String in this example; cast accordingly.
    return _disk.keys.map((k) => k as K).toList();
  }
}

// ---------------------------------------------------------------------------
// Demo
// ---------------------------------------------------------------------------

Future<void> main() async {
  final l1 = MemoryStore<String, String>(); // fast in-memory layer
  final l2 = FakePersistentStore<String, String>(); // simulated disk layer

  final cache = VaultCache<String, String>(
    policy: const CachePolicy(ttl: Duration(minutes: 5)),
    l1: l1,
    l2: l2,
  );

  // Write — goes to both L1 and L2 (write-through).
  await cache.set('profile', 'Alice');
  print('Stored "profile" in L1 + L2');

  // Simulate app restart: clear L1 (in-memory) but L2 persists.
  await l1.clear();
  print('L1 cleared (simulating app restart)');

  // Read — L1 miss, promotes from L2.
  final value = await cache.get('profile');
  print('Read after restart: $value'); // Alice

  print('stats: ${cache.stats}');
  await cache.dispose();
}
