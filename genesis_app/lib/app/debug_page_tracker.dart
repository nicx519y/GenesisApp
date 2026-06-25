import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import 'telemetry/genesis_telemetry.dart';

final ValueNotifier<String> genesisCurrentPageClassName = ValueNotifier<String>(
  AppRouter.pageClassNameForRouteName(RouteNames.home),
);

final NavigatorObserver genesisRouteObserver = _GenesisRouteObserver();

class _GenesisRouteObserver extends NavigatorObserver {
  void _sync(
    Route<dynamic>? route, {
    Route<dynamic>? previousRoute,
    required String navigationType,
  }) {
    if (route == null || route is PopupRoute) return;
    final pageClassName = AppRouter.pageClassNameForRouteName(
      route.settings.name,
    );
    genesisCurrentPageClassName.value = pageClassName;
    GenesisTelemetry.pageView(
      routeName: route.settings.name ?? '',
      pageClassName: pageClassName,
      fromRouteName: previousRoute?.settings.name,
      fromPageClassName: previousRoute == null
          ? null
          : AppRouter.pageClassNameForRouteName(previousRoute.settings.name),
      navigationType: navigationType,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sync(route, previousRoute: previousRoute, navigationType: 'push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sync(previousRoute, previousRoute: route, navigationType: 'pop');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sync(newRoute, previousRoute: oldRoute, navigationType: 'replace');
  }
}
