import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug_page_tracker.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/l10n/language_data_refresh.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/home/home_feed_cache_store.dart';
import 'package:genesis_flutter_android/pages/origin/origin_feed_cache_store.dart';

class _Page extends StatefulWidget {
  const _Page({required this.active, required this.onRefresh});
  final ValueNotifier<bool> active;
  final Future<void> Function() onRefresh;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with LanguageDataRefresh<_Page> {
  final input = TextEditingController();
  @override
  ValueNotifier<bool> get languagePageActive => widget.active;
  @override
  Future<void> refreshLanguageData() => widget.onRefresh();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: TextField(controller: input));
}

class _DelayedTransport implements HttpTransport {
  final dispatched = Completer<void>();
  final response = Completer<TransportResponse>();
  @override
  Future<TransportResponse> send(TransportRequest request) {
    dispatched.complete();
    return response.future;
  }
}

Future<void> _switch(String code) async {
  await appLanguageController.select(
    code == 'zh-TW' ? const Locale('zh', 'TW') : const Locale('en'),
    saveLanguage: (_) async {},
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appLanguageController.load();
  });

  testWidgets(
    'visible page refreshes once and preserves input; hidden tab waits',
    (tester) async {
      final active = ValueNotifier(true);
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: _Page(
            active: active,
            onRefresh: () async {
              refreshes++;
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'keep my search');
      expect(refreshes, 0);
      await _switch('zh-TW');
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(find.text('keep my search'), findsOneWidget);
      active.value = false;
      await _switch('en');
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      active.value = true;
      await tester.pumpAndSettle();
      expect(refreshes, 2);
      active.value = false;
      active.value = true;
      await tester.pumpAndSettle();
      expect(refreshes, 2);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
    },
  );

  testWidgets('covered route refreshes on pop, not while covered', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final active = ValueNotifier(true);
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [genesisPageRouteObserver],
        home: _Page(
          active: active,
          onRefresh: () async {
            refreshes++;
          },
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('settings')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _switch('zh-TW');
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });

  testWidgets(
    'failed save does not refresh; change during refresh schedules latest revision',
    (tester) async {
      final active = ValueNotifier(true);
      final pending = Completer<void>();
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: _Page(
            active: active,
            onRefresh: () {
              refreshes++;
              return refreshes == 1 ? pending.future : Future.value();
            },
          ),
        ),
      );
      await expectLater(
        appLanguageController.select(
          const Locale('zh', 'TW'),
          saveLanguage: (_) async {
            throw StateError('failed');
          },
        ),
        throwsStateError,
      );
      await tester.pump();
      expect(refreshes, 0);
      await _switch('zh-TW');
      await tester.pump();
      expect(refreshes, 1);
      await _switch('en');
      await tester.pump();
      expect(refreshes, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(refreshes, 2);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
    },
  );

  testWidgets('feed caches isolate languages while preserving gender choice', (
    tester,
  ) async {
    const home = HomeFeedCacheStore(ownerUid: 'u_1');
    const origin = OriginFeedCacheStore(ownerUid: 'u_1');
    await _switch('en');
    await home.save(HomeFeedCacheKind.myWorlds, {'name': 'English'});
    await origin.saveForYouFirstPage({'name': 'English'});
    await origin.saveManualGender('Female');
    await _switch('zh-TW');
    expect(await home.load(HomeFeedCacheKind.myWorlds), isNull);
    expect(await origin.loadForYouFirstPage(), isNull);
    expect(await origin.loadManualGender(), 'Female');
    await home.save(HomeFeedCacheKind.myWorlds, {'name': '繁體'});
    await _switch('en');
    expect((await home.load(HomeFeedCacheKind.myWorlds))!['name'], 'English');
    expect((await origin.loadForYouFirstPage())!['name'], 'English');
  });

  testWidgets('failed refresh stays stale and retries on next activation', (
    tester,
  ) async {
    final active = ValueNotifier(true);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _Page(
          active: active,
          onRefresh: () async {
            if (++attempts == 1) throw StateError('offline');
          },
        ),
      ),
    );
    await _switch('zh-TW');
    await tester.pumpAndSettle();
    expect(attempts, 1);
    active.value = false;
    active.value = true;
    await tester.pumpAndSettle();
    expect(attempts, 2);
    active.value = false;
    active.value = true;
    await tester.pumpAndSettle();
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });

  testWidgets(
    'startup config and user language responses remain authoritative',
    (tester) async {
      for (final path in ['/api/v1/app/config', '/api/v1/user/info']) {
        await appLanguageController.load();
        final transport = _DelayedTransport();
        final client = ApiClient(
          baseUrl: 'https://example.com',
          transport: transport,
        );
        final result = client.get<Object?>(path);
        await transport.dispatched.future;
        await _switch('zh-TW');
        transport.response.complete(
          const TransportResponse(
            statusCode: 200,
            headers: {},
            body: '{"language":"en"}',
          ),
        );
        expect(await result, {'language': 'en'});
      }
    },
  );

  testWidgets('old GET response is discarded; mutation completes normally', (
    tester,
  ) async {
    for (final method in ['GET', 'POST']) {
      SharedPreferences.setMockInitialValues({});
      await appLanguageController.load();
      final transport = _DelayedTransport();
      final client = ApiClient(
        baseUrl: 'https://example.com',
        transport: transport,
      );
      final result = client.request<Object?>(method, '/api/v1/world/info');
      final checked = method == 'GET'
          ? expectLater(
              result,
              throwsA(isA<NetworkRequestCancelledException>()),
            )
          : expectLater(result, completion({'title': 'old'}));
      await transport.dispatched.future;
      await _switch('zh-TW');
      transport.response.complete(
        const TransportResponse(
          statusCode: 200,
          headers: {},
          body: '{"title":"old"}',
        ),
      );
      await checked;
    }
  });
}
