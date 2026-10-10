import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/attribution/adjust_device_registration.dart';
import '../../app/bootstrap/app_services_scope.dart';

/// One non-blocking registration for each purchase tab shown by this surface.
class PurchaseAttributionRegistration {
  final Set<int> _requestedTabs = <int>{};

  void schedule(
    BuildContext context, {
    required int tabIndex,
    required int Function() currentTabIndex,
    AdjustDeviceRegistration? registration,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || currentTabIndex() != tabIndex) return;
      final resolved =
          registration ??
          AppServicesScope.maybeRead(context)?.adjustDeviceRegistration;
      if (resolved == null || !_requestedTabs.add(tabIndex)) return;
      // A payment surface may re-read identifiers, but must never await the
      // network request before showing products or accepting store actions.
      unawaited(resolved.register(force: true));
    });
  }
}
