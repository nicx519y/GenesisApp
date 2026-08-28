import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/service_registry.dart';
import 'app/config/app_config.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/debug/origin_world_sheet_debug_settings.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'app/telemetry/telemetry_runtime_controller.dart';
import 'components/tilemap/tilemap_settings_store.dart';
import 'network/network_capture.dart';
import 'network/websocket_capture.dart';
import 'platform/session/user_session_store.dart';
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
  final originWorldSheetDebugSettingsLoad = kDebugMode
      ? originWorldSheetDebugSettings.load()
      : Future<bool>.value(false);
  final appConfig = await AppEndpointOverrideStore.loadConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      debugPrint('[Startup] endpoint override load timed out; using defaults');
      return const AppConfig();
    },
  );
  final services = AppBootstrap.createInitialServices(config: appConfig);
  final appGlobalConfigLoad = _loadAppGlobalConfig(services);
  final initialIndexFuture = _resolveInitialBottomTab(services);
  await Future.wait<Object?>(<Future<Object?>>[
    tilemapSettingsLoad,
    captureSettingsLoad,
    originWorldSheetDebugSettingsLoad,
  ]);
  // Native Firebase collection is disabled for every build. Enable it only
  // after the actual runtime endpoints and persisted debug override are known.
  await TelemetryRuntimeController.initialize(appConfig);

  AppStartupCoordinator.recordStartupFirstReport();
  AppStartupCoordinator.configure();
  final initialIndex = await initialIndexFuture;
  await appGlobalConfigLoad;
  runApp(GenesisApp(services: services, initialIndex: initialIndex));
}

Future<void> _loadAppGlobalConfig(AppServices services) async {
  try {
    await services.appGlobalConfig.refresh().timeout(
      const Duration(seconds: 3),
    );
  } catch (error) {
    debugPrint(
      '[Startup] app global config load failed; using defaults: $error',
    );
  }
}

Future<int> _resolveInitialBottomTab(AppServices services) async {
  try {
    return await services.sessionStore.readCompleteSession() == null ? 1 : 0;
  } catch (_) {
    return 1;
  }
}
