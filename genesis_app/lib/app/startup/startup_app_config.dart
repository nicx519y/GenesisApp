import 'package:flutter/foundation.dart';

import '../../network/api_request_trace_sampling.dart';
import '../config/app_global_config.dart';
import 'app_startup_coordinator.dart';
import 'startup_dependency_guard.dart';
import 'startup_uid_resolution.dart';

/// Starts config in the background while keeping its pending state observable.
/// Gateway signing still prepares server time before sending the config request.
/// The HTTP client's own timeout applies; this work never gates the first frame.
Future<void> loadStartupAppConfig({
  required AppGlobalConfigStore store,
  required Future<StartupUidResolution> uidResolution,
  required Future<void> collectReady,
}) async {
  try {
    await store.refresh(
      resolveUid: () async {
        await waitForStartupDependency(
          collectReady,
          timeout: const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('[Startup] Collect readiness timed out; loading config');
          },
          onError: (error, stackTrace) {
            debugPrint('[Startup] Collect readiness failed: $error');
            debugPrint('[Startup] stacktrace:\n$stackTrace');
          },
        );
        return (await uidResolution).uid;
      },
    );
    ApiRequestTraceSampling.configureForLaunch(
      store.value.apiTraceSamplingRate,
    );
  } catch (error) {
    debugPrint(
      '[Startup] app global config load failed; using defaults: $error',
    );
  } finally {
    AppStartupCoordinator.recordLaunchAppConfigReady();
  }
}
