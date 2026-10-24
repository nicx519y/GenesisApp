import 'package:flutter/widgets.dart';
import '../../../../pages/world/world_header.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ae902ad40417a12b1d8e2/hook.dart' show success;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'wait');
  final s = success();
  await s.owner.requireOwner();
  if (s.failure != null)
    throw StateError('Mock completion failed: ${s.failure}');
  final w = worldElement();
  final headers = w == null
      ? <Element>[]
      : elements(w).where((e) => e.widget is WorldInfoHeader).toList();
  final refreshed = headers.any((e) {
    final world = (e.widget as WorldInfoHeader).world;
    return world.worldId == s.owner.worldId &&
        world.tickCount == s.newRound &&
        world.currentTime == s.newTime;
  });
  return {
    'completed': s.completed,
    'success': s.completed && s.failure == null,
    'worldDataRefreshed': s.completed && refreshed,
    'matchesCurrentAttempt':
        s.active && s.submissions > 0 && identical(s, success()),
    'attempt': s.owner.attempt,
    'round': s.newRound,
    'worldTime': s.newTime,
  };
}
