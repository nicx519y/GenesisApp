import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final provider in MembershipProvider.values) {
    for (final signedIn in [false, true]) {
      for (final hasLastUuid in [false, true]) {
        test(
          '$provider signedIn=$signedIn lastUuid=$hasLastUuid selects checkout identity',
          () async {
            final h = support.Harness(provider: provider);
            addTearDown(h.service.dispose);
            h.uid = signedIn ? 'user-test' : null;
            h.lastAccountUuid = hasLastUuid ? support.guest.accountUuid : null;
            var userLookups = 0;
            h.accountUuidHandler = () async {
              userLookups++;
              return support.accountUuid;
            };
            final expected = hasLastUuid || !signedIn
                ? support.guest.accountUuid
                : support.accountUuid;
            await h.service.purchase(h.product(yearly: true));
            expect(h.platform.uuid, expected);
            expect(h.platform.product!.isYearly, isTrue);
            expect(h.guestPrepares, !signedIn && !hasLastUuid ? 1 : 0);
            expect(userLookups, signedIn && !hasLastUuid ? 1 : 0);
            expect(h.store.records, isEmpty);
            await h.service.interceptPurchase(
              h.purchase(
                yearly: true,
                uuid: expected,
                token: 'new-year-token',
                transaction: '200',
              ),
            );
            final report = h.reports.single;
            expect(report.guest?.accountUuid, signedIn ? null : expected);
            expect(report.product.planCode, 'pro_yearly');
            expect(report.transactionId, '200');
            if (provider == MembershipProvider.google) {
              expect(report.toJson()['purchase_token'], 'new-year-token');
            }
            expect(h.service.state.value, MembershipCheckoutState.completed);
          },
        );
      }
    }
    test(
      '$provider guest proof retains original UUID without report retry after catalog changes',
      () async {
        final h = support.Harness(provider: provider)..uid = null;
        addTearDown(h.service.dispose);
        h.lastAccountUuid = support.guest.accountUuid;
        h.reportHandler = (_) async => const MembershipPurchaseReport(
          status: MembershipReportStatus.accepted,
        );
        await h.service.purchase(h.product(yearly: true));
        await h.service.interceptPurchase(h.purchase(yearly: true));
        expect(
          h.store.confirmed.values.single.accountUuid,
          support.guest.accountUuid,
        );
        h.lastAccountUuid = support.accountUuid;
        h.reportHandler = (_) async => support.completed;
        await h.service.recover();
        expect(h.reports, hasLength(1));
        expect(h.reports.last.toJson(), h.reports.first.toJson());
        expect(h.platform.launches, 1);
        expect(h.guestPrepares, 0);
      },
    );
  }

  test(
    'restored monthly history cannot complete a new annual purchase',
    () async {
      final h = support.Harness()..lastAccountUuid = support.guest.accountUuid;
      addTearDown(h.service.dispose);
      await h.service.purchase(h.product(yearly: true));
      await h.service.interceptPurchase(
        h.purchase(
          uuid: support.guest.accountUuid,
          token: 'old-month-token',
          status: BillingPurchaseStatus.restored,
        ),
      );
      expect(h.reports, isEmpty);
      expect(h.service.state.value, MembershipCheckoutState.store);
      await h.service.interceptPurchase(
        h.purchase(
          yearly: true,
          uuid: support.guest.accountUuid,
          token: 'new-year-token',
          transaction: '200',
        ),
      );
      expect(h.reports.single.purchaseToken, 'new-year-token');
      expect(h.service.state.value, MembershipCheckoutState.completed);
    },
  );

  test('catalog failure cannot use a stale checkout identity', () async {
    final h = support.Harness()..lastAccountUuid = support.guest.accountUuid;
    addTearDown(h.service.dispose);
    h.productsHandler = () async => throw StateError('server unavailable');
    await h.service.purchase(h.product(yearly: true));
    expect(h.service.state.value, MembershipCheckoutState.failed);
    expect(h.platform.launches, 0);
    expect(h.store.records, isEmpty);
  });
}
