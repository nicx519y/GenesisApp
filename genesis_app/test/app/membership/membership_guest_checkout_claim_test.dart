import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final provider in MembershipProvider.values) {
    for (final pendingFirst in [false, true]) {
      test(
        '$provider login claims this checkout with old guest cache; pending=$pendingFirst',
        () async {
          final old = support.Harness(provider: provider)..uid = null;
          await old.service.purchase(old.product(), attemptId: 'old-checkout');
          await old.service.interceptPurchase(
            old.purchase(transaction: 'old-transaction', token: 'old-token'),
          );
          old.service.dispose();

          final h = support.Harness(
            provider: provider,
            claimEnabled: true,
            guestRecoveryEnabled: true,
            storage: old.store,
          )..uid = null;
          h.lastAccountUuid = support.guest.accountUuid;
          h.signedTransactionHandler = (_) async =>
              throw const BillingPlatformException(
                'membership_signed_transaction_missing',
              );
          await h.service.purchase(h.product(), attemptId: 'current-checkout');
          if (pendingFirst) {
            await h.service.interceptPurchase(
              h.purchase(
                status: BillingPurchaseStatus.pending,
                transaction: '',
                token: '',
              ),
            );
          }
          await h.service.interceptPurchase(
            h.purchase(
              transaction: 'current-transaction',
              token: 'current-token',
            ),
          );
          final report = h.reports.single;
          expect(
            h.store.claims.values.single.purchaseRequestId,
            'current-checkout',
          );

          // Old stream replay and maintenance must not replace this checkout.
          await h.service.interceptPurchase(
            h.purchase(transaction: 'old-transaction', token: 'old-token'),
          );
          await h.service.recover();
          expect(
            h.store.claims.values.single.purchaseRequestId,
            'current-checkout',
          );
          await h.service.confirmGuestPurchase('current-checkout');
          h.uid = 'first-login';
          h.service.resetForSession();
          await h.service.recover();
          expect(h.claimRequests.single.toJson(), report.toJson());
          expect(h.claimRequests.single.transactionId, 'current-transaction');
          expect(h.signedTransactionQueries, 0);
          expect(h.guestDiscoveries, 0);
          expect(h.reports, hasLength(1));
          expect(h.store.claims, isEmpty);
        },
      );
    }
  }
}
