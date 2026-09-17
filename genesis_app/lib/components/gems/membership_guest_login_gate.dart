import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/membership/membership_purchase_service.dart';
import '../../routers/app_router.dart';
import '../auth/login_guard.dart';

/// Keeps paid guest purchases actionable after leaving a page or restarting.
class MembershipGuestLoginGate extends StatefulWidget {
  const MembershipGuestLoginGate({
    super.key,
    required this.service,
    required this.navigatorKey,
    required this.child,
    this.requestLogin,
    this.blocked,
  });

  final MembershipPurchaseService? service;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final Future<bool> Function(BuildContext)? requestLogin;
  final ValueListenable<bool>? blocked;

  @override
  State<MembershipGuestLoginGate> createState() =>
      _MembershipGuestLoginGateState();
}

class _MembershipGuestLoginGateState extends State<MembershipGuestLoginGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.service?.guestLoginRequestId.addListener(_schedule);
    widget.blocked?.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(MembershipGuestLoginGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.blocked, oldWidget.blocked)) {
      oldWidget.blocked?.removeListener(_schedule);
      widget.blocked?.addListener(_schedule);
      _schedule();
    }
    if (!identical(widget.service, oldWidget.service)) {
      oldWidget.service?.guestLoginRequestId.removeListener(_schedule);
      widget.service?.guestLoginRequestId.addListener(_schedule);
      _schedule();
    }
  }

  void _schedule() {
    if (!mounted || _showing || widget.blocked?.value == true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showing) unawaited(_show());
    });
    // Secure storage may finish while Home is idle, with no frame pending.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _show() async {
    if (widget.blocked?.value == true) return;
    final service = widget.service;
    final requestId = service?.guestLoginRequestId.value;
    final context = widget.navigatorKey.currentState?.overlay?.context;
    if (service == null || requestId == null || context == null) return;
    _showing = true;
    try {
      // The active checkout owns its success/OK dialog. A cached purchase on
      // startup goes straight to mandatory login, even without its old page.
      if (!mounted || !context.mounted) return;
      final login = widget.requestLogin;
      final loggedIn = login != null
          ? await login(context)
          : await ensureGenesisLogin(
              context,
              source: LoginSource.membershipClaim,
              continueAfterLogin: true,
              isDismissible: false,
              linkPurchasedMembership: true,
            );
      if (loggedIn) {
        if (mounted && identical(service, widget.service)) {
          // Finish the guest checkout journey immediately after login. Claim
          // retries belong to the app service and must outlive the purchase UI.
          unawaited(
            widget.navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
              RouteNames.me,
              (_) => false,
            ),
          );
        }
        await service.recover();
      }
    } finally {
      _showing = false;
      if (mounted && service.guestLoginRequestId.value != null) _schedule();
    }
  }

  @override
  void dispose() {
    widget.blocked?.removeListener(_schedule);
    widget.service?.guestLoginRequestId.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
