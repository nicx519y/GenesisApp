import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';
import '../qa%253Aandroid%253A9ad73fa4984b5264a357/hook.dart' as origin;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  final d = await selection();
  if (!origin.atOrigin(d))
    throw StateError('Selected world entry is not at recorded origin');
  final action = origin.cardAction(origin.entryCard(d.selectedId!)!);
  if (action == null) throw StateError('Selected world entry is disabled');
  action();
  return {'performed': true, 'worldId': d.selectedId, 'resource': d.resource};
}
