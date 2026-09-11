import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'membership_product_store_test.dart' as fixture;

class _Client extends Fake implements BillingClient {
  BillingResultWrapper result = const BillingResultWrapper(
    responseCode: BillingResponse.ok,
  );
  int launches = 0;
  @override
  Future<BillingResultWrapper> launchBillingFlow({
    required String product,
    String? offerToken,
    String? accountId,
    String? obfuscatedProfileId,
    String? oldProduct,
    String? purchaseToken,
    ReplacementMode? replacementMode,
  }) async {
    launches++;
    return result;
  }
}

class _Manager extends Fake implements BillingClientManager {
  final native = _Client();
  final updates = StreamController<PurchasesResultWrapper>.broadcast();
  int retryableCalls = 0;
  int nonRetryableCalls = 0;
  @override
  Stream<PurchasesResultWrapper> get purchasesUpdatedStream => updates.stream;
  @override
  Stream<UserChoiceDetailsWrapper> get userChoiceDetailsStream =>
      const Stream.empty();
  @override
  Future<R> runWithClient<R extends HasBillingResponse>(
    Future<R> Function(BillingClient) action,
  ) {
    retryableCalls++;
    return action(native);
  }

  @override
  Future<R> runWithClientNonRetryable<R>(
    Future<R> Function(BillingClient) action,
  ) {
    nonRetryableCalls++;
    return action(native);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'VIP launch surfaces every native failure and never retries the launch; Gems keeps bool results',
    () async {
      final manager = _Manager();
      final plugin = InAppPurchaseAndroidPlatform(manager: manager);
      final product = fixture.details([fixture.offer()]).single;
      for (final code in BillingResponse.values) {
        manager.native.result = BillingResultWrapper(
          responseCode: code,
          subResponseCode: 2,
          debugMessage: 'original response',
        );
        final vip = GooglePlayPurchaseParam(
          productDetails: product,
          applicationUserName: 'catalog-uuid',
          throwOnBillingFailure: true,
        );
        final before = manager.native.launches;
        if (code == BillingResponse.ok) {
          expect(await plugin.buyNonConsumable(purchaseParam: vip), isTrue);
        } else {
          await expectLater(
            plugin.buyNonConsumable(purchaseParam: vip),
            throwsA(
              isA<PlatformException>()
                  .having((e) => e.code, 'native code', code.name)
                  .having((e) => e.message, 'raw message', 'original response')
                  .having(
                    (e) => (e.details as Map)['subResponseCode'],
                    'native subcode',
                    2,
                  ),
            ),
          );
        }
        expect(manager.native.launches, before + 1);
        expect(manager.retryableCalls, 0);
      }
      manager.native.result = const BillingResultWrapper(
        responseCode: BillingResponse.developerError,
      );
      expect(
        await plugin.buyNonConsumable(
          purchaseParam: GooglePlayPurchaseParam(productDetails: product),
        ),
        isFalse,
      );
      expect(manager.retryableCalls, 1);
      expect(manager.nonRetryableCalls, BillingResponse.values.length);
      await manager.updates.close();
    },
  );

  test(
    'native purchase callback retains the main code, subcode and original diagnostic',
    () async {
      final manager = _Manager();
      final plugin = InAppPurchaseAndroidPlatform(manager: manager);
      final callback = plugin.purchaseStream.first;
      manager.updates.add(
        PurchasesResultWrapper(
          responseCode: BillingResponse.error,
          billingResult: const BillingResultWrapper(
            responseCode: BillingResponse.error,
            subResponseCode: 1,
            debugMessage: 'original callback',
          ),
          purchasesList: const [],
        ),
      );
      final result = (await callback).single;
      expect(result.status, PurchaseStatus.error);
      expect(result.error!.message, 'BillingResponse.error');
      expect(result.error!.details, {
        'responseCode': 'error',
        'subResponseCode': 1,
        'debugMessage': 'original callback',
      });
      await manager.updates.close();
    },
  );
}
