import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';

import '../../support/membership_fixtures.dart';
import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const catalogUuid = '2b74ec68-7abc-4cce-a223-e997e31dc811';
  const staleUuid = '3b74ec68-7abc-4cce-a223-e997e31dc811';

  for (final provider in MembershipProvider.values) {
    for (final guest in [false, true]) {
      for (final yearly in [false, true]) {
        for (final supplied in [false, true]) {
          test(
            '$provider guest=$guest yearly=$yearly catalogUuid=$supplied chooses the current purchase identity',
            () async {
              final h = support.Harness(provider: provider, claimEnabled: true);
              if (guest) h.uid = null;
              var userInfoCalls = 0;
              h.accountUuidHandler = () async {
                userInfoCalls++;
                return support.accountUuid;
              };
              h.productsHandler = () async => [
                membershipProduct(
                  provider: provider,
                  yearly: yearly,
                  accountUuid: supplied ? catalogUuid : null,
                ),
              ];
              final expected = supplied
                  ? catalogUuid
                  : guest
                  ? support.guest.accountUuid
                  : support.accountUuid;

              // A displayed snapshot must not override the refreshed catalog.
              await h.service.purchase(
                membershipProduct(
                  provider: provider,
                  yearly: yearly,
                  accountUuid: staleUuid,
                ),
              );
              expect(h.eligibilityQueries, 1);
              expect(h.platform.launches, 1);
              expect(h.platform.uuid, expected);
              expect(h.guestPrepares, guest && !supplied ? 1 : 0);
              expect(userInfoCalls, !guest && !supplied ? 1 : 0);

              await h.service.interceptPurchase(
                h.purchase(yearly: yearly, uuid: expected),
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
                expect(h.store.claims[expected]!.status, 'completed');
              } else {
                expect(report, isNot(contains('account_uuid')));
                expect(h.claimRequests, isEmpty);
              }
            },
          );
        }
      }
    }

    test(
      '$provider catalog UUID does not bypass purchase eligibility',
      () async {
        final h = support.Harness(provider: provider)..uid = null;
        h.vipStatus = MembershipVipStatus.monthly;
        h.productsHandler = () async => [
          membershipProduct(provider: provider, accountUuid: catalogUuid),
        ];
        await h.service.purchase(h.product());
        expect(h.service.state.value, MembershipCheckoutState.failed);
        expect(h.platform.launches, 0);
        expect(h.guestPrepares, 0);
      },
    );
  }
}
