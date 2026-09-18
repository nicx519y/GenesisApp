import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/membership_pending_store.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'guest claim uses the product Apple returned instead of the selected plan',
    () async {
      final h = support.Harness(
        provider: MembershipProvider.apple,
        claimEnabled: true,
      )..uid = null;
      addTearDown(h.service.dispose);
      await h.service.purchase(h.product(), attemptId: 'current');
      final returned = h.purchase(yearly: true);
      await h.service.interceptPurchase(returned);
      final report = h.reports.single;
      expect(report.product.storeProductId, returned.productId);
      await h.service.confirmGuestPurchase('current');
      h.uid = 'first-login';
      h.service.resetForSession();
      await h.service.recover();
      expect(h.claimRequests.single.toJson(), report.toJson());
      expect(h.claimRequests.single.transactionId, returned.transactionId);
      expect(h.signedTransactionQueries, 0);
    },
  );

  for (final pinned in [false, true]) {
    test(
      'restart repairs only unowned legacy claim references; pinned=$pinned',
      () async {
        final h = support.Harness(provider: MembershipProvider.apple)
          ..uid = null;
        await h.service.purchase(h.product(), attemptId: 'old-checkout');
        await h.service.interceptPurchase(
          h.purchase(transaction: 'old-transaction'),
        );
        final staleClaim = h.store.claims.values.single;
        await h.service.purchase(h.product(), attemptId: 'current-checkout');
        await h.service.interceptPurchase(
          h.purchase(transaction: 'current-transaction'),
        );
        final report = pinned ? h.reports.first : h.reports.last;
        // Reproduce the persisted state left by the previous client: both paid
        // receipts exist, but claim still references the first one and has no JWS.
        h.store.claims[support.guest.accountUuid] = pinned
            ? staleClaim.copyWith(ownerUid: 'first-login', status: 'accepted')
            : staleClaim;
        for (final saved in h.store.confirmed.values.toList()) {
          h.store.confirmed[saved.requestId] =
              MembershipPurchaseRecord.fromJson(
                saved.toJson()..remove('signed_transaction'),
              );
        }
        h.service.dispose();
        final restarted = support.Harness(
          provider: MembershipProvider.apple,
          claimEnabled: true,
          guestRecoveryEnabled: true,
          storage: h.store,
        )..uid = null;
        restarted.signedTransactionHandler = (request) async {
          if (request.transactionId != report.transactionId) {
            throw const BillingPlatformException(
              'membership_signed_transaction_missing',
            );
          }
          return report.signedTransaction;
        };
        await restarted.service.start();
        await restarted.service.checkGuestPurchasesOnHome();
        expect(
          restarted.service.guestLoginRequestId.value,
          pinned ? 'old-checkout' : 'current-checkout',
        );
        restarted.uid = 'first-login';
        restarted.service.resetForSession();
        await restarted.service.recover();
        expect(restarted.claimRequests.single.toJson(), report.toJson());
        expect(restarted.reports, isEmpty);
        expect(restarted.signedTransactionQueries, 1);
        expect(restarted.guestDiscoveries, 0);
      },
    );
  }

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
