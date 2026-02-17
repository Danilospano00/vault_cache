import 'cache_entry.dart';
import 'cache_store.dart';

/// Orchestrates two cache layers: a fast L1 (usually in-memory) and an
/// optional slower L2 (usually disk/network-persisted).
///
/// ### Read path
/// 1. Check L1. On hit, return immediately.
/// 2. On L1 miss, check L2. On hit, **promote** the entry to L1 and return.
/// 3. On total miss, return `null`.
///
/// ### Write path (write-through)
/// All writes go to both L1 and L2 simultaneously.
///
/// ### Delete / clear
/// Operations are forwarded to both layers.
class LayeredCache<K, V> {
  /// Creates a [LayeredCache].
  ///
  /// - [l1]: the primary, fast layer (required).
  /// - [l2]: the secondary, persistent layer (optional). When null, reads and
  ///   writes only hit [l1].
  LayeredCache({required this.l1, this.l2});

  /// The primary (fast) cache layer.
  final CacheStore<K, V> l1;

  /// The secondary (persistent) cache layer. May be null.
  final CacheStore<K, V>? l2;

  /// Looks up [key] across both layers.
  ///
  /// Returns the [CacheEntry] on hit (promoting from L2 to L1 if necessary),
  /// or `null` on a total miss.
  Future<CacheEntry<V>?> get(K key) async {
    final l1Entry = await l1.get(key);
    if (l1Entry != null) return l1Entry;

    final l2Entry = await l2?.get(key);
    if (l2Entry != null) {
      // Promote L2 hit into L1 for faster future access.
      await l1.set(key, l2Entry);
      return l2Entry;
    }

    return null;
  }

  /// Stores [entry] under [key] in both layers (write-through).
  Future<void> set(K key, CacheEntry<V> entry) async {
    await l1.set(key, entry);
    await l2?.set(key, entry);
  }

  /// Removes [key] from both layers.
  Future<void> delete(K key) async {
    await l1.delete(key);
    await l2?.delete(key);
  }

  /// Removes all entries from both layers.
  Future<void> clear() async {
    await l1.clear();
    await l2?.clear();
  }

  /// Returns the union of keys from both layers.
  Future<List<K>> keys() async {
    final l1Keys = await l1.keys();
    if (l2 == null) return l1Keys;

    final l2Keys = await l2!.keys();
    return {...l1Keys, ...l2Keys}.toList();
  }
}
