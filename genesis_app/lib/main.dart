import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'components/common/genesis_modal_routes.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appStartedAt = DateTime.now();
  unawaited(
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]),
  );
  final appConfig = await AppEndpointOverrideStore.loadConfig();

  void runGenesisApp() {
    final services = AppBootstrap.createInitialServices(config: appConfig);
    AppStartupCoordinator.configure(startedAt: appStartedAt);
    GenesisSystemUiChrome.applyDefault();
    runApp(GenesisApp(services: services));
  }

  runGenesisApp();
}
