import 'package:genesis_flutter_android/platform/billing/payment_failure_diagnostics.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'dart:convert';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/platform/billing/billing_analytics.dart';

class _CapturingTelemetrySink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}

class _AsyncFailingTelemetrySink extends _CapturingTelemetrySink {
  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    throw StateError('asynchronous telemetry write failed');
  }
}

void main() {
  test(
    'Gems skipped success has monitor projection and no extra data',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);
      const GenesisBillingAnalytics().track(
        'purchase_success_skipped',
        properties: {
          'source': 'from_me_gems',
          'store_product_id': 'store-sku',
          'reason': 'duplicate_transaction',
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.single.collectPayload, {
        'action_type': 'monitor',
        'action': 'purchase_success_skipped',
        'object1': 'from_me_gems',
        'object2': 'store-sku',
        'object3': 'duplicate_transaction',
      });
    },
  );

  test(
    'business entry maps consistently and unknown entry is not uploaded',
    () async {
      expect(
        BillingPurchaseSource.fromEntry('tick_no_balance'),
        BillingPurchaseSource.tickNoBalance,
      );
      expect(
        BillingPurchaseSource.fromEntry('from_me_gems'),
        BillingPurchaseSource.meGems,
      );
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);
      const GenesisBillingAnalytics().track(
        'product_click',
        properties: {'source': 'from_unknown'},
      );
      await Future<void>.delayed(Duration.zero);
      expect(sink.events, isEmpty);
    },
  );

  for (final action in [
    'product_click',
    'purchase_success',
    'purchase_pending',
    'purchase_failed',
  ]) {
    test('$action carries store SKU in object2', () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);
      const GenesisBillingAnalytics().track(
        action,
        properties: {
          'product_id': 'business-product',
          'store_product_id': 'store-sku',
          'source': 'from_me_gems',
          'reason': 'canceled',
          'timeout_type': 'prepare',
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(sink.events.single.collectPayload?['object1'], 'from_me_gems');
      expect(sink.events.single.collectPayload?['object2'], 'store-sku');
    });
  }

  for (final provider in ['googlePlay', 'appStore']) {
    test('$provider Gems cancellation uses the same common schema', () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);
      const GenesisBillingAnalytics().track(
        'purchase_failed',
        properties: {
          'attempt_id': 'click-1',
          'product_id': 'gem-1',
          'store_product_id': 'store.gem-1',
          'provider': provider,
          'reason': 'canceled',
          'failure_diagnostics': paymentFailureDiagnostics(
            provider: provider,
            stage: 'callback',
            status: 'canceled',
          ),
        },
      );
      await Future<void>.delayed(Duration.zero);
      final payload = sink.events.single.collectPayload!;
      expect(payload['object3'], 'callback_failed[reason=canceled]');
      final d = jsonDecode(payload['ext_data'] as String) as Map;
      expect(d['provider'], provider == 'googlePlay' ? 'google' : 'apple');
      expect(d['attempt_id'], 'click-1');
      expect(d['product_id'], 'gem-1');
      expect(d['store_product_id'], 'store.gem-1');
      expect(d['purchase_status'], 'canceled');
      expect(d['event_status'], 'canceled');
      expect(d['payment_outcome'], 'canceled');
    });
  }

  test(
    'asynchronous telemetry failure is contained at the payment boundary',
    () async {
      GenesisTelemetry.setSinkForTesting(_AsyncFailingTelemetrySink());
      expect(
        () => const GenesisBillingAnalytics().track(
          'purchase_failed',
          properties: {
            'reason': 'query_failed',
            'error_code': 'product_not_found',
            'attempt_id': 'safe-attempt',
          },
        ),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'confirmation diagnostic distinguishes actual price drift without changing catalog',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);
      const product = GemProduct(
        productId: 'gem',
        appleProductId: 'apple.gem',
        googleProductId: 'google.gem',
        baseGemsCent: 100,
        bonusGemsCent: 0,
        priceCurrencyCode: 'USD',
        priceAmount: 100,
        canPurchase: true,
        activityType: 'none',
      );
      final displayed = product.withStorePrice(
        formatted: r'$1',
        micros: 1000000,
        currency: 'EUR',
      );
      final current = product.withStorePrice(
        formatted: r'$2',
        micros: 2000000,
        currency: 'EUR',
      );
      reportGemConfirmationFailure(
        product: displayed,
        attemptId: 'click-1',
        source: 'buy_gems_page',
        reason: 'catalog_unavailable',
        currentProducts: [current],
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        sink.events.single.collectPayload?['object3'],
        'query_failed[reason=price_changed]',
      );
      final diagnostic =
          jsonDecode(sink.events.single.collectPayload!['ext_data'] as String)
              as Map;
      expect(diagnostic['expected_price_amount_micros'], 1000000);
      expect(diagnostic['actual_price_amount_micros'], 2000000);
      expect(displayed.storeAmountMicros, 1000000);
    },
  );

  test(
    'failure Collect retains detailed diagnostics without leaking to analytics data',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);
      const GenesisBillingAnalytics().track(
        'purchase_failed',
        properties: {
          'attempt_id': 'a-1',
          'product_id': 'gem_pack_1000',
          'reason': 'purchase_callback_error',
          'failure_diagnostics': {
            'stage': 'callback',
            'response_code': 'developerError',
            'sub_response_code': 0,
            'debug_message': 'Invalid product details',
            'purchase_token': 'secret-token',
            'association': 'active_attempt_fallback',
          },
        },
      );
      await Future<void>.delayed(Duration.zero);
      final event = sink.events.single;
      final diagnostic =
          jsonDecode(event.collectPayload!['ext_data'] as String) as Map;
      expect(diagnostic['debug_message'], 'Invalid product details');
      expect(diagnostic['attempt_id'], 'a-1');
      expect(diagnostic['response_code'], 'developerError');
      expect(diagnostic['association'], 'active_attempt_fallback');
      expect(diagnostic.containsKey('purchase_token'), isFalse);
      expect(event.data.containsKey('failure_diagnostics'), isFalse);
    },
  );

  tearDown(GenesisTelemetry.resetForTesting);

  test('billing analytics sanitizes sensitive properties', () {
    final result = sanitizeBillingAnalyticsProperties(<String, Object?>{
      'action': 'product_click',
      'attempt_id': 'attempt-1',
      'product_id': 'gem_pack_500',
      'offer_token_present': true,
      'billing_account_id_present': true,
      'source': 'buy_gems_sheet',
      'timeout_type': 'report',
      'purchase_token': 'purchase-token-1',
      'offerToken': 'offer-token-1',
      'billing_account_id': 'account-1',
      'uid': 'u_1',
      'device_id': 'device-1',
      'transaction_id': 'GPA.1',
      'original_json': '{"purchaseToken":"purchase-token-1"}',
      'payload': <String, Object?>{'secret': 'value'},
      'unknown_field': 'value',
    });

    expect(result, <String, Object?>{
      'action': 'product_click',
      'product_id': 'gem_pack_500',
      'offer_token_present': true,
      'billing_account_id_present': true,
      'source': 'buy_gems_sheet',
      'timeout_type': 'report',
      'transaction_id': 'GPA.1',
    });
  });

  test(
    'product click collect projection keeps source as object3 text',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'product_click',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_500',
          'source': 'buy_gems_sheet',
          'provider': 'google',
          'can_purchase': true,
        },
      );
      await Future<void>.delayed(Duration.zero);

      final event = sink.events.single;
      expect(event.collectPayload, {
        'action_type': 'pay_event',
        'action': 'product_click',
        'object1': 'buy_gems_sheet',
        'object2': '',
      });
    },
  );

  test('success collect projection sends transaction id as object3', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_success',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_500',
        'store_product_id': 'worldo_gem_pack_500',
        'transaction_id': 'GPA.1',
      },
    );
    await Future<void>.delayed(Duration.zero);

    final event = sink.events.single;
    expect(event.collectPayload, {
      'action_type': 'pay_event',
      'action': 'purchase_success',
      'object1': '',
      'object2': 'worldo_gem_pack_500',
      'object3': 'GPA.1',
    });
  });

  test('pending collect projection uses the store callback status', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_pending',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_500',
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(sink.events.single.collectPayload, {
      'action_type': 'pay_event',
      'action': 'purchase_pending',
      'object1': '',
      'object2': '',
      'object3': 'store_callback_pending',
    });
  });

  test('price confirmation timeout is a query failed monitor', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);
    const product = GemProduct(
      productId: 'gem',
      appleProductId: 'apple.gem',
      googleProductId: 'google.gem',
      baseGemsCent: 100,
      bonusGemsCent: 0,
      priceCurrencyCode: 'USD',
      priceAmount: 100,
      canPurchase: true,
      activityType: 'none',
    );
    reportGemConfirmationTimeout(
      product: product,
      attemptId: 'confirm-timeout',
      source: 'buy_gems_sheet',
    );
    await Future<void>.delayed(Duration.zero);
    final payload = sink.events.single.collectPayload!;
    expect(payload['action_type'], 'monitor');
    expect(payload['action'], 'purchase_failed');
    expect(payload['object1'], 'buy_gems_sheet');
    expect(payload['object3'], 'query_failed[reason=timeout]');
    final d = jsonDecode(payload['ext_data'] as String) as Map;
    expect(d['attempt_id'], 'confirm-timeout');
    expect(d['timeout_type'], 'prepare');
    expect(d['step'], 'confirm_product');
    expect(d['payment_outcome'], 'unknown');
  });

  for (final stage in ['prepare', 'query', 'callback']) {
    test(
      'timeout is a failed monitor with stage $stage and diagnostic details',
      () async {
        final sink = _CapturingTelemetrySink();
        GenesisTelemetry.setSinkForTesting(sink);
        const GenesisBillingAnalytics().track(
          'purchase_failed',
          properties: {
            'attempt_id': 'attempt-1',
            'product_id': 'gem_pack_500',
            'store_product_id': 'store-sku',
            'source': 'from_me_gems',
            'reason': 'timeout',
            'timeout_type': 'prepare',
            'failure_diagnostics': {'stage': stage, 'step': 'confirm_product'},
          },
        );
        await Future<void>.delayed(Duration.zero);
        final payload = sink.events.single.collectPayload!;
        expect(payload['action_type'], 'monitor');
        expect(payload['action'], 'purchase_failed');
        expect(payload['object1'], 'from_me_gems');
        expect(payload['object2'], 'store-sku');
        expect(payload['object3'], '${stage}_failed[reason=timeout]');
        final d = jsonDecode(payload['ext_data'] as String) as Map;
        expect(d['reason'], 'timeout');
        expect(d['timeout_type'], 'prepare');
        expect(d['stage'], stage);
        expect(d['step'], 'confirm_product');
        expect(d['payment_outcome'], 'unknown');
        expect(d['attempt_id'], 'attempt-1');
      },
    );
  }

  test('query failure collect projection appends error code', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_500',
        'reason': 'query_failed',
        'error_code': 'product_not_found',
      },
    );
    await Future<void>.delayed(Duration.zero);

    final event = sink.events.single;
    expect(event.collectPayload, {
      'action_type': 'monitor',
      'ext_data': isA<String>(),
      'action': 'purchase_failed',
      'object1': '',
      'object2': '',
      'object3': 'query_failed[reason=product_not_found]',
    });
  });

  test('query failure keeps its stage in purchase object3', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_500',
        'reason': 'query_failed',
        'error_code': 'billing_unavailable',
        'failure_reason': 'google[response_code=billingUnavailable]',
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      sink.events.single.collectPayload?['object3'],
      'query_failed[reason=store_query_error]',
    );
  });

  test(
    'query failure collect projection uses unknown without a code',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'purchase_failed',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_500',
          'reason': 'query_failed',
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        sink.events.single.collectPayload?['object3'],
        'query_failed[reason=store_query_error]',
      );
    },
  );

  test('precheck failure collect projection includes its code', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: const <String, Object?>{
        'product_id': 'gem_pack_500',
        'reason': 'precheck_failed',
        'error_code': 'gp_unavailable',
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      sink.events.single.collectPayload?['object3'],
      'prepare_failed[reason=service_unavailable]',
    );
  });

  test(
    'callback error collect projection appends normalized error code',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'purchase_failed',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_500',
          'reason': 'purchase_callback_error',
          'error_code': 'network_error',
        },
      );
      await Future<void>.delayed(Duration.zero);

      final event = sink.events.single;
      expect(event.collectPayload, {
        'action_type': 'monitor',
        'ext_data': isA<String>(),
        'action': 'purchase_failed',
        'object1': '',
        'object2': '',
        'object3': 'callback_failed[reason=store_error]',
      });
    },
  );

  test(
    'callback error collect projection uses unknown without a code',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'purchase_failed',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_500',
          'reason': 'purchase_callback_error',
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        sink.events.single.collectPayload?['object3'],
        'callback_failed[reason=store_error]',
      );
    },
  );

  test('launch failure collect projection appends error code', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_1000',
        'reason': 'launch_failed',
        'error_code': 'storekit_duplicate_product_object',
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(sink.events.single.collectPayload, {
      'action_type': 'monitor',
      'ext_data': isA<String>(),
      'action': 'purchase_failed',
      'object1': '',
      'object2': '',
      'object3': 'launch_failed[reason=store_launch_error]',
    });
  });

  for (final reason in <String>['report_failed', 'report_rejected']) {
    test('$reason collect projection appends server reason', () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'purchase_failed',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_1000',
          'reason': reason,
          'error_code': 'account_mismatch',
          'failure_diagnostics': {'stage': 'report', 'step': 'purchase_report'},
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        sink.events.single.collectPayload?['object3'],
        'report_failed[reason=account_mismatch]',
      );
    });
  }
}
