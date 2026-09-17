import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:genesis_flutter_android/platform/billing/app_store_billing_platform.dart';

class _Store extends Fake implements InAppPurchase {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'StoreKit result correlation reaches billing without changing its proof',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final store = _Store();
      addTearDown(store.controller.close);
      final observer = SK2TransactionObserverWrapper(
        transactionsCreatedController: store.controller,
      );
      final platform = AppStoreBillingPlatform(inAppPurchase: store);
      for (final attemptId in ['current-click', null]) {
        final message = SK2TransactionMessage(
          id: 123,
          originalId: 100,
          productId: 'test-subscription',
          appAccountToken: 'original-account',
          receiptData: 'original.signed.proof',
          status: SK2PurchaseStatusMessage.purchased,
          checkoutAttemptId: attemptId,
        );
        // Cross the same generated codec used by the native callback channel.
        final codec = InAppPurchase2CallbackAPI.pigeonChannelCodec;
        final decoded =
            codec.decodeMessage(codec.encodeMessage([message]))!
                as List<Object?>;
        final next = platform.purchaseStream.first;
        observer.onTransactionsUpdated([
          decoded.single! as SK2TransactionMessage,
        ]);
        final purchase = (await next).single;
        expect(purchase.checkoutAttemptId, attemptId);
        expect(purchase.obfuscatedAccountId, 'original-account');
        expect(purchase.transactionId, '123');
        expect(purchase.signedTransaction, 'original.signed.proof');
      }
    },
  );
}
