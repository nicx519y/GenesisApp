import 'package:flutter/services.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_eligibility.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_style.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_carousel.dart';
import 'package:genesis_flutter_android/components/gems/pro_membership_badge.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/gems/pro_user_name.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/user.dart';
import 'package:genesis_flutter_android/platform/billing/membership_catalog_cache.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import '../../support/membership_fixtures.dart';
import 'membership_purchase_service_test.dart' as support;

MembershipProduct deluxe({
  bool yearly = false,
  MembershipProvider provider = MembershipProvider.google,
}) => MembershipProduct.fromJson({
  ...membershipProduct(provider: provider, yearly: yearly).toJson(),
  'plan_code': yearly ? 'deluxe_yearly' : 'deluxe_monthly',
  'store_product_id': provider == MembershipProvider.google
      ? 'test_deluxe'
      : yearly
      ? 'test_deluxe_yearly'
      : 'test_deluxe_monthly',
});
GemWalletMembership summary(String plan, {int status = 1, int blue = 100}) =>
    GemWalletMembership(
      status: status,
      planCode: plan,
      expiresAt: DateTime.utc(2040),
      autoRenew: true,
      blueGemsCent: blue,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'both catalogs retain independent UUIDs and never persist credentials',
    () {
      final catalog = MembershipProductList.fromJson({
        'list': [membershipProduct().toJson()],
        'list_deluxe': [deluxe().toJson()],
        'has_purchased': true,
        'last_account_uuid': support.accountUuid,
        'last_account_uuid_deluxe': support.guest.accountUuid,
      });
      expect(catalog.allProducts, hasLength(2));
      expect(
        catalog.accountUuidFor(MembershipType.premium),
        support.accountUuid,
      );
      expect(
        catalog.accountUuidFor(MembershipType.deluxe),
        support.guest.accountUuid,
      );
      expect(catalog.toJson().keys, isNot(contains('last_account_uuid')));
      expect(
        catalog.toJson().keys,
        isNot(contains('last_account_uuid_deluxe')),
      );
      final cached = MembershipProductList.fromJson(catalog.toJson());
      expect(cached.hasPurchased, true);
      expect(
        cached.deluxeProducts.single.membershipType,
        MembershipType.deluxe,
      );
      expect(cached.lastAccountUuidDeluxe, isNull);
    },
  );
  test('wallet sums both balances without treating one as the other', () {
    final wallet = GemWallet.fromJson({
      'wallet': {'balance_cent': 100},
      'membership': {
        'membership_status': 1,
        'plan_code': 'pro_monthly',
        'expires_at': 2100000000,
        'auto_renew': true,
        'blue_gems_cent': 125,
      },
      'membership_deluxe': {
        'membership_status': 1,
        'plan_code': 'deluxe_yearly',
        'expires_at': 2200000000,
        'auto_renew': false,
        'blue_gems_cent': 250,
      },
    });
    expect(wallet.blueGemsCent, 375);
    expect(wallet.membershipDeluxe!.autoRenew, false);
    expect(wallet.membership!.planCode, 'pro_monthly');
  });
  test('Premium annual does not block Deluxe monthly and vice versa', () {
    final access = MembershipAccessState(
      status: MembershipAccessStatus.active,
      membership: summary('pro_yearly'),
      membershipDeluxe: summary('deluxe_monthly'),
    );
    expect(membershipIsDowngrade(deluxe(), access), false);
    expect(membershipIsDowngrade(membershipProduct(), access), true);
    expect(membershipIsSubscribedToSelectedPlan(deluxe(), access), true);
    final onlyDeluxe = MembershipAccessState(
      status: MembershipAccessStatus.active,
      membershipDeluxe: summary('deluxe_yearly'),
    );
    expect(membershipIsDowngrade(membershipProduct(), onlyDeluxe), false);
    expect(membershipIsDowngrade(deluxe(), onlyDeluxe), true);
  });
  test('Deluxe-only wallet grants shared membership without Premium', () async {
    final wallet = GemWalletStore(
      loadWallet: () async => GemWallet(
        balanceCent: 0,
        membership: summary('', status: 0),
        membershipDeluxe: summary('deluxe_yearly'),
      ),
      readUid: () async => 'user',
    );
    final access = MembershipAccessStore(
      wallet: wallet,
      readLoginUid: () async => 'user',
      serverNow: () => DateTime.utc(2030),
    );
    addTearDown(access.dispose);
    addTearDown(wallet.dispose);
    final result = await access.refresh();
    expect(result.isVip, true);
    expect(result.activeFor(MembershipType.premium), false);
    expect(result.activeFor(MembershipType.deluxe), true);
  });
  test('the two groups apply the same expiry and renewal rules', () async {
    for (final expired in [false, true]) {
      for (final status in [0, 1, 2]) {
        final end = expired ? DateTime.utc(2020) : DateTime.utc(2040);
        GemWalletMembership group(String plan) => GemWalletMembership(
          status: status,
          planCode: plan,
          expiresAt: end,
          autoRenew: false,
          blueGemsCent: 0,
        );
        final wallet = GemWalletStore(
          loadWallet: () async => GemWallet(
            balanceCent: 0,
            membership: group('pro_yearly'),
            membershipDeluxe: group('deluxe_yearly'),
          ),
          readUid: () async => 'user',
        );
        final access = MembershipAccessStore(
          wallet: wallet,
          readLoginUid: () async => 'user',
          serverNow: () => DateTime.utc(2030),
        );
        final state = await access.refresh();
        expect(
          state.activeFor(MembershipType.premium),
          status == 1 && !expired,
        );
        expect(
          state.activeFor(MembershipType.deluxe),
          state.activeFor(MembershipType.premium),
        );
        expect(state.isDeluxeExpired, state.isExpired);
        access.dispose();
        wallet.dispose();
      }
    }
  });
  test('display cache restores both groups and history flag', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = MembershipCatalogCache(namespace: 'deluxe_test');
    await cache.save(
      MembershipProvider.google,
      'user',
      MembershipProductList(
        products: [membershipProduct()],
        deluxeProducts: [deluxe()],
        hasPurchased: true,
        lastAccountUuidDeluxe: support.guest.accountUuid,
      ),
    );
    final restored = await cache.load(MembershipProvider.google, 'user');
    expect(restored!.allProducts, hasLength(2));
    expect(restored.hasPurchased, true);
    expect(restored.lastAccountUuidDeluxe, isNull);
  });
  for (final provider in MembershipProvider.values) {
    test(
      '$provider launches Deluxe with its own UUID and existing checkout',
      () async {
        final product = deluxe(provider: provider);
        final h = support.Harness(
          provider: provider,
          checkoutProducts: () async => MembershipProductList(
            products: [membershipProduct(provider: provider)],
            deluxeProducts: [product],
            lastAccountUuid: support.accountUuid,
            lastAccountUuidDeluxe: support.guest.accountUuid,
          ),
        );
        addTearDown(h.service.dispose);
        await h.service.purchase(product);
        expect(h.platform.product!.storeProductId, product.storeProductId);
        expect(h.platform.uuid, support.guest.accountUuid);
        expect(h.platform.launches, 1);
        expect(h.service.state.value, MembershipCheckoutState.store);
      },
    );
  }
  test(
    'Deluxe local crown is included in the application asset bundle',
    () async {
      expect(
        (await rootBundle.load(proCrownDeluxeIconAsset)).lengthInBytes,
        greaterThan(0),
      );
    },
  );
  for (final provider in MembershipProvider.values) {
    for (final outcome in [
      BillingPurchaseStatus.purchased,
      BillingPurchaseStatus.canceled,
      BillingPurchaseStatus.error,
    ]) {
      test(
        '$provider Deluxe store result $outcome uses existing report and failure events',
        () async {
          final events = <SubscriptionAnalyticsEvent>[];
          final product = deluxe(provider: provider);
          final h = support.Harness(
            provider: provider,
            analytics: SubscriptionAnalytics(sink: events.add),
            checkoutProducts: () async => MembershipProductList(
              products: const [],
              deluxeProducts: [product],
            ),
          );
          addTearDown(h.service.dispose);
          await h.service.purchase(
            product,
            tracking: const SubscriptionTracking(
              id: 'deluxe-attempt',
              source: SubscriptionSource.meMembership,
            ),
          );
          await h.service.interceptPurchase(
            BillingPurchase(
              provider: provider == MembershipProvider.apple
                  ? BillingProvider.appStore
                  : BillingProvider.googlePlay,
              productId: product.storeProductId,
              purchaseToken: 'deluxe-test-token',
              transactionId: 'deluxe-test-transaction',
              originalTransactionId: 'deluxe-test-original',
              originalJson: '',
              purchaseTime: '',
              status: outcome,
              obfuscatedAccountId: support.accountUuid,
              checkoutAttemptId: h.platform.checkoutAttemptId,
              signedTransaction: provider == MembershipProvider.apple
                  ? 'test.header.signature'
                  : '',
              errorCode: outcome == BillingPurchaseStatus.error
                  ? 'test_store_failure'
                  : null,
              errorMessage: outcome == BillingPurchaseStatus.error
                  ? 'Full test store diagnostic'
                  : null,
            ),
          );
          if (outcome == BillingPurchaseStatus.purchased) {
            expect(
              h.reports.single.product.storeProductId,
              product.storeProductId,
            );
            expect(h.service.state.value, MembershipCheckoutState.completed);
          } else {
            expect(h.reports, isEmpty);
            expect(
              h.service.state.value,
              outcome == BillingPurchaseStatus.canceled
                  ? MembershipCheckoutState.canceled
                  : MembershipCheckoutState.failed,
            );
            expect(
              events.where((e) => e.action == 'subscription_failed'),
              hasLength(1),
            );
            expect(
              events.single.object1,
              SubscriptionSource.meMembership.value,
            );
            if (outcome == BillingPurchaseStatus.error) {
              expect(
                events.single.extData,
                contains('Full test store diagnostic'),
              );
            }
          }
        },
      );
    }
  }
  testWidgets(
    'public profiles show independent local crowns and hide deleted users',
    (tester) async {
      for (final pair in [
        (0, 0, 0),
        (1, 0, 1),
        (0, 1, 1),
        (1, 1, 2),
        (2, 2, 0),
      ]) {
        final user = User.fromJson({
          'membership_status': pair.$1,
          'membership_deluxe_status': pair.$2,
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProUserName(
                membershipStatus: user.membershipStatus,
                membershipDeluxeStatus: user.membershipDeluxeStatus,
                fontSize: 20,
                child: const Text('Name'),
              ),
            ),
          ),
        );
        expect(find.byType(ProMembershipBadge), findsNWidgets(pair.$3));
        if (pair.$3 == 2) {
          expect(
            tester
                .widget<ProMembershipBadge>(
                  find.byType(ProMembershipBadge).first,
                )
                .deluxe,
            true,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProUserName(
              membershipStatus: 1,
              membershipDeluxeStatus: 1,
              deleted: true,
              fontSize: 20,
              child: Text('Deleted'),
            ),
          ),
        ),
      );
      expect(find.byType(ProMembershipBadge), findsNothing);
    },
  );
  for (final purchased in [false, true]) {
    testWidgets(
      'fixed order starts at history=$purchased selection and buys the visible monthly product',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final selected = <MembershipProduct>[];
        final offers = [
          membershipProduct(),
          membershipProduct(yearly: true),
          deluxe(),
          deluxe(yearly: true),
        ].map((p) => MembershipOffer(product: p)).toList();
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: Scaffold(
              body: ProSubscriptionContent(
                productsLoader: () async => MembershipCatalogData(
                  offers: offers,
                  hasPurchased: purchased,
                ),
                purchaseHandler: (p) async => selected.add(p),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final type = purchased ? 'deluxe' : 'premium';
        await tester.tap(find.byKey(ValueKey('membership-$type-monthly')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('pro-subscribe-button')),
        );
        await tester.tap(find.byKey(const ValueKey('pro-subscribe-button')));
        await tester.pumpAndSettle();
        expect(
          selected.single.membershipType,
          purchased ? MembershipType.deluxe : MembershipType.premium,
        );
        expect(selected.single.isYearly, false);
        await tester.drag(
          find.byKey(const ValueKey('membership-subscription-pages')),
          Offset(purchased ? 180 : -180, 0),
        );
        await tester.pumpAndSettle();
        final other = purchased ? 'premium' : 'deluxe';
        await tester.tap(find.byKey(ValueKey('membership-$other-monthly')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('pro-subscribe-button')),
        );
        await tester.tap(find.byKey(const ValueKey('pro-subscribe-button')));
        await tester.pumpAndSettle();
        expect(selected, hasLength(2));
        expect(
          selected.last.membershipType,
          purchased ? MembershipType.premium : MembershipType.deluxe,
        );
        expect(selected.last.isYearly, false);
        await tester.drag(
          find.byKey(const ValueKey('membership-subscription-pages')),
          Offset(purchased ? -180 : 180, 0),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Semantics>(
                find.byKey(ValueKey('membership-$type-monthly')),
              )
              .properties
              .selected,
          true,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final history in [false, true]) {
    testWidgets(
      'card swipes preserve membership selection then move purchase tabs history=$history',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var purchases = 0;
        final offers = [
          membershipProduct(),
          membershipProduct(yearly: true),
          deluxe(),
          deluxe(yearly: true),
        ].map((p) => MembershipOffer(product: p)).toList();
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  title: const TabBar(
                    key: ValueKey('test-purchase-tabs'),
                    tabs: [
                      Tab(text: 'Subscription'),
                      Tab(text: 'Buy Gems'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    ProSubscriptionContent(
                      productsLoader: () async => MembershipCatalogData(
                        offers: offers,
                        hasPurchased: history,
                      ),
                      purchaseHandler: (_) async {
                        purchases++;
                      },
                    ),
                    const ColoredBox(
                      key: ValueKey('test-gems-page'),
                      color: Colors.black,
                      child: Center(child: Text('Gems content')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tabs = DefaultTabController.of(
          tester.element(find.byKey(const ValueKey('test-purchase-tabs'))),
        );
        final cards = find.byKey(
          const ValueKey('membership-subscription-pages'),
        );
        if (!history) {
          await tester.drag(cards, const Offset(-240, 0));
          await tester.pumpAndSettle();
          expect(tabs.index, 0);
          expect(
            find.byKey(const ValueKey('membership-deluxe-yearly')),
            findsOneWidget,
          );
        }
        // A partial edge swipe follows the finger and can return without switching.
        final partial = await tester.startGesture(tester.getCenter(cards));
        await partial.moveBy(const Offset(-40, 0));
        await tester.pump();
        await partial.moveBy(const Offset(-40, 0));
        await tester.pump();
        expect(tabs.animation!.value, greaterThan(0));
        expect(tabs.animation!.value, lessThan(1));
        await tester.pump(const Duration(milliseconds: 500));
        await partial.up();
        await tester.pumpAndSettle();
        expect(tabs.index, 0);
        // A completed edge swipe switches to Buy Gems through the actual page view.
        await tester.drag(cards, const Offset(-330, 0));
        await tester.pumpAndSettle();
        expect(tabs.index, 1);
        await tester.drag(
          find.byKey(const ValueKey('test-gems-page')),
          const Offset(330, 0),
        );
        await tester.pumpAndSettle();
        expect(tabs.index, 0);
        expect(purchases, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final history in [false, true]) {
    testWidgets(
      'Subscription matches the source branch 48px drag configuration, history=$history',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var purchases = 0;
        final offers = [
          membershipProduct(),
          membershipProduct(yearly: true),
          deluxe(),
          deluxe(yearly: true),
        ].map((p) => MembershipOffer(product: p)).toList();
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: Scaffold(
              body: ProSubscriptionContent(
                productsLoader: () async => MembershipCatalogData(
                  offers: offers,
                  hasPurchased: history,
                ),
                purchaseHandler: (_) async {
                  purchases++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cards = find.byKey(
          const ValueKey('membership-subscription-pages'),
        );
        final other = history ? 'premium' : 'deluxe';
        final initial = history ? 'deluxe' : 'premium';
        await tester.timedDrag(
          cards,
          Offset(history ? 50 : -50, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('membership-$initial-yearly')),
          findsOneWidget,
        );
        await tester.timedDrag(
          cards,
          Offset(history ? 90 : -90, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('membership-$other-yearly')),
          findsOneWidget,
        );
        await tester.timedDrag(
          cards,
          Offset(history ? -25 : 25, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('membership-$other-yearly')),
          findsOneWidget,
        );
        expect(purchases, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test('fixed order and history-selected initial card are separate', () {
    expect(memoryMembershipOrder(), [
      MembershipType.premium,
      MembershipType.deluxe,
    ]);
    expect(
      memoryMembershipInitialTier(hasPurchased: false),
      MembershipType.premium,
    );
    expect(
      memoryMembershipInitialTier(hasPurchased: true),
      MembershipType.deluxe,
    );
  });
  for (final history in [false, true]) {
    testWidgets(
      'Me cards retain Premium then Deluxe and locate history=$history',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: MemoryMembershipProfileCarousel(
                  hasPurchased: history,
                  onPremiumSubscribe: () {},
                  onDeluxeSubscribe: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = tester
            .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('membership-profile-pages')),
            )
            .controller!;
        expect(scroll.offset, history ? greaterThan(0) : 0);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('membership-profile-premium')))
              .left,
          lessThan(
            tester
                .getRect(
                  find.byKey(const ValueKey('membership-profile-deluxe')),
                )
                .left,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Me history arriving later positions Deluxe but preserves a manual swipe',
    (tester) async {
      Widget page(bool history) => MaterialApp(
        theme: GenesisTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: MemoryMembershipProfileCarousel(
              hasPurchased: history,
              onPremiumSubscribe: () {},
              onDeluxeSubscribe: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('membership-profile-pages')),
          )
          .controller!;
      expect(scroll.offset, greaterThan(0));
      await tester.drag(
        find.byKey(const ValueKey('membership-profile-pages')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
