import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
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
    AppStartupCoordinator.configure(
      startedAt: appStartedAt,
      appVersion: appVersion,
    );
    GenesisSystemUiChrome.applyDefault();
    runApp(GenesisApp(services: services));
  }

  await runGenesisApp();
}
