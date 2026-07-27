import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/developer_debug_floating_button.dart';
import '../routers/app_router.dart';
import '../ui/genesis_ui.dart';
import 'agent_control/agent_control_host.dart';
import 'bootstrap/app_services_scope.dart';
import 'bootstrap/service_registry.dart';
import 'debug_page_tracker.dart';
import 'genesis_navigator.dart';
import 'telemetry/genesis_telemetry.dart';
import 'version/force_upgrade_gate.dart';

class GenesisApp extends StatefulWidget {
  const GenesisApp({
    super.key,
    this.services,
    this.initialIndex = 0,
    this.colorController,
  });

  final AppServices? services;
  final int initialIndex;
  final GenesisColorController? colorController;

  @override
  State<GenesisApp> createState() => _GenesisAppState();
}

class _GenesisAppState extends State<GenesisApp> {
  late GenesisColorController _colorController;
  late AppServices _services;
  late bool _ownsColorController;
  bool _initialRoutePending = true;

  @override
  void initState() {
    super.initState();
    _services = widget.services ?? ServiceRegistry.build();
    _installColorController(widget.colorController);
  }

  @override
  void didUpdateWidget(covariant GenesisApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.services, widget.services) &&
        widget.services != null) {
      _services = widget.services!;
    }
    if (!identical(oldWidget.colorController, widget.colorController)) {
      if (_ownsColorController) _colorController.dispose();
      _installColorController(widget.colorController);
    }
  }

  void _installColorController(GenesisColorController? controller) {
    _ownsColorController = controller == null;
    _colorController = controller ?? GenesisColorController();
  }

  @override
  void dispose() {
    if (_ownsColorController) _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorController,
      builder: (context, _) {
        GenesisColorRuntime.activate(
          _colorController.configFor(_colorController.activeBrightness),
          _colorController.revision,
        );
        return GenesisColorScope(
          controller: _colorController,
          child: AppServicesScope(
            services: _services,
            child: AgentControlHost(
              child: MaterialApp(
                title: 'Worldo',
                debugShowCheckedModeBanner: false,
                theme: GenesisTheme.light(
                  config: _colorController.lightConfig,
                  revision: _colorController.revision,
                ),
                darkTheme: GenesisTheme.dark(
                  config: _colorController.darkConfig,
                  revision: _colorController.revision,
                ),
                themeMode: _colorController.mode,
                initialRoute: RouteNames.home,
                navigatorKey: genesisNavigatorKey,
                navigatorObservers: [
                  genesisRouteObserver,
                  genesisPageRouteObserver,
                ],
                onGenerateRoute: (settings) {
                  if (settings.name == RouteNames.home &&
                      settings.arguments == null &&
                      _initialRoutePending) {
                    _initialRoutePending = false;
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
                  final theme = Theme.of(context);
                  final colors = GenesisSemanticColors.of(context);
                  final dark = theme.brightness == Brightness.dark;
                  final surface = colors.color(GenesisColorToken.surface);
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: surface,
                      statusBarIconBrightness: dark
                          ? Brightness.light
                          : Brightness.dark,
                      statusBarBrightness: dark
                          ? Brightness.dark
                          : Brightness.light,
                      systemNavigationBarColor: surface,
                      systemNavigationBarIconBrightness: dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarDividerColor: colors.color(
                        GenesisColorToken.border,
                      ),
                    ),
                    child: GenesisTelemetryTapRegion(
                      child: GenesisBottomSystemBarBoundary(
                        child: ForceUpgradeGate(
                          child: DeveloperDebugFloatingButton(
                            navigatorKey: genesisNavigatorKey,
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
