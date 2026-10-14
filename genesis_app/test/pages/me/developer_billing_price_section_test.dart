import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:genesis_flutter_android/pages/me/developer_page.dart';
import 'package:genesis_flutter_android/platform/billing/store_price_query_diagnostics.dart';
import 'package:genesis_flutter_android/app/debug/billing_price_diagnostics.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';

void main() {
  testWidgets(
    'diagnostics preserve last query across collapse and background updates',
    (tester) async {
      void record(String price) => storePriceQueryDiagnostics.recordResponse(
        group: 'Gems',
        requestedIds: {'pack'},
        response: ProductDetailsResponse(
          productDetails: [
            ProductDetails(
              id: 'pack',
              title: 'Pack',
              description: '',
              price: price,
              rawPrice: 12,
              currencyCode: 'GBP',
              currencySymbol: '£',
            ),
          ],
          notFoundIDs: [],
        ),
      );
      addTearDown(storePriceQueryDiagnostics.clear);
      addTearDown(billingPriceDiagnostics.clear);
      billingPriceDiagnostics.recordGems(
        surface: 'Buy Gems sheet',
        snapshotSource: 'fresh',
        products: [
          GemProduct.fromJson({
            'product_id': 'pack',
            'google_product_id': 'pack',
            'apple_product_id': 'pack',
            'base_gems_cent': 50000,
            'bonus_gems_cent': 0,
            'price_amount': 1200,
            'price_currency_code': 'GBP',
          }),
        ],
      );
      record('£12.00');
      Widget page() => MaterialApp(
        home: Scaffold(
          body: ListView(children: [developerBillingPriceSectionForTesting()]),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.textContaining('"price": "£12.00"'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(
        tester.getRect(find.text('Page').first).left,
        closeTo(tester.getRect(find.text('Store')).left, 0.1),
      );
      expect(
        tester.getRect(find.textContaining('"price": "£12.00"')).left,
        tester
            .getRect(find.text('No page display captured for this product.'))
            .left,
      );
      await tester.tap(find.text('Price diagnostics'));
      await tester.pumpAndSettle();
      record('£15.00');
      await tester.tap(find.text('Price diagnostics'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"price": "£12.00"'), findsNothing);
      expect(find.textContaining('"price": "£15.00"'), findsOneWidget);
      expect(find.text('Page').first, findsOneWidget);
      expect(
        find.text('No page display captured for this product.'),
        findsOneWidget,
      );
      record('£20.00');
      await tester.pump();
      expect(find.textContaining('"price": "£15.00"'), findsOneWidget);
      expect(find.textContaining('"price": "£20.00"'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.textContaining('"price": "£20.00"'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
