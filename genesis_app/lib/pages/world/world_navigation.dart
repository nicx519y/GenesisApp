import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../routers/app_router.dart';
import 'world_deletion_events.dart';
import 'world_page_result.dart';

void openWorldFromMyWorldsRoot(
  NavigatorState navigator, {
  required Map<String, Object?> arguments,
}) {
  final worldArguments = Map<String, Object?>.unmodifiable(arguments);
  unawaited(
    navigator.pushNamedAndRemoveUntil<void>(
      RouteNames.home,
      (_) => false,
      arguments: const {'home_tab': 'my_world'},
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!navigator.mounted) return;
    unawaited(_openWorldAndRefreshAfterDelete(navigator, worldArguments));
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
