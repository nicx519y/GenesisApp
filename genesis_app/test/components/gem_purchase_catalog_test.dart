import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_catalog.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';

void main() {
  testWidgets('product card uses backend activity and currency fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: 142,
            child: GemProductCard(
              product: _product(
                activityType: 'New user',
                priceCurrencyCode: 'HKD',
              ),
              isBuying: false,
              isPurchaseInProgress: false,
              onPurchase: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('New user'), findsOneWidget);
    expect(find.text('HKD1.49'), findsOneWidget);
  });

  testWidgets('activity type is displayed without mapping', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: 142,
            child: GemProductCard(
              product: _product(activityType: 'none'),
              isBuying: false,
              isPurchaseInProgress: false,
              onPurchase: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('none'), findsOneWidget);
  });

  testWidgets('unavailable product is greyed out and ignores taps', (
    tester,
  ) async {
    var purchaseCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: 142,
            child: GemProductCard(
              product: _product(canPurchase: false),
              isBuying: false,
              isPurchaseInProgress: false,
              onPurchase: () => purchaseCalls += 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_500')),
    );
    await tester.pump();

    expect(purchaseCalls, 0);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}

GemProduct _product({
  String activityType = 'none',
  String priceCurrencyCode = 'USD',
  bool canPurchase = true,
}) {
  return GemProduct(
    productId: 'gem_pack_500',
    appleProductId: 'com.worldo.gems.500',
    googleProductId: 'worldo_gems_500',
    baseGems: 500,
    bonusGems: 500,
    priceCurrencyCode: priceCurrencyCode,
    priceAmount: 149,
    canPurchase: canPurchase,
    activityType: activityType,
  );
}
