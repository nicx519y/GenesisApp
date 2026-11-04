import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/debug/membership_debug_override.dart';
import 'package:genesis_flutter_android/app/debug/world_memory_debug_preview.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_style.dart';
import 'package:genesis_flutter_android/components/world_memory/world_memory.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/models/world_recent_summary.dart';
import 'package:genesis_flutter_android/pages/world/world_memory_host.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_cache.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

import '../../support/mini_phone_music_services.dart';

// Controlled test data only: never delegates summary requests to a transport.
class _SummaryApi extends GenesisApi {
  _SummaryApi() : super(useMock: true);

  final requests = <String>[];
  final responses = <Completer<WorldRecentSummaryPage>>[];

  @override
  Future<WorldRecentSummaryPage> getWorldRecentSummary({
    required String worldId,
    String? cursor,
  }) {
    requests.add(worldId);
    final response = Completer<WorldRecentSummaryPage>();
    responses.add(response);
    return response.future;
  }

  void complete(int index, String text) =>
      responses[index].complete(_page(text));
}

WorldRecentSummaryPage _page(String text) => WorldRecentSummaryPage(
  items: [WorldRecentSummary(body: text, tickNo: 1)],
  hasMore: false,
  cursor: '',
);

class _Routes extends NavigatorObserver {
  final pushes = <RouteSettings>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route.settings);
  }
}

