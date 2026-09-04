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
import 'app/startup/initial_landing_page_resolver.dart';
import 'app/telemetry/genesis_telemetry.dart';
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
  final appConfigLoad = AppEndpointOverrideStore.loadConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      debugPrint('[Startup] endpoint override load timed out; using defaults');
      return const AppConfig();
    },
  );
  final systemUiInitialization = GenesisSystemUi.initialize().whenComplete(
    AppStartupCoordinator.recordLaunchSystemUiReady,
  );
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
  final appConfig = await appConfigLoad;
  AppStartupCoordinator.recordLaunchEndpointConfigReady();
  final collectReady = Completer<void>();
  // Prepare the durable Collect queue as soon as the runtime endpoints are
  // known. The two launch sentinels intentionally do not wait for UID,
  // Firebase, Gateway, or the remote App Config request.
  final telemetryRuntimeInitialization = TelemetryRuntimeController.initialize(
    appConfig,
    onCollectReady: () {
      AppStartupCoordinator.recordStartupFirstReport();
      AppStartupCoordinator.recordLaunchTelemetryReady();
      if (!collectReady.isCompleted) collectReady.complete();
    },
  );
  unawaited(
    telemetryRuntimeInitialization.catchError((Object error, StackTrace stack) {
      debugPrint('[Startup] telemetry runtime initialization failed: $error');
      debugPrint('[Startup] stacktrace:\n$stack');
      if (!collectReady.isCompleted) collectReady.complete();
    }),
  );
  final services = AppBootstrap.createInitialServices(config: appConfig);
  final startupUidResolution = _resolveStartupUid(services.sessionStore);
  final initialLandingPageFuture = resolveInitialLandingPage(
    loadUid: () async {
      final resolution = await startupUidResolution;
      if (resolution.readFailed) {
        throw StateError('Startup UID read failed');
      }
      return resolution.uid;
    },
  );
  final appGlobalConfigLoad = () async {
    await collectReady.future;
    final resolution = await startupUidResolution;
    await _loadAppGlobalConfig(services, uid: resolution.uid);
  }().whenComplete(AppStartupCoordinator.recordLaunchAppConfigReady);
  await Future.wait<Object?>(<Future<Object?>>[
    systemUiInitialization,
    tilemapSettingsLoad,
    captureSettingsLoad,
    originWorldSheetDebugSettingsLoad,
    worldNewContentDebugSettingsLoad,
  ]);
  AppStartupCoordinator.recordLaunchLocalSettingsReady();

  AppStartupCoordinator.configure();
  final initialLandingPage = await initialLandingPageFuture;
  AppStartupCoordinator.setLaunchPageDecision(
    page: initialLandingPage.page,
    reason: initialLandingPage.reason,
  );
  await appGlobalConfigLoad;
  AppStartupCoordinator.recordLaunchBootstrapReady();
  runApp(
    GenesisApp(services: services, initialIndex: initialLandingPage.index),
  );
}

typedef _StartupUidResolution = ({String? uid, bool readFailed});

Future<_StartupUidResolution> _resolveStartupUid(
  UserSessionStore sessionStore,
) async {
  try {
    final uid = await sessionStore.readLoginUid().timeout(
      const Duration(seconds: 2),
    );
    if (uid == null) {
      GenesisTelemetry.clearUser();
    } else {
      GenesisTelemetry.setUserId(uid);
    }
    return (uid: uid, readFailed: false);
  } catch (error, stackTrace) {
    // A storage failure is not evidence that the user logged out. Keep any
    // existing telemetry identity and let startup use the anonymous fallback.
    debugPrint('[Startup] UID read failed: $error');
    debugPrint('[Startup] stacktrace:\n$stackTrace');
    return (uid: null, readFailed: true);
  }
}

Future<void> _loadAppGlobalConfig(
  AppServices services, {
  required String? uid,
}) async {
  try {
    await services.appGlobalConfig
        .refresh(uid: uid)
        .timeout(const Duration(seconds: 3));
    ApiRequestTraceSampling.configureForLaunch(
      services.appGlobalConfig.value.apiTraceSamplingRate,
    );
  } catch (error) {
    debugPrint(
      '[Startup] app global config load failed; using defaults: $error',
    );
  }
}
