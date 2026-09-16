import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/network/models/membership_benefit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/platform/billing/membership_catalog_cache.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

import '../support/membership_fixtures.dart';
import '../app/membership/membership_purchase_service_test.dart' as support;

const surfaceKey = ValueKey('subscription-test-surface');
const buttonKey = ValueKey('pro-subscribe-button');

class _InjectedCacheCatalog extends MembershipCatalog {
  _InjectedCacheCatalog({required this.loadCache, required super.loadProducts})
    : super(provider: MembershipProvider.google);

  final Future<MembershipCatalogData?> Function() loadCache;

  @override
  Future<MembershipCatalogData?> loadCached() => loadCache();
}

Widget page(
  MembershipCatalogLoader? loader, {
  MembershipCatalog? catalog,
  Future<void> Function(MembershipProduct)? purchase,
  MembershipPurchaseService? service,
  MembershipAccessStore? membership,
}) => MaterialApp(
  theme: GenesisTheme.light(),
  home: Scaffold(
    body: RepaintBoundary(
      key: surfaceKey,
      child: ProSubscriptionContent(
        productsLoader: loader,
        catalog: catalog,
        purchaseHandler: purchase,
        purchaseService: service,
        membershipAccess: membership,
      ),
    ),
  ),
);

MembershipAccessStore accessFor(
  String plan, {
  Future<GemWallet> Function()? load,
  bool autoRenew = true,
}) {
  final wallet = GemWalletStore(
    readUid: () async => 'user-test',
    loadWallet:
        load ??
        () async => GemWallet(
          balanceCent: 123,
          membership: membershipAccessSnapshot(
            planCode: plan,
            autoRenew: autoRenew,
          ).membership,
        ),
  );
  final access = MembershipAccessStore(
    wallet: wallet,
    readLoginUid: () async => 'user-test',
    serverNow: () => DateTime.utc(2040),
  );
  _accessDisposals.add(() {
    access.dispose();
    wallet.dispose();
  });
  return access;
}

void expectOriginalContent(WidgetTester tester) {
  expect(find.byKey(const ValueKey('pro-plan-yearly')), findsOneWidget);
  expect(find.byKey(const ValueKey('pro-plan-monthly')), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(
    tester.widget<GenesisPrimaryButton>(find.byKey(buttonKey)).onPressed,
    isNotNull,
  );
}

Future<List<int>> pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(surfaceKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data!.buffer.asUint8List().toList();
    } finally {
      image.dispose();
    }
  }))!;
}

final _accessDisposals = <void Function()>[];
void _testWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final dispose in _accessDisposals) {
        dispose();
      }
      _accessDisposals.clear();
    }
  });
}

