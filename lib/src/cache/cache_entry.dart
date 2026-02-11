/// A typed wrapper around a cached value, including all metadata needed to
/// determine freshness, staleness, and expiry.
class CacheEntry<V> {
  /// Creates a [CacheEntry] with the given [value] and timing metadata.
  ///
  /// - [value]: the cached value.
  /// - [createdAt]: when the entry was stored (defaults to now).
  /// - [expiresAt]: when the entry becomes fully expired and must be dropped.
  /// - [staleAt]: when the entry becomes stale but can still be served while
  ///   a background revalidation runs. Null disables stale-while-revalidate.
  /// - [tags]: optional set of tags used for group invalidation.
  const CacheEntry({
    required this.value,
    required this.createdAt,
    required this.expiresAt,
    this.staleAt,
    this.tags = const {},
  });

  /// The cached value.
  final V value;

  /// When this entry was created/stored.
  final DateTime createdAt;

  /// When this entry is fully expired. Reads after this point must not use
  /// the cached value (unless via stale-while-revalidate within [staleAt]).
  final DateTime expiresAt;

  /// When this entry transitions from *fresh* to *stale*.
  ///
  /// If null, the entry is either fresh or expired — there is no stale window.
  /// If set, the entry can be served stale between [staleAt] and [expiresAt]
  /// while a background fetch refreshes the value.
  final DateTime? staleAt;

  /// Tags associated with this entry, used for group invalidation.
  final Set<String> tags;

  /// Returns `true` if the entry has passed [expiresAt] and must not be used.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Returns `true` if [staleAt] is set and the current time is after it,
  /// but the entry has not yet fully [isExpired].
  ///
  /// A stale entry can still be returned immediately to the caller, but a
  /// background revalidation should be triggered.
  bool get isStale {
    if (staleAt == null) return false;
    final now = DateTime.now();
    return now.isAfter(staleAt!) && !now.isAfter(expiresAt);
  }

  /// Returns `true` if the entry is within its fresh window (before [staleAt],
  /// or before [expiresAt] when [staleAt] is null).
  bool get isFresh {
    if (isExpired) return false;
    if (staleAt != null) return !DateTime.now().isAfter(staleAt!);
    return true;
  }

  /// Creates a copy of this entry with updated fields.
  CacheEntry<V> copyWith({
    V? value,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? staleAt,
    Set<String>? tags,
  }) {
    return CacheEntry<V>(
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      staleAt: staleAt ?? this.staleAt,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() =>
      'CacheEntry(createdAt: $createdAt, expiresAt: $expiresAt, '
      'staleAt: $staleAt, tags: $tags, isFresh: $isFresh, '
      'isStale: $isStale, isExpired: $isExpired)';
}
