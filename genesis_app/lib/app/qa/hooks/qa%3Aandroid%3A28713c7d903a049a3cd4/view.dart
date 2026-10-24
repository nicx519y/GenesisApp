import 'package:flutter/material.dart';
import '../../../../pages/world/world_page.dart';
import '../../../../pages/world/world_sections.dart';
import '../../../../components/world_tick_event_item.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible, textElements, actionForText;
export '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible, textElements, actionForText;
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' show resource;

Element? worldElement() {
  final r = resource();
  final found = elements()
      .where(
        (e) =>
            e.widget is WorldPage &&
            (e.widget as WorldPage).wid == r.worldId &&
            visible(e) &&
            ModalRoute.of(e) == r.route,
      )
      .toList();
  if (found.length > 1) throw StateError('Ambiguous owned world');
  return found.isEmpty ? null : found.single;
}

Element? eventsPanel() {
  final r = resource();
  if (r.route?.isActive != true) return null;
  final found = elements()
      .where(
        (e) =>
            e.widget is WorldEventsSection &&
            (e.widget as WorldEventsSection).world.worldId == r.worldId &&
            visible(e) &&
            ModalRoute.of(e)?.isCurrent == true,
      )
      .toList();
  if (found.length > 1) throw StateError('Ambiguous world event panel');
  return found.isEmpty ? null : found.single;
}

List<Element> visibleEvents() {
  final p = eventsPanel();
  return p == null
      ? []
      : elements(
          p,
        ).where((e) => e.widget is WorldTickEventItem && visible(e)).toList();
}

void validate(Map<String, dynamic> p, bool started, String op) {
  if (!started || p.length != 1 || p['operation'] != op)
    throw ArgumentError('Ready parameterless ' + op + ' required');
}
