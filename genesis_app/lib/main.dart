import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/service_registry.dart';
import 'app/config/app_config.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/config/app_flavor_config.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'app/telemetry/telemetry_runtime_controller.dart';
import 'app/theme/genesis_theme_mode_controller.dart';
import 'components/tilemap/tilemap_settings_store.dart';
import 'network/network_capture.dart';
import 'network/websocket_capture.dart';
import 'ui/system/genesis_system_ui.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GenesisSystemUi.initialize();
  unawaited(
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]),
  );
  final themeModeControllerLoad =
      GenesisThemeModeController.load(
        allowDeveloperOverride: kDebugMode || AppFlavorConfig.currentIsInternal,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('[Startup] theme mode load timed out; using dark');
          return GenesisThemeModeController();
        },
      );
  final tilemapSettingsLoad = () async {
    try {
      await const TilemapSettingsStore().load().timeout(
        const Duration(seconds: 2),
      );
    } catch (error) {
      debugPrint(
        '[Startup] tilemap settings load failed; using defaults: $error',
      );
    }
  }();
  final captureSettingsLoad = kDebugMode
      ? Future.wait<bool>(<Future<bool>>[
          networkCaptureController.loadEnabled(),
          webSocketCaptureController.loadSettings(),
        ])
      : Future<List<bool>>.value(const <bool>[]);
  final appConfig = await AppEndpointOverrideStore.loadConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      debugPrint('[Startup] endpoint override load timed out; using defaults');
      return const AppConfig();
    },
  );
  await Future.wait<Object?>(<Future<Object?>>[
    tilemapSettingsLoad,
    captureSettingsLoad,
  ]);
  // Native Firebase collection is disabled for every build. Enable it only
  // after the actual runtime endpoints and persisted debug override are known.
  await TelemetryRuntimeController.initialize(appConfig);
  final themeModeController = await themeModeControllerLoad;

  void runGenesisApp() {
    final services = AppBootstrap.createInitialServices(config: appConfig);
    AppStartupCoordinator.recordStartupFirstReport();
    final initialIndexFuture = _resolveInitialBottomTab(services);
    AppStartupCoordinator.configure();
    unawaited(
      initialIndexFuture.then(
        (initialIndex) => runApp(
          GenesisApp(
            services: services,
            initialIndex: initialIndex,
            themeModeController: themeModeController,
          ),
        ),
      ),
    );
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
