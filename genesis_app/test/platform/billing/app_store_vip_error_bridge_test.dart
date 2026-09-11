import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:genesis_flutter_android/app/membership/membership_store_failure.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/app_store_billing_platform.dart';

class _Store extends Fake implements InAppPurchase {
  _Store(this.purchases);
  final List<PurchaseDetails> purchases;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => Stream.value(purchases);
}

void main() {
  test(
    'StoreKit transaction error codes reach VIP without changing shared legacy codes',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final platform = AppStoreBillingPlatform(
        inAppPurchase: _Store([
          for (var code = 0; code <= 21; code++)
            AppStorePurchaseDetails.fromSKTransaction(
              SKPaymentTransactionWrapper(
                payment: const SKPaymentWrapper(
                  productIdentifier: 'vip.monthly',
                ),
                transactionState: SKPaymentTransactionStateWrapper.failed,
                error: SKError(
                  code: code,
                  domain: 'SKErrorDomain',
                  userInfo: const {},
                ),
              ),
              '',
            ),
        ]),
      );
      final results = await platform.purchaseStream.first;
      expect(results, hasLength(22));
      for (var code = 0; code <= 21; code++) {
        final purchase = results[code];
        expect(purchase.errorCode, 'purchase_error');
        expect(purchase.errorMessage, 'SKErrorDomain');
        expect(purchase.errorDetails, {
          'domain': 'SKErrorDomain',
          'nativeCode': code,
        });
        final failure = membershipStoreError(
          MembershipProvider.apple,
          code: purchase.errorCode,
          message: purchase.errorMessage,
          details: purchase.errorDetails,
        );
        expect(failure.code, membershipAppleNativeCodes[code]);
      }
    },
  );
}
