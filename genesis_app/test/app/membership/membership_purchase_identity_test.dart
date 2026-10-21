import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

import '../../support/membership_fixtures.dart';
import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const catalogUuid = '2b74ec68-7abc-4cce-a223-e997e31dc811';

  for (final provider in MembershipProvider.values) {
    for (final guest in [false, true]) {
      for (final yearly in [false, true]) {
        for (final supplied in [false, true]) {
          test(
            '$provider guest=$guest yearly=$yearly catalogUuid=$supplied uses fetched UUID without comparing callback UUID',
            () async {
              final h = support.Harness(provider: provider, claimEnabled: true);
              if (guest) h.uid = null;
              var userInfoCalls = 0;
              h.accountUuidHandler = () async {
                userInfoCalls++;
                return support.accountUuid;
              };
              h.lastAccountUuid = supplied ? catalogUuid : null;
              h.productsHandler = () async => [
                membershipProduct(provider: provider, yearly: yearly),
              ];
              final expected = supplied
                  ? catalogUuid
                  : guest
                  ? support.guest.accountUuid
                  : support.accountUuid;

              // A displayed snapshot must not override the current checkout catalog.
              await h.service.purchase(
                membershipProduct(provider: provider, yearly: yearly),
              );
              expect(h.eligibilityQueries, 2);
              expect(h.platform.launches, 1);
              expect(h.platform.uuid, expected);
              expect(h.guestPrepares, guest && !supplied ? 1 : 0);
              expect(userInfoCalls, !guest && !supplied ? 1 : 0);

              await h.service.interceptPurchase(
                h.purchase(
                  yearly: yearly,
                  uuid: '00000000-0000-4000-8000-000000000002',
                ),
              );
              expect(h.reports, hasLength(1));
              expect(h.service.state.value, MembershipCheckoutState.completed);
              final report = h.reports.single.toJson();
              expect(report, isNot(contains('plan_code')));
              expect(report, isNot(contains('request_id')));
              if (guest) {
                expect(report['account_uuid'], expected);
                expect(h.store.confirmed.values.single.accountUuid, expected);
                expect(h.store.claims.keys, [expected]);
                h.uid = 'first-login';
                await h.service.recover();
                expect(h.claimRequests.single.toJson(), report);
                expect(h.store.claims, isEmpty);
              } else {
                expect(report, isNot(contains('account_uuid')));
                expect(h.claimRequests, isEmpty);
              }
            },
          );
        }
      }
    }
  }

  for (final provider in MembershipProvider.values) {
    test(
      '$provider changed callback UUID still respects backend rejection',
      () async {
        final h = support.Harness(provider: provider);
        addTearDown(h.service.dispose);
        h.reportHandler = (_) async => const MembershipPurchaseReport(
          status: MembershipReportStatus.rejected,
        );
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(
          h.purchase(uuid: '00000000-0000-4000-8000-000000000002'),
        );
        expect(h.reports, hasLength(1));
        expect(h.service.state.value, MembershipCheckoutState.rejected);
        expect(h.refreshes, 0);
      },
    );

    test(
      '$provider changed callback UUID cannot bypass account switch',
      () async {
        final h = support.Harness(provider: provider);
        addTearDown(h.service.dispose);
        await h.service.purchase(h.product());
        h.uid = 'another-user';
        await h.service.interceptPurchase(
          h.purchase(uuid: '00000000-0000-4000-8000-000000000002'),
        );
        expect(h.reports, isEmpty);
        expect(h.refreshes, 0);
      },
    );

    for (final status in [
      BillingPurchaseStatus.pending,
      BillingPurchaseStatus.restored,
      BillingPurchaseStatus.canceled,
      BillingPurchaseStatus.error,
    ]) {
      test('$provider $status with changed UUID never starts report', () async {
        final h = support.Harness(provider: provider);
        addTearDown(h.service.dispose);
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(
          h.purchase(
            status: status,
            uuid: '00000000-0000-4000-8000-000000000002',
          ),
        );
        expect(h.reports, isEmpty);
        expect(h.refreshes, 0);
      });
    }

    for (final isGuest in [false, true]) {
      test(
        '$provider guest=$isGuest uses fetched UUID when catalog UUID changes during preparation',
        () async {
          final h = support.Harness(provider: provider);
          if (isGuest) h.uid = null;
          h.lastAccountUuid = catalogUuid;
          h.platform.onPrepare = () async {
            h.lastAccountUuid = '00000000-0000-4000-8000-000000000002';
          };
          await h.service.purchase(h.product());
          expect(h.platform.launches, 1);
          expect(h.platform.uuid, catalogUuid);
          expect(h.service.state.value, MembershipCheckoutState.store);
        },
      );
    }
  }
}
