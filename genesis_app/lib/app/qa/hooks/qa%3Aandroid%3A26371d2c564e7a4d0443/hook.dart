import 'package:flutter/widgets.dart';
import '../../../../pages/world/world_header.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

String loadingState(Element? world, String id) {
  if (world == null) return 'absent';
  if (elements(world).any(
    (e) =>
        e.widget is WorldFeedContent &&
        (e.widget as WorldFeedContent).world.worldId == id,
  ))
    return 'loaded';
  if (textElements('Retry', world).isNotEmpty) return 'failed';
  return 'loading';
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'wait');
  final d = await selection();
  return loadingState(selectedWorld(d.selectedId!), d.selectedId!);
}
