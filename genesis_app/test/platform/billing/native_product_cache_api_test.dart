import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
// ignore: implementation_imports
import 'package:in_app_purchase_android/src/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.in_app_purchase_android.InAppPurchaseApi.getCachedProductDetails',
    InAppPurchaseApi.pigeonChannelCodec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler(channel, null));

  for (final hit in [true, false]) {
    test(
      'native cache ${hit ? "hit" : "miss"} crosses Pigeon boundary',
      () async {
        messenger.setMockDecodedMessageHandler(channel, (message) async {
          final request = (message as List).single as PlatformQueryProduct;
          expect(request.productId, 'sku');
          expect(request.productType, PlatformProductType.inapp);
          return [
            hit
                ? PlatformProductDetails(
                    description: 'Description',
                    name: 'Gems',
                    productId: 'sku',
                    productType: PlatformProductType.inapp,
                    title: 'Gems',
                    oneTimePurchaseOfferDetails: null,
                    oneTimePurchaseOfferDetailsList: null,
                    subscriptionOfferDetails: null,
                  )
                : null,
          ];
        });
        final client = BillingClient((_) {}, null);
        final result = await client.getCachedProductDetails(
          const ProductWrapper(
            productId: 'sku',
            productType: ProductType.inapp,
          ),
        );
        if (hit) {
          expect(result?.productId, 'sku');
          expect(result?.title, 'Gems');
        } else {
          expect(result, isNull);
        }
      },
    );
  }
}
