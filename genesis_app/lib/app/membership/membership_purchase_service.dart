import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../telemetry/firebase_analytics_monitoring.dart';
import '../../network/models/membership_product.dart';
import '../../network/models/membership_purchase.dart';
import '../../network/models/membership_claim.dart';
import '../../network/models/membership_guest_purchase_check.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/membership_checkout_platform.dart';
import '../../platform/billing/membership_pending_store.dart';
import '../../platform/billing/membership_store_purchase.dart';
import '../../platform/billing/membership_guest_claim_record.dart';
import '../../platform/billing/membership_guest_claim_proof.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';
import 'membership_purchase_eligibility.dart';
import 'membership_access_store.dart';
import 'membership_store_failure.dart';
import 'subscription_analytics.dart';
import 'subscription_failure_reason.dart';

part 'membership_checkout_preparation.dart';
part 'membership_purchase_tracking.dart';
part 'membership_guest_claim.dart';
part 'membership_guest_startup_check.dart';

const _appleResultCallbackTimeout = Duration(seconds: 10);

enum MembershipCheckoutState {
  idle,
  preparing,
  store,
  pending,
  reporting,
  completed,
  accepted,
  rejected,
  canceled,
  failed,
  deferred,
}

class MembershipCheckoutEvent {
  const MembershipCheckoutEvent({
    required this.attemptId,
    required this.state,
    this.reason,
    this.debugInfo,
    this.storeFailure,
    this.reportMessage,
  });
  final String attemptId;
  final MembershipCheckoutState state;
  final String? reason;
  final String? debugInfo;
  final MembershipStoreFailure? storeFailure;
  // Report feedback is separate from local eligibility guard codes.
  final String? reportMessage;
}

/// Owns subscription attempts and receipts independently of the Gems queue/UI.
class MembershipPurchaseService with WidgetsBindingObserver {
  MembershipPurchaseService({
    required this.platform,
    required this.store,
    required this.readLoginUid,
    required this.loadAccountUuid,
    required this.prepareGuest,
    required this.reportPurchase,
    required this.queryPurchases,
    required this.provider,
    required this.readCheckoutProducts,
    SubscriptionAnalytics? analytics,
    this.ensureStoreListening,
    this.otherPurchaseBusy,
    this.readMembershipAccess,
    this.refreshWallet,
    this.claimGuest,
    this.loadSignedTransaction,
    this.queryRestorePurchases,
    this.checkGuestPurchase,
    this.discoverGuestPurchases,
    this.retryDelay = const Duration(seconds: 15),
    this.attemptTimeout = const Duration(seconds: 90),
    this.guestRecoveryTimeout = const Duration(seconds: 15),
  }) : analytics = analytics ?? SubscriptionAnalytics();

  final SubscriptionAnalytics analytics;
  final Map<String, SubscriptionTracking> _attemptTracking = {};

  final MembershipCheckoutPlatform platform;
  final MembershipPendingStore store;
  final Future<String?> Function() readLoginUid;
  final Future<String> Function() loadAccountUuid;
  final Future<MembershipGuestIdentity> Function() prepareGuest;
  final Future<MembershipPurchaseReport> Function(MembershipPurchaseRequest)
  reportPurchase;
  final Future<List<BillingPurchase>> Function() queryPurchases;
  final MembershipProvider provider;
  final Future<MembershipProductList> Function() readCheckoutProducts;
  final Future<void> Function()? ensureStoreListening;

  final ValueNotifier<int> catalogRevision = ValueNotifier(0);
  final _debugStoreOrderId = ValueNotifier<String?>(null);
  String? _debugAttemptId;

  /// Latest store order number from a checkout in this session, debug only.
  ValueListenable<String?> get debugStoreOrderId => _debugStoreOrderId;
  final bool Function()? otherPurchaseBusy;
  final Future<MembershipAccessState> Function()? readMembershipAccess;
  final Future<void> Function()? refreshWallet;
  final Future<MembershipClaimResult> Function(MembershipClaimRequest)?
  claimGuest;
  final Future<String> Function(MembershipClaimRequest)? loadSignedTransaction;
  final Future<MembershipGuestPurchaseCheck> Function(String accountUuid)?
  checkGuestPurchase;
  final Future<List<MembershipStorePurchase>> Function()?
  discoverGuestPurchases;
  final Set<String> _currentGuestLoginUuids = {};
  final Set<String> _guestStoreEvents = {};
  final Set<String> _unpaidGuestCleanup = {};
  bool _guestStartupResolved = false;
  bool _guestStartupRefreshNeeded = false;
  int _guestStartupRevision = 0;
  int _guestStartupRetryCount = 0;
  Timer? _guestStartupRetry;
  DateTime? _guestStartupCheckedAt;
  final Map<String, MembershipGuestPurchaseCheck> _guestOrderChecks = {};
  Future<void>? _guestHomeCheck;
  bool _guestHomeSeen = false;

  /// Ownership snapshots only; never use these as active VIP entitlement.
  Map<String, MembershipGuestPurchaseCheck> get guestOrderChecks =>
      Map.unmodifiable(_guestOrderChecks);

