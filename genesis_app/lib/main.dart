import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/service_registry.dart';
import 'app/config/app_config.dart';
import 'app/config/app_endpoint_overrides.dart';
import 'app/genesis_app.dart';
import 'app/startup/app_startup_coordinator.dart';
import 'app/telemetry/genesis_telemetry.dart';
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
  final appConfig = await AppEndpointOverrideStore.loadConfig().timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      debugPrint('[Startup] endpoint override load timed out; using defaults');
      return const AppConfig();
    },
  );

  void runGenesisApp() {
    GenesisTelemetry.prepareCollect(appConfig);
    AppStartupCoordinator.recordStartupFirstReport();
    final services = AppBootstrap.createInitialServices(config: appConfig);
    final initialIndexFuture = _resolveInitialBottomTab(services);
    AppStartupCoordinator.configure(startedAt: appStartedAt);
    GenesisSystemUiChrome.applyDefault();
    unawaited(
      initialIndexFuture.then(
        (initialIndex) =>
            runApp(GenesisApp(services: services, initialIndex: initialIndex)),
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
