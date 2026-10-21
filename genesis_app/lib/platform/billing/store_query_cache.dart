import 'dart:async';

/// Native store objects are process-local, never serialized as display prices.
/// Owners are store instances; different stores and query configurations cannot
/// reuse one another's purchase credentials. Failed lookups are not cached.
abstract final class StoreQueryCache {
  static Expando<Map<String, Object>> _values = Expando();
  static Expando<Map<String, Future<Object?>>> _pending = Expando();
  static int _generation = 0;
  static int get revision => _generation;

  static void reset() {
    _generation++;
    _values = Expando();
    _pending = Expando();
  }

  static Future<bool> launch(Future<bool> Function() action) async {
    try {
      final accepted = await action();
      if (!accepted) reset();
      return accepted;
    } catch (_) {
      // A rejected launch may indicate expired product/offer credentials.
      // The next attempt retries store lookup, not the backend catalog.
      reset();
      rethrow;
    }
  }

  static Future<T> load<T extends Object>(
    Object owner,
    String key,
    Future<T> Function() loader, {
    required bool Function(T) usable,
  }) async {
    final values = _values[owner] ??= {};
    final cached = values[key];
    if (cached is T && usable(cached)) return cached;
    final pending = _pending[owner] ??= {};
    final existing = pending[key];
    if (existing != null) return (await existing) as T;
    final generation = _generation;
    final future = Future<T>.sync(loader);
    pending[key] = future;
    try {
      final value = await future;
      if (generation == _generation && usable(value)) values[key] = value;
      return value;
    } finally {
      if (identical(pending[key], future)) pending.remove(key);
    }
  }
}