  /// Checks a paid cached identity, or the latest owned store subscription.
  Future<void> checkGuestPurchasesOnHome() => _checkGuestPurchasesOnHome();
  final Map<String, String> _signedTransactions = {};
  // Reuse the exact guest report body for claim after login, including Apple JWS.
  // This stays in memory across login and is not a report retry queue.
  final Map<String, MembershipPurchaseRequest> _guestPurchaseRequests = {};
  final ValueNotifier<String?> guestLoginRequestId = ValueNotifier(null);
  final Set<String> _presentedAttempts = {};
  final Map<String, MembershipGuestClaimRecord> _guestClaims = {};
  final Set<String> _pendingGuestClaimWrites = {};
  final Map<String, _MembershipClaimRetry> _claimRetries = {};
  final Map<String, int> _claimWalletRefreshSessions = {};
  final Future<List<BillingPurchase>> Function(Set<String>)?
  queryRestorePurchases;
  final Duration retryDelay;
  final Duration attemptTimeout;
  final Duration guestRecoveryTimeout;
  final _checkoutEvents = StreamController<MembershipCheckoutEvent>.broadcast();
  Stream<MembershipCheckoutEvent> get checkoutEvents => _checkoutEvents.stream;
  final Map<String, _MembershipCheckoutWait> _checkoutWaits = {};
  final ValueNotifier<MembershipCheckoutState> state = ValueNotifier(
    MembershipCheckoutState.idle,
  );
  final Map<String, MembershipPurchaseRecord> _records = {};
  // Consumed by one callback-driven operation, regardless of business outcome
  // or technical failure. Never persisted as a report queue.
  final Set<String> _reportedRequestIds = {};
  Future<void>? _loading;
  Future<void>? _recovery;
  bool _recoverAgain = false;
  Future<void> _events = Future.value();
  Timer? _retry;
  String? _activeRequestId;
  bool _busy = false;
  bool _disposed = false;
  bool _observing = false;
  int _session = 0;
  int _retryCount = 0;

  bool get isBusy => _busy;

  /// Wait for this login's guest claim attempt and its post-claim wallet refresh.
  /// False means binding is unresolved, not that the user is a non-member.
  Future<bool> waitForGuestClaim() async {
    final session = _session;
    final uid = await readLoginUid();
    if (_disposed || session != _session) return false;
    if (uid == null) return true;
    await _load();
    if (_disposed || session != _session) return false;

    bool needsSync() {
      for (final claim in _guestClaims.values) {
        if (claim.hasPurchase &&
            (claim.ownerUid == uid ||
                claim.ownerUid == null && claim.autoClaimAllowed) &&
            (claim.status != 'completed' ||
                _claimWalletRefreshSessions[claim.guest.accountUuid] !=
                    session)) {
          return true;
        }
      }
      // A paid receipt may have survived a failed claim-cache write.
      return _records.values.any(
        (record) =>
            record.guest != null &&
            record.paid &&
            record.hasReceipt &&
            record.reportStatus != 'rejected' &&
            !_guestClaims.containsKey(record.guest!.accountUuid),
      );
    }

    if (!needsSync()) return true;
    var pending = recover();
    while (true) {
      await pending;
      if (_disposed || session != _session || await readLoginUid() != uid) {
        return false;
      }
      // A recovery begun before login queues a new pass for the new session.
      final next = _recovery;
      if (next == null || identical(next, pending)) break;
      pending = next;
    }
    return !needsSync();
  }

  void attachCheckoutPresentation(String requestId) {
    _presentedAttempts.add(requestId);
  }

  Future<void> detachCheckoutPresentation(String requestId) async {
    _presentedAttempts.remove(requestId);
    await _refreshGuestLoginRequest();
    if (_guestHomeSeen) unawaited(checkGuestPurchasesOnHome());
  }

  bool hasAcknowledgedGuestPurchase(String requestId) =>
      _guestClaims[_records[requestId]?.guest?.accountUuid]?.loginRequired ??
      false;

  Future<void> confirmGuestPurchase(String requestId) async {
    await _serialize(() async {
      final purchase = _records[requestId];
      final claim = _guestClaims[purchase?.guest?.accountUuid];
      if (_disposed || claim == null || purchase?.reportStatus != 'completed') {
        return;
      }
      try {
        _currentGuestLoginUuids.add(claim.guest.accountUuid);
        await _saveGuestClaim(claim.copyWith(loginRequired: true));
      } catch (error) {
        _scheduleGuestMaintenance();
        _log('guest login persistence deferred', error);
      }
    });
  }

  Future<void> start() async {
    if (_disposed) return;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await recover();
  }

