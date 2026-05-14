import 'package:flutter/widgets.dart';

import 'service_registry.dart';

class AppServicesScope extends InheritedWidget {
  static AppServices? _fallbackServices;
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppServicesScope>();
    if (scope != null) return scope.services;
    return _fallbackServices ??= ServiceRegistry.build();
  }

  static AppServices read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppServicesScope>();
    final scope = element?.widget as AppServicesScope?;
    if (scope != null) return scope.services;
    return _fallbackServices ??= ServiceRegistry.build();
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) {
    return !identical(services, oldWidget.services);
  }
}
