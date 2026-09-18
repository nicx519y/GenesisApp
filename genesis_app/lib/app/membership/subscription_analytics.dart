import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../platform/billing/billing_models.dart';
import '../telemetry/genesis_telemetry.dart';

enum SubscriptionSource {
  homeMembership('from_home_membership'),
  meMembership('from_me_membership'),
  mePinkGems('from_me_pink_gems'),
  dailyCheckIn('from_daily_check_in'),
  chatFeatureQuota('from_chat_feature_quota'),
  onboarding('from_onboarding'),
  buyGemsTab('from_buy_gems_tab'),
  unknown('from_unknown');

  const SubscriptionSource(this.value);
  final String value;

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
    this.pending = const [],
    this.successEventId,
  });

  factory SubscriptionTracking.recovery(String identity) =>
      SubscriptionTracking(id: 'recovery_${subscriptionEventId(identity)}');

  final String id;
  final SubscriptionSource source;
  final List<String> pending;
  final String? successEventId;

  SubscriptionTracking copyWith({
    List<String>? pending,
    String? successEventId,
  }) => SubscriptionTracking(
    id: id,
    source: source,
    pending: pending ?? this.pending,
    successEventId: successEventId ?? this.successEventId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.value,
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
    this.eventId,
  });
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
      actionType: 'pay_event',
      action: event.action,
      object1: event.object1,
      object2: event.object2,
      object3: event.object3,
      eventId: event.eventId,
    );
  }

  void _emit(SubscriptionAnalyticsEvent event) {
    // Invoke synchronously so collect captures the UID at the event, even if
    // the queue write completes after a guest logs in or changes accounts.
    unawaited(Future<void>.sync(() => _sink(event)).catchError((Object _) {}));
  }

  void pageShow(
    String pageId,
    SubscriptionSurface surface,
    SubscriptionSource source,
  ) {
    if (!_once.add('page:$pageId')) return;
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_page_show',
        billingPageTrackId(pageId),
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
  }) {
    final tracking = SubscriptionTracking(
      id: billingPurchaseTrackId(pageId),
      source: source,
    );
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_purchase_click',
        tracking.id,
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
  }) {
    if (once && !_once.add('checkout:${tracking.id}')) return;
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_failed',
        tracking.id,
        reason,
        object1: tracking.source.value,
      ),
    );
  }

  void timeout(SubscriptionTracking tracking, String stage) {
    if (stage == 'prepare' && !_once.add('prepare_timeout:${tracking.id}')) {
      return;
    }
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_timeout',
        tracking.id,
        stage,
        object1: tracking.source.value,
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
        tracking.id,
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
    final alreadyRecorded =
        tracking.successEventId != null || !_successfulReceipts.add(identity);
    _successfulReceipts.add(identity);
    final eventId =
        tracking.successEventId ?? subscriptionEventId('success:$identity');
    if (alreadyRecorded) return tracking.copyWith(successEventId: eventId);
    _emit(
      SubscriptionAnalyticsEvent(
        'subscription_success',
        tracking.id,
        orderId,
        object1: tracking.source.value,
        eventId: eventId,
      ),
    );
    return tracking.copyWith(successEventId: eventId);
  }

  void claim(SubscriptionTracking tracking, String result) => _emit(
    SubscriptionAnalyticsEvent(
      'subscription_claim_result',
      tracking.id,
      result,
      object1: tracking.source.value,
    ),
  );
}
