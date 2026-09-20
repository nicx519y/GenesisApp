import 'dart:math' as math;

/// A count is a cache budget, never permission to evict the current viewport.
/// The caller owns persistence, identity and protocol cursor semantics.
class LocationMessageRetention {
  const LocationMessageRetention({
    this.target = 200,
    this.highWater = 240,
    this.recent = 40,
  });
  final int target;
  final int highWater;
  final int recent;

  List<T> select<T>(
    List<T> messages, {
    required Object Function(T) identity,
    required Set<Object> protected,
    Object? focus,
    bool force = false,
  }) {
    if (messages.length <= (force ? target : highWater)) return messages;
    final selected = <int>{};
    for (var i = 0; i < messages.length; i++) {
      if (protected.contains(identity(messages[i]))) selected.add(i);
    }
    selected.addAll(
      Iterable<int>.generate(
        math.min(recent, messages.length),
        (i) => messages.length - 1 - i,
      ),
    );
    final focusIndex = focus == null
        ? -1
        : messages.indexWhere((m) => identity(m) == focus);
    final center = focusIndex < 0 ? messages.length - 1 : focusIndex;
    for (
      var distance = 0;
      selected.length < target && distance < messages.length;
      distance++
    ) {
      for (final index in [center - distance, center + distance]) {
        if (index >= 0 && index < messages.length) selected.add(index);
        if (selected.length >= target) break;
      }
    }
    final indices = selected.toList()..sort();
    return List.unmodifiable(indices.map((i) => messages[i]));
  }
}
