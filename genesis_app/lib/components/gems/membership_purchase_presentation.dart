import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/membership/subscription_analytics.dart';
import '../../app/membership/membership_purchase_service.dart';
import '../../app/membership/membership_purchase_eligibility.dart';
import '../../network/models/membership_product.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';
import '../auth/login_guard.dart';
import '../common/genesis_action_box.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_modal_routes.dart';
import 'gem_billing_purchase_dialog.dart';

Future<void> showMembershipPurchaseFailure(
  BuildContext context,
  String reason, {
  MembershipProduct? product,
  String? debugInfo,
}) async {
  if (reason == 'downgrade_not_allowed') {
    await showGenesisActionBox<bool>(
      context: context,
      title: 'Notification',
      titleHeight: null,
      titleContent: const Text(
        'Worldo Premium is active in your subscription and does not support downgrades.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: const [GenesisActionBoxAction(label: 'Got It', value: true)],
      showCancel: false,
    );
    return;
  }
  showGenesisToast(
    context,
    membershipPurchaseFailureMessage(
      reason,
      product: product,
      debugInfo: debugInfo,
    ),
  );
}

/// Owns only the dialog for this user's purchase, never background restore UI.
class MembershipPurchasePresentation {
  MembershipPurchasePresentation({
    required this.context,
    required this.service,
    this.requestLogin,
  });

  final BuildContext context;
  final MembershipPurchaseService service;
  final Future<bool> Function(BuildContext)? requestLogin;
  RawDialogRoute<bool>? _route;
  NavigatorState? _navigator;
  StreamSubscription<MembershipCheckoutEvent>? _subscription;
  Completer<bool>? _dialogResult;
  String? _attemptId;
  bool _disposed = false;
  bool _resolved = false;
  bool _closing = false;
  bool _requiresCatalogRefresh = false;

  /// The checkout product credentials held by [MembershipCatalog] were no
  /// longer usable when this attempt started. The caller must refresh the
  /// catalog before accepting another purchase click.
  bool get requiresCatalogRefresh => _requiresCatalogRefresh;

  Future<bool> purchase(
    MembershipProduct product, {
    SubscriptionTracking? tracking,
    MembershipCheckoutPreparation? preparation,
  }) async {
    if (_disposed || _route != null || service.isBusy) {
      if (tracking != null) {
        service.analytics.failed(tracking, 'purchase_in_progress', once: true);
      }
      return false;
    }
    final attemptId = tracking?.id ?? newBillingAttemptId();
    _attemptId = attemptId;
    service.attachCheckoutPresentation(attemptId);
    final state = ValueNotifier(
      GemBillingPurchaseDialogState.processing(attemptId: attemptId),
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    _navigator = navigator;
    _resolved = false;
    _closing = false;
    _requiresCatalogRefresh = false;
    final route = RawDialogRoute<bool>(
      barrierColor: kGenesisModalBarrierColor,
      barrierDismissible: false,
      pageBuilder: (_, _, _) => Center(
        child: GemBillingPurchaseDialog.membership(
          state: state,
          onConfirm: () => _close(true),
        ),
      ),
    );
    _route = route;
    final result = Completer<bool>();
    _dialogResult = result;
    var dialogShown = false;
    void showPurchaseDialog() {
      if (dialogShown || _disposed || result.isCompleted) return;
      dialogShown = true;
      unawaited(
        navigator.push(route).then((confirmed) {
          if (!result.isCompleted) result.complete(confirmed == true);
        }),
      );
    }

    var loginRequired = false;
    _subscription = service.checkoutEvents.listen((event) {
      if (_disposed || _resolved || event.attemptId != attemptId) return;
      switch (event.state) {
        case MembershipCheckoutState.checking:
          return;
        case MembershipCheckoutState.preparing:
        case MembershipCheckoutState.store:
        case MembershipCheckoutState.reporting:
          showPurchaseDialog();
          return;
        case MembershipCheckoutState.completed:
          _resolved = true;
          state.value = GemBillingPurchaseDialogState.success(
            attemptId: attemptId,
            grantedText: '',
          );
          showPurchaseDialog();
          return;
        case MembershipCheckoutState.idle:
          _resolved = true;
          _close(false);
          return;
        case MembershipCheckoutState.loginRequired:
          loginRequired = true;
          _resolved = true;
          _close(false);
          return;
        case MembershipCheckoutState.accepted:
        case MembershipCheckoutState.pending:
        case MembershipCheckoutState.deferred:
        case MembershipCheckoutState.canceled:
        case MembershipCheckoutState.failed:
        case MembershipCheckoutState.rejected:
          _resolved = true;
          // The service emits this internal reason when its in-memory catalog
          // is missing, stale, or no longer matches the displayed offer. It
          // happens before StoreKit/Play is launched.
          _requiresCatalogRefresh = event.reason == 'eligibility_unavailable';
          _close(false);
          if (context.mounted) {
            final debugInfo =
                event.debugInfo ??
                purchaseDebugInfo(
                  'vip.checkout',
                  status: event.state.name,
                  reason: event.reason,
                );
            final reason = event.reason;
            final reportMessage = event.reportMessage;
            if (reportMessage != null) {
              showGenesisToast(
                context,
                purchaseToastMessage(reportMessage, debugInfo: debugInfo),
              );
            } else if (reason != null) {
              unawaited(
                showMembershipPurchaseFailure(
                  context,
                  reason,
                  product: product,
                  debugInfo: debugInfo,
                ),
              );
            } else {
              showGenesisToast(
                context,
                purchaseToastMessage(
                  event.storeFailure?.message ?? _message(event.state),
                  debugInfo: debugInfo,
                ),
              );
            }
          }
      }
    }, onDone: () => _close(false));
    unawaited(
      service
          .purchase(
            product,
            attemptId: attemptId,
            tracking: tracking,
            preparation: preparation,
          )
          .catchError((Object error) {
            if (_disposed || _resolved) return;
            _resolved = true;
            _close(false);
            if (context.mounted) {
              showGenesisToast(
                context,
                purchaseToastMessage(
                  'Purchase failed.',
                  debugInfo: purchaseDebugInfo(
                    'vip.checkout_exception',
                    error: error,
                  ),
                ),
              );
            }
          }),
    );
    try {
      final confirmed = await result.future;
      if (confirmed) await service.confirmGuestPurchase(attemptId);
      if (loginRequired) {
        // The order check finishes before any purchase dialog is pushed. Login
        // ends this click and never automatically starts another purchase.
        if (!_disposed && context.mounted) {
          final login = requestLogin;
          if (login != null) {
            await login(context);
          } else {
            await ensureGenesisLogin(
              context,
              source: LoginSource.membershipPurchase,
            );
          }
        }
      }
      return confirmed;
    } finally {
      _resolved = true;
      unawaited(_subscription?.cancel());
      _subscription = null;
      // The route still renders during its dismissal transition.
      if (dialogShown) {
        await route.completed;
      } else {
        route.dispose();
      }
      state.dispose();
      if (identical(_route, route)) {
        _route = null;
        _dialogResult = null;
        _attemptId = null;
      }
      await service.detachCheckoutPresentation(attemptId);
    }
  }

  String _message(MembershipCheckoutState state) => switch (state) {
    MembershipCheckoutState.canceled => 'Purchase canceled.',
    MembershipCheckoutState.pending => 'Your purchase is pending.',
    MembershipCheckoutState.accepted => 'Your purchase is being confirmed.',
    MembershipCheckoutState.deferred =>
      'Purchase confirmation is delayed. Please check again later.',
    _ => 'Purchase failed.',
  };

  void _close(bool confirmed) {
    final route = _route;
    final navigator = _navigator;
    if (_closing || route == null || navigator == null) {
      return;
    }
    _closing = true;
    if (route.navigator == null) {
      final result = _dialogResult;
      if (result != null && !result.isCompleted) result.complete(confirmed);
      return;
    }
    if (!navigator.mounted || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop(confirmed);
    } else {
      navigator.removeRoute(route, confirmed);
    }
  }

  void dispose() {
    _disposed = true;
    final attemptId = _attemptId;
    if (attemptId != null) service.cancelCheckoutBeforeStore(attemptId);
    unawaited(_subscription?.cancel());
    // Parent disposal can run while the Navigator is locked for a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _close(false));
  }
}
