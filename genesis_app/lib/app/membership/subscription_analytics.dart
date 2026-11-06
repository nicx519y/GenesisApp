import '../../platform/billing/payment_failure_classification.dart';
import '../../platform/billing/payment_failure_diagnostics.dart';
import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../network/models/membership_order_product.dart';
import '../../platform/billing/billing_models.dart';
import '../telemetry/genesis_telemetry.dart';

enum SubscriptionSource {
  homeMembership('from_home_membership'),
  meMembership('from_me_membership'),
  mePinkGems('from_me_pink_gems'),
  dailyCheckIn('from_daily_check_in'),
  chatFeatureQuota('from_chat_feature_quota'),
  chatEditSaveQuota('from_chat_edit_save_quota'),
  onboarding('from_onboarding'),
  buyGemsTab('from_buy_gems_tab'),
  worldRecap('from_world_recap'),
  buyGemsFromMeGems('from_buy_gems_tab[from_me_gems]'),
  buyGemsFromTickNoBalance('from_buy_gems_tab[from_tick_no_balance]'),
  buyGemsFromMsgLowBalance('from_buy_gems_tab[from_msg_low_balance]'),
  buyGemsFromMsgNoBalance('from_buy_gems_tab[from_msg_no_balance]'),
  unknown('from_unknown');

  const SubscriptionSource(this.value);
  final String value;

  static SubscriptionSource fromGemsEntry(BillingPurchaseSource source) =>
      switch (source) {
        BillingPurchaseSource.meGems => buyGemsFromMeGems,
        BillingPurchaseSource.tickNoBalance => buyGemsFromTickNoBalance,
        BillingPurchaseSource.msgLowBalance => buyGemsFromMsgLowBalance,
        BillingPurchaseSource.msgNoBalance => buyGemsFromMsgNoBalance,
        _ => unknown,
      };

  static SubscriptionSource parse(Object? value) => values.firstWhere(
    (source) => source.value == value,
    orElse: () => unknown,
  );
}

enum SubscriptionSurface {
  page('subscription_page'),
  sheet('subscription_sheet');

  const SubscriptionSurface(this.value);
  final String value;
}

/// Local analytics metadata only; never included in a payment API request.
class SubscriptionTracking {
  const SubscriptionTracking({
    required this.id,
    this.source = SubscriptionSource.unknown,
    this.storeProductId = '',
    this.basePlanId = '',
    this.pending = const [],
    this.successEventId,
  });

  factory SubscriptionTracking.recovery(String identity) =>
      SubscriptionTracking(id: 'recovery_${subscriptionEventId(identity)}');

  final String id;
  final SubscriptionSource source;
  final String storeProductId;
  final String basePlanId;
  String get analyticsProductId =>
      basePlanId.isNotEmpty ? basePlanId : storeProductId;
  final List<String> pending;
  final String? successEventId;

  SubscriptionTracking copyWith({
    String? storeProductId,
    String? basePlanId,
    List<String>? pending,
    String? successEventId,
  }) => SubscriptionTracking(
    id: id,
    source: source,
    storeProductId: storeProductId ?? this.storeProductId,
    basePlanId: basePlanId ?? this.basePlanId,
    pending: pending ?? this.pending,
    successEventId: successEventId ?? this.successEventId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.value,
    'store_product_id': storeProductId,
    'base_plan_id': basePlanId,
    'pending': pending,
    if (successEventId != null) 'success_event_id': successEventId,
  };

  static SubscriptionTracking? fromJson(Object? json) {
    if (json is! Map ||
        json['id'] is! String ||
        (json['id'] as String).isEmpty) {
      return null;
    }
    return SubscriptionTracking(
      id: json['id'] as String,
      source: SubscriptionSource.parse(json['source']),
      basePlanId: json['base_plan_id'] is String
          ? json['base_plan_id'] as String
          : '',
      storeProductId: json['store_product_id'] is String
          ? json['store_product_id'] as String
          : '',
      pending: json['pending'] is List
          ? (json['pending'] as List).whereType<String>().toList()
          : const [],
      successEventId: json['success_event_id'] is String
          ? json['success_event_id'] as String
          : null,
    );
  }
}

String subscriptionEventId(String identity) =>
    const Uuid().v5(Namespace.url.value, 'worldo:subscription:$identity');

class SubscriptionAnalyticsEvent {
  const SubscriptionAnalyticsEvent(
    this.action,
    this.object2,
    this.object3, {
    this.object1 = '',
    this.extData = '',
    this.eventId,
  });
  final String extData;
  final String action;
  final String object1;
  final String object2;
  final String object3;
  final String? eventId;
}

typedef SubscriptionEventSink =
    FutureOr<void> Function(SubscriptionAnalyticsEvent);

/// Emits at the business result, independently of UI state and payment waits.
class SubscriptionAnalytics {
  SubscriptionAnalytics({SubscriptionEventSink? sink})
    : _sink = sink ?? _collect;
  final SubscriptionEventSink _sink;
  final Set<String> _once = {};
  final Set<String> _successfulReceipts = {};

  static Future<void> _collect(SubscriptionAnalyticsEvent event) async {
    await GenesisTelemetry.collectLogAndWait(
      actionType:
          (event.action == 'subscription_failed' ||
              event.action == 'subscription_success_skipped')
          ? 'monitor'
          : 'pay_event',
      action: event.action,
      object1: event.object1,
      object2: event.object2,
      object3: event.object3,
      eventId: event.eventId,
      extData: event.extData,
    );
  }

