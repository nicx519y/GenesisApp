import 'dart:async';

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
  final appVersion = await AppMetadataService.appVersion();
  Future<void> runGenesisApp() async {
    final services = AppBootstrap.createInitialServices(config: appConfig);
    Future<void> prepareBeforeRunApp() async {
      await GenesisTelemetry.initialize(
        config: appConfig,
        deviceIdService: services.deviceId,
        appVersion: appVersion,
      );
      WidgetsBinding.instance.addObserver(
        GenesisTelemetryLifecycleObserver(startedAt: appStartedAt),
      );
      GenesisSystemUiChrome.applyDefault();
    }

    await prepareBeforeRunApp();
    runApp(GenesisApp(services: services));
    unawaited(AppBootstrap.warmUp(services));
  }

  await runGenesisApp();
}
