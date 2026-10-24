import '../qa%253Aandroid%253A896f8ec3a61f21c926bf/hook.dart' as close_event;
import 'package:flutter/material.dart';
import '../../../../pages/world/world_bottom_sheet.dart';
import '../../../../pages/world/world_models.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' show resource;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  final r = resource();
  await r.requireOwner();
  final w = worldElement();
  if (w == null || r.route?.isCurrent != true || eventsPanel() != null)
    throw StateError('Uncovered target world required');
  final tags = elements(w)
      .where(
        (e) =>
            e.widget is WorldBottomTagContent &&
            visible(e) &&
            (e.widget as WorldBottomTagContent).item.kind ==
                WorldBottomSheetKind.events,
      )
      .toList();
  if (tags.length != 1) throw StateError('Events entry unavailable');
  (tags.single.widget as WorldBottomTagContent).onTap();
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (eventsPanel() == null && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  final panel = eventsPanel();
  final succeeded = panel != null;
  // A reversible usability interaction returns the page to its initial state.
  if (succeeded)
    await close_event.invoke({'operation': 'interact'}, prepared, started);
  return {
    'targetWorldMatches': worldElement() != null,
    'operationSucceeded': succeeded,
  };
}
