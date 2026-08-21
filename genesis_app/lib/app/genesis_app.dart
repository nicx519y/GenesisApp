import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/developer_debug_floating_button.dart';
import '../components/internal_build_indicator.dart';
import 'agent_control/agent_control_host.dart';
import 'debug_page_tracker.dart';
import 'genesis_navigator.dart';
import 'telemetry/genesis_telemetry.dart';
import 'version/force_upgrade_gate.dart';
import '../routers/app_router.dart';
import '../network/genesis_http_cache_manager.dart';
import '../ui/genesis_ui.dart';
import 'bootstrap/app_services_scope.dart';
import 'bootstrap/service_registry.dart';
import 'theme/genesis_theme_mode_controller.dart';
import 'theme/genesis_theme_mode_scope.dart';
import 'theme/worldo_theme.dart';

class GenesisApp extends StatefulWidget {
  const GenesisApp({
    super.key,
    this.services,
    this.initialIndex = 0,
    this.themeModeController,
  });

  final AppServices? services;
  final int initialIndex;
  final GenesisThemeModeController? themeModeController;

  @override
  State<GenesisApp> createState() => _GenesisAppState();
}

class _GenesisAppState extends State<GenesisApp> {
  late GenesisThemeModeController _themeModeController;
  late bool _ownsThemeModeController;

  @override
  void initState() {
    super.initState();
    _installThemeModeController(widget.themeModeController);
  }

  @override
  void didUpdateWidget(covariant GenesisApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeModeController == widget.themeModeController) return;
    if (_ownsThemeModeController) _themeModeController.dispose();
    _installThemeModeController(widget.themeModeController);
  }

  void _installThemeModeController(
    GenesisThemeModeController? externalController,
  ) {
    _ownsThemeModeController = externalController == null;
    _themeModeController = externalController ?? GenesisThemeModeController();
  }

  @override
  void dispose() {
    if (_ownsThemeModeController) _themeModeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    GenesisStaticNetworkImageProvider.configureDefaultCacheManager(
      GenesisHttpCacheManager.new,
    );
    var initialRoutePending = true;
    return AppServicesScope(
      services: widget.services ?? ServiceRegistry.build(),
      child: AgentControlHost(
        child: GenesisThemeModeScope(
          controller: _themeModeController,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: _themeModeController,
            builder: (context, themeMode, _) => MaterialApp(
              title: 'Worldo',
              debugShowCheckedModeBanner: false,
              theme: WorldoTheme.light(),
              darkTheme: WorldoTheme.dark(),
              themeMode: themeMode,
              initialRoute: RouteNames.home,
              navigatorKey: genesisNavigatorKey,
              navigatorObservers: [
                genesisRouteObserver,
                genesisPageRouteObserver,
              ],
              onGenerateInitialRoutes: (_) {
                initialRoutePending = false;
                return <Route<dynamic>>[
                  AppRouter.onGenerateRoute(
                    RouteSettings(
                      name: RouteNames.home,
                      arguments: widget.initialIndex,
                    ),
                  ),
                ];
              },
              onGenerateRoute: (settings) {
                if (settings.name == RouteNames.home &&
                    settings.arguments == null &&
                    initialRoutePending) {
                  initialRoutePending = false;
                  return AppRouter.onGenerateRoute(
                    RouteSettings(
                      name: RouteNames.home,
                      arguments: widget.initialIndex,
                    ),
                  );
                }
                return AppRouter.onGenerateRoute(settings);
              },
              builder: (context, child) {
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: GenesisSystemUi.forThemeBrightness(
                    Theme.of(context).brightness,
                  ),
                  child: GenesisUiInteractionScope(
                    onButtonInteraction: (interaction) {
                      GenesisTelemetry.click(
                        actionId: interaction.actionId,
                        component: interaction.component,
                        enabled: interaction.enabled,
                        data: interaction.data,
                      );
                    },
                    child: GenesisTelemetryTapRegion(
                      child: GenesisBottomSystemBarBoundary(
                        child: InternalBuildIndicator(
                          child: ForceUpgradeGate(
                            child: DeveloperDebugFloatingButton(
                              navigatorKey: genesisNavigatorKey,
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
