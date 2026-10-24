import 'package:flutter/material.dart';
import '../../../../pages/world/world_header.dart';
import '../../../../network/models/world.dart';
import '../../../../components/world_tick_event_item.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Aa2066fb18358fd39923e/hook.dart' as map_view;
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';

List<Map<String, Object?>> displayedEvents() => [
  for (final e in visibleEvents())
    {
      'round': (e.widget as WorldTickEventItem).tickNumber,
      'event': (e.widget as WorldTickEventItem).tick,
    },
];
WorldDetail displayedWorld() {
  final w = worldElement();
  final headers = w == null
      ? <Element>[]
      : elements(w).where((e) => e.widget is WorldInfoHeader).toList();
  if (headers.length != 1)
    throw StateError('Target world map preparation/navigation required');
  return (headers.single.widget as WorldInfoHeader).world;
}

class Baseline {
  Baseline(this.element, this.worldId, this.round, this.time, this.events);
  final Element element;
  final String worldId, time;
  final int round;
  final List<Map<String, Object?>> events;
  String get pageId =>
      '${resource().attempt}:page:${identityHashCode(element)}';
  Map<String, Object?> continuity() {
    final w = worldElement();
    return {
      'sameWorld': w != null && displayedWorld().worldId == worldId,
      'samePageInstance': identical(w, element) && element.mounted,
      'exitedAndReentered': !element.mounted || !identical(w, element),
    };
  }
}

final baselines = Expando<Baseline>();
Baseline baseline() {
  final r = resource();
  return baselines[r] ?? (throw StateError('World baseline required'));
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final r = resource();
  await r.requireOwner();
  final w = worldElement();
  if (w == null ||
      r.route?.isCurrent != true ||
      !map_view.observe(w, r.worldId))
    throw StateError('Target world map preparation/navigation required');
  final actual = displayedWorld();
  final b = baselines[r] ??= Baseline(
    w,
    actual.worldId,
    actual.tickCount,
    actual.currentTime,
    displayedEvents(),
  );
  return {
    'onTargetWorldMap': identical(w, b.element) && actual.worldId == r.worldId,
    'worldId': b.worldId,
    'round': b.round,
    'worldTime': b.time,
    'displayedCompletionEvents': b.events,
    'pageInstanceId': b.pageId,
  };
}
