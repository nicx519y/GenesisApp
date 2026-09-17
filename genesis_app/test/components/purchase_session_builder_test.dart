import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_state.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/components/gems/profile_membership_card.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/components/gems/purchase_session_builder.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/pages/gems/gem_wallet_page.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

import '../support/membership_fixtures.dart';

class _DeferredSession extends MemoryUserSessionStore {
  final uid = Completer<String?>();

  @override
  Future<String?> readUid() => uid.future;
}

class _DelayedLoginSession extends MemoryUserSessionStore {
  Completer<String?>? loginRead;

  @override
  Future<String?> readUid() => loginRead?.future ?? super.readUid();
}

AppServices _servicesFor(MemoryUserSessionStore session) {
  // Session and routing checks do not need a native store connection.
  final platform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    return ServiceRegistry.build(
      config: const AppConfig(useMock: true),
      sessionStoreOverride: session,
    );
  } finally {
    debugDefaultTargetPlatformOverride = platform;
  }
}

void main() {
  for (final sheet in [false, true]) {
    for (final refreshFails in [false, true]) {
      testWidgets(
        'login keeps ${sheet ? 'sheet' : 'page'} visible and selected while refreshing, failure=$refreshFails',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = _DelayedLoginSession();
          final services = _servicesFor(session);
          final fresh = Completer<MembershipCatalogData>();
          var requests = 0;
          Future<MembershipCatalogData> loadMemberships() {
            requests++;
            return requests == 1 ? loadTestMembershipOffers() : fresh.future;
          }

          await tester.pumpWidget(
            AppServicesScope(
              services: services,
              child: MaterialApp(
                home: Scaffold(
                  body: PurchaseSessionBuilder(
                    builder: (_, showBuyGems) => sheet
                        ? PurchaseOptionsSheet(
                            showBuyGems: showBuyGems,
                            initialTab: PurchaseSheetTab.subscription,
                            membershipProductsLoader: loadMemberships,
                            gemsBuilder: (_) => const Text('Gem packs'),
                          )
                        : GemWalletPage(
                            showBuyGems: showBuyGems,
                            showSubscriptionInitially: true,
                            membershipProductsLoader: loadMemberships,
                          ),
                  ),
                ),
              ),
            ),
          );
          try {
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('pro-plan-monthly')));
            final benefits = find.byKey(
              const PageStorageKey('pro-benefits-scroll'),
            );
            await tester.drag(benefits, const Offset(0, -120));
            await tester.pumpAndSettle();
            final content = tester.state(find.byType(ProSubscriptionContent));
            final scroll = tester.state<ScrollableState>(
              find
                  .descendant(of: benefits, matching: find.byType(Scrollable))
                  .first,
            );
            final offset = scroll.position.pixels;
            expect(offset, greaterThan(0));
            expect(requests, 1);

            void expectStableContent() {
              expect(find.byType(GemPurchaseLoading), findsNothing);
              expect(
                tester.state(find.byType(ProSubscriptionContent)),
                same(content),
              );
              expect(scroll.position.pixels, closeTo(offset, .01));
              expect(find.text(r'Monthly: $9.99'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }

            await session.saveUid('member');
            session.loginRead = Completer<String?>();
            services.notifySessionChanged();
            for (var frame = 0; frame < 4; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expectStableContent();
            }
            expect(requests, 2);
            session.loginRead!.complete('member');
            for (var frame = 0; frame < 25; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expectStableContent();
            }
            expect(find.text('Buy Gems'), findsOneWidget);
            expect(requests, 2);
            if (refreshFails) {
              fresh.completeError(StateError('catalog offline'));
            } else {
              fresh.complete(
                MembershipCatalogData(
                  offers: [
                    for (final yearly in [true, false])
                      MembershipOffer(
                        product: membershipProduct(
                          yearly: yearly,
                          priceAmount: yearly ? 11999 : 1299,
                        ),
                      ),
                  ],
                ),
              );
            }
            await tester.pumpAndSettle();
            expect(find.byType(GemPurchaseLoading), findsNothing);
            expect(
              tester.state(find.byType(ProSubscriptionContent)),
              same(content),
            );
            expect(scroll.position.pixels, closeTo(offset, .01));
            expect(
              find.text(refreshFails ? r'Monthly: $9.99' : r'Monthly: $12.99'),
              findsOneWidget,
            );
            expect(requests, 2);
            expect(tester.takeException(), isNull);
          } finally {
            if (!fresh.isCompleted) {
              fresh.complete(await loadTestMembershipOffers());
            }
            if (session.loginRead?.isCompleted == false) {
              session.loginRead!.complete('member');
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }

  for (final sheet in [false, true]) {
    testWidgets(
      'guest ${sheet ? 'sheet' : 'page'} hides Gems and follows login changes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = MemoryUserSessionStore();
        await session.saveUid('guest_legacy');
        final services = _servicesFor(session);
        var memberships = 0;
        var gems = 0;
        var balances = 0;
        var tasks = 0;
        final wallet = GemWalletStore(
          readUid: session.readUid,
          loadWallet: () async {
            balances++;
            return const GemWallet(balanceCent: 100);
          },
        );
        addTearDown(wallet.dispose);
        Future<MembershipCatalogData> loadMemberships() {
          memberships++;
          return loadTestMembershipOffers();
        }

        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              home: Scaffold(
                body: PurchaseSessionBuilder(
                  builder: (_, showBuyGems) => sheet
                      ? PurchaseOptionsSheet(
                          showBuyGems: showBuyGems,
                          initialTab: PurchaseSheetTab.subscription,
                          membershipProductsLoader: loadMemberships,
                          gemsBuilder: (_) {
                            gems++;
                            return const Text('Gem packs');
                          },
                        )
                      : GemWalletPage(
                          showBuyGems: showBuyGems,
                          showSubscriptionInitially: true,
                          membershipProductsLoader: loadMemberships,
                          walletStore: wallet,
                          productsLoader: (_) async {
                            gems++;
                            return [];
                          },
                          tasksLoader: (_) async {
                            tasks++;
                            return [];
                          },
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Subscription'), findsOneWidget);
        expect(find.text('Buy Gems'), findsNothing);
        expect(find.byType(LoginSheet), findsNothing);
        expect(memberships, 1);
        expect([gems, tasks, balances], [0, 0, 0]);
        final pages = find.byKey(
          ValueKey(sheet ? 'purchase-sheet-pages' : 'wallet-purchase-pages'),
        );
        await tester.drag(pages, const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(find.byType(ProSubscriptionContent), findsOneWidget);
        expect([gems, tasks, balances], [0, 0, 0]);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect([gems, tasks, balances], [0, 0, 0]);

        await session.saveUid('member');
        services.notifySessionChanged();
        await tester.pumpAndSettle();
        expect(find.text('Buy Gems'), findsOneWidget);
        expect([gems, tasks, balances], [0, 0, 0]);
        await tester.tap(find.text('Buy Gems'));
        await tester.pumpAndSettle();
        expect(gems, 1);
        if (!sheet) expect([tasks, balances], [1, 1]);

        await session.clearUid();
        services.notifySessionChanged();
        await tester.pumpAndSettle();
        expect(find.text('Buy Gems'), findsNothing);
        expect(find.byType(ProSubscriptionContent), findsOneWidget);
        expect(gems, 1);
        expect(find.byType(LoginSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('catalogs wait for the initial login state to resolve', (
    tester,
  ) async {
    final session = _DeferredSession();
    final services = _servicesFor(session);
    var builds = 0;
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: PurchaseSessionBuilder(
              builder: (_, showBuyGems) {
                builds++;
                return Text(showBuyGems ? 'Buy Gems' : 'Subscription');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(builds, 0);
    final loading = find.byType(GemPurchaseLoading);
    expect(Theme.of(tester.element(loading)).brightness, Brightness.dark);
    final background = tester.widget<ColoredBox>(
      find.ancestor(of: loading, matching: find.byType(ColoredBox)).first,
    );
    expect(background.color, GenesisColors.darkBackground);

    expect(find.text('Buy Gems'), findsNothing);
    session.uid.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Subscription'), findsOneWidget);
  });

  testWidgets('guest membership card enters the real VIP route without login', (
    tester,
  ) async {
    final services = _servicesFor(MemoryUserSessionStore());
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: const Scaffold(body: ProfileMembershipCard()),
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();
    expect(find.byType(GemWalletPage), findsOneWidget);
    expect(find.byType(ProSubscriptionContent), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Buy Gems'), findsNothing);
    expect(find.byType(LoginSheet), findsNothing);
  });
}
