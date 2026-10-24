import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';
import 'dart:async';
import '../../../../app/genesis_navigator.dart';
import '../../../../pages/world/world_page.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1 || p['operation'] != 'invoke')
    throw ArgumentError('Expected invoke');
  final lease = requireWorldLease();
  await lease.sameOwner();
  if (worldElement() != null) throw StateError('Target already open');
  final navigator = genesisNavigatorKey.currentState;
  if (navigator == null) throw StateError('App navigator not ready');
  final page = WorldPage(wid: lease.worldId);
  final route = GenesisDarkPageRoute<void>(builder: (_) => page);
  lease.route = route;
  unawaited(navigator.push(route));
  return {
    'invoked': true,
    'targetMatchesPreparedWorld': page.wid == lease.worldId,
    'loadedWorldDetail': page.initialWorldDetail,
    'directLocationChat': page.initialLocationId.isNotEmpty,
  };
}
