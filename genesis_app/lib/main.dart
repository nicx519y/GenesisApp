import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/service_registry.dart';
import 'app/config/app_config.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/debug/origin_world_sheet_debug_settings.dart';
import 'app/debug/world_new_content_debug_settings.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'app/telemetry/telemetry_runtime_controller.dart';
import 'components/tilemap/tilemap_settings_store.dart';
import 'network/network_capture.dart';
import 'network/api_request_trace_sampling.dart';
import 'network/websocket_capture.dart';
import 'platform/session/user_session_store.dart';
import 'ui/system/genesis_system_ui.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  AppStartupCoordinator.beginLaunchTracking();
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
  final worldNewContentDebugSettingsLoad = kDebugMode
      ? worldNewContentDebugSettings.load()
      : Future<bool>.value(false);
  final appConfig = await AppEndpointOverrideStore.loadConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      debugPrint('[Startup] endpoint override load timed out; using defaults');
      return const AppConfig();
    },
  );
  final services = AppBootstrap.createInitialServices(config: appConfig);
  final initialTabFuture = _resolveInitialBottomTab(services);
  await Future.wait<Object?>(<Future<Object?>>[
    tilemapSettingsLoad,
    captureSettingsLoad,
    originWorldSheetDebugSettingsLoad,
    worldNewContentDebugSettingsLoad,
  ]);
  // Native Firebase collection is disabled for every build. Enable it only
  // after the actual runtime endpoints and persisted debug override are known.
  await TelemetryRuntimeController.initialize(appConfig);
  final appGlobalConfigLoad = _loadAppGlobalConfig(services);

  AppStartupCoordinator.recordStartupFirstReport();
  AppStartupCoordinator.configure();
  final initialTab = await initialTabFuture;
  if (initialTab.index == 1) {
    AppStartupCoordinator.setLaunchPageDecision(
      page: 'worldo',
      reason: initialTab.reason,
    );
  }
  await appGlobalConfigLoad;
  runApp(GenesisApp(services: services, initialIndex: initialTab.index));
}

Future<void> _loadAppGlobalConfig(AppServices services) async {
  try {
    await services.appGlobalConfig.refresh().timeout(
      const Duration(seconds: 3),
    );
    ApiRequestTraceSampling.configureForLaunch(
      services.appGlobalConfig.value.apiTraceSamplingRate,
    );
  } catch (error) {
    debugPrint(
      '[Startup] app global config load failed; using defaults: $error',
    );
  }
}

Future<({int index, String reason})> _resolveInitialBottomTab(
  AppServices services,
) async {
  try {
    final session = await services.sessionStore.readCompleteSession();
    return session == null
        ? (index: 1, reason: 'no_session')
        : (index: 0, reason: 'session_pending');
  } catch (_) {
    return (index: 1, reason: 'session_error');
  }
}
