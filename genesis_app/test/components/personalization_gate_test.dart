import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/config/app_global_config.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/app/onboarding/personalization_store.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_gate.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/components/gems/membership_guest_login_gate.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import '../app/membership/membership_purchase_service_test.dart' show Harness;
import '../support/personalization_fixtures.dart';
import '../support/membership_fixtures.dart';

Finder control(String value) => find.byKey(ValueKey('personalization-$value'));
Future<void> tap(WidgetTester tester, String value) async {
  await tester.ensureVisible(control(value));
  await tester.tap(control(value));
  await tester.pumpAndSettle();
}

void main() {
  late ValueNotifier<AppGlobalConfig> appConfig;
  setUp(() {
    appConfig = ValueNotifier(
      const AppGlobalConfig(showPersonalizationForm: true),
    );
    addTearDown(appConfig.dispose);
    SharedPreferences.setMockInitialValues({});
  });

  for (final entry in ['form', 'home_completed', 'home_disabled']) {
    for (final preloadReady in [true, false]) {
      testWidgets('entry refreshes preload $entry ready=$preloadReady', (
        tester,
      ) async {
        final enabled = entry != 'home_disabled';
        appConfig.value = AppGlobalConfig(showPersonalizationForm: enabled);
        var profileCalls = 0;
        var productCalls = 0;
        final profile = Completer<PersonalizationData>();
        final products = Completer<MembershipProductList>();
        final catalog = MembershipCatalog(
          provider: MembershipProvider.google,
          loadProducts: (_) {
            productCalls++;
            return products.future;
          },
        );
        final store = PersonalizationStore(
          readLoginUid: () async => null,
          load: () {
            profileCalls++;
            return profile.future;
          },
          save: (value) async => PersonalizationProfile(
            gender: value.gender,
            age: value.age,
            completed: true,
          ),
        );
        final navigator = GlobalKey<NavigatorState>();
        Widget subscription(BuildContext _) => ProSubscriptionContent(
          catalog: catalog,
          refreshMembershipOnOpen: false,
        );
        void completeProducts() => products.complete(
          MembershipProductList(products: [membershipProduct(yearly: true)]),
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              builder: (_, child) => PersonalizationGate(
                appConfig: appConfig,
                store: store,
                navigatorKey: navigator,
                preloadMembership: catalog.preload,
                subscriptionBuilder: subscription,
                child: child!,
              ),
              home: Scaffold(
                body: TextButton(
                  onPressed: () => navigator.currentState!.push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          Scaffold(body: subscription(context)),
                    ),
                  ),
                  child: const Text('Open subscription'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Both requests start before personalization returns; disabled forms
          // still warm the shared catalog for the Home entry.
          expect(profileCalls, enabled ? 1 : 0);
          expect(productCalls, 1);
          expect(find.byType(PersonalizationSheet), findsNothing);
          profile.complete(personalizationData(completed: entry != 'form'));
          await tester.pumpAndSettle();
          if (preloadReady) {
            completeProducts();
            await tester.pumpAndSettle();
          }
          if (entry == 'form') {
            await tap(tester, 'g4');
            await tap(tester, 'a6');
            await tester.tap(control('continue'));
          } else {
            await tester.tap(find.text('Open subscription'));
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(productCalls, 2);
          if (!preloadReady) completeProducts();
          await tester.pumpAndSettle();
          expect(find.text(r'Yearly: $99.99'), findsOneWidget);
          expect(productCalls, 2);
        } finally {
          if (!products.isCompleted) completeProducts();
          await tester.pumpWidget(const SizedBox.shrink());
          store.dispose();
        }
      });
    }
  }

  testWidgets('preload failure does not block personalization or Continue', (
    tester,
  ) async {
    final store = PersonalizationStore(
      readLoginUid: () async => null,
      load: () async => personalizationData(),
      save: (value) async => PersonalizationProfile(
        gender: value.gender,
        age: value.age,
        completed: true,
      ),
    );
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            appConfig: appConfig,
            store: store,
            navigatorKey: navigator,
            preloadMembership: () async => throw StateError('offline'),
            subscriptionBuilder: (_) => const Text('Subscription entry'),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PersonalizationSheet), findsOneWidget);
      await tap(tester, 'g4');
      await tap(tester, 'a6');
      await tap(tester, 'continue');
      expect(find.text('Subscription entry'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('config controls form entry without changing Continue', (
    tester,
  ) async {
    appConfig.value = const AppGlobalConfig();
    var loads = 0;
    var saves = 0;
    final store = PersonalizationStore(
      readLoginUid: () async => 'user',
      load: () async {
        loads++;
        return personalizationData();
      },
      save: (profile) async {
        saves++;
        return PersonalizationProfile(
          gender: profile.gender,
          age: profile.age,
          completed: true,
        );
      },
    );
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            appConfig: appConfig,
            store: store,
            navigatorKey: navigator,
            subscriptionBuilder: (_) => const Text('Subscription entry'),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(store.blocksOtherPrompts.value, isFalse);

      appConfig.value = const AppGlobalConfig(showPersonalizationForm: true);
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(find.byType(PersonalizationSheet), findsOneWidget);
      // A later flag change must not interrupt the active form or purchase.
      appConfig.value = const AppGlobalConfig();
      await tap(tester, 'g4');
      await tap(tester, 'a6');
      await tap(tester, 'continue');
      expect(saves, 1);
      expect(find.text('Subscription entry'), findsOneWidget);
      await tap(tester, 'skip');
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(store.blocksOtherPrompts.value, isFalse);
      store.resetForSession();
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(store.isEnabled, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('disabling form stops profile retries', (tester) async {
    var loads = 0;
    final store = PersonalizationStore(
      readLoginUid: () async => 'user',
      load: () async {
        loads++;
        throw StateError('offline');
      },
      save: (_) async => throw UnimplementedError(),
    );
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            appConfig: appConfig,
            store: store,
            navigatorKey: navigator,
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 1);
      appConfig.value = const AppGlobalConfig();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 40));
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(store.blocksOtherPrompts.value, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  for (final uid in [null, 'signed-in']) {
    testWidgets('startup dynamic locked form and saved subscription for $uid', (
      tester,
    ) async {
      final loaded = Completer<PersonalizationData>();
      final saved = Completer<PersonalizationProfile>();
      PersonalizationProfile? submitted;
      var checks = 0;
      final store = PersonalizationStore(
        readLoginUid: () async => uid,
        load: () => loaded.future,
        save: (profile) {
          submitted = profile;
          return saved.future;
        },
      );
      final navigator = GlobalKey<NavigatorState>();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            navigatorKey: navigator,
            builder: (_, child) => PersonalizationGate(
              appConfig: appConfig,
              store: store,
              navigatorKey: navigator,
              checkGuestPurchases: () async {
                checks++;
              },
              subscriptionBuilder: (_) => const Text('Real subscription entry'),
              child: child!,
            ),
            home: const Scaffold(body: Text('Home')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsNothing);
        loaded.complete(personalizationData());
        await tester.pumpAndSettle();
        expect(find.byType(OutlinedButton), findsNWidgets(12));
        expect(control('sign-in'), uid == null ? findsOneWidget : findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsOneWidget);
        await tap(tester, 'g4');
        await tap(tester, 'a6');
        await tap(tester, 'continue');
        expect(submitted!.toJson(), {'gender': 'g4', 'age': 'a6'});
        expect(find.text('Real subscription entry'), findsNothing);
        expect(store.blocksOtherPrompts.value, isTrue);
        saved.complete(
          const PersonalizationProfile(
            gender: 'g4',
            age: 'a6',
            completed: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Real subscription entry'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Real subscription entry'), findsOneWidget);
        expect(store.blocksOtherPrompts.value, isTrue);
        await tap(tester, 'skip');
        expect(store.blocksOtherPrompts.value, isFalse);
        expect(find.byType(PersonalizationSheet), findsNothing);
        expect(checks, uid == null ? 1 : 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    });
  }

  for (final scenario in [
    'monthly',
    'yearly',
    'non_member',
    'expired_status',
    'expired_time',
    'unknown',
    'refreshing_to_active',
  ]) {
    testWidgets(
      'Continue uses global VIP access before subscription: $scenario',
      (tester) async {
        final now = DateTime.utc(2040);
        final response = Completer<GemWallet>();
        var walletRequests = 0;
        var saves = 0;
        var subscriptionBuilds = 0;
        final wallet = GemWalletStore(
          readUid: () async => 'profile-user',
          loadWallet: () async {
            walletRequests++;
            if (scenario == 'refreshing_to_active' && walletRequests == 1) {
              return const GemWallet(
                balanceCent: 0,
                membership: GemWalletMembership(
                  status: 0,
                  planCode: '',
                  expiresAt: null,
                  autoRenew: false,
                  blueGemsCent: 0,
                ),
              );
            }
            return response.future;
          },
        );
        final membership = MembershipAccessStore(
          wallet: wallet,
          readLoginUid: () async => 'profile-user',
          serverNow: () => now,
        );
        final store = PersonalizationStore(
          readLoginUid: () async => 'profile-user',
          load: () async => personalizationData(),
          save: (profile) async {
            saves++;
            return PersonalizationProfile(
              gender: profile.gender,
              age: profile.age,
              completed: true,
            );
          },
        );
        final navigator = GlobalKey<NavigatorState>();
        try {
          if (scenario == 'refreshing_to_active') {
            expect((await membership.refresh()).isVip, isFalse);
          }
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              builder: (_, child) => PersonalizationGate(
                appConfig: appConfig,
                store: store,
                navigatorKey: navigator,
                membershipAccess: membership,
                checkGuestPurchases: () async =>
                    fail('Signed-in Continue must not check guest purchases'),
                subscriptionBuilder: (_) {
                  subscriptionBuilds++;
                  return const Text('Subscription offer');
                },
                child: child!,
              ),
              home: const Scaffold(body: Text('Main page')),
            ),
          );
          await tester.pumpAndSettle();
          await tap(tester, 'g0');
          await tap(tester, 'a0');
          if (scenario == 'refreshing_to_active') {
            unawaited(wallet.refresh());
            await tester.pump();
          }
          await tap(tester, 'continue');
          await tap(tester, 'continue');
          expect(saves, 1);
          expect(subscriptionBuilds, 0);
          expect(find.byType(PersonalizationSheet), findsOneWidget);
          expect(walletRequests, scenario == 'refreshing_to_active' ? 2 : 1);
          if (scenario == 'unknown') {
            response.completeError(StateError('wallet unavailable'));
          } else {
            response.complete(
              GemWallet(
                balanceCent: 0,
                membership: GemWalletMembership(
                  status: scenario == 'non_member'
                      ? 0
                      : scenario == 'expired_status'
                      ? 2
                      : 1,
                  planCode: scenario == 'yearly' ? 'pro_yearly' : 'pro_monthly',
                  expiresAt: scenario == 'expired_time'
                      ? now
                      : DateTime.utc(2041),
                  autoRenew: true,
                  blueGemsCent: 0,
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          final showsOffer = [
            'non_member',
            'expired_status',
            'expired_time',
          ].contains(scenario);
          expect(
            find.text('Subscription offer'),
            showsOffer ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(PersonalizationSheet),
            showsOffer ? findsOneWidget : findsNothing,
          );
          expect(subscriptionBuilds, showsOffer ? greaterThan(0) : 0);
          expect(store.state.value.data?.profile.completed, isTrue);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          store.dispose();
          membership.dispose();
          wallet.dispose();
        }
      },
    );
  }

  for (final scenario in [
    'needs_form',
    'already_completed',
    'form_disabled',
    'late_config',
  ]) {
    testWidgets(
      'paid guest logs in before loading account profile: $scenario',
      (tester) async {
        // Removing the debug panel also removes any saved login bypass.
        SharedPreferences.setMockInitialValues({
          'developer_membership_guest_force_login_v1': false,
        });
        final accountCompleted = scenario == 'already_completed';
        final formEnabled = scenario != 'form_disabled';
        appConfig.value = AppGlobalConfig(
          showPersonalizationForm: formEnabled && scenario != 'late_config',
        );
        final h = Harness()..uid = null;
        h.service.guestLoginRequestId.value = 'pending-test-order';
        final loadedFor = <String?>[];
        final savedFor = <String?>[];
        var checks = 0;
        var loginCalls = 0;
        var attempts = 0;
        var secondaryLoginCalls = 0;
        var subscriptionBuilds = 0;
        var failSave = true;
        final authenticated = Completer<void>();
        final store = PersonalizationStore(
          readLoginUid: () async => h.uid,
          load: () async {
            loadedFor.add(h.uid);
            return personalizationData(completed: accountCompleted);
          },
          save: (profile) async {
            if (failSave) throw StateError('offline');
            savedFor.add(h.uid);
            return PersonalizationProfile(
              gender: profile.gender,
              age: profile.age,
              completed: true,
            );
          },
        );
        final navigator = GlobalKey<NavigatorState>();
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: GenesisTheme.dark(),
              navigatorKey: navigator,
              builder: (_, child) => PersonalizationGate(
                appConfig: appConfig,
                store: store,
                navigatorKey: navigator,
                loginPending: h.service.guestLoginRequestId,
                checkGuestPurchases: () async {
                  checks++;
                },
                requestRequiredLogin: (context) {
                  loginCalls++;
                  return showLoginSheet(
                    context: context,
                    isDismissible: false,
                    onLogin: (_) async {
                      attempts++;
                      if (attempts == 1) return false;
                      if (attempts == 2) throw StateError('Login failed');
                      await authenticated.future;
                      h.uid = 'bound-user';
                      h.service.guestLoginRequestId.value = null;
                      store.resetForSession();
                      return true;
                    },
                  );
                },
                subscriptionBuilder: (_) {
                  subscriptionBuilds++;
                  return const Text('Subscription must not open');
                },
                child: MembershipGuestLoginGate(
                  service: h.service,
                  navigatorKey: navigator,
                  blocked: store.blocksOtherPrompts,
                  requestLogin: (_) async {
                    secondaryLoginCalls++;
                    return false;
                  },
                  child: child!,
                ),
              ),
              routes: {
                RouteNames.me: (_) =>
                    const Scaffold(body: Text('Me destination')),
              },
              home: const Scaffold(body: Text('Home')),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(LoginSheet), findsOneWidget);
          expect(find.byType(PersonalizationSheet), findsNothing);
          expect(loadedFor, isEmpty);
          expect(checks, 0); // Already-known pending payment needs no recheck.
          expect(loginCalls, 1);
          expect(secondaryLoginCalls, 0);
          await tester.binding.handlePopRoute();
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(find.byType(LoginSheet), findsOneWidget);
          for (var attempt = 0; attempt < 3; attempt++) {
            await tester.ensureVisible(find.text('Continue with Google'));
            await tester.tap(find.text('Continue with Google'));
            await tester.pump();
            await tester.pump(const Duration(seconds: 2));
            expect(find.byType(LoginSheet), findsOneWidget);
            expect(find.byType(PersonalizationSheet), findsNothing);
            expect(loadedFor, isEmpty);
          }
          if (scenario == 'late_config') {
            appConfig.value = const AppGlobalConfig(
              showPersonalizationForm: true,
            );
            await tester.pump();
            expect(find.byType(LoginSheet), findsOneWidget);
            expect(loginCalls, 1);
            expect(secondaryLoginCalls, 0);
            expect(loadedFor, isEmpty);
          }
          authenticated.complete();
          await tester.pumpAndSettle();
          expect(find.byType(LoginSheet), findsNothing);
          expect(loadedFor, formEnabled ? ['bound-user'] : isEmpty);
          expect(find.text('Me destination'), findsOneWidget);
          if (formEnabled && !accountCompleted) {
            expect(find.byType(PersonalizationSheet), findsOneWidget);
            expect(control('sign-in'), findsNothing);
            await tap(tester, 'g4');
            await tap(tester, 'a6');
            await tap(tester, 'continue');
            expect(find.byType(PersonalizationSheet), findsOneWidget);
            await tester.pump(const Duration(seconds: 2));
            failSave = false;
            await tap(tester, 'continue');
            expect(savedFor, ['bound-user']);
          }
          expect(find.byType(PersonalizationSheet), findsNothing);
          expect(store.blocksOtherPrompts.value, isFalse);
          expect(checks, 0);
          expect(loginCalls, 1);
          expect(secondaryLoginCalls, 0);
          expect(subscriptionBuilds, 0);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          store.dispose();
        }
      },
    );
  }

  testWidgets('startup waits for guest check; Continue never checks again', (
    tester,
  ) async {
    String? uid;
    final pending = ValueNotifier<String?>(null);
    final checked = Completer<void>();
    var checks = 0;
    var loginCalls = 0;
    final preloadedFor = <String?>[];
    final loadedFor = <String?>[];
    final store = PersonalizationStore(
      readLoginUid: () async => uid,
      load: () async {
        loadedFor.add(uid);
        return personalizationData();
      },
      save: (profile) async => PersonalizationProfile(
        gender: profile.gender,
        age: profile.age,
        completed: true,
      ),
    );
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            appConfig: appConfig,
            store: store,
            navigatorKey: navigator,
            loginPending: pending,
            checkGuestPurchases: () async {
              checks++;
              await checked.future;
              pending.value = 'recovered-order';
            },
            preloadMembership: () async {
              preloadedFor.add(uid);
            },
            requestRequiredLogin: (context) {
              loginCalls++;
              return showLoginSheet(
                context: context,
                isDismissible: false,
                onLogin: (_) async {
                  uid = 'recovered-user';
                  // Deliberately leave a stale login request until after save.
                  store.resetForSession();
                  return true;
                },
              );
            },
            subscriptionBuilder: (_) => const Text('Unexpected subscription'),
            child: child!,
          ),
          routes: {
            RouteNames.me: (_) => const Scaffold(body: Text('Me destination')),
          },
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(loadedFor, isEmpty);
      expect(preloadedFor, isEmpty);
      expect(find.byType(PersonalizationSheet), findsNothing);
      checked.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoginSheet), findsOneWidget);
      expect(loadedFor, isEmpty);
      expect(preloadedFor, isEmpty);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(loadedFor, ['recovered-user']);
      expect(preloadedFor, ['recovered-user']);
      await tap(tester, 'g0');
      await tap(tester, 'a0');
      await tap(tester, 'continue');
      expect(find.byType(LoginSheet), findsNothing);
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(find.text('Unexpected subscription'), findsNothing);
      expect(loginCalls, 1);
      expect(checks, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      pending.dispose();
    }
  });

  for (final afterSave in [false, true]) {
    testWidgets('late VIP check locks Sign in; already saved=$afterSave', (
      tester,
    ) async {
      String? uid;
      final pending = ValueNotifier<String?>(null);
      final savedFor = <String?>[];
      final store = PersonalizationStore(
        readLoginUid: () async => uid,
        load: () async => personalizationData(),
        save: (profile) async {
          savedFor.add(uid);
          return PersonalizationProfile(
            gender: profile.gender,
            age: profile.age,
            completed: true,
          );
        },
      );
      final navigator = GlobalKey<NavigatorState>();
      var subscriptionBuilds = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => PersonalizationGate(
              appConfig: appConfig,
              store: store,
              navigatorKey: navigator,
              loginPending: pending,
              signIn: (_, _) async {
                uid = 'logged-in';
                pending.value = null;
                store.resetForSession();
              },
              subscriptionBuilder: (_) {
                subscriptionBuilds++;
                return const Text('Subscription entry');
              },
              child: child!,
            ),
            routes: {
              RouteNames.me: (_) =>
                  const Scaffold(body: Text('Me destination')),
            },
            home: const Scaffold(body: Text('Home')),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'g4');
        await tap(tester, 'a6');
        if (afterSave) {
          await tap(tester, 'continue');
          expect(find.text('Subscription entry'), findsOneWidget);
        }
        pending.value = 'late-order';
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Subscription entry'), findsNothing);
        expect(control('skip'), findsNothing);
        final buildsBeforeLogin = subscriptionBuilds;
        await tester.ensureVisible(find.text('Continue with Google'));
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(store.state.value.uid, 'logged-in');
        expect(store.state.value.data!.profile.completed, isFalse);
        expect(control('continue'), findsOneWidget);
        expect(control('sign-in'), findsNothing);
        expect(store.blocksOtherPrompts.value, isTrue);
        await tap(tester, 'continue');
        expect(savedFor, [if (afterSave) null, 'logged-in']);
        expect(find.text('Me destination'), findsOneWidget);
        expect(find.byType(PersonalizationSheet), findsNothing);
        expect(subscriptionBuilds, buildsBeforeLogin);
        expect(store.blocksOtherPrompts.value, isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        pending.dispose();
      }
    });
  }

  testWidgets(
    'late completed profile read after login dismisses the blocked form',
    (tester) async {
      String? uid;
      var failed = true;
      final store = PersonalizationStore(
        readLoginUid: () async => uid,
        load: () async {
          if (uid != null && failed) throw StateError('offline');
          return personalizationData(completed: uid != null);
        },
        save: (_) async => throw UnimplementedError(),
      );
      final navigator = GlobalKey<NavigatorState>();
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => PersonalizationGate(
              appConfig: appConfig,
              store: store,
              navigatorKey: navigator,
              signIn: (_, _) async {
                uid = 'logged-in';
                store.resetForSession();
              },
              child: child!,
            ),
            home: const Scaffold(body: Text('Home')),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'sign-in');
        await tester.ensureVisible(find.text('Continue with Google'));
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsOneWidget);
        expect(store.blocksOtherPrompts.value, isTrue);
        failed = false;
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(store.blocksOtherPrompts.value, isFalse);
        expect(find.byType(PersonalizationSheet), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );

  testWidgets('failed startup check retries before showing the guest form', (
    tester,
  ) async {
    var checks = 0;
    var loads = 0;
    final store = PersonalizationStore(
      readLoginUid: () async => null,
      load: () async {
        loads++;
        return personalizationData();
      },
      save: (_) async => throw UnimplementedError(),
    );
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            appConfig: appConfig,
            store: store,
            navigatorKey: navigator,
            checkGuestPurchases: () async {
              if (++checks == 1) throw StateError('offline');
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 0);
      expect(find.byType(PersonalizationSheet), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(checks, 2);
      expect(loads, 1);
      expect(find.byType(PersonalizationSheet), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets('completed server profile never opens form', (tester) async {
    final store = PersonalizationStore(
      readLoginUid: () async => null,
      load: () async => personalizationData(completed: true),
      save: (_) async => throw UnimplementedError(),
    );
    final navigator = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersonalizationGate(
            appConfig: appConfig,
            store: store,
            navigatorKey: navigator,
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(store.blocksOtherPrompts.value, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });

  testWidgets(
    'sign in reloads account completion and closes only when completed',
    (tester) async {
      String? uid;
      var loads = 0;
      final store = PersonalizationStore(
        readLoginUid: () async => uid,
        load: () async {
          loads++;
          return personalizationData(completed: uid != null);
        },
        save: (_) async => throw UnimplementedError(),
      );
      final navigator = GlobalKey<NavigatorState>();
      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => PersonalizationGate(
              appConfig: appConfig,
              store: store,
              navigatorKey: navigator,
              signIn: (_, _) async {
                uid = 'logged-in';
                store.resetForSession();
              },
              child: child!,
            ),
            home: const Scaffold(body: Text('Home')),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'sign-in');
        await tester.ensureVisible(find.text('Continue with Google'));
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(loads, 2);
        expect(store.state.value.uid, 'logged-in');
        expect(store.blocksOtherPrompts.value, isFalse);
        expect(find.byType(PersonalizationSheet), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
}