Widget _app(Widget child) => MaterialApp(
  theme: GenesisTheme.dark(),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _host(
  AppServices services,
  WorldRecapCache cache, {
  bool active = true,
  Listenable? updates,
}) => WorldMemoryHost(
  services: services,
  cache: cache,
  worldId: 'test-world',
  section: WorldMemorySection.recap,
  active: active,
  summaryUpdates: updates,
);

void main() {
  final servicesToDispose = <AppServices>[];
  final cachesToDispose = <WorldRecapCache>[];

  AppServices servicesFor(_SummaryApi api) {
    final services = musicTestServices(api);
    servicesToDispose.add(services);
    return services;
  }

  WorldRecapCache newCache() {
    final cache = WorldRecapCache();
    cachesToDispose.add(cache);
    return cache;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    membershipDebugOverride.value = MembershipDebugOverride.yearly;
  });

  tearDown(() {
    for (final services in servicesToDispose) {
      services.dispose();
    }
    servicesToDispose.clear();
    for (final cache in cachesToDispose) {
      cache.dispose();
    }
    cachesToDispose.clear();
    membershipDebugOverride.value = MembershipDebugOverride.off;
    worldMemoryDebugPreview.value = const WorldMemoryDebugPreview();
  });

  testWidgets(
    'debug preview shows the sample story and skips the summary API',
    (tester) async {
      worldMemoryDebugPreview.value = const WorldMemoryDebugPreview(
        membership: WorldMemoryDebugMembership.both,
      );
      final api = _SummaryApi();
      await tester.pumpWidget(_app(_host(servicesFor(api), newCache())));
      await tester.pump();
      expect(find.textContaining('Vivienne privately asked'), findsOneWidget);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets('without the debug preview no sample story is shown', (
    tester,
  ) async {
    final api = _SummaryApi();
    await tester.pumpWidget(_app(_host(servicesFor(api), newCache())));
    await tester.pump();
    expect(find.textContaining('Vivienne privately asked'), findsNothing);
  });

  for (final deluxe in [false, true]) {
    testWidgets(
      'nested Subscribe opens root gemWallet for ${deluxe ? 'Deluxe' : 'Premium'}',
      (tester) async {
        membershipDebugOverride.value = MembershipDebugOverride.none;
        final api = _SummaryApi();
        final services = servicesFor(api);
        final root = _Routes();
        final inner = _Routes();
        final rootKey = GlobalKey<NavigatorState>();
        final innerKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: rootKey,
            navigatorObservers: [root],
            theme: GenesisTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('root wallet target')),
            ),
            home: Navigator(
              key: innerKey,
              observers: [inner],
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => Scaffold(
                  body: WorldMemoryHost(
                    services: services,
                    worldId: 'test-world',
                    section: deluxe
                        ? WorldMemorySection.cast
                        : WorldMemorySection.recap,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final subscribe = find.byKey(
          ValueKey('membership-subscribe-${deluxe ? 'deluxe' : 'premium'}'),
        );
        await tester.ensureVisible(subscribe);
        await tester.tap(subscribe);
        await tester.pumpAndSettle();
        expect(
          root.pushes.where((route) => route.name == RouteNames.gemWallet),
          hasLength(1),
        );
        expect(
          inner.pushes.where((route) => route.name == RouteNames.gemWallet),
          isEmpty,
        );
        final args = root.pushes.last.arguments! as GemWalletRouteArgs;
        expect(args.showSubscription, isTrue);
        expect(
          args.membershipTier,
          deluxe ? MemoryMembershipTier.deluxe : MemoryMembershipTier.premium,
        );
        expect(args.subscriptionSource, SubscriptionSource.worldRecap);
        expect(rootKey.currentState!.canPop(), isTrue);
        expect(innerKey.currentState!.canPop(), isFalse);
        expect(api.requests, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'same services and revision preserve a shared cache across inactive remounts',
    (tester) async {
      final api = _SummaryApi();
      final services = servicesFor(api);
      final cache = newCache();
      cache.bindScope((services, services.sessionRevision.value));
      await cache.refresh(
        'test-world',
        ({required worldId, cursor}) async =>
            _page('same account cached summary'),
      );
      await tester.pumpWidget(_app(_host(services, cache, active: false)));
      await tester.pumpAndSettle();
      expect(find.text('same account cached summary'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(_host(services, cache, active: false)));
      await tester.pumpAndSettle();
      expect(cache.hasLoaded, isTrue);
      expect(find.text('same account cached summary'), findsOneWidget);
      expect(api.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'new services at the same revision isolate cache and reject late old responses',
    (tester) async {
      final firstApi = _SummaryApi();
      final first = servicesFor(firstApi);
      final secondApi = _SummaryApi();
      final second = servicesFor(secondApi);
      final cache = newCache();
      expect(first.sessionRevision.value, second.sessionRevision.value);
      await tester.pumpWidget(_app(_host(first, cache)));
      await tester.pumpAndSettle();
      expect(firstApi.requests, ['test-world']);
      await tester.pumpWidget(_app(_host(second, cache, active: false)));
      await tester.pumpAndSettle();
      expect(cache.hasLoaded, isFalse);
      expect(cache.items, isEmpty);
      firstApi.complete(0, 'old services private summary');
      await tester.pumpAndSettle();
      expect(cache.items, isEmpty);
      expect(find.text('old services private summary'), findsNothing);
      await tester.pumpWidget(_app(_host(second, cache)));
      await tester.pumpAndSettle();
      secondApi.complete(0, 'new services summary');
      await tester.pumpAndSettle();
      expect(find.text('new services summary'), findsOneWidget);
      expect(cache.items.single.body, 'new services summary');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'revision change while unmounted invalidates the same services cache on return',
    (tester) async {
      final api = _SummaryApi();
      final services = servicesFor(api);
      final cache = newCache();
      await tester.pumpWidget(_app(_host(services, cache)));
      await tester.pumpAndSettle();
      api.complete(0, 'previous session summary');
      await tester.pumpAndSettle();
      expect(find.text('previous session summary'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      services.sessionRevision.value++;
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(_host(services, cache, active: false)));
      await tester.pumpAndSettle();
      expect(cache.hasLoaded, isFalse);
      expect(cache.items, isEmpty);
      expect(find.text('previous session summary'), findsNothing);
      expect(api.requests, hasLength(1));
      await tester.pumpWidget(_app(_host(services, cache)));
      await tester.pumpAndSettle();
      api.complete(1, 'current session summary');
      await tester.pumpAndSettle();
      expect(find.text('current session summary'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('inactive to active refreshes Summary once on every reentry', (
    tester,
  ) async {
    final api = _SummaryApi();
    final services = servicesFor(api);
    final cache = newCache();
    await tester.pumpWidget(_app(_host(services, cache, active: false)));
    await tester.pumpAndSettle();
    expect(api.requests, isEmpty);
    await tester.pumpWidget(_app(_host(services, cache)));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(1));
    api.complete(0, 'first visit summary');
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(_host(services, cache, active: false)));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(1));
    await tester.pumpWidget(_app(_host(services, cache)));
    await tester.pumpAndSettle();
    expect(api.requests, hasLength(2));
    api.complete(1, 'second visit summary');
    await tester.pumpAndSettle();
    expect(find.text('second visit summary'), findsOneWidget);
    expect(find.text('first visit summary'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'repeat active membership notifications do not refresh within one mount',
    (tester) async {
      final api = _SummaryApi();
      final services = servicesFor(api);
      final cache = newCache();
      await tester.pumpWidget(_app(_host(services, cache)));
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
      membershipDebugOverride.value = MembershipDebugOverride.monthly;
      await tester.pumpAndSettle();
      api.complete(0, 'stable summary');
      await tester.pumpAndSettle();
      membershipDebugOverride.value = MembershipDebugOverride.yearly;
      await tester.pumpAndSettle();
      membershipDebugOverride.value = MembershipDebugOverride.monthly;
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
      expect(find.text('stable summary'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'summaryUpdates queues one refresh during load and defers updates while inactive',
    (tester) async {
      final api = _SummaryApi();
      final services = servicesFor(api);
      final cache = newCache();
      final updates = ValueNotifier(0);
      addTearDown(updates.dispose);
      await tester.pumpWidget(_app(_host(services, cache, updates: updates)));
      await tester.pumpAndSettle();
      updates.value++;
      updates.value++;
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
      api.complete(0, 'entry response');
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(2));
      api.complete(1, 'push response');
      await tester.pumpAndSettle();
      expect(find.text('push response'), findsOneWidget);
      await tester.pumpWidget(
        _app(_host(services, cache, active: false, updates: updates)),
      );
      await tester.pumpAndSettle();
      updates.value++;
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(2));
      await tester.pumpWidget(_app(_host(services, cache, updates: updates)));
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(3));
      api.complete(2, 'reentry response');
      await tester.pumpAndSettle();
      expect(find.text('reentry response'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
