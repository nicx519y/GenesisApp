import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/startup/startup_endpoint_config.dart';
import 'app/debug/origin_world_sheet_debug_settings.dart';
import 'app/debug/screen_translation_debug_settings.dart';
import 'app/debug/world_new_content_debug_settings.dart';
import 'app/debug/purchase_toast_debug_settings.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'app/startup/initial_landing_page_resolver.dart';
import 'app/startup/ios_startup_network.dart';
import 'app/startup/startup_app_config.dart';
import 'app/startup/startup_dependency_guard.dart';
import 'app/startup/startup_uid_resolution.dart';
import 'platform/session/method_channel_user_session_store.dart';
import 'app/telemetry/genesis_telemetry.dart';
import 'app/telemetry/telemetry_runtime_controller.dart';
import 'components/tilemap/tilemap_settings_store.dart';
import 'network/network_capture.dart';
import 'network/websocket_capture.dart';
import 'platform/session/user_session_store.dart';
import 'ui/system/genesis_system_ui.dart';

export 'app/genesis_app.dart';

const _startupSystemUiTimeout = Duration(seconds: 2);

Future<void> main() async {
  AppStartupCoordinator.beginLaunchTracking();
  WidgetsFlutterBinding.ensureInitialized();
  final appConfigLoad = loadStartupEndpointConfig();
  final systemUiInitialization = waitForStartupDependency(
    GenesisSystemUi.initialize(),
    timeout: _startupSystemUiTimeout,
    onTimeout: () {
      debugPrint(
        '[Startup] System UI initialization timed out; continuing startup',
      );
    },
    onError: (error, stackTrace) {
      debugPrint(
        '[Startup] System UI initialization failed; continuing startup: $error',
      );
      debugPrint('[Startup] stacktrace:\n$stackTrace');
    },
  ).whenComplete(AppStartupCoordinator.recordLaunchSystemUiReady);
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
  // Local debug preference loads in parallel without holding the first frame.
  if (kDebugMode) {
    unawaited(purchaseToastDebugSettings.load());
    unawaited(screenTranslationDebugSettings.load());
  }
  final appConfig = await appConfigLoad;
  AppStartupCoordinator.recordLaunchEndpointConfigReady();
  if (appConfig.useMock != true) {
    // Keep the iOS permission flow ahead of service creation (image warm-up,
    // billing and Gateway requests).
    await waitForIosStartupNetwork(
      probeUri: Uri.parse(appConfig.gatewayApiBaseUrl).resolve('v1/time'),
    );
  }
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
    uidReadAlreadyBounded: true,
    loadUid: () async {
      final resolution = await startupUidResolution;
      if (resolution.readFailed) {
        throw StateError('Startup UID read failed');
      }
      return resolution.uid;
    },
  );
  // Publish pending config now; render the page/cache independently of Gateway
  // preparation and config. Config listeners apply confirmed flags when ready.
  unawaited(
    loadStartupAppConfig(
      store: services.appGlobalConfig,
      uidResolution: startupUidResolution,
      collectReady: collectReady.future,
    ),
  );
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
  AppStartupCoordinator.recordLaunchBootstrapReady();
  runApp(
    GenesisApp(services: services, initialIndex: initialLandingPage.index),
  );
}

Future<StartupUidResolution> _resolveStartupUid(UserSessionStore sessionStore) {
  final nativeTiming = <String, Object>{};
  return resolveStartupUid(
    readUid: () => sessionStore is NativeUserSessionStore
        ? sessionStore.readStartupLoginUid(nativeTiming)
        : sessionStore.readLoginUid(),
    nativeTiming: nativeTiming,
    setTelemetryUser: (uid) {
      if (uid == null) {
        GenesisTelemetry.clearUser();
      } else {
        GenesisTelemetry.setUserId(uid);
      }
    },
    recordDiagnostics: AppStartupCoordinator.recordLaunchUidResolution,
  );
}
