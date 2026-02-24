## 0.1.0

* Initial release.
* Typed multi-layer cache (L1 memory + optional L2 adapter) with automatic L2→L1 promotion.
* Stale-while-revalidate: returns stale value immediately while refreshing in background.
* Tag-based invalidation: invalidate groups of entries with a single `invalidateTag()` call.
* Three built-in eviction strategies: LRU, LFU, FIFO.
* Abstract `CacheStore<K, V>` interface for custom storage backends (Hive, SharedPreferences, etc.).
* `CacheStats` with hit rate, miss rate, eviction count and revalidation count.
* Pure Dart — no Flutter dependency, works in Flutter apps, Dart server and CLI.
