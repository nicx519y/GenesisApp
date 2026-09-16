import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/components/gems/subscription_tracking_scope.dart';

import '../support/membership_fixtures.dart';

class _Sink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];
  @override
  Future<void> record(GenesisTelemetryEvent event) async => events.add(event);
  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}
  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}
  @override
  Future<void> setUserId(String? uid) async {}
}

void main() {
  tearDown(GenesisTelemetry.resetForTesting);

  testWidgets(
    'hidden constructed content does not expose; first loading paint does',
    (tester) async {
      final events = <SubscriptionAnalyticsEvent>[];
      final page = SubscriptionPageTracking(
        analytics: SubscriptionAnalytics(sink: events.add),
        source: SubscriptionSource.onboarding,
      );
      final hidden = ValueNotifier(true);
      final catalog = Completer<MembershipCatalogData>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionTrackingScope(
              page: page,
              child: ValueListenableBuilder<bool>(
                valueListenable: hidden,
                builder: (_, value, child) =>
                    Offstage(offstage: value, child: child),
                child: ProSubscriptionContent(
                  productsLoader: () => catalog.future,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(events, isEmpty);
      hidden.value = false;
      await tester.pump();
      expect(events.single.action, 'subscription_page_show');
      expect(events.single.object3, 'from_onboarding');
      expect(catalog.isCompleted, isFalse);
      hidden.value = true;
      await tester.pump();
      hidden.value = false;
      await tester.pump();
      expect(events, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      hidden.dispose();
    },
  );

  testWidgets('click shares page ID and precedes async purchase handling', (
    tester,
  ) async {
    final events = <SubscriptionAnalyticsEvent>[];
    final page = SubscriptionPageTracking(
      pageId: 'container',
      surface: SubscriptionSurface.page,
      source: SubscriptionSource.homeMembership,
      analytics: SubscriptionAnalytics(sink: events.add),
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionTrackingScope(
            page: page,
            child: ProSubscriptionContent(
              productsLoader: loadTestMembershipOffers,
              purchaseHandler: (_) async {
                calls++;
                expect(events.last.action, 'subscription_product_click');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('pro-subscribe-button')),
    );
    await tester.tap(find.byKey(const ValueKey('pro-subscribe-button')));
    await tester.pump();
    expect(calls, 1);
    expect(events.first.object2, 'track_id_container');
    expect(events.last.object2, startsWith('track_id_container_'));
    expect(events.last.object1, '');
    expect(events.last.object3, 'subscription_page');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'sheet tab switches expose once with Buy Gems source, never on build',
    (tester) async {
      final sink = _Sink();
      GenesisTelemetry.setSinkForTesting(sink);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseOptionsSheet(
              membershipProductsLoader: loadTestMembershipOffers,
              gemsBuilder: (_) => const Text('gems'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        sink.events.where((e) => e.name == 'subscription_page_show'),
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('wallet-subscription-tab')));
      await tester.pumpAndSettle();
      var exposure = sink.events
          .where((e) => e.name == 'subscription_page_show')
          .single;
      expect(exposure.data['object1'], 'subscription_sheet');
      expect(exposure.data['object3'], 'from_buy_gems_tab');
      await tester.tap(find.byKey(const ValueKey('wallet-buy-gems-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wallet-subscription-tab')));
      await tester.pumpAndSettle();
      expect(
        sink.events.where((e) => e.name == 'subscription_page_show'),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'same container survives keyed account rebuild, reopening gets a new ID',
    (tester) async {
      final events = <SubscriptionAnalyticsEvent>[];
      final analytics = SubscriptionAnalytics(sink: events.add);
      final page = SubscriptionPageTracking(analytics: analytics);
      Future<void> show(
        SubscriptionPageTracking tracking,
        String account,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: KeyedSubtree(
                key: ValueKey(account),
                child: SubscriptionTrackingScope(
                  page: tracking,
                  child: ProSubscriptionContent(
                    productsLoader: loadTestMembershipOffers,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(page, 'guest');
      await show(page, 'logged-in');
      expect(
        events.where((e) => e.action == 'subscription_page_show'),
        hasLength(1),
      );
      await show(SubscriptionPageTracking(analytics: analytics), 'reopened');
      expect(
        events.where((e) => e.action == 'subscription_page_show'),
        hasLength(2),
      );
      expect(events.first.object2, isNot(events.last.object2));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
