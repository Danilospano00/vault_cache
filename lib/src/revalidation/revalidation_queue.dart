/// Manages background revalidation tasks for stale-while-revalidate.
///
/// Ensures that at most one revalidation is in flight per key at any given
/// time (deduplication). If a revalidation for a key is already running when
/// another request arrives for the same key, the second request is ignored and
/// the first future is reused.
///
/// Errors thrown by the [fetcher] are swallowed silently so they never surface
/// to callers who received the stale value.
class RevalidationQueue<K, V> {
  final Map<K, Future<void>> _pending = {};

  /// Schedules a background revalidation for [key] if one is not already
  /// running.
  ///
  /// - [fetcher]: async function that fetches the fresh value.
  /// - [onResult]: callback invoked with the fresh value on success.
  /// - [onError]: optional callback invoked on error (for logging/metrics).
  void schedule({
    required K key,
    required Future<V> Function() fetcher,
    required Future<void> Function(V value) onResult,
    void Function(Object error, StackTrace stack)? onError,
  }) {
    if (_pending.containsKey(key)) return; // already in flight

    final future = _run(
      key: key,
      fetcher: fetcher,
      onResult: onResult,
      onError: onError,
    );
    _pending[key] = future;
  }

  Future<void> _run({
    required K key,
    required Future<V> Function() fetcher,
    required Future<void> Function(V value) onResult,
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    try {
      final value = await fetcher();
      await onResult(value);
    } catch (error, stack) {
      onError?.call(error, stack);
      // Intentionally swallow: stale value remains in cache.
    } finally {
      _pending.remove(key);
    }
  }

  /// Returns `true` if a revalidation is currently in flight for [key].
  bool isPending(K key) => _pending.containsKey(key);

  /// Waits for all in-flight revalidations to complete.
  ///
  /// Useful in tests or when [dispose] is called.
  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.values);
    }
  }

  /// Cancels all pending revalidations.
  ///
  /// Note: Dart [Future]s cannot be cancelled. This simply clears the
  /// tracking map so new requests are no longer deduplicated against the
  /// old futures. In-flight async work will still complete but [onResult]
  /// may still be called.
  void dispose() => _pending.clear();
}
