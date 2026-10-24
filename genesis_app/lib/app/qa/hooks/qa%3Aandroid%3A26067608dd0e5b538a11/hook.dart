import '../../../../pages/world/world_header.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  final d = await selection();
  final world = selectedWorld(d.selectedId!);
  if (world == null) throw StateError('Selected world back button is absent');
  final buttons = elements(
    world,
  ).where((e) => e.widget is WorldMapBackButton && visible(e)).toList();
  if (buttons.length != 1)
    throw StateError('Selected world back button is absent or ambiguous');
  (buttons.single.widget as WorldMapBackButton).onPressed();
  return {'performed': true, 'worldId': d.selectedId, 'resource': d.resource};
}
