import 'package:flutter/material.dart';

import '../components/developer_debug_floating_button.dart';
import 'agent_control/agent_control_host.dart';
import 'debug_page_tracker.dart';
import 'genesis_navigator.dart';
import 'telemetry/genesis_telemetry.dart';
import 'version/force_upgrade_gate.dart';
import '../routers/app_router.dart';
import '../ui/genesis_ui.dart';
import 'bootstrap/app_services_scope.dart';
import 'bootstrap/service_registry.dart';

class GenesisApp extends StatelessWidget {
  const GenesisApp({super.key, this.services});

  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: services ?? ServiceRegistry.build(),
      child: AgentControlHost(
        child: MaterialApp(
          title: 'Worldo',
          debugShowCheckedModeBanner: false,
          theme: GenesisTheme.light(),
          initialRoute: RouteNames.home,
          navigatorKey: genesisNavigatorKey,
          navigatorObservers: [genesisRouteObserver],
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (context, child) {
            return GenesisTelemetryTapRegion(
              child: GenesisBottomSystemBarBoundary(
                child: ForceUpgradeGate(
                  child: DeveloperDebugFloatingButton(
                    navigatorKey: genesisNavigatorKey,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
