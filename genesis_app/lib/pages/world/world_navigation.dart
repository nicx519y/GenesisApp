import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../routers/app_router.dart';
import '../app_shell_navigation.dart';
import 'world_deletion_events.dart';
import 'world_page_result.dart';

void openWorldFromMyWorldsRoot(
  NavigatorState navigator, {
  required Map<String, Object?> arguments,
}) {
  final worldArguments = Map<String, Object?>.unmodifiable(arguments);
  unawaited(
    navigator.pushNamedAndRemoveUntil<void>(RouteNames.home, (_) => false),
  );
  scheduleMicrotask(() {
    if (!navigator.mounted) return;
    unawaited(_openWorldAndRefreshAfterDelete(navigator, worldArguments));
  });
}

/// Enters a newly launched World without rebuilding the main-tab shell.
void openLaunchedWorldFromRetainedMainTabs(
  NavigatorState navigator, {
  required Map<String, Object?> arguments,
}) {
  final worldArguments = Map<String, Object?>.unmodifiable(arguments);
  requestHomeTabForWorldEntry();
  navigator.popUntil((route) {
    return route.settings.name == RouteNames.home ||
        route.settings.name == RouteNames.origin ||
        route.settings.name == RouteNames.shell ||
        route.isFirst;
  });
  scheduleMicrotask(() {
    if (!navigator.mounted) return;
    unawaited(_openLaunchedWorldAndRefreshOnReturn(navigator, worldArguments));
  });
}

Future<void> _openWorldAndRefreshAfterDelete(
  NavigatorState navigator,
  Map<String, Object?> arguments,
) async {
  final result = await navigator.pushNamed<WorldPageResult>(
    RouteNames.world,
    arguments: arguments,
  );
  if (!navigator.mounted || result == null) return;
  publishWorldDeletion(result.deletedWorldId);
}

Future<void> _openLaunchedWorldAndRefreshOnReturn(
  NavigatorState navigator,
  Map<String, Object?> arguments,
) async {
  final result = await navigator.pushNamed<WorldPageResult>(
    RouteNames.world,
    arguments: arguments,
  );
  if (!navigator.mounted) return;
  if (result != null) {
    publishWorldDeletion(result.deletedWorldId);
    return;
  }
  publishWorldListRefresh('${arguments['wid'] ?? ''}');
}
