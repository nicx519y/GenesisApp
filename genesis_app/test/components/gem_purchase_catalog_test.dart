import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_catalog.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';

void main() {
  testWidgets('new user product card uses backend activity label and color', (
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
                activityType: 'Backend New User',
                activityText: 'Backend New User',
                activityColor: '#123456',
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

    expect(find.text('Backend New User'), findsOneWidget);
    expect(find.text('HKD1.49'), findsOneWidget);
    expect(find.text('+550'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);

    final tagStyle = tester.widget<Text>(find.text('Backend New User')).style;
    expect(tagStyle?.fontSize, 10);
    expect(tagStyle?.height, 14 / 10);
    expect(tagStyle?.fontWeight, FontWeight.w400);
    final tagContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Backend New User'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (tagContainer.decoration as BoxDecoration).color,
      const Color(0xFF123456),
    );

    final amountStyle = tester.widget<Text>(find.text('+550')).style;
    expect(amountStyle?.fontSize, 14);
    expect(amountStyle?.height, 20 / 14);
    expect(amountStyle?.fontWeight, FontWeight.w600);
    expect(amountStyle?.color, const Color(0xFF111111));

    final originalAmount = find.text('500');
    final originalAmountStyle = tester.widget<Text>(originalAmount).style;
    expect(originalAmountStyle?.fontSize, 12);
    expect(originalAmountStyle?.fontWeight, FontWeight.w400);
    expect(originalAmountStyle?.color, const Color(0xFF888888));
    expect(originalAmountStyle?.decoration, TextDecoration.lineThrough);

    final currentAmountRect = tester.getRect(find.text('+550'));
    final originalAmountRect = tester.getRect(originalAmount);
    final priceButtonRect = tester.getRect(
      find.byKey(const ValueKey('gem-product-price-gem_pack_500')),
    );
    expect(
      priceButtonRect.top - originalAmountRect.bottom,
      closeTo(originalAmountRect.top - currentAmountRect.bottom + 4, 0.1),
    );

    final priceStyle = tester.widget<Text>(find.text('HKD1.49')).style;
    expect(priceStyle?.fontSize, 12);
    expect(priceStyle?.height, 14 / 12);
    expect(priceStyle?.fontWeight, FontWeight.w600);
    expect(priceStyle?.color, Colors.white);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('gem-product-icon-gem_pack_500')),
      ),
      const Size(28, 24),
    );
  });

  testWidgets('balance panel uses the Gem Wallet typography', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GemBalancePanel(balance: 430))),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('gem-balance-panel'))).height,
      100,
    );
    final labelStyle = tester.widget<Text>(find.text('My Balance')).style;
    expect(labelStyle?.fontSize, 14);
    expect(labelStyle?.height, 18 / 14);
    expect(labelStyle?.fontWeight, FontWeight.w600);
    expect(labelStyle?.color, const Color(0xFF666666));

    final balanceStyle = tester.widget<Text>(find.text('430')).style;
    expect(balanceStyle?.fontSize, 30);
    expect(balanceStyle?.height, 40 / 30);
    expect(balanceStyle?.fontWeight, FontWeight.w600);
    expect(balanceStyle?.color, const Color(0xFF333333));
    expect(
      tester.getSize(find.byKey(const ValueKey('gem-balance-icon'))),
      const Size.square(24),
    );
  });

  testWidgets('other products use backend activity label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: 142,
            child: GemProductCard(
              product: _product(
                productId: 'gem_pack_1100',
                activityType: 'Backend Top-up',
                activityText: 'Backend Top-up',
                activityColor: '#654321',
              ),
              isBuying: false,
              isPurchaseInProgress: false,
              onPurchase: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Backend Top-up'), findsOneWidget);
    final tagContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Backend Top-up'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (tagContainer.decoration as BoxDecoration).color,
      const Color(0xFF654321),
    );
  });

  testWidgets('sold out new user product keeps its card styling', (
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
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.text('Sold Out'), findsOneWidget);
    expect(find.text('USD1.49'), findsNothing);
    final soldOutButton = tester.widget<Container>(
      find.byKey(const ValueKey('gem-product-price-gem_pack_500')),
    );
    expect(
      (soldOutButton.decoration as BoxDecoration).color,
      const Color(0xFFFF9AAA),
    );
  });

  testWidgets('other unavailable products remain greyed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: 142,
            child: GemProductCard(
              product: _product(productId: 'gem_pack_1100', canPurchase: false),
              isBuying: false,
              isPurchaseInProgress: false,
              onPurchase: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.text('Sold Out'), findsNothing);
  });
}

GemProduct _product({
  String productId = 'gem_pack_500',
  String activityType = 'none',
  String activityText = 'none',
  String activityColor = '',
  String priceCurrencyCode = 'USD',
  bool canPurchase = true,
}) {
  return GemProduct(
    productId: productId,
    appleProductId: 'com.worldo.gems.500',
    googleProductId: 'worldo_gems_500',
    baseGems: 500,
    bonusGems: 50,
    priceCurrencyCode: priceCurrencyCode,
    priceAmount: 149,
    canPurchase: canPurchase,
    activityType: activityType,
    activityText: activityText,
    activityColor: activityColor,
  );
}
