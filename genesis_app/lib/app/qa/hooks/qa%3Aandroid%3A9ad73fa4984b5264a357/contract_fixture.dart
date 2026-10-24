import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/genesis_navigator.dart';
import '../../../../pages/home/home_page.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

class ParentFixture {
  ParentFixture(this.route, this.previous);
  final Route<void> route;
  final Route<dynamic>? previous;
}

Set<Route<dynamic>> currentRoutes(NavigatorState navigator) => elements()
    .where((e) => e is! InheritedElement)
    .map((e) => ModalRoute.of(e))
    .whereType<Route<dynamic>>()
    .where((r) => r.isCurrent && r.navigator == navigator)
    .toSet();

final fixtures = Expando<ParentFixture>();
Future<Object?> fixture(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  final d = await selection();
  final navigator = genesisNavigatorKey.currentState;
  if (navigator == null) throw StateError('App navigator not ready');
  if (p['operation'] == 'prepare') {
    if (fixtures[d] != null)
      throw StateError('Contract parent already acquired');
    final currents = currentRoutes(navigator);
    if (currents.length != 1) throw StateError('Ambiguous current route');
    final route = GenesisDarkPageRoute<void>(builder: (_) => const HomePage());
    fixtures[d] = ParentFixture(route, currents.single);
    unawaited(navigator.push(route));
    return {'resource': d.resource, 'prepared': route.navigator == navigator};
  }
  if (p['operation'] == 'restore') {
    final f = fixtures[d];
    if (f == null) throw StateError('No contract parent acquired');
    if (f.route.isActive) {
      // Only the selected-world child may be removed above our owned route.
      if (!f.route.isCurrent) {
        final world = selectedWorld(d.selectedId!);
        if (world == null)
          throw StateError('Foreign route above contract parent');
        navigator.removeRoute(ModalRoute.of(world)!);
      }
      navigator.removeRoute(f.route);
    }
    final matches = f.previous?.isCurrent == true;
    if (!matches) throw StateError('Contract parent restoration mismatch');
    return {
      'restored': !f.route.isActive,
      'matchesSnapshot': matches,
      'resource': d.resource,
    };
  }
  throw ArgumentError('Unknown contract parent operation');
}
