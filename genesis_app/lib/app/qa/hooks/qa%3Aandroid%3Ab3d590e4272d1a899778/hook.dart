import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import '../qa%253Aandroid%253A5b3990fd6789b5efbe42/hook.dart';
import '../qa%253Aandroid%253A1cd4ae5d9b2c78255d2b/hook.dart';
import '../../../../pages/world/world_sections.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  final f = fault(), panel = eventsPanel();
  final events = displayedEvents();
  final world = panel == null
      ? null
      : (panel.widget as WorldEventsSection).world;
  return {
    'eventsVisible': events.isNotEmpty,
    'matchesRetryWorld': f.completed && world?.worldId == f.owner.worldId,
    'matchesRetryNewRound':
        f.completed &&
        events.any(
          (e) =>
              e['round'] == f.newRound &&
              (e['event'] as Map)['tick_id'] == f.event['tick_id'],
        ),
    'displayedEvents': events,
    'worldId': world?.worldId ?? '',
    'round': world?.tickCount ?? 0,
    'requestId': f.retryRequestId ?? '',
  };
}
