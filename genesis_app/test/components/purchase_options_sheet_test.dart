import 'package:genesis_flutter_android/ui/components/genesis_fixed_underline_indicator.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_style.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'dart:async';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/components/gems/subscription_tracking_scope.dart';

import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_dark_close_button.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_bottom_sheet.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/platform/billing/billing_service.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/components/gems/wallet_purchase_tabs.dart';
import 'package:genesis_flutter_android/app/attribution/adjust_device_registration.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

import '../support/membership_fixtures.dart';

void main() {
  testWidgets(
    'membership indicator follows Deluxe and interpolates in the sheet',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final offers = [
        for (final deluxe in [false, true])
          for (final yearly in [false, true])
            MembershipOffer(
              product: MembershipProduct.fromJson({
                ...membershipProduct(yearly: yearly).toJson(),
                if (deluxe)
                  'plan_code': yearly ? 'deluxe_yearly' : 'deluxe_monthly',
                if (deluxe) 'store_product_id': 'test_deluxe',
              }),
            ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Scaffold(
            body: PurchaseOptionsSheet(
              initialTab: PurchaseSheetTab.subscription,
              membershipProductsLoader: () async =>
                  MembershipCatalogData(offers: offers, hasPurchased: true),
              gemsBuilder: (_) => const Text('Gems content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Color color() =>
          (tester.widget<TabBar>(find.byType(TabBar)).indicator!
                  as GenesisFixedUnderlineIndicator)
              .color;
      expect(color(), MemoryMembershipTier.deluxe.accent);
      final cards = find.byKey(const ValueKey('membership-subscription-pages'));
      await tester.drag(cards, const Offset(200, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(color(), isNot(MemoryMembershipTier.deluxe.accent));
      expect(color(), isNot(MemoryMembershipTier.premium.accent));
      await tester.pumpAndSettle();
      expect(color(), MemoryMembershipTier.premium.accent);
      await tester.drag(cards, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(color(), MemoryMembershipTier.deluxe.accent);
      final controller = tester
          .widget<WalletPurchaseTabs>(find.byType(WalletPurchaseTabs))
          .controller;
      controller.animateTo(1);
      await tester.pumpAndSettle();
      controller.animateTo(0, duration: const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        color(),
        Color.lerp(
          MemoryMembershipTier.deluxe.accent,
          GenesisColors.redPrimary,
          controller.animation!.value,
        ),
      );
      await tester.pumpAndSettle();
      expect(color(), MemoryMembershipTier.deluxe.accent);
      final swipe = await tester.startGesture(tester.getCenter(cards));
      await swipe.moveBy(const Offset(-40, 0));
      await swipe.moveBy(const Offset(8, 0));
      await tester.pump();
      expect(controller.animation!.value, 0);
      await swipe.moveBy(
        const Offset(-85, 0),
        timeStamp: const Duration(milliseconds: 600),
      );
      await tester.pump();
      expect(controller.offset, inExclusiveRange(0, .5));
      await swipe.up(timeStamp: const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(controller.index, 1);

      final returnSwipe = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('purchase-sheet-pages'))),
      );
      await returnSwipe.moveBy(const Offset(40, 0));
      await returnSwipe.moveBy(
        const Offset(75, 0),
        timeStamp: const Duration(milliseconds: 600),
      );
      await tester.pump();
      expect(controller.offset, inExclusiveRange(-.5, 0));
      await returnSwipe.up(timeStamp: const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(controller.index, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final initial in PurchaseSheetTab.values) {
    testWidgets('tab round trips preserve original source for $initial', (
      tester,
    ) async {
      final expected = initial == PurchaseSheetTab.buyGems
          ? 'from_buy_gems_tab[from_msg_no_balance]'
          : 'from_home_membership';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseOptionsSheet(
              initialTab: initial,
              gemsSource: BillingPurchaseSource.msgNoBalance,
              subscriptionSource: SubscriptionSource.homeMembership,
              subscriptionBuilder: (_) => Builder(
                builder: (context) => Text(
                  SubscriptionTrackingScope.maybeOf(context)!.source.value,
                ),
              ),
              gemsBuilder: (_) => const Text('Original Gems tab'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('wallet-subscription-tab')));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('wallet-buy-gems-tab')));
        await tester.pumpAndSettle();
        expect(find.text('Original Gems tab'), findsOneWidget);
      }
    });
  }

  testWidgets('purchase sheet stays visible while registration is pending', (
    tester,
  ) async {
    final pendingRequest = Completer<void>();
    var requests = 0;
    final registration = AdjustDeviceRegistration(
      platform: TargetPlatform.android,
      environmentProvider: () => 'sandbox',
      readAdid: (_) async => 'ready-adid',
      readGoogleAdId: () async => 'ready-gaid',
      registerDevice:
          ({
            required adid,
            required environment,
            gpsAdid,
            idfa,
            idfv,
            required appInstanceId,
            privacyConsent,
          }) async {
            requests++;
            await pendingRequest.future;
          },
    );
    addTearDown(registration.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PurchaseOptionsSheet(
            attributionRegistration: registration,
            subscriptionBuilder: (_) => const SizedBox.expand(),
            gemsBuilder: (_) => const Text('Gems content'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.text('Gems content'), findsOneWidget);
    pendingRequest.complete();
    await tester.pump();
  });

  for (final initialTab in PurchaseSheetTab.values) {
    testWidgets('purchase sheet registers once per visible tab: $initialTab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      final registration = AdjustDeviceRegistration(
        platform: TargetPlatform.android,
        environmentProvider: () => 'sandbox',
        readAdid: (_) async => 'ready-adid',
        readGoogleAdId: () async => 'ready-gaid',
        registerDevice:
            ({
              required adid,
              required environment,
              gpsAdid,
              idfa,
              idfv,
              required appInstanceId,
              privacyConsent,
            }) async {
              requests.add(adid);
            },
      );
      addTearDown(registration.dispose);

      Widget purchaseSheet() => MaterialApp(
        home: Scaffold(
          body: PurchaseOptionsSheet(
            initialTab: initialTab,
            attributionRegistration: registration,
            subscriptionBuilder: (_) => const SizedBox.expand(),
            gemsBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );

      await tester.pumpWidget(purchaseSheet());
      await tester.pumpAndSettle();
      expect(requests, ['ready-adid']);

      final otherTab = initialTab == PurchaseSheetTab.subscription
          ? 'wallet-buy-gems-tab'
          : 'wallet-subscription-tab';
      final originalTab = initialTab == PurchaseSheetTab.subscription
          ? 'wallet-subscription-tab'
          : 'wallet-buy-gems-tab';
      await tester.tap(find.byKey(ValueKey(otherTab)));
      await tester.pumpAndSettle();
      expect(requests, ['ready-adid', 'ready-adid']);

      await tester.tap(find.byKey(ValueKey(originalTab)));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(purchaseSheet());
      await tester.pumpAndSettle();
      expect(requests, hasLength(3));
    });
  }

  for (final initialTab in PurchaseSheetTab.values) {
    testWidgets(
      'sheet loads only selected tab $initialTab, including canceled swipes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var memberships = 0;
        var products = 0;
        var balances = 0;
        final wallet = GemWalletStore(
          readUid: () async => 'u_test',
          loadWallet: () async {
            balances++;
            return const GemWallet(balanceCent: 43000);
          },
        );
        final billing = _SheetBillingService();
        addTearDown(wallet.dispose);
        addTearDown(billing.state.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.light(),
            home: Scaffold(
              body: PurchaseOptionsSheet(
                initialTab: initialTab,
                membershipProductsLoader: () {
                  memberships++;
                  return loadTestMembershipOffers();
                },
                gemsBuilder: (_) => GemPurchaseBottomSheet(
                  productsLoader: () async {
                    products++;
                    return [];
                  },
                  walletStore: wallet,
                  billingService: billing,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final subscriptionFirst = initialTab == PurchaseSheetTab.subscription;
        expect(memberships, subscriptionFirst ? 1 : 0);
        expect(products, subscriptionFirst ? 0 : 1);
        expect(balances, products);
        expect(billing.starts, products);
        final pages = find.byKey(const ValueKey('purchase-sheet-pages'));
        final gesture = await tester.startGesture(tester.getCenter(pages));
        final direction = subscriptionFirst ? -1.0 : 1.0;
        await gesture.moveBy(Offset(direction * 60, 0));
        await tester.pump();
        expect(memberships, subscriptionFirst ? 1 : 0);
        expect(products, subscriptionFirst ? 0 : 1);
        await gesture.moveBy(Offset(-direction * 60, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(memberships, subscriptionFirst ? 1 : 0);
        expect(products, subscriptionFirst ? 0 : 1);
        await tester.drag(pages, Offset(direction * 330, 0));
        await tester.pumpAndSettle();
        expect([memberships, products, balances, billing.starts], [1, 1, 1, 1]);
        double? subscriptionTop;
        for (final tabKey in [
          'wallet-subscription-tab',
          'wallet-buy-gems-tab',
        ]) {
          await tester.tap(find.byKey(ValueKey(tabKey)));
          await tester.pumpAndSettle();
          final headerBottom = tester
              .getRect(find.byType(GenesisActionSheetHeader))
              .bottom;
          final contentTop = tester
              .getTopLeft(
                find.byKey(
                  ValueKey(
                    tabKey == 'wallet-subscription-tab'
                        ? 'pro-benefits-card'
                        : 'gem-balance-panel',
                  ),
                ),
              )
              .dy;
          expect(contentTop, closeTo(headerBottom, .01));
          final pageRect = tester.getRect(
            find.byKey(const ValueKey('purchase-sheet-pages')),
          );
          final contentRect = tester.getRect(
            find.byKey(
              ValueKey(
                tabKey == 'wallet-subscription-tab'
                    ? 'pro-benefits-card'
                    : 'gem-balance-panel',
              ),
            ),
          );
          expect(contentRect.left - pageRect.left, 16);
          expect(pageRect.right - contentRect.right, 16);
          if (tabKey == 'wallet-subscription-tab') {
            final buttonRect = tester.getRect(
              find.byKey(const ValueKey('pro-subscribe-button')),
            );
            expect(buttonRect.left - pageRect.left, 16);
            expect(pageRect.right - buttonRect.right, 16);
          }

          if (tabKey == 'wallet-subscription-tab') {
            subscriptionTop = contentTop;
          } else {
            expect(contentTop, closeTo(subscriptionTop!, .01));
            // The label heads the panel and the gem now leads the figure a
            // line below it, so both share the content's left edge instead.
            final label = tester.getTopLeft(find.text('My Balance'));
            expect(label.dy, closeTo(headerBottom, .01));
            expect(
              tester
                  .getTopLeft(find.byKey(const ValueKey('gem-balance-icon')))
                  .dx,
              closeTo(label.dx, .01),
            );
          }
        }
        for (final key in [
          'wallet-subscription-tab',
          'wallet-buy-gems-tab',
          'wallet-subscription-tab',
        ]) {
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pumpAndSettle();
        }
        expect(
          [memberships, products, balances, billing.starts],
          [subscriptionFirst ? 4 : 3, 3, 1, 1],
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'both purchase tabs reject outside taps and drags but allow close and back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.light(),
          scrollBehavior: const GenesisScrollBehavior(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showGenesisModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: .8,
                    child: PurchaseOptionsSheet(
                      membershipProductsLoader: loadTestMembershipOffers,
                      initialTab: PurchaseSheetTab.subscription,
                      gemsBuilder: (_) => ListView.builder(
                        key: const ValueKey('scrollable-gems'),
                        itemExtent: 60,
                        itemCount: 30,
                        itemBuilder: (_, index) => Text('Gem pack $index'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open purchase'),
              ),
            ),
          ),
        ),
      );
      for (final tab in PurchaseSheetTab.values) {
        await tester.tap(find.text('Open purchase'));
        await tester.pumpAndSettle();
        if (tab == PurchaseSheetTab.buyGems) {
          await tester.drag(
            find.byKey(const ValueKey('purchase-sheet-pages')),
            const Offset(-320, 0),
          );
          await tester.pumpAndSettle();
          expect(find.byType(PurchaseOptionsSheet), findsOneWidget);
        }
        final list = tab == PurchaseSheetTab.subscription
            ? find.byKey(const PageStorageKey('pro-benefits-scroll'))
            : find.byKey(const ValueKey('scrollable-gems'));
        await tester.drag(list, const Offset(0, -180));
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        expect(position.pixels, greaterThan(50));
        await tester.drag(list, const Offset(0, 40));
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsOneWidget);
        position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, 120));
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsOneWidget);
        await tester.drag(
          find.byType(GenesisActionSheetHeader),
          const Offset(0, 160),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('gem-purchase-sheet-close')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsNothing);
        expect(find.text('Open purchase'), findsOneWidget);
        await tester.tap(find.text('Open purchase'));
        await tester.pumpAndSettle();
        if (tab == PurchaseSheetTab.buyGems) {
          await tester.tap(find.text('Buy Gems'));
          await tester.pumpAndSettle();
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PurchaseOptionsSheet), findsNothing);
      }
    },
  );

  testWidgets('sheet shares Wallet UI and preserves both tabs while swiping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var gemsBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.light(),
        scrollBehavior: const GenesisScrollBehavior(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: .8,
              child: PurchaseOptionsSheet(
                membershipProductsLoader: loadTestMembershipOffers,
                initialTab: PurchaseSheetTab.subscription,
                gemsBuilder: (_) {
                  gemsBuilds++;
                  return const TextField(key: ValueKey('demo-gems-state'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WalletPurchaseTabs), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(WalletPurchaseTabs))).brightness,
      Brightness.dark,
    );
    expect(find.byType(GenesisDarkCloseButton), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Subscription')).style?.color,
      GenesisColors.darkTextPrimary,
    );

    expect(find.byType(ProSubscriptionContent), findsOneWidget);
    final headerRect = tester.getRect(find.byType(GenesisActionSheetHeader));
    expect(headerRect.height, 68);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('pro-benefits-card'))).dy,
      headerRect.bottom,
    );
    expect(tester.widget<Text>(find.text('Subscription')).style?.fontSize, 16);

    expect(gemsBuilds, 0);
    final subscription = tester.getRect(
      find.byKey(const ValueKey('wallet-subscription-tab')),
    );
    final gems = tester.getRect(
      find.byKey(const ValueKey('wallet-buy-gems-tab')),
    );
    expect(subscription.width, closeTo(gems.width, .01));
    expect((subscription.right + gems.left) / 2, closeTo(195, .01));
    await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
    await tester.pumpAndSettle();
    final pages = find.byKey(const ValueKey('purchase-sheet-pages'));
    await tester.drag(pages, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(gemsBuilds, greaterThan(0));
    await tester.enterText(
      find.byKey(const ValueKey('demo-gems-state')),
      'Preserved',
    );
    await tester.tap(find.byKey(const ValueKey('wallet-subscription-tab')));
    await tester.pumpAndSettle();
    expect(findSubscriptionLabel('Monthly: \$9.99'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-buy-gems-tab')));
    await tester.pumpAndSettle();
    expect(find.text('Preserved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SheetBillingService implements BillingService {
  int starts = 0;
  @override
  final ValueNotifier<BillingState> state = ValueNotifier<BillingState>(
    BillingState(storeAvailable: true),
  );
  @override
  Stream<BillingUiEvent> get events => const Stream.empty();
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
