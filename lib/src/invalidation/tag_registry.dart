/// Maintains a mapping from tag names to the set of cache keys associated with
/// each tag, enabling efficient group invalidation.
///
/// When an entry is stored with one or more tags, each tag is registered here.
/// Calling [keysForTag] returns all keys that share that tag, so the cache can
/// invalidate them in bulk.
class TagRegistry<K> {
  final Map<String, Set<K>> _tagToKeys = {};

  /// Associates [key] with every tag in [tags].
  ///
  /// If [key] was previously registered under other tags, those associations
  /// are preserved. Call [removeKey] first if you want a clean replacement.
  void register(K key, Set<String> tags) {
    for (final tag in tags) {
      _tagToKeys.putIfAbsent(tag, () => {}).add(key);
    }
  }

  /// Removes [key] from all tag associations.
  ///
  /// Call this when an entry is deleted or expires so the registry stays clean.
  void removeKey(K key) {
    for (final keys in _tagToKeys.values) {
      keys.remove(key);
    }
    // Prune empty tag sets to avoid unbounded memory growth.
    _tagToKeys.removeWhere((_, keys) => keys.isEmpty);
  }

  /// Returns an unmodifiable snapshot of all keys associated with [tag].
  ///
  /// Returns an empty set if [tag] is unknown.
  Set<K> keysForTag(String tag) {
    final keys = _tagToKeys[tag];
    if (keys == null) return const {};
    return Set<K>.unmodifiable(keys);
  }

  /// Removes [tag] and all its key associations from the registry.
  void removeTag(String tag) {
    _tagToKeys.remove(tag);
  }

  /// Clears all tag-to-key associations.
  void clear() => _tagToKeys.clear();

  /// Returns all currently registered tags.
  Set<String> get tags => Set<String>.unmodifiable(_tagToKeys.keys);
}
