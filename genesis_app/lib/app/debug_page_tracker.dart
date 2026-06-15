import 'package:flutter/material.dart';

import '../routers/app_router.dart';

final ValueNotifier<String> genesisCurrentPageClassName = ValueNotifier<String>(
  AppRouter.pageClassNameForRouteName(RouteNames.home),
);

final NavigatorObserver genesisRouteObserver = _GenesisRouteObserver();

class _GenesisRouteObserver extends NavigatorObserver {
  void _sync(Route<dynamic>? route) {
    if (route == null || route is PopupRoute) return;
    genesisCurrentPageClassName.value = AppRouter.pageClassNameForRouteName(
      route.settings.name,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sync(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sync(newRoute);
  }
}
