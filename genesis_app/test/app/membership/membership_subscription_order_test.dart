import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final provider in MembershipProvider.values) {
    for (final yearly in [false, true]) {
      for (final signedIn in [false, true]) {
        test(
          '$provider yearly=$yearly signedIn=$signedIn existing order',
          () async {
            final h = support.Harness(provider: provider)
              ..uid = signedIn ? 'user-test' : null
              ..hasSubscriptionOrder = true;
            addTearDown(h.service.dispose);
            var identityReads = 0;
            h.accountUuidHandler = () async {
              identityReads++;
              return support.accountUuid;
            };
            await h.service.purchase(h.product(yearly: yearly));
            if (signedIn) {
              expect(h.platform.launches, 1);
              expect(identityReads, 1);
              await h.service.interceptPurchase(
                h.purchase(
                  yearly: yearly,
                  status: BillingPurchaseStatus.canceled,
                ),
              );
            } else {
              expect(
                h.service.state.value,
                MembershipCheckoutState.loginRequired,
              );
              expect(h.service.isBusy, isFalse);
              expect(h.platform.launches, 0);
              expect(identityReads, 0);
              expect(h.store.records, isEmpty);
            }
            expect(h.guestPrepares, 0);
            expect(h.reports, isEmpty);
          },
        );
      }
    }

    test('$provider guest without an order continues checkout', () async {
      final h = support.Harness(provider: provider)..uid = null;
      addTearDown(h.service.dispose);
      await h.service.purchase(h.product());
      expect(h.platform.launches, 1);
      expect(h.guestPrepares, 1);
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.canceled),
      );
    });

    test(
      '$provider click waits for the current catalog before requiring login',
      () async {
        final response = Completer<MembershipProductList>();
        final h = support.Harness(
          provider: provider,
          checkoutProducts: () => response.future,
        )..uid = null;
        addTearDown(h.service.dispose);
        final purchase = h.service.purchase(h.product());
        await pumpEventQueue();
        expect(h.platform.launches, 0);
        expect(h.guestPrepares, 0);
        response.complete(
          MembershipProductList(
            products: [h.product()],
            lastAccountUuid: support.guest.accountUuid,
            hasSubscriptionOrder: true,
          ),
        );
        await purchase;
        expect(h.service.state.value, MembershipCheckoutState.loginRequired);
        expect(h.platform.launches, 0);
        expect(h.guestPrepares, 0);
        expect(h.reports, isEmpty);
      },
    );
  }
}
