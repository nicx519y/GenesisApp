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

    final tagStyle = tester.widget<Text>(find.text('New user')).style;
    expect(tagStyle?.fontSize, 8);
    expect(tagStyle?.height, 10 / 8);
    expect(tagStyle?.fontWeight, FontWeight.w700);

    final amountStyle = tester.widget<Text>(find.text('+500')).style;
    expect(amountStyle?.fontSize, 15);
    expect(amountStyle?.height, 20 / 15);
    expect(amountStyle?.fontWeight, FontWeight.w700);
    expect(amountStyle?.color, const Color(0xFF333333));

    final priceStyle = tester.widget<Text>(find.text('HKD1.49')).style;
    expect(priceStyle?.fontSize, 11);
    expect(priceStyle?.height, 14 / 11);
    expect(priceStyle?.fontWeight, FontWeight.w600);
    expect(priceStyle?.color, Colors.white);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('gem-product-icon-gem_pack_500')),
      ),
      const Size.square(24),
    );
  });

  testWidgets('balance panel uses the Gem Wallet typography', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GemBalancePanel(balance: 430))),
    );

    final labelStyle = tester.widget<Text>(find.text('My Balance')).style;
    expect(labelStyle?.fontSize, 12);
    expect(labelStyle?.height, 18 / 12);
    expect(labelStyle?.fontWeight, FontWeight.w600);
    expect(labelStyle?.color, const Color(0xFF666666));

    final balanceStyle = tester.widget<Text>(find.text('430')).style;
    expect(balanceStyle?.fontSize, 34);
    expect(balanceStyle?.height, 40 / 34);
    expect(balanceStyle?.fontWeight, FontWeight.w700);
    expect(balanceStyle?.color, const Color(0xFF333333));
    expect(
      tester.getSize(find.byKey(const ValueKey('gem-balance-icon'))),
      const Size.square(24),
    );
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
