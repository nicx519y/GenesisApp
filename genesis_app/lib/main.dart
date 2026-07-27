import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/service_registry.dart';
import 'app/config/app_config.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'app/telemetry/genesis_telemetry.dart';
import 'components/common/genesis_modal_routes.dart';
import 'ui/theme/genesis_color_controller.dart';
import 'ui/theme/genesis_semantic_colors.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appStartedAt = DateTime.now();
  final colorControllerFuture = GenesisColorController.load().catchError((
    Object error,
  ) {
    debugPrint('[Startup] developer color configuration failed: $error');
    return GenesisColorController();
  });
  unawaited(
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]),
  );
  final appConfig = await AppEndpointOverrideStore.loadConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      debugPrint('[Startup] endpoint override load timed out; using defaults');
      return const AppConfig();
    },
  );

  void runGenesisApp() {
    GenesisTelemetry.prepareCollect(appConfig);
    AppStartupCoordinator.recordStartupFirstReport();
    final services = AppBootstrap.createInitialServices(config: appConfig);
    final initialIndexFuture = _resolveInitialBottomTab(services);
    final resolvedColorControllerFuture = colorControllerFuture;
    AppStartupCoordinator.configure(startedAt: appStartedAt);
    unawaited(() async {
      final results = await Future.wait<Object>(<Future<Object>>[
        initialIndexFuture,
        resolvedColorControllerFuture,
      ]);
      final colorController = results[1] as GenesisColorController;
      GenesisColorRuntime.activate(
        colorController.configFor(colorController.activeBrightness),
        colorController.revision,
      );
      GenesisSystemUiChrome.applyDefault();
      runApp(
        GenesisApp(
          services: services,
          initialIndex: results[0] as int,
          colorController: colorController,
        ),
      );
    }());
  }

  runGenesisApp();
}

Future<int> _resolveInitialBottomTab(AppServices services) async {
  try {
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return 1;
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return authToken.isEmpty ? 1 : 0;
  } catch (_) {
    return 1;
  }
}
