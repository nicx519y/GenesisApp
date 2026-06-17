import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'service_registry.dart';

class AppServicesScope extends StatefulWidget {
  static AppServices? _fallbackServices;
  const AppServicesScope({
    super.key,
    required this.services,
    required this.child,
  });

  final AppServices services;
  final Widget child;

  static AppServices of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppServicesInheritedScope>();
    if (scope != null) return scope.services;
    return _fallbackServices ??= ServiceRegistry.build();
  }

  static AppServices read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<_AppServicesInheritedScope>();
    final scope = element?.widget as _AppServicesInheritedScope?;
    if (scope != null) return scope.services;
    return _fallbackServices ??= ServiceRegistry.build();
  }

  static AppServices replaceWithConfig(BuildContext context, AppConfig config) {
    final current = read(context);
    final updated = ServiceRegistry.rebuildFrom(current, config: config);
    final element = context
        .getElementForInheritedWidgetOfExactType<_AppServicesInheritedScope>();
    final scope = element?.widget as _AppServicesInheritedScope?;
    final state = scope?.scopeState;
    if (state != null) {
      state.replaceServices(updated);
    } else {
      _fallbackServices = updated;
    }
    return updated;
  }

  @override
  State<AppServicesScope> createState() => _AppServicesScopeState();
}

class _AppServicesScopeState extends State<AppServicesScope> {
  late AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = widget.services;
  }

  @override
  void didUpdateWidget(AppServicesScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.services, oldWidget.services)) {
      _services = widget.services;
    }
  }

  void replaceServices(AppServices services) {
    if (identical(_services, services)) return;
    setState(() => _services = services);
  }

  @override
  Widget build(BuildContext context) {
    return _AppServicesInheritedScope(
      services: _services,
      scopeState: this,
      child: widget.child,
    );
  }
}

class _AppServicesInheritedScope extends InheritedWidget {
  const _AppServicesInheritedScope({
    required this.services,
    required this.scopeState,
    required super.child,
  });

  final AppServices services;
  final _AppServicesScopeState scopeState;

  @override
  bool updateShouldNotify(_AppServicesInheritedScope oldWidget) {
    return !identical(services, oldWidget.services);
  }
}
