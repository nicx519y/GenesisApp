import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import 'telemetry/genesis_telemetry.dart';

final ValueNotifier<String> genesisCurrentPageClassName = ValueNotifier<String>(
  AppRouter.pageClassNameForRouteName(RouteNames.home),
);

final ValueNotifier<String> genesisCurrentRouteName = ValueNotifier<String>(
  RouteNames.home,
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
    genesisCurrentRouteName.value = route.settings.name ?? '';
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
    _recordCollectPageView(route.settings);
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

void _recordCollectPageView(RouteSettings settings) {
  final routeName = settings.name ?? '';
  final args = settings.arguments;
  switch (routeName) {
    case RouteNames.originWorld:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'worldo_detail',
        object1: _argString(args, const ['oid', 'origin_id', 'originId']),
      );
      return;
    case RouteNames.world:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'world_detail',
        object1: _argString(args, const ['wid', 'world_id', 'worldId']),
      );
      return;
    case RouteNames.locationChat:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'world_location_chat',
        object1: _argString(args, const ['wid', 'world_id', 'worldId']),
        object2: _argString(args, const [
          'location_id',
          'locationId',
          'scene_id',
          'sceneId',
          'point_id',
          'pointId',
        ]),
      );
      return;
    case RouteNames.chat:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'messages_private_chat',
        object1: _argString(args, const ['peer_uid', 'peerUid', 'uid']),
      );
      return;
    case RouteNames.search:
      GenesisTelemetry.collectLog(actionType: 'pageview', action: 'search');
      return;
    case RouteNames.create:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'create_worldo',
      );
      return;
    case RouteNames.notifications:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'messages_notifications',
      );
      return;
    case RouteNames.newFollowers:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'messages_new_followers',
      );
      return;
    case RouteNames.comments:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'messages_comments',
      );
      return;
    case RouteNames.userInfo:
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'profile',
        object1: _argString(args, const ['uid', 'userId', 'id']),
      );
      return;
  }
}

String _argString(Object? args, List<String> keys) {
  if (args is String) return args.trim();
  if (args is! Map) return '';
  for (final key in keys) {
    final value = args[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