  Future<void> _load() async {
    if (_loading != null) return _loading!;
    final task = () async {
      // The login gate depends only on the guest cache, not receipt recovery.
      for (final record in await store.loadGuestClaims()) {
        _guestClaims[record.guest.accountUuid] = record;
      }
      await _refreshGuestLoginRequest();
      for (final record in await store.loadConfirmedReceipts()) {
        if (record.guest != null) {
          _records[record.requestId] = record;
          _reportedRequestIds.add(record.requestId);
        } else {
          await store.complete(record);
        }
      }
      // Retire legacy report queues without issuing any network report. Guest
      // receipts remain separate proof for login/claim, never report recovery.
      for (final record in await store.loadAll()) {
        if (record.guest != null && record.paid && record.hasReceipt) {
          _records[record.requestId] = record;
          _reportedRequestIds.add(record.requestId);
        }
        await store.complete(record);
      }
      await _repairLegacyGuestClaimReferences();
      for (final record in await store.loadRestores()) {
        await store.removeRestore(record.requestId);
      }
    }();
    _loading = task;
    try {
      await task;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> _save(MembershipPurchaseRecord record) async {
    // Checkout attempts and successful history live only in this process.
    record = record.copyWith(tracking: _trackingFor(record));
    _records[record.requestId] = record;
  }

  /// Preload only the store product for a fresh, visible subscription page.
  /// Purchase identity is obtained only after an explicit purchase click.
  /// Failure is silent; a real click retries through the normal checkout path.
  MembershipCheckoutPreparation? prepareCheckout(
    MembershipProduct product, {
    VoidCallback? onExpired,
  }) {
    if (_disposed || product.provider != provider) {
      return null;
    }
    final ticket = MembershipCheckoutPreparation._(
      this,
      _session,
      catalogRevision.value,
      onExpired,
    );
    ticket._future = () async {
      try {
        final results = await Future.wait<Object?>([
          Future<void>.sync(() async {
            await ensureStoreListening?.call();
          }),
          _load(),
          readLoginUid(),
          readCheckoutProducts(),
        ], eagerError: true);
        if (!ticket._usable ||
            ticket._session != _session ||
            ticket._revision != catalogRevision.value ||
            _disposed) {
          return null;
        }
        final uid = results[2] as String?;
        final products = results[3] as MembershipProductList;
        final matches = products.products.where(
          (p) =>
              p.provider == provider &&
              p.planCode == product.planCode &&
              p.storeProductId == product.storeProductId &&
              p.basePlanId == product.basePlanId &&
              p.offerId == product.offerId,
        );
        if (matches.length != 1) return null;
        final prepared = await _prepareStoreProduct(
          uid,
          products,
          matches.single,
        );
        if (!ticket._usable ||
            ticket._session != _session ||
            ticket._revision != catalogRevision.value ||
            _disposed) {
          return null;
        }
        ticket._markReady();
        return prepared;
      } catch (_) {
        ticket.invalidate();
        return null;
      }
    }();
    return ticket;
  }

  Future<void> purchase(
    MembershipProduct product, {
    String? attemptId,
    SubscriptionTracking? tracking,
    MembershipCheckoutPreparation? preparation,
  }) async {
    final startedAt = DateTime.now();
    attemptId ??= newBillingAttemptId();
    if (_disposed) return;
    _attemptTracking[attemptId] =
        tracking ??
        SubscriptionTracking.recovery('${provider.name}:attempt:$attemptId');
    if (_busy || (otherPurchaseBusy?.call() ?? false)) {
      _checkoutFailure(attemptId, 'purchase_in_progress');
      _emitCheckout(
        MembershipCheckoutState.failed,
        attemptId,
        debugInfo: purchaseDebugInfo(
          'vip.precheck',
          reason: 'purchase_in_progress',
        ),
      );
      return;
    }
    final id = attemptId;
    _busy = true;
    _activeRequestId = id;
    final session = _session;
    final wait = _MembershipCheckoutWait();
    var stage = 'precheck';
    Object? preparationError;
    _checkoutWaits[id] = wait;
    bool isCurrent() =>
        !_disposed &&
        session == _session &&
        _activeRequestId == id &&
        identical(_checkoutWaits[id], wait) &&
        !wait.storeCallbackReceived;
    void onTimeout() {
      if (!isCurrent() || wait.storeHandedOff) return;
      analytics.timeout(_attemptTracking[id]!, 'prepare');
      _release(id);
      _setState(
        MembershipCheckoutState.deferred,
        attemptId: id,
        debugInfo: purchaseDebugInfo('vip.$stage', reason: 'prepare_timeout'),
      );
    }

    bool canContinue() {
      if (!isCurrent()) return false;
      if (!wait.storeHandedOff &&
          DateTime.now().difference(startedAt) >= attemptTimeout) {
        onTimeout();
        return false;
      }
      return true;
    }

    bool onStoreHandoff() {
      if (!canContinue()) return false;
      wait.storeHandedOff = true;
      wait.timer?.cancel();
      wait.timer = null;
      return true;
    }

    Future<bool> canContinueForOwner(String? uid) async {
      if (!canContinue()) return false;
      final currentUid = await readLoginUid();
      if (!canContinue()) return false;
      if (currentUid == uid) return true;
      _checkoutFailure(id, 'session_changed');
      _release(id);
      _setState(MembershipCheckoutState.idle, attemptId: id);
      return false;
    }

    final elapsed = DateTime.now().difference(startedAt);
    wait.timer = Timer(
      elapsed < attemptTimeout ? attemptTimeout - elapsed : Duration.zero,
      onTimeout,
    );
    _setState(MembershipCheckoutState.preparing, attemptId: id);
    Future<void> runCheckout() async {
      try {
        if (product.provider != provider) {
          throw StateError('membership_provider_mismatch');
        }
        // Subscriptions launch through the platform directly, while their
        // results arrive through the shared billing service. Never launch
        // without first starting that listener, including after replacement.
        stage = 'start_store_listener';
        await ensureStoreListening?.call();
        if (!canContinue()) return;
        stage = 'load_local_orders';
        await _load();
        if (!canContinue()) return;
        stage = 'read_session';
        final uid = await readLoginUid();
        if (!canContinue()) return;
        stage = 'check_membership';
        final access = product.isYearly
            ? null
            : await readMembershipAccess?.call();
        if (!await canContinueForOwner(uid)) return;
        if (access != null &&
            access.ownerUid == uid &&
            membershipIsDowngrade(product, access)) {
          throw const MembershipPurchaseBlocked('downgrade_not_allowed');
        }
        final MembershipProductList products;
        stage = 'read_catalog';
        try {
          products = await readCheckoutProducts();
        } catch (error) {
          preparationError = error;
          throw const MembershipPurchaseBlocked('eligibility_unavailable');
        }
        if (!await canContinueForOwner(uid)) return;
        final matches = products.products.where(
          (p) => p.provider == provider && p.planCode == product.planCode,
        );
        if (matches.length != 1) {
          throw const MembershipPurchaseBlocked('eligibility_unavailable');
        }
        final current = matches.single;
        if (current.storeProductId != product.storeProductId ||
            current.basePlanId != product.basePlanId ||
            current.offerId != product.offerId) {
          throw const MembershipPurchaseBlocked('eligibility_unavailable');
        }
        product = current;
        late final Object nativeProduct;
        late final MembershipGuestIdentity? guest;
        late final String uuid;
        stage = 'prepare_store_checkout';
        try {
          // Product prewarming must never create guest identities. Only this
          // purchase click fetches the UUID, in parallel with the store query.
          final results = await Future.wait<Object?>([
            () async {
              final reusable = await _takeCheckoutPreparation(
                preparation,
                uid,
                products,
                product,
              );
              if (!await canContinueForOwner(uid)) return null;
              return reusable ??
                  await _prepareStoreProduct(uid, products, product);
            }(),
            _prepareCheckoutIdentity(uid, products),
          ], eagerError: true);
          if (!await canContinueForOwner(uid)) return;
          final prepared = results[0] as _PreparedMembershipProduct?;
          if (prepared == null) return;
          final identity = results[1] as _CheckoutIdentity;
          nativeProduct = prepared.nativeProduct;
          guest = identity.guest;
          uuid = identity.uuid;
        } on _CheckoutPreparationFailure catch (failure) {
          stage = failure.stage;
          throw failure.error;
        }
        if (!await canContinueForOwner(uid)) return;
        // A page refresh can finish while store or identity preparation waits.
        // Re-read the in-memory catalog, never a new products API request.
        stage = 'read_catalog';
        final latestProducts = await readCheckoutProducts();
        if (!await canContinueForOwner(uid)) return;
        if (!latestProducts.products.any(
          (p) =>
              p.provider == product.provider &&
              p.planCode == product.planCode &&
              p.storeProductId == product.storeProductId &&
              p.basePlanId == product.basePlanId &&
              p.offerId == product.offerId &&
              p.priceAmount == product.priceAmount &&
              p.priceCurrencyCode == product.priceCurrencyCode,
        )) {
          throw const MembershipPurchaseBlocked('eligibility_unavailable');
        }
        final record = MembershipPurchaseRecord(
          requestId: id,
          tracking: _attemptTracking[id],
          product: product,
          accountUuid: uuid,
          ownerUid: uid,
          guest: guest,
        );
        // Retain the selected plan in memory until the store callback arrives.
        stage = 'prepare_order';
        await _save(record);
        if (!await canContinueForOwner(uid)) return;
        final purchaseGuest = guest;
        if (purchaseGuest != null) {
          stage = 'persist_guest_identity';
          await _serialize(() async {
            if (!await canContinueForOwner(uid)) return;
            final previous = _guestClaims[purchaseGuest.accountUuid];
            if (previous == null || previous.status == 'completed') {
              // Identity only: no paid order, login request or claim permission.
              await _saveGuestClaim(
                MembershipGuestClaimRecord(
                  guest: purchaseGuest,
                  autoClaimAllowed: false,
                  tracking: _attemptTracking[id],
                ),
              );
            }
          });
          if (!await canContinueForOwner(uid)) return;
          _invalidateGuestStartupCheck();
        }
        _setState(MembershipCheckoutState.store, attemptId: id);
        wait.launchRequested = true;
        stage = 'launch_store';
        final launchClock = Stopwatch()..start();
        final launched = await platform
            .launch(
              nativeProduct,
              uuid,
              onStoreHandoff: onStoreHandoff,
              checkoutAttemptId: id,
            )
            .whenComplete(() {
              if (kDebugMode) {
                debugPrint(
                  '[Membership][checkout_timing] stage=launch_store elapsed_ms=${launchClock.elapsedMilliseconds} click_elapsed_ms=${DateTime.now().difference(startedAt).inMilliseconds}',
                );
              }
            });
        if (!canContinue()) return;
        if (!launched) {
          throw const BillingPlatformException('membership_launch_rejected');
        }
        if (provider == MembershipProvider.apple) {
          // StoreKit's purchase Future returns after the user's store flow has
          // ended. Its stream callback can still arrive on a separate channel.
          // Bound only that delivery/matching wait, never time in Apple's UI.
          wait.storeResultReturned = true;
          wait.timer?.cancel();
          wait.timer = Timer(_appleResultCallbackTimeout, () {
            if (!isCurrent()) return;
            analytics.timeout(_attemptTracking[id]!, 'store_callback');
            _release(id);
            _setState(
              MembershipCheckoutState.deferred,
              attemptId: id,
              debugInfo: purchaseDebugInfo(
                'vip.store_result',
                reason: 'store_callback_missing',
              ),
            );
            // Keep the original attempt/identity for a delayed valid receipt.
            // This is an unconfirmed result, not a new purchase or a failure.
          });
        }
      } catch (error) {
        // Expired operations and completed callbacks cannot overwrite a newer UI.
        if (!canContinue()) return;
        _checkoutFailure(
          id,
          _preparationFailure(preparationError ?? error, stage),
        );
        final record = _records[attemptId];
        if (record != null && record.state == 'prepared') {
          try {
            await _save(record.copyWith(state: 'error'));
          } catch (_) {}
        }
        if (!canContinue()) return;
        _release(attemptId);
        final storeFailure = membershipStoreFailure(provider, error);
        if (record?.guest != null &&
            !record!.paid &&
            !record.hasReceipt &&
            (storeFailure?.canceled == true ||
                !wait.launchRequested ||
                error is BillingPlatformException &&
                    error.code == 'membership_launch_rejected')) {
          await _serialize(() async {
            final current = _records[attemptId];
            if (current == null || current.paid || current.hasReceipt) return;
            await _save(current.copyWith(state: 'canceled'));
            await _discardUnpurchasedGuestIdentity(current.accountUuid);
          });
        }
        _setState(
          storeFailure?.canceled == true
              ? MembershipCheckoutState.canceled
              : MembershipCheckoutState.failed,
          attemptId: id,
          storeFailure: storeFailure,
          reason: error is MembershipPurchaseBlocked ? error.reason : null,
          debugInfo: purchaseDebugInfo(
            'vip.$stage',
            status: 'failed',
            reason: error is MembershipPurchaseBlocked ? error.reason : null,
            error: preparationError ?? error,
          ),
        );
        _log('launch failed', error);
      } finally {
        // A delayed pre-launch write must not leave a recoverable prepared order.
        final record = _records[id];
        if (!wait.launchRequested &&
            record != null &&
            record.state == 'prepared' &&
            !record.hasReceipt) {
          try {
            await _save(record.copyWith(state: 'canceled'));
          } catch (error) {
            _log('unlaunched checkout cleanup deferred', error);
          }
        }
      }
    }

    // Release the caller even if the platform or identity request never returns.
    await Future.any<void>([runCheckout(), wait.done.future]);
  }

  void _catalogChanged() {
    if (!_disposed) {
      catalogRevision.value++;
      if (_guestHomeSeen && checkGuestPurchase != null) {
        _invalidateGuestStartupCheck();
        unawaited(checkGuestPurchasesOnHome());
      }
    }
  }

  /// Returns true when a callback belongs to subscriptions, before Gems sees it.
  Future<bool> interceptPurchase(BillingPurchase purchase) async {
    return _serialize(() async {
      try {
        await _load();
        if (kDebugMode && provider == MembershipProvider.apple) {
          final active = _records[_activeRequestId];
          final transaction = purchase.transactionId;
          final suffix = transaction.length > 6
              ? transaction.substring(transaction.length - 6)
              : transaction;
          debugPrint(
            '[Membership][store_callback] status=${purchase.status.name} '
            'product=${purchase.productId} transaction_suffix=$suffix '
            'purchase_time=${purchase.purchaseTime} '
            'active=${active != null} '
            'direct_result=${purchase.checkoutAttemptId != null} '
            'same_product=${active?.product.storeProductId == purchase.productId}',
          );
        }
        if (purchase.productId.isEmpty) {
          final active = _records[_activeRequestId];
          if (active == null) return false;
          await _handle(purchase, productId: active.product.storeProductId);
          return true;
        }
        final known = _records.values.any(
          (r) => r.product.storeProductId == purchase.productId,
        );
        if (!known && !await platform.isSubscription(purchase.productId)) {
          return false;
        }
        await _handle(purchase);
      } catch (error) {
        _setState(MembershipCheckoutState.deferred);
        _log('callback deferred', error);
      }
      return true;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final previous = _events;
    final task = () async {
      await previous;
      return action();
    }();
    _events = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> _handle(BillingPurchase purchase, {String? productId}) async {
    productId ??= purchase.productId;
    if (_disposed || purchase.provider.apiValue != provider.name) return;
    final sourceId = provider == MembershipProvider.apple
        ? purchase.checkoutAttemptId
        : null;
    final sourceAttempt = sourceId == null ? null : _records[sourceId];
    // A direct StoreKit result belongs only to its original call, including
    // when it arrives after timeout. Never attach it to a newer checkout.
    if (sourceId != null &&
        (sourceAttempt == null ||
            sourceAttempt.product.storeProductId != productId)) {
      return;
    }
    MembershipPurchaseRecord? record;
    final candidates = _records.values
        .where(
          (r) =>
              r.product.storeProductId == productId &&
              !r.replacesPurchaseToken(purchase.purchaseToken),
        )
        .toList();
    MembershipPurchaseRecord? tokenMatch;
    for (final candidate in candidates.reversed) {
      if (provider == MembershipProvider.google) {
        if (purchase.purchaseToken.isEmpty ||
            candidate.purchaseToken != purchase.purchaseToken) {
          continue;
        }
        tokenMatch ??= candidate;
      }
      if (purchase.transactionId.isNotEmpty &&
          candidate.transactionId == purchase.transactionId) {
        record = candidate;
        break;
      }
    }
    // Prefer the exact renewal transaction so a late older callback stays deduplicated.
    record ??= tokenMatch;
    // A correlated StoreKit result is the outcome of this exact purchase call.
    // Send its original proof to the server even when appAccountToken differs
    // from the requested UUID; receipt ownership is not a client eligibility gate.
    record ??= sourceAttempt;
    bool canAttachToAttempt(MembershipPurchaseRecord r) =>
        purchase.status != BillingPurchaseStatus.restored ||
        r.hasReceipt ||
        r.needsReceiptRecovery;
    if (record == null) {
      final active = _records[_activeRequestId];
      if (active != null &&
          active.product.storeProductId == productId &&
          canAttachToAttempt(active) &&
          !active.replacesPurchaseToken(purchase.purchaseToken)) {
        record = active;
      }
    }
    if (record == null && sourceAttempt == null) {
      final pending = candidates
          .where(
            (r) =>
                (r.state == 'prepared' ||
                    r.state == 'pending' ||
                    r.needsReceiptRecovery) &&
                canAttachToAttempt(r),
          )
          .toList();
      if (pending.length == 1) record = pending.single;
    }
    final sourceWait = _checkoutWaits[sourceId];
    if (sourceAttempt != null &&
        _activeRequestId == sourceId &&
        sourceWait?.launchRequested == true &&
        !sourceWait!.storeCallbackReceived &&
        record?.requestId != sourceId) {
      // Apple can return an existing transaction after "already subscribed".
      // Receipt deduplication must not leave this separate click waiting for a
      // callback that has already arrived. Do not transfer its proof/ownership.
      sourceWait.receiveStoreCallback();
      _release(sourceId);
      _setState(
        switch (record?.reportStatus) {
          'completed' => MembershipCheckoutState.idle,
          'accepted' => MembershipCheckoutState.accepted,
          'rejected' => MembershipCheckoutState.rejected,
          _ when _reportedRequestIds.contains(record?.requestId) =>
            MembershipCheckoutState.failed,
          _ => MembershipCheckoutState.deferred,
        },
        attemptId: sourceId,
        reportMessage: _reportFailureMessage(record),
        debugInfo: purchaseDebugInfo(
          'vip.store_result',
          status: record?.reportStatus,
          reason: 'existing_store_transaction',
        ),
      );
      if (!sourceAttempt.paid && !sourceAttempt.hasReceipt) {
        _records.remove(sourceId);
        if (sourceAttempt.guest != null) {
          await _discardUnpurchasedGuestIdentity(sourceAttempt.accountUuid);
        }
      }
      return;
    }
    if (record == null) {
      // Unsolicited store history is not a failed report from this client.
      if (purchase.status == BillingPurchaseStatus.purchased ||
          purchase.status == BillingPurchaseStatus.restored) {
        if (_guestStoreEvents.add(_guestStoreEventKey(purchase))) {
          _invalidateGuestStartupCheck();
          if (_guestHomeSeen) unawaited(checkGuestPurchasesOnHome());
        }
      }
      return;
    }
    _trackingFor(record);
    // Only this order's callback ends its store deadline. Reporting has its own
    // HTTP timeout; keep the wait registered so session/stream resets close UI.
    final wait = _checkoutWaits[record.requestId];
    if (wait != null && wait.launchRequested) wait.receiveStoreCallback();
    try {
      await _handleCheckoutRecord(record, purchase);
    } catch (error) {
      _release(record.requestId);
      _setState(
        MembershipCheckoutState.deferred,
        attemptId: record.requestId,
        debugInfo: purchaseDebugInfo('vip.handle_callback', error: error),
      );
      _log('callback deferred', error);
    }
  }

  Future<void> _handleCheckoutRecord(
    MembershipPurchaseRecord record,
    BillingPurchase purchase,
  ) async {
    if (provider == MembershipProvider.apple &&
        record.guest != null &&
        purchase.transactionId.isNotEmpty &&
        purchase.signedTransaction.isNotEmpty) {
      _signedTransactions['${record.accountUuid}:${purchase.transactionId}'] =
          purchase.signedTransaction;
    }
    if (_reportedRequestIds.contains(record.requestId) &&
        record.paid &&
        (purchase.transactionId.isEmpty ||
            purchase.transactionId == record.transactionId)) {
      return;
    }
    if (purchase.status == BillingPurchaseStatus.canceled ||
        purchase.status == BillingPurchaseStatus.error) {
      _checkoutFailure(
        record.requestId,
        subscriptionStoreFailureReason(
          provider,
          code: purchase.rawErrorCode ?? purchase.errorCode,
          source: purchase.errorSource,
          details: purchase.errorDetails,
          stage: 'callback',
          status: purchase.status.name,
        )!,
      );
      final failure = purchase.status == BillingPurchaseStatus.error
          ? membershipStoreError(
              provider,
              code: purchase.errorCode,
              message: purchase.errorMessage,
              details: purchase.errorDetails,
            )
          : null;
      final canceled =
          purchase.status == BillingPurchaseStatus.canceled ||
          failure?.canceled == true;
      if (!record.paid) {
        await _save(record.copyWith(state: canceled ? 'canceled' : 'error'));
        if (canceled && record.guest != null) {
          await _discardUnpurchasedGuestIdentity(record.accountUuid);
        }
      }
      _release(record.requestId);
      _setState(
        purchase.status == BillingPurchaseStatus.canceled ||
                failure?.canceled == true
            ? MembershipCheckoutState.canceled
            : MembershipCheckoutState.failed,
        attemptId: record.requestId,
        storeFailure: failure,
        debugInfo: purchaseDebugInfo(
          'vip.store_callback',
          status: purchase.status.name,
          errorCode: purchase.errorCode,
          errorMessage: purchase.errorMessage,
        ),
      );
      return;
    }
    // A new Google renewal can reuse its token; retain a separate operation key.
    if (record.paid &&
        record.transactionId.isNotEmpty &&
        purchase.transactionId.isNotEmpty &&
        record.transactionId != purchase.transactionId) {
      record = record.copyWith(
        requestId: newBillingAttemptId(),
        newReport: true,
      );
    }
    record = record.copyWith(
      transactionId: purchase.transactionId.isEmpty
          ? null
          : purchase.transactionId,
      originalTransactionId: purchase.originalTransactionId.isEmpty
          ? null
          : purchase.originalTransactionId,
      purchaseToken: purchase.purchaseToken.isEmpty
          ? null
          : purchase.purchaseToken,
      signedTransaction:
          record.guest != null && purchase.signedTransaction.isNotEmpty
          ? purchase.signedTransaction
          : null,
      state: record.paid && purchase.status == BillingPurchaseStatus.pending
          ? null
          : purchase.status.name,
    );
    await _save(record);
    _release(record.requestId);
    if (record.needsReceiptRecovery) {
      _checkoutFailure(record.requestId, 'receipt_missing');
      _setState(
        MembershipCheckoutState.deferred,
        attemptId: record.requestId,
        debugInfo: purchaseDebugInfo(
          'vip.store_callback',
          reason: 'receipt_missing',
        ),
      );
      return;
    }
    if (purchase.status == BillingPurchaseStatus.pending) {
      record = _trackPending(record, 'store_callback_pending');
      await _save(record);
    }
    try {
      await _prepareGuestClaim(
        record,
        purchaseTime: purchase.purchaseTime,
        fromStoreCallback: true,
      );
    } catch (error) {
      _scheduleGuestMaintenance();
      _log('guest proof persistence deferred', error);
    }
    if (purchase.status == BillingPurchaseStatus.pending) {
      _setState(
        MembershipCheckoutState.pending,
        attemptId: record.requestId,
        debugInfo: purchaseDebugInfo('vip.store_callback', status: 'pending'),
      );
      return;
    }
    // Restore callbacks retain ownership proof for claim, but only a successful
    // purchase callback may start the single report request.
    if (purchase.status != BillingPurchaseStatus.purchased) {
      _setState(
        MembershipCheckoutState.deferred,
        attemptId: record.requestId,
        debugInfo: purchaseDebugInfo(
          'vip.store_callback',
          status: purchase.status.name,
        ),
      );
      return;
    }
    await _report(record);
    await _claimPendingGuests();
  }

  Future<void> _report(MembershipPurchaseRecord record) async {
    record = record.copyWith(tracking: _trackingFor(record));
    if (_disposed ||
        _reportedRequestIds.contains(record.requestId) ||
        !record.hasReceipt ||
        record.state != 'purchased') {
      return;
    }
    if (record.guest == null && await readLoginUid() != record.ownerUid) return;
    final session = _session;
    final previousResult = record.reportStatus;
    _reportedRequestIds.add(record.requestId);
    try {
      await _save(record);
      if (record.reportStatus == null) {
        if (_disposed ||
            session != _session ||
            record.guest == null && await readLoginUid() != record.ownerUid) {
          return;
        }
        _setState(
          MembershipCheckoutState.reporting,
          attemptId: record.requestId,
        );
        late final MembershipPurchaseRequest request;
        try {
          request = await _guestPurchaseRequest(record);
        } catch (error) {
          _checkoutFailure(
            record.requestId,
            error is BillingPlatformException &&
                    error.code == 'membership_signed_transaction_missing'
                ? 'signed_transaction_missing'
                : subscriptionStoreFailureReason(
                        provider,
                        error: error,
                        stage: 'query',
                      ) ??
                      'unknown_error',
          );
          rethrow;
        }
        if (_disposed ||
            session != _session ||
            record.guest == null && await readLoginUid() != record.ownerUid) {
          return;
        }
        final report = await _sendTrackedReport(record, request);
        record = _trackReportResult(record, report);
        record = record.copyWith(
          signedTransaction: request.signedTransaction,
          reportStatus: report.status.name,
          reportReason: report.reason,
          state:
              report.status == MembershipReportStatus.completed && !record.paid
              ? 'purchased'
              : null,
        );
        await _save(record);
      }
      if (record.reportStatus == 'completed' &&
          record.state != 'restored' &&
          !_disposed &&
          session == _session) {
        unawaited(
          FirebaseAnalyticsMonitoring.recordPurchase(
            provider: provider.name,
            productId: record.product.storeProductId,
            kind: FirebaseAnalyticsPurchaseKind.subscription,
            purchaseIdentity: provider == MembershipProvider.google
                ? record.purchaseToken
                : record.transactionId,
          ),
        );
      }
      // Guest ownership proof supports claim after login, not report retry.
      try {
        await _prepareGuestClaim(record);
      } catch (error) {
        _scheduleGuestMaintenance();
        _log('guest proof persistence deferred', error);
      }
      if (record.reportStatus == 'completed' &&
          record.guest == null &&
          await readLoginUid() == record.ownerUid) {
        try {
          await refreshWallet?.call();
        } catch (_) {}
      }
      // Every server status ends this report operation. Store settlement
      // remains server-owned; there is no persisted report or background retry.
      _setState(
        switch (record.reportStatus) {
          'completed' => MembershipCheckoutState.completed,
          'accepted' => MembershipCheckoutState.accepted,
          'rejected' => MembershipCheckoutState.rejected,
          _ => MembershipCheckoutState.deferred,
        },
        attemptId: record.requestId,
        reportMessage: _reportFailureMessage(record),
        debugInfo: purchaseDebugInfo('vip.report', status: record.reportStatus),
      );
      _release(record.requestId);
    } catch (error) {
      _setState(
        MembershipCheckoutState.failed,
        attemptId: record.requestId,
        reportMessage: 'Report failed.',
        debugInfo: purchaseDebugInfo('vip.report', error: error),
      );
      _log('report ended', error);
    } finally {
      if (session == _session &&
          record.reportStatus != null &&
          previousResult != record.reportStatus) {
        _catalogChanged();
      }
    }
  }

  String? _reportFailureMessage(MembershipPurchaseRecord? record) {
    if (record == null) return null;
    if (record.reportStatus == 'rejected') {
      final reason = record.reportReason;
      if (reason?.trim() == 'account_mismatch') {
        return membershipAccountIdentifiersMismatchMessage;
      }
      return reason != null && reason.trim().isNotEmpty
          ? reason
          : 'Report failed.';
    }
    if (record.reportStatus == null &&
        _reportedRequestIds.contains(record.requestId)) {
      return 'Report failed.';
    }
    return null;
  }

  /// Recover guest identity/claim and local cleanup only. Never repost reports.
  Future<void> recover() {
    final existing = _recovery;
    if (existing != null) return existing;
    final session = _session;
    late final Future<void> task;
    task =
        () async {
          try {
            await _load();
            if (_disposed) return;
            // A cached purchase must require login before network retries.
            await _refreshGuestLoginRequest();
            await _serialize(() async {
              await _flushGuestClaims();
              for (final record in _records.values.toList()) {
                await _prepareGuestClaim(record);
              }
              await _refreshGuestLoginRequest();
              await _claimPendingGuests();
            });
          } catch (error) {
            _scheduleGuestMaintenance();
            _log('recovery deferred', error);
          }
        }().whenComplete(() {
          if (identical(_recovery, task)) _recovery = null;
          if (!_disposed && (_recoverAgain || session != _session)) {
            _recoverAgain = false;
            unawaited(recover());
          }
        });
    _recovery = task;
    return task;
  }

  void _scheduleGuestMaintenance() {
    if (_disposed || _retry != null) return;
    final delay = Duration(
      milliseconds: math.min(
        300000,
        retryDelay.inMilliseconds * (1 << math.min(_retryCount++, 5)),
      ),
    );
    _retry = Timer(delay, () {
      _retry = null;
      unawaited(recover());
    });
  }

  void _release(String? requestId) {
    if (_activeRequestId == requestId || _activeRequestId == null) {
      _activeRequestId = null;
      _busy = false;
    }
  }

  void _setState(
    MembershipCheckoutState value, {
    String? attemptId,
    String? reason,
    String? debugInfo,
    MembershipStoreFailure? storeFailure,
    String? reportMessage,
  }) {
    if (_disposed) return;
    state.value = value;
    if (attemptId != null) {
      _emitCheckout(
        value,
        attemptId,
        reason: reason,
        debugInfo: debugInfo,
        storeFailure: storeFailure,
        reportMessage: reportMessage,
      );
    }
  }

  void _emitCheckout(
    MembershipCheckoutState value,
    String attemptId, {
    String? reason,
    String? debugInfo,
    MembershipStoreFailure? storeFailure,
    String? reportMessage,
  }) {
    if (_disposed) return;
    if (kDebugMode) {
      if (value == MembershipCheckoutState.preparing) {
        _debugAttemptId = attemptId;
        _debugStoreOrderId.value = null;
      }
      if (_debugAttemptId == attemptId) {
        final transactionId = _records[attemptId]?.transactionId.trim();
        if (transactionId?.isNotEmpty == true) {
          _debugStoreOrderId.value = transactionId;
        }
      }
    }
    if (value != MembershipCheckoutState.preparing &&
        value != MembershipCheckoutState.store &&
        value != MembershipCheckoutState.reporting) {
      _checkoutWaits.remove(attemptId)?.finish();
    }
    _checkoutEvents.add(
      MembershipCheckoutEvent(
        attemptId: attemptId,
        state: value,
        reason: reason,
        debugInfo: debugInfo,
        storeFailure: storeFailure,
        reportMessage: reportMessage,
      ),
    );
  }

  void _endCheckoutWaits(MembershipCheckoutState value, {String? debugInfo}) {
    for (final id in _checkoutWaits.keys.toList()) {
      _emitCheckout(value, id, debugInfo: debugInfo);
    }
  }

  void _log(String operation, Object error) => debugPrint(
    '[Membership] $operation: ${error.runtimeType}'
    '${error is BillingPlatformException ? '; code=${error.code}' : ''}',
  );

  void resetForSession() {
    for (final entry in _checkoutWaits.entries) {
      if (!entry.value.storeHandedOff && !entry.value.storeCallbackReceived) {
        _checkoutFailure(entry.key, 'session_changed');
      }
    }
    _endCheckoutWaits(MembershipCheckoutState.idle);
    _session++;
    _debugAttemptId = null;
    _debugStoreOrderId.value = null;
    _guestOrderChecks.clear();
    _guestHomeCheck = null;
    _invalidateGuestStartupCheck();
    _currentGuestLoginUuids.clear();
    _guestStoreEvents.clear();
    _resetGuestClaimRetries();
    _activeRequestId = null;
    _busy = false;
    _setState(MembershipCheckoutState.idle);
    // An in-flight HTTP retry must not delay the forced-login gate on expiry.
    unawaited(_refreshGuestLoginRequest());
    unawaited(recover());
    if (_guestHomeSeen) unawaited(checkGuestPurchasesOnHome());
  }

  void handleStreamError([Object? error]) {
    final reason =
        subscriptionStoreFailureReason(
          provider,
          error: error,
          stage: 'callback',
        ) ??
        'unknown_error';
    for (final entry in _checkoutWaits.entries) {
      if (!entry.value.storeCallbackReceived) {
        _checkoutFailure(entry.key, reason);
      }
    }
    _endCheckoutWaits(
      MembershipCheckoutState.deferred,
      debugInfo: purchaseDebugInfo('vip.store_stream', reason: 'stream_error'),
    );
    _activeRequestId = null;
    _busy = false;
    _setState(MembershipCheckoutState.deferred);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(recover());
      if (_guestHomeSeen) unawaited(checkGuestPurchasesOnHome());
    }
  }

  /// Compatibility entry: guest claim maintenance; never report store history.
  Future<void> restorePurchases({List<MembershipProduct>? products}) =>
      recover();

  void dispose() {
    _signedTransactions.clear();
    _guestPurchaseRequests.clear();
    if (_disposed) return;
    _endCheckoutWaits(MembershipCheckoutState.idle);
    _disposed = true;
    unawaited(_checkoutEvents.close());
    _session++;
    _retry?.cancel();
    _guestStartupRetry?.cancel();
    _resetGuestClaimRetries();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    guestLoginRequestId.dispose();
    catalogRevision.dispose();
    _debugStoreOrderId.dispose();
  }
}

class _MembershipCheckoutWait {
  Timer? timer;
  final done = Completer<void>();
  bool launchRequested = false;
  bool storeHandedOff = false;
  bool storeResultReturned = false;
  bool storeCallbackReceived = false;

  void receiveStoreCallback() {
    storeCallbackReceived = true;
    finish();
  }

  void finish() {
    timer?.cancel();
    timer = null;
    if (!done.isCompleted) done.complete();
  }
}
