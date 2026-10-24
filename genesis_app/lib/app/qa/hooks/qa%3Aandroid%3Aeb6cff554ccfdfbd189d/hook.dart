import 'dart:async';
import 'package:flutter/material.dart';
import '../../../genesis_navigator.dart';
import '../../qa_bridge.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../../../../pages/world/world_page.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show selectedWorld, elements;
import '../qa%253Aandroid%253Aa2066fb18358fd39923e/hook.dart' as map_view;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart'
    show activePanel, observedRoute;

Future<Map<String, Object?>> read() async {
  final r = resource();
  await r.requireOwner();
  final world = selectedWorld(r.worldId);
  final state = await r.read();
  return {
    'targetWorldMatches': world != null,
    'mapVisible': map_view.observe(world, r.worldId),
    'locationChatVisible': activePanel() != null,
    'worldAdvancing': state['worldAdvancing'],
    'chatConnectionAvailable': state['chatConnectionAvailable'],
  };
}

Set<Route<dynamic>> currentRoutes(NavigatorState nav) => elements()
    .map(observedRoute)
    .whereType<Route<dynamic>>()
    .where((route) => route.isCurrent && route.navigator == nav)
    .toSet();

Future<Map<String, Object?>> prepare() async {
  final r = resource();
  await r.requireOwner();
  if (r.route != null) throw StateError('Map preparation already acquired');
  final nav = genesisNavigatorKey.currentState;
  if (nav == null) throw StateError('App navigator not ready');
  final originals = currentRoutes(nav);
  if (originals.length != 1) throw StateError('Ambiguous original route');
  r.previousRoute = originals.single;
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
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await WidgetsBinding.instance.endOfFrame;
    final observed = await read();
    if (observed['mapVisible'] == true) return observed;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Prepared world map did not render');
}

Future<Map<String, Object?>> cleanup() async {
  final r = resource();
  if (!identical(QaBridge.current, r.bridge))
    throw StateError('Map resource owner changed');
  final route = r.route;
  if (route == null || r.previousRoute == null)
    throw StateError('No map route acquired');
  if (route.isActive) {
    await r.requireOwner();
    if (!route.isCurrent) throw StateError('Foreign route above map');
    route.navigator!.removeRoute(route);
    await WidgetsBinding.instance.endOfFrame;
    r.servicesReleased = true;
  }
  final matches = r.previousRoute!.isCurrent && !route.isActive;
  if (!matches) throw StateError('Map route restoration mismatch');
  return {
    'restored': matches,
    'matchesSnapshot': matches,
    'resource': r.bridge.resource,
  };
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1)
    throw ArgumentError('Ready parameterless operation required');
  if (p['operation'] == 'read') return read();
  if (prepared)
    throw StateError('Case preparation cannot use contract session');
  return switch (p['operation']) {
    'prepare' => prepare(),
    'cleanup' => cleanup(),
    _ => throw ArgumentError('Unsupported map operation'),
  };
}

Future<Object?> contract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  return switch (p['operation']) {
    'prepare' => prepare(),
    'read' => read(),
    'cleanup' => cleanup(),
    _ => throw ArgumentError('Unsupported contract map operation'),
  };
}
