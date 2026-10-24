import 'package:flutter/foundation.dart';
import '../../../../components/world_tick_event_item.dart';
import '../../../../pages/world/world_sections.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ae902ad40417a12b1d8e2/hook.dart' show success;

String? _lastDiagnostic;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final s = success();
  await s.owner.requireOwner();
  final panel = eventsPanel();
  final items = visibleEvents();
  final diagnostic =
      '${s.owner.attempt}: completed=${s.completed} '
      'expected=${s.newRound} target=${panel == null ? null : (panel.widget as WorldEventsSection).targetTickNumber} '
      'visible=${items.map((e) => (e.widget as WorldTickEventItem).tickNumber).toList()}';
  if (diagnostic != _lastDiagnostic) {
    _lastDiagnostic = diagnostic;
    debugPrint('[QA tick position] $diagnostic');
  }
  return s.completed &&
      panel != null &&
      (panel.widget as WorldEventsSection).targetTickNumber == s.newRound &&
      items.any(
        (e) => (e.widget as WorldTickEventItem).tickNumber == s.newRound,
      );
}
