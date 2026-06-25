import 'dart:async';

import 'package:alibabacloud_rum_flutter_plugin/alibabacloud_rum_flutter_plugin.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/genesis_app.dart';
import 'app/telemetry/genesis_telemetry.dart';
import 'components/common/genesis_modal_routes.dart';
import 'platform/app/app_metadata_service.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appStartedAt = DateTime.now();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  final appConfig = await AppEndpointOverrideStore.loadConfig();
  final sentryConfig = GenesisSentryConfig.fromAppConfig(appConfig);
  final appVersion = await AppMetadataService.appVersion();
  Future<void> runGenesisApp() async {
    final services = AppBootstrap.createInitialServices(config: appConfig);
    Future<void> prepareBeforeRunApp() async {
      await GenesisTelemetry.initialize(
        config: sentryConfig,
        deviceIdService: services.deviceId,
        appVersion: appVersion,
      );
      WidgetsBinding.instance.addObserver(
        GenesisTelemetryLifecycleObserver(startedAt: appStartedAt),
      );
      GenesisSystemUiChrome.applyDefault();
    }

    final rootWidget = AlibabaCloudActionCapture(
      child: SentryWidget(child: GenesisApp(services: services)),
    );

    await AlibabaCloudRUM().start(
      rootWidget,
      beforeRunApp: prepareBeforeRunApp,
    );
    unawaited(AppBootstrap.warmUp(services));
  }

  if (!sentryConfig.isEnabled) {
    await runGenesisApp();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = sentryConfig.dsn;
    options.environment = sentryConfig.environment;
    options.tracesSampleRate = sentryConfig.parsedTracesSampleRate;
    options.debug = sentryConfig.debug;
    options.sendDefaultPii = false;
    final versionName = appVersion.versionName.trim();
    final buildNumber = appVersion.versionCode.trim();
    final releaseVersion = versionName.isEmpty ? 'unknown' : versionName;
    options.release =
        'worldo@$releaseVersion'
        '${buildNumber.isEmpty ? '' : '+$buildNumber'}';
    if (buildNumber.isNotEmpty) {
      options.dist = buildNumber;
    }
  }, appRunner: runGenesisApp);
}
