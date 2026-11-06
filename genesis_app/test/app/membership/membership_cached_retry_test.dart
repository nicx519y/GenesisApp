import 'dart:async';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/checkout_preparation_budget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/store_product_access.dart';
import '../../support/membership_fixtures.dart';
import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('page preparation uses the same remaining service deadline', (
    tester,
  ) async {
    final h = support.Harness();
    addTearDown(h.service.dispose);
    final budget = CheckoutPreparationBudget(
      startedAt: DateTime.now().subtract(const Duration(seconds: 29)),
    );
    final gate = Completer<void>();
    h.platform.onPrepare = () => gate.future;
    var finished = false;
    final work = budget
        .run(() => h.service.purchase(h.product()))
        .then((_) => finished = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(finished, true);
    expect(h.service.isBusy, false);
    gate.complete();
    await tester.pump();
    await work;
    expect(h.platform.launches, 0);
  });

  test(
    'prepare and launch share one recovery and one guest identity',
    () async {
      var refreshes = 0;
      var prepares = 0;
      final h = support.Harness(
        refreshCheckoutProducts: () async {
          refreshes++;
          return MembershipProductList(
            products: [membershipProduct(offerId: 'updated')],
          );
        },
      );
      addTearDown(h.service.dispose);
      h.uid = null;
      h.platform.onPrepare = () async {
        if (++prepares == 1) {
          throw const BillingPlatformException('membership_product_not_found');
        }
        expect(StoreProductAccess.forceRefresh, true);
        expect(h.platform.product?.offerId, 'updated');
      };
      h.platform.onLaunch = () async =>
          throw PlatformException(code: 'NOT_FOUND');
      await h.service.purchase(h.product());
      expect(refreshes, 1);
      expect(prepares, 2);
      expect(h.platform.launches, 1);
      expect(h.guestPrepares, 1);
      expect(h.service.state.value, MembershipCheckoutState.failed);
    },
  );

  test(
    'stale catalog offer refreshes before identity and payment launch',
    () async {
      var refreshes = 0;
      final h = support.Harness(
        checkoutProducts: () async => MembershipProductList(
          products: [membershipProduct(offerId: 'changed')],
        ),
        refreshCheckoutProducts: () async {
          refreshes++;
          return MembershipProductList(
            products: [membershipProduct(offerId: 'updated')],
          );
        },
      );
      addTearDown(h.service.dispose);
      await h.service.purchase(h.product());
      expect(refreshes, 1);
      expect(h.platform.launches, 1);
      expect(h.platform.product?.offerId, 'updated');
    },
  );

  testWidgets('late recovery cannot launch after the original deadline', (
    tester,
  ) async {
    final gate = Completer<MembershipProductList>();
    final h = support.Harness(refreshCheckoutProducts: () => gate.future);
    addTearDown(h.service.dispose);
    h.platform.onPrepare = () async =>
        throw PlatformException(code: 'product_not_found');
    final work = h.service.purchase(h.product());
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await work;
    gate.complete(
      MembershipProductList(products: [membershipProduct(offerId: 'updated')]),
    );
    await tester.pump();
    expect(h.platform.launches, 0);
    expect(h.service.isBusy, false);
  });
  for (final code in ['NOT_FOUND', 'product_details_changed']) {
    test(
      'cached $code refreshes backend and platform then launches the new offer',
      () async {
        var refreshes = 0;
        final h = support.Harness(
          refreshCheckoutProducts: () async {
            refreshes++;
            return MembershipProductList(
              products: [membershipProduct(offerId: 'updated')],
            );
          },
        );
        h.platform.onLaunch = () async {
          if (h.platform.launches == 1) throw PlatformException(code: code);
          expect(h.platform.product?.offerId, 'updated');
        };
        h.platform.onPrepare = () async {
          if (h.platform.product?.offerId == 'updated') {
            expect(StoreProductAccess.forceRefresh, true);
          }
        };
        await h.service.purchase(h.product());
        expect(refreshes, 1);
        expect(h.platform.launches, 2);
        expect(h.platform.uuid, support.accountUuid);
      },
    );
  }
}
