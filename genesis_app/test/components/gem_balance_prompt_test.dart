import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/components/gems/gem_balance_prompt.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_catalog.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/billing_service.dart';

void main() {
  testWidgets('insufficient balance opens the purchase bottom sheet', (
    tester,
  ) async {
    final fixture = _PromptFixture();
    addTearDown(fixture.dispose);
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.insufficient),
      fixture,
    );

    expect(find.text(insufficientGemBalancePrompt), findsOneWidget);
    final titleStyle = tester
        .widget<Text>(find.text(insufficientGemBalancePrompt))
        .style;
    expect(titleStyle?.fontWeight, FontWeight.w600);
    expect(titleStyle?.color, const Color(0xFF111111));
    final closeButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('gem-purchase-sheet-close')),
    );
    expect((closeButton.icon! as Icon).color, const Color(0xFF111111));
    expect(find.text('430'), findsOneWidget);
    expect(find.text('+550'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text(formatGemPrice(149, 'USD')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('gem-purchase-sheet-close')),
      findsOneWidget,
    );
    final sheet = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey<String>('gem-purchase-sheet-size')),
    );
    expect(sheet.heightFactor, 0.8);
  });

  testWidgets('low balance uses the same purchase sheet with low copy', (
    tester,
  ) async {
    final fixture = _PromptFixture();
    addTearDown(fixture.dispose);
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.low, balance: 10),
      fixture,
    );

    expect(find.text(lowGemBalancePrompt), findsOneWidget);
    expect(find.text('+550'), findsOneWidget);
  });

  testWidgets('purchase sheet keeps half of the bottom safe area', (
    tester,
  ) async {
    final fixture = _PromptFixture();
    addTearDown(fixture.dispose);
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.insufficient),
      fixture,
      bottomViewPadding: 40,
    );

    final safeArea = tester.widget<Padding>(
      find.byKey(const ValueKey<String>('gem-purchase-sheet-safe-area')),
    );
    expect(safeArea.padding, const EdgeInsets.only(bottom: 20));
  });

  testWidgets('purchase sheet starts one purchase and closes on success', (
    tester,
  ) async {
    final fixture = _PromptFixture(
      products: [_product('gem_pack_500'), _product('gem_pack_1100')],
    );
    addTearDown(fixture.dispose);
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.insufficient),
      fixture,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_500')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('gem-product-gem_pack_1100')),
    );
    await tester.pump();

    expect(fixture.billing.purchasedProducts, hasLength(1));
    expect(fixture.billing.purchasedProducts.single.productId, 'gem_pack_500');

    fixture.billing.emitSuccess('gem_pack_500');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(insufficientGemBalancePrompt), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('purchase sheet closes from its close button', (tester) async {
    final fixture = _PromptFixture();
    addTearDown(fixture.dispose);
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.insufficient),
      fixture,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('gem-purchase-sheet-close')),
    );
    await tester.pumpAndSettle();

    expect(find.text(insufficientGemBalancePrompt), findsNothing);
  });
}

Future<void> _pumpPrompt(
  WidgetTester tester,
  GemBalanceAlert alert,
  _PromptFixture fixture, {
  double bottomViewPadding = 0,
}) async {
  tester.view.viewPadding = FakeViewPadding(
    bottom: bottomViewPadding * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetViewPadding);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showGemBalancePrompt(
              context,
              alert,
              productsLoader: () async => fixture.products,
              walletStore: fixture.walletStore,
              billingService: fixture.billing,
            ),
            child: const Text('Show prompt'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Show prompt'));
  await tester.pumpAndSettle();
}

class _PromptFixture {
  _PromptFixture({List<GemProduct>? products})
    : products = products ?? [_product('gem_pack_500')],
      walletStore = GemWalletStore(
        loadWallet: () async => const GemWallet(balance: 430),
        readUid: () async => 'u_user',
      );

  final List<GemProduct> products;
  final GemWalletStore walletStore;
  final _FakeBillingService billing = _FakeBillingService();

  void dispose() {
    walletStore.dispose();
    billing.dispose();
  }
}

class _FakeBillingService implements BillingService {
  final ValueNotifier<BillingState> _state = ValueNotifier<BillingState>(
    BillingState(storeAvailable: true),
  );
  final StreamController<BillingUiEvent> _events =
      StreamController<BillingUiEvent>.broadcast();
  final List<GemProduct> purchasedProducts = <GemProduct>[];

  @override
  Stream<BillingUiEvent> get events => _events.stream;

  @override
  ValueListenable<BillingState> get state => _state;

  @override
  Future<void> purchaseGem(GemProduct product) async {
    if (_state.value.hasBusyPurchase) return;
    purchasedProducts.add(product);
    _state.value = BillingState(
      storeAvailable: true,
      busyProductIds: <String>{product.productId},
    );
  }

  void emitSuccess(String productId) {
    _state.value = BillingState(storeAvailable: true);
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.success,
        productId: productId,
        attemptId: 'pay_test',
        message: 'Purchase successful.',
      ),
    );
  }

  @override
  Future<void> recover(BillingRecoverySource source) async {}

  @override
  void resetForSession() {}

  @override
  Future<void> start() async {}

  @override
  void dispose() {
    _state.dispose();
    _events.close();
  }
}

GemProduct _product(String productId) {
  return GemProduct(
    productId: productId,
    appleProductId: productId,
    googleProductId: productId,
    baseGems: productId == 'gem_pack_500' ? 500 : 1100,
    bonusGems: 50,
    priceCurrencyCode: 'USD',
    priceAmount: 149,
    canPurchase: true,
    activityType: 'first_purchase_bonus',
  );
}
