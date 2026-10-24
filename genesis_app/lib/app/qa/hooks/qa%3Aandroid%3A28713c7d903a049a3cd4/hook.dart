import 'dart:async';
import 'package:flutter/material.dart';
import '../../../genesis_navigator.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../../../../pages/world/world_page.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../qa%253Aandroid%253Aa2066fb18358fd39923e/hook.dart' as map_view;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' show resource;
import 'view.dart';

Future<Map<String, Object?>> read() async {
  final r = resource();
  await r.requireOwner();
  final w = worldElement();
  return {
    'targetWorldMatches': w != null,
    'mapPageVisible': map_view.observe(w, r.worldId),
    'locationChatOpen': activePanel() != null,
    'otherOverlayOpen': r.route?.isCurrent != true,
  };
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'invoke');
  final r = resource();
  await r.requireOwner();
  if (r.route != null) throw StateError('World entry already acquired');
  final nav = genesisNavigatorKey.currentState;
  if (nav == null || r.isolatedServices == null)
    throw StateError('World preparation required');
  final routes = elements()
      .map((e) => ModalRoute.of(e))
      .whereType<Route<dynamic>>()
      .where((v) => v.isCurrent && v.navigator == nav)
      .toSet();
  if (routes.length != 1) throw StateError('Ambiguous original route');
  r.previousRoute = routes.single;
  r.route = GenesisDarkPageRoute<void>(
    builder: (_) {
      r.servicesMounted = true;
      return AppServicesScope(
        services: r.isolatedServices!,
        child: WorldPage(wid: r.worldId),
      );
    },
  );
  unawaited(nav.push(r.route!));
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    await WidgetsBinding.instance.endOfFrame;
    final value = await read();
    if (value['mapPageVisible'] == true) return value;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Target world map not ready');
}
