import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_claim.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/membership_store_purchase.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reinstalled Apple transaction finishes only after claim completes',
    () async {
      final h = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
        claimEnabled: true,
      )..uid = null;
      h.guestPurchases = [
        MembershipStorePurchase(purchase: h.purchase(transaction: '101')),
      ];
      await h.service.checkGuestPurchasesOnHome();
      final result = Completer<MembershipClaimResult>();
      h.claimHandler = (_) => result.future;
      h.uid = 'first-login';
      final recovery = h.service.recover();
      await pumpEventQueue();
      expect(h.claimRequests, hasLength(1));
      expect(h.platform.finishes, 0);
      expect(h.store.claims.values.single.recoveredProof, isNotNull);
      result.complete(
        const MembershipClaimResult(status: MembershipReportStatus.completed),
      );
      await recovery;
      expect(h.platform.finishedTransactions, ['101']);
      expect(h.store.claims.values.single.recoveredProof, isNull);
      expect(
        h.store.claims.values.single.guest.accountUuid,
        support.guest.accountUuid,
      );
      expect(h.reports, isEmpty);
      await h.service.recover();
      expect(h.platform.finishes, 1);
      expect(h.claimRequests, hasLength(1));
    },
  );

  for (final status in [
    MembershipReportStatus.accepted,
    MembershipReportStatus.rejected,
  ]) {
    test(
      'reinstalled Apple $status claim does not finish the transaction',
      () async {
        final h = support.Harness(
          provider: MembershipProvider.apple,
          guestRecoveryEnabled: true,
          claimEnabled: true,
        )..uid = null;
        h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
        await h.service.checkGuestPurchasesOnHome();
        h.claimHandler = (_) async => MembershipClaimResult(status: status);
        h.uid = 'first-login';
        await h.service.recover();
        expect(h.platform.finishes, 0);
        expect(h.store.claims.values.single.recoveredProof, isNotNull);
        expect(h.reports, isEmpty);
      },
    );
  }

  test(
    'completed Apple claim retries finish after restart without claiming again',
    () async {
      final h = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
        claimEnabled: true,
      )..uid = null;
      h.guestPurchases = [
        MembershipStorePurchase(purchase: h.purchase(transaction: '102')),
      ];
      await h.service.checkGuestPurchasesOnHome();
      h.platform.finishFails = true;
      h.uid = 'first-login';
      await h.service.recover();
      expect(h.claimRequests, hasLength(1));
      expect(h.platform.finishedTransactions, isEmpty);
      expect(h.store.claims.values.single.status, 'completed');
      expect(h.store.claims.values.single.recoveredProof!.transactionId, '102');
      h.service.dispose();
      final restarted = support.Harness(
        provider: MembershipProvider.apple,
        claimEnabled: true,
        storage: h.store,
      )..uid = 'first-login';
      await restarted.service.start();
      expect(restarted.platform.finishedTransactions, ['102']);
      expect(restarted.claimRequests, isEmpty);
      expect(restarted.reports, isEmpty);
      expect(restarted.store.claims.values.single.recoveredProof, isNull);
      expect(restarted.store.claims.values.single.ownerUid, 'first-login');
    },
  );

  for (final provider in MembershipProvider.values) {
    for (final outcome in ['failure', 'accepted']) {
      testWidgets(
        '$provider reinstalled $outcome claim retries the same proof without report',
        (tester) async {
          final h = support.Harness(
            provider: provider,
            guestRecoveryEnabled: true,
            claimEnabled: true,
            retryDelay: const Duration(seconds: 15),
          )..uid = null;
          h.guestPurchases = [
            MembershipStorePurchase(purchase: h.purchase(yearly: true)),
          ];
          await h.service.checkGuestPurchasesOnHome();
          final saved = h.store.claims.values.single.recoveredProof!;
          h.claimHandler = (_) async {
            if (outcome == 'failure') throw StateError('offline');
            return const MembershipClaimResult(
              status: MembershipReportStatus.accepted,
            );
          };
          h.productsHandler = () async =>
              throw StateError('catalog must not be queried for claim');
          h.uid = 'first-login';
          h.service.resetForSession();
          await h.service.recover();
          expect(h.claimRequests, hasLength(1));
          expect(h.eligibilityQueries, 0);
          expect(h.claimRequests.single.toJson(), isNot(contains('plan_code')));
          for (final seconds in [15, 30, 60, 120, 240]) {
            final before = h.claimRequests.length;
            await h.service.recover();
            expect(h.claimRequests, hasLength(before));
            await tester.pump(Duration(seconds: seconds));
            await h.service.recover();
            expect(h.claimRequests, hasLength(before + 1));
          }
          await tester.pump(const Duration(days: 1));
          await h.service.recover();
          expect(h.claimRequests, hasLength(6));
          for (final request in h.claimRequests) {
            expect(request.purchaseToken, saved.purchaseToken);
            expect(request.transactionId, saved.transactionId);
            expect(request.toJson(), isNot(contains('request_id')));
            expect(request.toJson(), h.claimRequests.first.toJson());
          }
          expect(h.store.claims.values.single.ownerUid, 'first-login');
          expect(
            h.store.claims.values.single.recoveredProof!.toJson(),
            isNot(contains('plan_code')),
          );
          expect(h.reports, isEmpty);
          expect(h.store.records, isEmpty);
          expect(h.store.confirmed, isEmpty);
          expect(h.store.restores, isEmpty);
          h.service.dispose();

          final restarted = support.Harness(
            provider: provider,
            guestRecoveryEnabled: true,
            claimEnabled: true,
            storage: h.store,
          )..uid = 'other-login';
          await restarted.service.start();
          expect(restarted.claimRequests, isEmpty);
          restarted.uid = 'first-login';
          restarted.service.resetForSession();
          await restarted.service.recover();
          expect(
            restarted.claimRequests.single.purchaseToken,
            saved.purchaseToken,
          );
          expect(
            restarted.claimRequests.single.transactionId,
            saved.transactionId,
          );
          expect(
            restarted.signedTransactionQueries,
            provider == MembershipProvider.apple ? 1 : 0,
          );
          expect(restarted.eligibilityQueries, 0);
          expect(restarted.store.claims.values.single.status, 'completed');
          expect(restarted.store.claims.values.single.recoveredProof, isNull);
          expect(
            restarted.store.claims.values.single.guest.accountUuid,
            support.guest.accountUuid,
          );
          expect(restarted.refreshes, 1);
          await restarted.service.recover();
          expect(restarted.claimRequests, hasLength(1));
        },
      );
    }
  }

  test(
    'restarting before login uses persisted proof and reloads only Apple JWS',
    () async {
      final first = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
      )..uid = null;
      first.guestPurchases = [
        MembershipStorePurchase(purchase: first.purchase()),
      ];
      await first.service.checkGuestPurchasesOnHome();
      final proof = first.store.claims.values.single.recoveredProof!;
      first.service.dispose();
      final h = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
        claimEnabled: true,
        storage: first.store,
      )..uid = null;
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestDiscoveries, 0);
      expect(h.guestChecks, [support.guest.accountUuid]);
      h.uid = 'first-login';
      h.service.resetForSession();
      await h.service.recover();
      expect(h.claimRequests.single.transactionId, proof.transactionId);
      expect(h.claimRequests.single.toJson(), isNot(contains('request_id')));
      expect(h.signedTransactionQueries, 1);
      expect(h.reports, isEmpty);
    },
  );

  test(
    'Google shared SKU claims original token without catalog or plan_code',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true, claimEnabled: true)
        ..uid = null;
      h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
      await h.service.checkGuestPurchasesOnHome();
      final before = h.store.claims.values.single.recoveredProof!.toJson();
      h.uid = 'first-login';
      await h.service.recover();
      expect(h.claimRequests, hasLength(1));
      expect(h.claimRequests.single.toJson(), {
        'provider': 'google',
        'store_product_id': h.product().storeProductId,
        'account_uuid': support.guest.accountUuid,
        'purchase_token': 'test-token',
      });
      expect(h.eligibilityQueries, 0);
      expect(h.store.claims.values.single.status, 'completed');
      expect(h.store.claims.values.single.recoveredProof, isNull);
      expect(before['purchase_token'], 'test-token');
      expect(before.containsKey('plan_code'), isFalse);
      expect(h.reports, isEmpty);
      expect(h.store.records, isEmpty);
      expect(h.platform.launches, 0);
    },
  );

  test(
    'session change while loading recovered signature prevents claim',
    () async {
      final first = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
      )..uid = null;
      first.guestPurchases = [
        MembershipStorePurchase(purchase: first.purchase()),
      ];
      await first.service.checkGuestPurchasesOnHome();
      first.service.dispose();
      final h = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
        claimEnabled: true,
        storage: first.store,
      )..uid = 'first-login';
      final signature = Completer<String>();
      h.signedTransactionHandler = (_) => signature.future;
      final recovery = h.service.recover();
      await pumpEventQueue();
      h.uid = null;
      h.service.resetForSession();
      signature.complete('header.payload.signature');
      await recovery;
      await h.service.recover();
      expect(h.claimRequests, isEmpty);
      expect(h.store.claims.values.single.ownerUid, isNull);
    },
  );

  test(
    'iOS waits for the original signed transaction and then claims the retained proof',
    () async {
      final first = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
      )..uid = null;
      first.guestPurchases = [
        MembershipStorePurchase(purchase: first.purchase(yearly: true)),
      ];
      await first.service.checkGuestPurchasesOnHome();
      final saved = first.store.claims.values.single.recoveredProof!;
      first.service.dispose();
      final h = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
        claimEnabled: true,
        storage: first.store,
      )..uid = 'first-login';
      h.signedTransactionHandler = (_) async => '';
      await h.service.start();
      expect(h.claimRequests, isEmpty);
      expect(
        h.store.claims.values.single.recoveredProof!.requestId,
        saved.requestId,
      );
      h.signedTransactionHandler = (request) async {
        expect(request.transactionId, saved.transactionId);
        expect(request.storeProductId, saved.storeProductId);
        expect(request.guest.accountUuid, support.guest.accountUuid);
        return 'reloaded.transaction.signature';
      };
      await h.service.recover();
      expect(h.claimRequests.single.toJson(), {
        'provider': 'apple',
        'store_product_id': saved.storeProductId,
        'transaction_id': saved.transactionId,
        'signed_transaction': 'reloaded.transaction.signature',
        'account_uuid': support.guest.accountUuid,
      });
      expect(h.store.claims.values.single.recoveredProof, isNull);
      expect(h.reports, isEmpty);
    },
  );

  test(
    'different receipts under one UUID are not arbitrarily selected for claim',
    () async {
      final h = support.Harness(
        provider: MembershipProvider.apple,
        guestRecoveryEnabled: true,
        claimEnabled: true,
      )..uid = null;
      h.guestPurchases = [
        MembershipStorePurchase(purchase: h.purchase()),
        MembershipStorePurchase(
          purchase: h.purchase(yearly: true, transaction: '200'),
        ),
      ];
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestChecks, [support.guest.accountUuid]);
      expect(h.store.claims, isEmpty);
      h.uid = 'first-login';
      await h.service.recover();
      expect(h.claimRequests, isEmpty);
      expect(h.reports, isEmpty);
    },
  );
}
