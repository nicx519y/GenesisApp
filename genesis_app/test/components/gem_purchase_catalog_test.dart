import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_catalog.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

void main() {
  testWidgets('New User and First Top-up tags share a compact width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final product in [
                _product(activityText: 'New User'),
                _product(
                  productId: 'gem_pack_1100',
                  activityText: 'First Top-up',
                ),
              ])
                SizedBox(
                  width: 120,
                  height: kGemProductCardHeight,
                  child: GemProductCard(
                    product: product,
                    isBuying: false,
                    isPurchaseInProgress: false,
                    onPurchase: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final newUserTag = find.byKey(
      const ValueKey<String>('gem-product-tag-gem_pack_500'),
    );
    final firstTopUpTag = find.byKey(
      const ValueKey<String>('gem-product-tag-gem_pack_1100'),
    );
    expect(tester.getSize(newUserTag), const Size(68, 20));
    expect(tester.getSize(firstTopUpTag), const Size(68, 20));
    expect(tester.widget<Container>(newUserTag).padding, isNull);
    expect(tester.widget<Container>(firstTopUpTag).padding, isNull);
  });

  testWidgets('promotion tag does not shift product card content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final product in [
                _product(activityText: 'New User'),
                _product(productId: 'gem_pack_1100', activityText: ''),
              ])
                SizedBox(
                  width: 120,
                  height: kGemProductCardHeight,
                  child: GemProductCard(
                    product: product,
                    isBuying: false,
                    isPurchaseInProgress: false,
                    onPurchase: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    for (final element in <String>['icon', 'amount', 'price']) {
      final taggedRect = tester.getRect(
        find.byKey(ValueKey<String>('gem-product-$element-gem_pack_500')),
      );
      final plainRect = tester.getRect(
        find.byKey(ValueKey<String>('gem-product-$element-gem_pack_1100')),
      );
      expect(taggedRect.top, closeTo(plainRect.top, 0.1));
      expect(taggedRect.bottom, closeTo(plainRect.bottom, 0.1));
    }
  });

  testWidgets('new user product card uses backend activity label and color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: kGemProductCardHeight,
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
    expect(tagStyle?.fontSize, 9.5);
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
    expect(amountStyle?.fontSize, 17);
    expect(amountStyle?.height, 1);
    expect(amountStyle?.fontWeight, FontWeight.w800);
    expect(amountStyle?.color, const Color(0xFF131215));

    final originalAmount = find.text('500');
    final originalAmountStyle = tester.widget<Text>(originalAmount).style;
    expect(originalAmountStyle?.fontSize, 9.5);
    expect(originalAmountStyle?.fontWeight, FontWeight.w600);
    expect(originalAmountStyle?.color, const Color(0xFF9E9E9E));
    expect(originalAmountStyle?.decoration, TextDecoration.lineThrough);

    final currentAmountRect = tester.getRect(find.text('+550'));
    final originalAmountRect = tester.getRect(originalAmount);
    final priceButtonRect = tester.getRect(
      find.byKey(const ValueKey('gem-product-price-gem_pack_500')),
    );
    // The struck base amount shares one bottom-aligned row with the total,
    // sitting to its right and above the price button.
    expect(originalAmountRect.bottom, closeTo(currentAmountRect.bottom, 0.6));
    expect(originalAmountRect.left, greaterThan(currentAmountRect.right));
    expect(priceButtonRect.top, greaterThan(originalAmountRect.bottom));

    final priceStyle = tester.widget<Text>(find.text('HKD1.49')).style;
    expect(priceStyle?.fontSize, 11);
    expect(priceStyle?.height, 1);
    expect(priceStyle?.fontWeight, FontWeight.w800);
    expect(priceStyle?.color, const Color(0xE0131215));
    final priceDecoration =
        tester
                .widget<Container>(
                  find.byKey(const ValueKey('gem-product-price-gem_pack_500')),
                )
                .decoration!
            as BoxDecoration;
    expect(priceDecoration.color, const Color(0xFFF82B3C));
    expect(priceDecoration.border, isNull);
    const iconKey = ValueKey<String>('gem-product-icon-gem_pack_500');
    final gemIcon = tester.widget<SvgPicture>(find.byKey(iconKey));
    expect(gemIcon.width, kGemProductIconSize.width);
    expect(gemIcon.height, kGemProductIconSize.height);
    // The artwork is fitted inside that box, so only the height is exact.
    expect(
      tester.getSize(find.byKey(iconKey)).height,
      kGemProductIconSize.height,
    );
  });

  testWidgets('balance panel uses the Gem Wallet typography', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          // The panel has no height of its own; give it the unbounded column
          // it gets in the wallet page so it reports its intrinsic height.
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [GemBalancePanel(balance: 430)],
          ),
        ),
      ),
    );

    final labelStyle = tester.widget<Text>(find.text('My balance')).style;
    expect(labelStyle?.fontSize, 11);
    expect(labelStyle?.height, 1);
    expect(labelStyle?.fontWeight, FontWeight.w600);
    expect(labelStyle?.color, const Color(0x99131215));

    final balanceStyle = tester.widget<Text>(find.text('430')).style;
    expect(balanceStyle?.fontSize, 30);
    expect(balanceStyle?.height, 1);
    expect(balanceStyle?.fontWeight, FontWeight.w800);
    expect(balanceStyle?.color, const Color(0xFF131215));
    const balanceIconKey = ValueKey('gem-balance-icon');
    final balanceIcon = tester.widget<SvgPicture>(find.byKey(balanceIconKey));
    expect(balanceIcon.width, 20);
    expect(balanceIcon.height, 31);
    // The artwork is fitted inside that box, so only the height is exact.
    expect(tester.getSize(find.byKey(balanceIconKey)).height, 31);
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('gem-balance-panel')),
    );
    // Label row (11pt, height 1) then a 6px gap, then the icon/value row that
    // is as tall as the 31px gem icon: 11 + 6 + 31.
    expect(panelRect.height, closeTo(48, 0.1));
    final iconRect = tester.getRect(
      find.byKey(const ValueKey('gem-balance-icon')),
    );
    expect(iconRect.top - panelRect.top, closeTo(17, 0.1));
    // The value row is bottom-aligned, so the balance sits flush with the
    // bottom of the panel.
    expect(
      panelRect.bottom - tester.getRect(find.text('430')).bottom,
      closeTo(0, 0.1),
    );
  });

  testWidgets('other products use backend activity label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: kGemProductCardHeight,
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
            height: kGemProductCardHeight,
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
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.4);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.text('Sold out'), findsOneWidget);
    expect(find.text(r'$1.49'), findsNothing);
    final soldOutButton = tester.widget<Container>(
      find.byKey(const ValueKey('gem-product-price-gem_pack_500')),
    );
    final soldOutDecoration = soldOutButton.decoration! as BoxDecoration;
    // The sold-out button is a flat subtle-surface fill, no outline.
    expect(soldOutDecoration.color, const Color(0xFFFAFAFA));
    expect(soldOutDecoration.border, isNull);
    expect(
      tester.widget<Text>(find.text('Sold out')).style?.color,
      const Color(0xFF9E9E9E),
    );
  });

  testWidgets('product without bonus keeps price bottom inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: kGemProductCardHeight,
            child: GemProductCard(
              product: _product(bonusGems: 0, canPurchase: false),
              isBuying: false,
              isPurchaseInProgress: false,
              onPurchase: () {},
            ),
          ),
        ),
      ),
    );

    final stackRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is Stack && widget.clipBehavior == Clip.none,
      ),
    );
    final priceButtonRect = tester.getRect(
      find.byKey(const ValueKey('gem-product-price-gem_pack_500')),
    );
    expect(stackRect.bottom - priceButtonRect.bottom, 13);
  });

  testWidgets('other unavailable products remain greyed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 105,
            height: kGemProductCardHeight,
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

  testWidgets('product grid keeps fixed heights and adapts widths', (
    tester,
  ) async {
    final billingState = ValueNotifier<BillingState>(BillingState());
    addTearDown(billingState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: GemProductGrid(
              products: [
                _product(productId: 'gem_pack_500'),
                _product(productId: 'gem_pack_1000'),
                _product(productId: 'gem_pack_4000'),
              ],
              billingStateListenable: billingState,
              onPurchase: (_) {},
            ),
          ),
        ),
      ),
    );

    final cardSize = tester.getSize(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_500')),
    );
    final buttonSize = tester.getSize(
      find.byKey(const ValueKey<String>('gem-product-price-gem_pack_500')),
    );

    expect(cardSize.height, kGemProductCardHeight);
    expect(cardSize.width, greaterThan(105));
    expect(buttonSize.height, kGemPriceButtonHeight);
    expect(buttonSize.width, closeTo(cardSize.width - 28, 0.1));
  });
}

GemProduct _product({
  String productId = 'gem_pack_500',
  String activityType = 'none',
  String activityText = 'none',
  String activityColor = '',
  String priceCurrencyCode = 'USD',
  bool canPurchase = true,
  int bonusGems = 50,
}) {
  return GemProduct(
    productId: productId,
    appleProductId: 'com.worldo.gems.500',
    googleProductId: 'worldo_gems_500',
    baseGems: 500,
    bonusGems: bonusGems,
    priceCurrencyCode: priceCurrencyCode,
    priceAmount: 149,
    canPurchase: canPurchase,
    activityType: activityType,
    activityText: activityText,
    activityColor: activityColor,
  );
}