void main() {
  _testWidgets(
    'payment proceeds while the page wallet refresh is still pending',
    (tester) async {
      var calls = 0;
      var purchases = 0;
      final response = Completer<GemWallet>();
      final purchaseFinished = Completer<void>();
      final access = accessFor(
        '',
        load: () async {
          if (++calls == 1) {
            return GemWallet(
              balanceCent: 0,
              membership: membershipAccessSnapshot().membership,
            );
          }
          return response.future;
        },
      );
      final checkout = support.Harness();
      await access.refresh();
      await tester.pumpWidget(
        page(
          loadTestMembershipOffers,
          membership: access,
          service: checkout.service,
          purchase: (_) async {
            purchases++;
            await purchaseFinished.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'Yearly: $99.99'), findsOneWidget);
      expect(calls, 2);
      await tester.tap(find.byKey(buttonKey));
      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(calls, 2);
      expect(purchases, 1);
      response.complete(
        GemWallet(
          balanceCent: 0,
          membership: membershipAccessSnapshot(
            planCode: 'pro_yearly',
          ).membership,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'Yearly: $99.99'), findsOneWidget);
      expect(purchases, 1);
      purchaseFinished.complete();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        page(loadTestMembershipOffers, membership: access),
      );
      await tester.pumpAndSettle();
      expect(calls, 3);
    },
  );

  for (final provider in MembershipProvider.values) {
    for (final (raw, autoRenew) in [
      for (final plan in ['', 'pro_monthly', 'pro_yearly'])
        for (final renew in [false, true]) (plan, renew),
    ]) {
      _testWidgets(
        '$provider membership plan=$raw autoRenew=$autoRenew preserves labels and delegates every purchase',
        (tester) async {
          var purchases = 0;
          final catalog = MembershipCatalogData(
            offers: [
              for (final yearly in [true, false])
                MembershipOffer(
                  product: membershipProduct(
                    provider: provider,
                    yearly: yearly,
                  ),
                ),
            ],
          );
          await tester.pumpWidget(
            page(
              () async => catalog,
              membership: accessFor(raw, autoRenew: autoRenew),
              purchase: (_) async {
                purchases++;
              },
            ),
          );
          await tester.pumpAndSettle();
          for (final yearly in [true, false]) {
            final subscribed =
                autoRenew && raw == (yearly ? 'pro_yearly' : 'pro_monthly');
            await tester.tap(
              find.byKey(
                ValueKey(yearly ? 'pro-plan-yearly' : 'pro-plan-monthly'),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.widget<GenesisPrimaryButton>(find.byKey(buttonKey)).label,
              subscribed
                  ? 'Subscribed'
                  : yearly
                  ? r'Yearly: $99.99'
                  : r'Monthly: $9.99',
            );
            final previous = purchases;
            await tester.tap(find.byKey(buttonKey));
            await tester.pump(const Duration(milliseconds: 300));
            expect(purchases, previous + 1);
            expect(find.text('Notification'), findsNothing);
            expect(
              find.textContaining(
                'You already have an active Premium subscription.',
              ),
              findsNothing,
            );
            await tester.pump(const Duration(seconds: 3));
          }
        },
      );
    }
  }

  for (final outcome in ['success', 'failure', 'empty']) {
    testWidgets(
      'immediate reentry shows cache and always refreshes with $outcome',
      (tester) async {
        final response = Completer<MembershipProductList>();
        var calls = 0;
        final catalog = MembershipCatalog(
          provider: MembershipProvider.google,
          loadProducts: (_) async {
            if (++calls == 1) {
              return MembershipProductList(
                products: [
                  membershipProduct(yearly: true, title: 'Cached VIP'),
                ],
              );
            }
            return response.future;
          },
        );
        await tester.pumpWidget(page(null, catalog: catalog));
        await tester.pumpAndSettle();
        expect(find.text(r'Yearly: $99.99'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(page(null, catalog: catalog));
        expect(find.text(r'Yearly: $99.99'), findsOneWidget);
        expect(find.text(r'Yearly: $99.99'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pump();
        expect(calls, 2);
        if (outcome == 'failure') {
          response.completeError(StateError('offline'));
        } else {
          response.complete(
            MembershipProductList(
              products: outcome == 'empty'
                  ? []
                  : [
                      membershipProduct(
                        yearly: true,
                        title: 'Fresh VIP',
                        priceAmount: 11999,
                      ),
                    ],
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.text(r'Yearly: $99.99'),
          outcome == 'failure' ? findsOneWidget : findsNothing,
        );
        if (outcome == 'success') {
          expect(find.text('Premium'), findsOneWidget);
          expect(find.text(r'Yearly: $119.99'), findsOneWidget);
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  }

  testWidgets('new app catalog displays disk cache before the API completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = MembershipCatalogCache(namespace: 'widget-test');
    await store.save(
      MembershipProvider.google,
      null,
      MembershipProductList(
        products: [membershipProduct(yearly: true, title: 'Disk VIP')],
      ),
    );
    final response = Completer<MembershipProductList>();
    final catalog = MembershipCatalog(
      provider: MembershipProvider.google,
      cacheStore: store,
      loadProducts: (_) => response.future,
    );
    await tester.pumpWidget(page(null, catalog: catalog));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text(r'Yearly: $99.99'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    response.complete(
      MembershipProductList(
        products: [membershipProduct(yearly: true, title: 'Fresh VIP')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subscribed'), findsNothing);
    expect(find.text(r'Yearly: $99.99'), findsOneWidget);
  });

  testWidgets('unsupported cached plan does not crash before fresh catalog', (
    tester,
  ) async {
    final fresh = Completer<MembershipProductList>();
    final monthly = membershipProduct();
    final unsupported = MembershipProduct(
      title: monthly.title,
      benefits: monthly.benefits,
      planCode: 'pro_weekly',
      provider: monthly.provider,
      storeProductId: monthly.storeProductId,
      basePlanId: monthly.basePlanId,
      billingMonths: monthly.billingMonths,
      monthlyGemsCent: monthly.monthlyGemsCent,
      priceCurrencyCode: monthly.priceCurrencyCode,
      priceAmount: monthly.priceAmount,
    );
    final catalog = _InjectedCacheCatalog(
      loadCache: () async => MembershipCatalogData(
        offers: [MembershipOffer(product: unsupported)],
      ),
      loadProducts: (_) => fresh.future,
    );
    await tester.pumpWidget(page(null, catalog: catalog));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(buttonKey), findsOneWidget);
    fresh.complete(
      MembershipProductList(products: [membershipProduct(yearly: true)]),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'Yearly: $99.99'), findsOneWidget);
  });

  testWidgets('cache read failure does not escape the background load', (
    tester,
  ) async {
    final fresh = Completer<MembershipProductList>();
    final catalog = _InjectedCacheCatalog(
      loadCache: () async => throw StateError('cache unavailable'),
      loadProducts: (_) => fresh.future,
    );
    await tester.pumpWidget(page(null, catalog: catalog));
    await tester.pump();
    expect(tester.takeException(), isNull);
    fresh.complete(
      MembershipProductList(products: [membershipProduct(yearly: true)]),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'Yearly: $99.99'), findsOneWidget);
  });
  for (final provider in MembershipProvider.values) {
    testWidgets('$provider purchase completion refreshes recent catalog', (
      tester,
    ) async {
      var calls = 0;
      final catalog = MembershipCatalog(
        provider: provider,
        loadProducts: (_) async => MembershipProductList(
          products: [
            membershipProduct(
              provider: provider,
              yearly: true,
              priceAmount: ++calls == 1 ? 9999 : 11999,
            ),
          ],
        ),
      );
      final h = support.Harness(provider: provider);
      try {
        await tester.pumpWidget(
          page(null, catalog: catalog, service: h.service),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        await tester.tap(find.byKey(buttonKey));
        await tester.pump(const Duration(milliseconds: 250));
        await h.service.interceptPurchase(h.purchase(yearly: true));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(
          (await catalog.readCheckoutProducts()).products.single.priceAmount,
          11999,
        );
        await tester.tap(find.text('Enjoy it'));
        await tester.pumpAndSettle();
        expect(find.text(r'Yearly: $119.99'), findsOneWidget);
        expect(calls, 2);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        h.service.dispose();
      }
    });

    testWidgets(
      '$provider debug store order number appears above purchase after callback',
      (tester) async {
        final h = support.Harness(provider: provider);
        final storeOrderId = provider == MembershipProvider.google
            ? 'GPA.1111-2222-3333-44444'
            : '9900123456789';
        final label = find.byKey(const ValueKey('pro-debug-store-order-id'));
        try {
          await tester.pumpWidget(
            page(
              () async => MembershipCatalogData(
                offers: [MembershipOffer(product: h.product(yearly: true))],
              ),
              service: h.service,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('debug 订单 id：暂无'), findsOneWidget);
          expect(
            tester.getBottomLeft(label).dy,
            lessThan(tester.getTopLeft(find.byKey(buttonKey)).dy),
          );
          await tester.tap(find.byKey(buttonKey));
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.text('debug 订单 id：暂无'), findsOneWidget);
          await h.service.interceptPurchase(
            h.purchase(yearly: true, transaction: storeOrderId),
          );
          await tester.pumpAndSettle();
          expect(find.text('debug 订单 id：$storeOrderId'), findsOneWidget);
          expect(tester.widget<Text>(label).maxLines, 1);
          await tester.tap(find.text('Enjoy it'));
          await tester.pumpAndSettle();
          expect(find.text('debug 订单 id：$storeOrderId'), findsOneWidget);
          h.uid = 'another-user';
          h.service.resetForSession();
          await h.service.recover();
          await tester.pumpAndSettle();
          expect(find.text('debug 订单 id：暂无'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          h.service.dispose();
        }
      },
    );

    for (final signedIn in [false, true]) {
      testWidgets(
        '$provider signedIn=$signedIn repeated taps reuse the entry catalog and upgrade credentials',
        (tester) async {
          var calls = 0;
          const uuid = '2b74ec68-7abc-4cce-a223-e997e31dc811';
          final product = membershipProduct(provider: provider, yearly: true);
          final catalog = MembershipCatalog(
            provider: provider,
            readOwnerUid: () async => signedIn ? 'user-test' : null,
            loadProducts: (_) async {
              calls++;
              return MembershipProductList(
                products: [product],
                lastAccountUuid: uuid,
              );
            },
          );
          final h = support.Harness(
            provider: provider,
            checkoutProducts: catalog.readCheckoutProducts,
          )..uid = signedIn ? 'user-test' : null;
          try {
            await tester.pumpWidget(
              page(null, catalog: catalog, service: h.service),
            );
            await tester.pumpAndSettle();
            expect(calls, 1);
            for (var attempt = 1; attempt <= 2; attempt++) {
              await tester.tap(find.byKey(buttonKey));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
              expect(calls, 1);
              expect(h.platform.launches, attempt);
              expect(h.platform.uuid, uuid);
              expect(h.refreshes, 0);
              expect(h.guestPrepares, 0);
              await h.service.interceptPurchase(
                h.purchase(
                  yearly: true,
                  uuid: uuid,
                  status: BillingPurchaseStatus.canceled,
                ),
              );
              await tester.pumpAndSettle();
              await tester.pump(const Duration(seconds: 3));
              expect(calls, 1);
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            h.service.dispose();
          }
        },
      );
    }

    testWidgets('$provider upgrade action does not block the purchase button', (
      tester,
    ) async {
      final product = MembershipProduct.fromJson({
        ...membershipProduct(provider: provider, yearly: true).toJson(),
        'purchase_action': 'upgrade',
      });
      final purchases = <MembershipProduct>[];
      await tester.pumpWidget(
        page(
          () async => MembershipCatalogData(
            offers: [MembershipOffer(product: product)],
          ),
          purchase: (selected) async => purchases.add(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      expect(purchases, [product]);
    });
  }

  for (final provider in MembershipProvider.values) {
    testWidgets(
      '$provider entry loads products once when restoring an unchanged purchase',
      (tester) async {
        final h = support.Harness(provider: provider, restoreEnabled: true);
        await h.service.purchase(h.product(yearly: true));
        await h.service.interceptPurchase(h.purchase(yearly: true));
        h.recoverable = [h.purchase(yearly: true)];
        var loads = 0;
        Future<MembershipCatalogData> load() async {
          loads++;
          return MembershipCatalogData(
            offers: [MembershipOffer(product: h.product(yearly: true))],
          );
        }

        await tester.pumpWidget(page(load, service: h.service));
        await tester.pumpAndSettle();
        expect(h.reports, hasLength(1));
        expect(loads, 1);
        expectOriginalContent(tester);

        // Re-checking the same receipt must not invalidate the displayed catalog.
        await h.service.restorePurchases();
        await tester.pumpAndSettle();
        expect(h.reports, hasLength(1));
        expect(loads, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        h.service.dispose();
      },
    );
  }

  testWidgets(
    'entry loads products once while a report retry remains pending',
    (tester) async {
      final h = support.Harness(
        provider: MembershipProvider.apple,
        restoreEnabled: true,
      );
      h.recoverable = [
        h.purchase(yearly: true, status: BillingPurchaseStatus.pending),
      ];
      h.reportHandler = (_) async => const MembershipPurchaseReport(
        status: MembershipReportStatus.accepted,
      );
      await h.service.purchase(h.product(yearly: true));
      await h.service.interceptPurchase(h.purchase(yearly: true));
      var loads = 0;
      Future<MembershipCatalogData> load() async {
        loads++;
        return MembershipCatalogData(
          offers: [MembershipOffer(product: h.product(yearly: true))],
        );
      }

      await tester.pumpWidget(page(load, service: h.service));
      await tester.pumpAndSettle();
      expect(loads, 1);
      // Opening the page never queries or imports store history.
      expect(h.reports, hasLength(1));
      expect(h.store.records.values.single.reportStatus, 'accepted');

      // A later real transition must still update purchase eligibility.
      h.reportHandler = null;
      await h.service.recover();
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(h.restoreQueries, 0);
      expect(h.store.restores, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      h.service.dispose();
    },
  );

  testWidgets(
    'Premium heading stays fixed while selected API benefits change',
    (tester) async {
      final products = MembershipProductList.fromJson({
        'list': [
          for (final yearly in [true, false])
            membershipProduct(
              yearly: yearly,
              title: yearly ? 'Annual VIP' : 'Monthly VIP',
              benefits: [
                MembershipBenefit(
                  code: 'same_code_in_each_plan',
                  title: yearly ? 'Annual benefit' : 'Monthly benefit',
                  iconKey: 'blue_gem',
                  displayType: MembershipBenefitDisplay.included,
                ),
              ],
            ).toJson(),
        ],
      });
      final catalog = MembershipCatalog(
        provider: MembershipProvider.google,
        loadProducts: (_) async => products,
      );
      await tester.pumpWidget(page(catalog.load));
      await tester.pumpAndSettle();
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Annual VIP'), findsNothing);
      expect(find.text('Annual benefit'), findsOneWidget);
      expect(find.text('Pro'), findsNothing);
      expect(find.text('Monthly VIP'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
      await tester.pumpAndSettle();
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Monthly VIP'), findsNothing);
      expect(find.text('Monthly benefit'), findsOneWidget);
      expect(find.text('Annual VIP'), findsNothing);
      expect(find.text('Annual benefit'), findsNothing);
    },
  );

  testWidgets('a single unpriced monthly product supplies its own display', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        () async => MembershipCatalogData(
          offers: [
            MembershipOffer(
              product: membershipProduct(title: 'Monthly VIP', hasPrice: false),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Monthly VIP'), findsNothing);
    expect(find.text('Monthly bonus Gems'), findsOneWidget);
    expect(find.text('Pro'), findsNothing);
    expect(find.text('Monthly: '), findsOneWidget);
  });

  _testWidgets(
    'renewal cancellation restores the price while preserving styling and checkout',
    (tester) async {
      var purchases = 0;
      var autoRenew = true;
      final access = accessFor(
        'pro_yearly',
        load: () async => GemWallet(
          balanceCent: 0,
          membership: membershipAccessSnapshot(
            planCode: 'pro_yearly',
            autoRenew: autoRenew,
          ).membership,
        ),
      );
      await tester.pumpWidget(page(loadTestMembershipOffers));
      await tester.pumpAndSettle();
      final filledButton = find.descendant(
        of: find.byKey(buttonKey),
        matching: find.byType(FilledButton),
      );
      final originalButtonStyle = tester
          .widget<FilledButton>(filledButton)
          .style;
      final originalButtonRect = tester.getRect(find.byKey(buttonKey));
      await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pro-plan-yearly')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        page(
          () async => MembershipCatalogData(
            offers: [
              for (final yearly in [true, false])
                MembershipOffer(product: membershipProduct(yearly: yearly)),
            ],
          ),
          membership: access,
          purchase: (_) async {
            purchases++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subscribed'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(filledButton).style,
        originalButtonStyle,
      );
      expect(tester.getRect(find.byKey(buttonKey)), originalButtonRect);
      expectOriginalContent(tester);
      await tester.tap(find.byKey(buttonKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('You already have an active Premium subscription.'),
        findsNothing,
      );
      expect(purchases, 1);
      await tester.pump(const Duration(seconds: 3));
      autoRenew = false;
      await access.refresh();
      await tester.pumpAndSettle();
      expect(access.state.value.isVip, isTrue);
      expect(find.text('Subscribed'), findsNothing);
      expect(find.text(r'Yearly: $99.99'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(filledButton).style,
        originalButtonStyle,
      );
      expect(tester.getRect(find.byKey(buttonKey)), originalButtonRect);
      await tester.tap(find.byKey(buttonKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(purchases, 2);
      await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
      await tester.pumpAndSettle();
      expect(find.text(r'Monthly: $9.99'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(filledButton).style,
        originalButtonStyle,
      );
      expect(tester.getRect(find.byKey(buttonKey)), originalButtonRect);
      await tester.tap(find.byKey(buttonKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Notification'), findsNothing);
      expect(purchases, 3);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  for (final status in MembershipReportStatus.values) {
    testWidgets(
      '$status report silently reloads eligibility without another restore',
      (tester) async {
        final h = support.Harness(
          provider: MembershipProvider.apple,
          restoreEnabled: true,
        );
        h.reportHandler = (_) async => MembershipPurchaseReport(status: status);
        var loads = 0;
        final refresh = Completer<MembershipCatalogData>();
        final initial = MembershipCatalogData(
          offers: [
            MembershipOffer(product: h.product(yearly: true)),
            MembershipOffer(product: h.product()),
          ],
        );
        await tester.pumpWidget(
          page(() async {
            if (++loads == 1) return initial;
            return refresh.future;
          }, service: h.service),
        );
        await tester.pumpAndSettle();
        expect(h.restoreQueries, 0);
        await h.service.purchase(h.product(yearly: true));
        await h.service.interceptPurchase(h.purchase(yearly: true));
        await tester.pump();
        expect(loads, 2);
        expectOriginalContent(tester);
        expect(find.text(r'Yearly: $99.99'), findsOneWidget);
        refresh.complete(
          MembershipCatalogData(
            offers: [
              MembershipOffer(
                product: membershipProduct(
                  provider: MembershipProvider.apple,
                  yearly: true,
                  priceAmount: 12000,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(r'Yearly: $120.00'), findsOneWidget);
        expect(h.restoreQueries, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        h.service.dispose();
      },
    );
  }

  testWidgets('server titles, order and status drive the existing benefit rows', (
    tester,
  ) async {
    final benefits = [
      for (final (code, title, icon, display) in [
        ('included', 'Server included', 'unknown_icon', 'included'),
        ('enhanced', 'Server enhanced', 'gem', 'enhanced'),
        ('locked', 'Server locked', 'memory', 'locked'),
      ])
        MembershipBenefit.fromJson({
          'code': code,
          'title': title,
          'icon_key': icon,
          'display_type': display,
        }),
    ];
    await tester.pumpWidget(
      page(
        () async => MembershipCatalogData(
          offers: [
            for (final yearly in [true, false])
              MembershipOffer(
                product: membershipProduct(yearly: yearly, benefits: benefits),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Monthly bonus Gems'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Server included')).dy,
      lessThan(tester.getTopLeft(find.text('Server enhanced')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Server enhanced')).dy,
      lessThan(tester.getTopLeft(find.text('Server locked')).dy),
    );
    expect(find.byIcon(Icons.stars_outlined), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('pro-benefit-status-Server included')),
          )
          .icon,
      Icons.check_rounded,
    );
    expect(
      find.byKey(const ValueKey('pro-benefit-status-Server enhanced')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SvgPicture>(
            find.byKey(const ValueKey('pro-benefit-status-Server enhanced')),
          )
          .semanticsLabel,
      'Improved with Pro',
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('pro-benefit-status-Server locked')),
          )
          .icon,
      Icons.lock_outline_rounded,
    );
    expect(
      tester.widget<Text>(find.text('Server locked')).style?.color,
      GenesisColors.darkTextPrimary,
    );
    await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
    await tester.pumpAndSettle();
    for (final benefit in benefits) {
      expect(find.text(benefit.title), findsOneWidget);
    }
    // A later server configuration can remove every row without restoring previews.
    await tester.pumpWidget(
      page(
        () async => MembershipCatalogData(
          offers: [
            for (final yearly in [true, false])
              MembershipOffer(
                product: membershipProduct(yearly: yearly, benefits: []),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final benefit in benefits) {
      expect(find.text(benefit.title), findsNothing);
    }
    expect(find.text('Monthly bonus Gems'), findsNothing);
    expect(find.text(r'Monthly: $9.99'), findsOneWidget);
  });

  testWidgets(
    'API prices control the month equivalent, full price and savings',
    (tester) async {
      final selected = <MembershipProduct>[];
      await tester.pumpWidget(
        page(
          () async => MembershipCatalogData(
            offers: [
              MembershipOffer(
                product: membershipProduct(yearly: true, priceAmount: 12000),
              ),
              MembershipOffer(product: membershipProduct(priceAmount: 2000)),
            ],
          ),
          purchase: (product) async => selected.add(product),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$10.00/mo', findRichText: true), findsOneWidget);
      expect(find.text(r'Yearly: $120.00'), findsOneWidget);
      expect(find.text('Save 50%'), findsOneWidget);
      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      expect(selected.single.priceAmount, 12000);
      await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
      await tester.pumpAndSettle();
      expect(find.text(r'Monthly: $20.00'), findsOneWidget);
      expect(find.text(r'$20.00/mo', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'fills the original cards with API prices and benefits after loading',
    (tester) async {
      final completer = Completer<MembershipCatalogData>();
      await tester.pumpWidget(page(() => completer.future));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(buttonKey), findsNothing);
      expect(find.text(r'Yearly: $99.99'), findsNothing);
      expect(find.text('Monthly bonus Gems'), findsNothing);
      expect(find.text('Pro'), findsNothing);
      completer.complete(await loadTestMembershipOffers());
      await tester.pumpAndSettle();
      expectOriginalContent(tester);
      expect(find.text(r'Yearly: $99.99'), findsOneWidget);
      expect(find.text(r'$8.33/mo', findRichText: true), findsOneWidget);
      expect(find.text('Save 17%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
      await tester.pump();
      expect(find.text(r'Monthly: $9.99'), findsOneWidget);
      expect(find.text('Monthly bonus Gems'), findsOneWidget);
    },
  );

  testWidgets('failure keeps original content and original button can retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      page(() async {
        if (++calls == 1) throw StateError('offline');
        return loadTestMembershipOffers();
      }),
    );
    await tester.pumpAndSettle();
    expectOriginalContent(tester);
    expect(find.text('Pro'), findsNothing);
    expect(find.text('Unable to load subscriptions.'), findsNothing);
    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text(r'Yearly: $99.99'), findsOneWidget);
  });

  testWidgets('each plan submits the selected API product', (tester) async {
    final selected = <MembershipProduct>[];
    await tester.pumpWidget(
      page(
        loadTestMembershipOffers,
        purchase: (product) async {
          selected.add(product);
        },
      ),
    );
    await tester.pumpAndSettle();
    for (final plan in ['yearly', 'monthly']) {
      await tester.tap(find.byKey(ValueKey('pro-plan-$plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      expect(selected.last.planCode, 'pro_$plan');
      expect(selected.last.priceAmount, plan == 'yearly' ? 9999 : 999);
    }
  });

  testWidgets(
    'empty and failed results keep the layout without static benefits',
    (tester) async {
      await tester.pumpWidget(page(() async => const MembershipCatalogData()));
      await tester.pumpAndSettle();
      expectOriginalContent(tester);
      expect(find.text('No subscriptions available right now.'), findsNothing);
      expect(find.text(r'Yearly: $99.99'), findsNothing);
      expect(find.text('Pro'), findsNothing);
      await tester.pumpWidget(page(() async => throw StateError('offline')));
      await tester.pumpAndSettle();
      expectOriginalContent(tester);
      expect(find.text('Log in to view subscriptions.'), findsNothing);
    },
  );

  testWidgets(
    'missing API prices can be queried again without preview prices',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        page(() async {
          if (++calls == 1) {
            return MembershipCatalogData(
              offers: [
                MembershipOffer(
                  product: membershipProduct(yearly: true, hasPrice: false),
                ),
              ],
            );
          }
          return loadTestMembershipOffers();
        }),
      );
      await tester.pumpAndSettle();
      expectOriginalContent(tester);
      expect(find.text('Price unavailable'), findsNothing);
      expect(find.text(r'Yearly: $99.99'), findsNothing);
      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(r'Yearly: $99.99'), findsOneWidget);
      expect(find.text('Pro subscriptions are coming soon.'), findsNothing);
    },
  );

  testWidgets('plan selection preserves benefit copy and narrow layout', (
    tester,
  ) async {
    final offers = MembershipCatalogData(
      offers: [
        MembershipOffer(
          product: membershipProduct(yearly: true, monthlyGemsCent: 200000),
        ),
        MembershipOffer(product: membershipProduct()),
      ],
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 568);
      await tester.pumpWidget(page(() async => offers));
      await tester.pumpAndSettle();
      for (final plan in ['yearly', 'monthly']) {
        await tester.tap(find.byKey(ValueKey('pro-plan-$plan')));
        await tester.pump();
        expectOriginalContent(tester);
        expect(find.text('Save 17%'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('obsolete request cannot replace a newer catalog', (
    tester,
  ) async {
    final old = Completer<MembershipCatalogData>();
    await tester.pumpWidget(page(() => old.future));
    await tester.pumpWidget(page(() async => const MembershipCatalogData()));
    await tester.pumpAndSettle();
    old.complete(await loadTestMembershipOffers());
    await tester.pumpAndSettle();
    expectOriginalContent(tester);
    expect(find.text(r'Yearly: $99.99'), findsNothing);
    expect(find.text('Save 17%'), findsNothing);
    expect(find.text('Monthly bonus Gems'), findsNothing);
    expect(find.text('Pro'), findsNothing);
  });
}
