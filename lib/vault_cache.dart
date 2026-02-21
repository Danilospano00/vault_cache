/// A pure Dart cache library with multi-layer storage, stale-while-revalidate,
/// tag-based invalidation, and swappable storage adapters.
///
/// ### Quick start
/// ```dart
/// import 'package:vault_cache/vault_cache.dart';
///
/// final cache = VaultCache<String, String>(
///   policy: CachePolicy(ttl: Duration(minutes: 5)),
///   l1: MemoryStore(),
/// );
///
/// final value = await cache.getOrFetch('key', fetcher: () async => 'hello');
/// ```
library vault_cache;

// Core
export 'src/cache/cache_entry.dart';
export 'src/cache/cache_policy.dart';
export 'src/cache/cache_stats.dart';
export 'src/cache/cache_store.dart';
export 'src/cache/layered_cache.dart';
export 'src/cache/vault_cache.dart';

// Eviction strategies
export 'src/eviction/eviction_strategy.dart';
export 'src/eviction/fifo_strategy.dart';
export 'src/eviction/lfu_strategy.dart';
export 'src/eviction/lru_strategy.dart';

// Built-in stores
export 'src/stores/memory_store.dart';
export 'src/stores/noop_store.dart';

// Invalidation
export 'src/invalidation/tag_registry.dart';

// Revalidation
export 'src/revalidation/revalidation_queue.dart';
