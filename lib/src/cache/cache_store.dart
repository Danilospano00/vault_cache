import 'cache_entry.dart';

/// Abstract storage adapter for a single cache layer.
///
/// Implement this interface to integrate any backend (in-memory map, Hive,
/// SharedPreferences, SQLite, Redis, etc.) with vault_cache without modifying
/// the library itself.
///
/// Type parameters:
/// - [K] — the key type (usually `String` or `int`).
/// - [V] — the value type stored in each [CacheEntry].
///
/// All methods are asynchronous to allow implementations backed by persistent
/// stores that perform I/O. In-memory implementations can simply wrap
/// synchronous operations in `Future.value(...)`.
abstract interface class CacheStore<K, V> {
  /// Returns the [CacheEntry] for [key], or `null` if not present.
  Future<CacheEntry<V>?> get(K key);

  /// Stores [entry] under [key], overwriting any previous value.
  Future<void> set(K key, CacheEntry<V> entry);

  /// Removes the entry associated with [key]. No-op if [key] is not present.
  Future<void> delete(K key);

  /// Removes all entries from this store.
  Future<void> clear();

  /// Returns all keys currently held by this store.
  Future<List<K>> keys();
}
