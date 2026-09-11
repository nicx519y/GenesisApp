import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';

class _ErrorStore extends Fake implements InAppPurchase {
  _ErrorStore(this.details);
  final String? details;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => Stream.value([
    PurchaseDetails(
        productID: '',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'google_play',
        ),
        transactionDate: null,
        status: PurchaseStatus.error,
      )
      ..error = IAPError(
        source: 'google_play',
        code: 'purchase_error',
        message: 'BillingResponse.developerError',
        details: details,
      ),
  ]);
}

void main() {
  test('Google callback keeps raw details and normalized error code', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final details in [
      null,
      'Original Google message\naccount_uuid=8b74ec68-7abc-4cce-a223-e997e31dc811',
    ]) {
      final platform = GooglePlayBillingPlatform(
        inAppPurchase: _ErrorStore(details),
      );
      final purchase = (await platform.purchaseStream.first).single;
      expect(purchase.status, BillingPurchaseStatus.error);
      expect(purchase.errorCode, 'developer_error');
      expect(purchase.errorMessage, contains('BillingResponse.developerError'));
      if (details != null) expect(purchase.errorMessage, contains(details));
    }
  });
}