  void _emit(SubscriptionAnalyticsEvent event) {
    // Unknown origins must not enter subscription analytics. Receipt reporting
    // and business purchase handling remain independent of this sink.
    if (SubscriptionSource.parse(event.object1) == SubscriptionSource.unknown) {
      return;
    }
    // Invoke synchronously so collect captures the UID at the event, even if
    // the queue write completes after a guest logs in or changes accounts.
    unawaited(Future<void>.sync(() => _sink(event)).catchError((Object _) {}));
  }

  void pageShow(
    String pageId,
    SubscriptionSurface surface,
    SubscriptionSource source,
    MembershipType membershipType,
  ) {
    if (!_once.add('page:$pageId')) return;
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_page_show',
        membershipType == MembershipType.deluxe ? 'Deluxe' : 'Premium',
        surface.value,
        object1: source.value,
      ),
    );
  }

  SubscriptionTracking click(
    String pageId,
    SubscriptionSurface surface,
    SubscriptionSource source, {
    required bool isYearly,
    String storeProductId = '',
    String basePlanId = '',
  }) {
    final tracking = SubscriptionTracking(
      id: newBillingAttemptId(),
      source: source,
      storeProductId: storeProductId,
      basePlanId: basePlanId,
    );
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_purchase_click',
        tracking.analyticsProductId,
        isYearly ? 'yearly' : 'monthly',
        object1: source.value,
      ),
    );
    return tracking;
  }

  void failed(
    SubscriptionTracking tracking,
    String reason, {
    bool once = false,
    Map<String, Object?> diagnostics = const {},
  }) {
    try {
      final classification = classifyPaymentFailure(reason, diagnostics);
      final failureKey = classification.stage == 'stream'
          ? 'checkout:${tracking.id}:stream'
          : 'checkout:${tracking.id}';
      if (once && !_once.add(failureKey)) return;
      _emit(
        SubscriptionAnalyticsEvent(
          'subscription_failed',
          tracking.analyticsProductId,
          classification.object3,
          object1: tracking.source.value,
          extData: encodePaymentFailureDiagnostics({
            'tracking_id': tracking.id,
            'source': tracking.source.value,
            ...diagnostics,
            'schema_version': 2,
            'purchase_kind': 'subscription',
            'stage': classification.stage,
            'step': classification.step,
            'reason': classification.reason,
            'original_reason': reason,
            'payment_outcome': classification.reason == 'canceled'
                ? 'canceled'
                : classification.stage == 'stream' ||
                      classification.reason.contains('receipt_missing') ||
                      classification.reason == 'signed_transaction_missing'
                ? 'unknown'
                : 'failed',
          }),
        ),
      );
    } catch (_) {
      /* Analytics must never interrupt checkout. */
    }
  }

  void timeout(
    SubscriptionTracking tracking,
    String type, {
    Map<String, Object?> diagnostics = const {},
  }) {
    if (!_once.add('timeout:${tracking.id}:$type')) return;
    final stage = type == 'store_callback' ? 'callback' : type;
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_failed',
        tracking.analyticsProductId,
        '${stage}_failed[reason=timeout]',
        object1: tracking.source.value,
        extData: encodePaymentFailureDiagnostics({
          'tracking_id': tracking.id,
          'source': tracking.source.value,
          'purchase_kind': 'subscription',
          ...diagnostics,
          'schema_version': 2,
          'stage': stage,
          'step':
              diagnostics['step'] ??
              (type == 'store_callback'
                  ? 'await_store_callback'
                  : 'prepare_checkout'),
          'reason': 'timeout',
          'original_reason': '${type}_timeout',
          'timeout_type': type,
          'payment_outcome': 'unknown',
        }),
      ),
    );
  }

  SubscriptionTracking pending(SubscriptionTracking tracking, String reason) {
    if (tracking.pending.contains(reason) ||
        !_once.add('pending:${tracking.id}:$reason')) {
      return tracking;
    }
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_pending',
        tracking.analyticsProductId,
        reason,
        object1: tracking.source.value,
        eventId: subscriptionEventId('pending:${tracking.id}:$reason'),
      ),
    );
    return tracking.copyWith(pending: [...tracking.pending, reason]);
  }

  SubscriptionTracking success(
    SubscriptionTracking tracking,
    String provider,
    String orderId,
  ) {
    final identity = '$provider:${orderId.isEmpty ? tracking.id : orderId}';
    final duplicateTransaction = _successfulReceipts.contains(identity);
    final alreadyRecorded =
        tracking.successEventId != null || duplicateTransaction;
    _successfulReceipts.add(identity);
    final eventId =
        tracking.successEventId ?? subscriptionEventId('success:$identity');
    if (alreadyRecorded) {
      successSkipped(
        tracking,
        duplicateTransaction ? 'duplicate_transaction' : 'duplicate_tracking',
        transactionIdentity: identity,
      );
      return tracking.copyWith(successEventId: eventId);
    }
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_success',
        tracking.analyticsProductId,
        orderId,
        object1: tracking.source.value,
        eventId: eventId,
      ),
    );
    return tracking.copyWith(successEventId: eventId);
  }

  void successSkipped(
    SubscriptionTracking tracking,
    String reason, {
    String transactionIdentity = '',
  }) {
    if (!_once.add(
      'success_skipped:${tracking.id}:$transactionIdentity:$reason',
    )) {
      return;
    }
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_success_skipped',
        tracking.analyticsProductId,
        reason,
        object1: tracking.source.value,
      ),
    );
  }

  void claim(SubscriptionTracking tracking, String result) => _emit(
    SubscriptionAnalyticsEvent(
      'subscription_claim_result',
      tracking.analyticsProductId,
      result,
      object1: tracking.source.value,
    ),
  );
}
