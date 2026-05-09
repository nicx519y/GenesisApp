import 'package:flutter/material.dart';

import '../pages/app_shell_page.dart';
import '../pages/origin/origin_world_page.dart';
import '../pages/world/world_page.dart';
import '../pages/chat/chat_page.dart';

sealed class RouteNames {
  static const shell = '/';
  static const home = '/home';
  static const origin = '/origin';
  static const originWorld = '/origin_world';
  static const world = '/world';
  static const chat = '/chat';
  static const create = '/create';
  static const messages = '/messages';
  static const me = '/me';
}

sealed class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 0),
        );
      case RouteNames.origin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 1),
        );
      case RouteNames.originWorld:
        final args = settings.arguments;
        var oid = '';
        var originId = 0;
        if (args is String) {
          oid = args;
        } else if (args is Map) {
          final rawOid = args['oid'];
          final rawOriginId = args['originId'];
          if (rawOid != null) oid = rawOid.toString();
          if (rawOriginId is int) {
            originId = rawOriginId;
          } else if (rawOriginId != null) {
            originId = int.tryParse(rawOriginId.toString()) ?? 0;
          }
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => OriginWorldPage(oid: oid, originId: originId),
        );
      case RouteNames.world:
        final args = settings.arguments;
        var wid = '';
        if (args is String) {
          wid = args;
        } else if (args is Map) {
          final rawWid = args['wid'];
          if (rawWid != null) wid = rawWid.toString();
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorldPage(wid: wid),
        );
      case RouteNames.chat:
        final args = settings.arguments;
        var wid = '';
        var locationId = 0;
        var locationName = '';
        if (args is Map) {
          final rawWid = args['wid'];
          if (rawWid != null) wid = rawWid.toString();

          final rawLocationId = args['locationId'] ?? args['location_id'];
          if (rawLocationId is int) {
            locationId = rawLocationId;
          } else if (rawLocationId != null) {
            locationId = int.tryParse(rawLocationId.toString()) ?? 0;
          }

          final rawLocationName = args['locationName'] ?? args['location_name'];
          if (rawLocationName != null) locationName = rawLocationName.toString();
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ChatPage(
            wid: wid,
            locationId: locationId,
            locationName: locationName,
          ),
        );
      case RouteNames.create:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 2),
        );
      case RouteNames.messages:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 3),
        );
      case RouteNames.me:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 4),
        );
      case RouteNames.shell:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 1),
        );
    }
  }
}
