import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/models/gem_model.dart';
import 'package:genesis_flutter_android/pages/gems/memory_model_page_cache.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/mini_phone_model_settings.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/mini_phone_model_settings_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_analytics.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_collect_probe.dart';
import '../../support/mini_phone_music_services.dart';

Map<String, Object?> _catalogJson({
  String title = 'Phone DM model',
  String selected = 'phone_model',
  int tokens = 8000,
}) => {
  'selected_model_code': selected,
  'list': [
    {
      'group_code': 'models',
      'group_title': 'Models',
      'models': [
        for (final code in ['phone_model', 'phone_pro'])
          {
            'model_code': code,
            'title': code == 'phone_model' ? title : 'Phone Pro',
            'tag': [],
            'description': 'Test model',
            'estimated_next_message_gems_cent': 375,
            'estimated_next_tick_gems_cent': 425,
            'min_gems_cent': 375,
            'max_gems_cent': 9125,
            'min_memory_tokens': tokens,
            'max_memory_tokens': 64000,
          },
      ],
    },
  ],
};

class _ModelTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  String selected = 'phone_model';
  int tokens = 8000;
  bool rejectWrites = false;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    Object? data;
    if (request.uri.path == '/api/v1/gem/model/list') {
      data = _catalogJson(selected: selected, tokens: tokens);
    } else if (request.uri.path == '/api/v1/gem/model/select') {
      if (!rejectWrites) {
        selected = body(request)['model_code'] as String;
      }
      data = {'selected_model_code': selected};
    } else if (request.uri.path == '/api/v1/user/memory-settings') {
      if (request.method == 'POST' && !rejectWrites) {
        tokens = body(request)['memory_tokens'] as int;
      }
      data = {
        'memory_tokens': tokens,
        'min_memory_tokens': 2000,
        'max_memory_tokens': 64000,
        if (request.uri.queryParameters['world_id']
            case final String worldId) ...{
          'world_id': worldId,
          'memory_used_tokens': 3000,
        },
      };
    } else {
      return LocalMockGenesisTransport.instance.send(request);
    }
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'err_no': rejectWrites && request.method == 'POST' ? 4004 : 0,
        'err_msg': 'Test result',
        'data': data,
      }),
    );
  }

  List<TransportRequest> matching(String path, [String method = 'GET']) =>
      requests
          .where((r) => r.uri.path == '/api/v1/$path' && r.method == method)
          .toList();

  Map<String, dynamic> body(TransportRequest request) =>
      jsonDecode(utf8.decode(request.bodyBytes!)) as Map<String, dynamic>;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

AppServices _services(GenesisApi api) {
  final platform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    return musicTestServices(api);
  } finally {
    debugDefaultTargetPlatformOverride = platform;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('phone catalogue preserves all server quotation fields', () async {
    final source = GemModelCatalog.fromJson(_catalogJson());
    final settings = MiniPhoneModelSettings()
      ..configure(worldId: 'W_PHONE', loader: () async => source);
    addTearDown(settings.dispose);
    expect(await settings.catalog(), same(source));
  });

  testWidgets('phone queries its business despite a warm World cache', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = _ModelTransport();
    final api = GenesisApi(
      useMock: false,
      apiClient: ApiClient(
        baseUrl: 'https://api.example/api/',
        transport: transport,
      ),
    );
    final services = _services(api);
    await services.sessionStore.saveUid('model-user');
    await services.sessionStore.saveAuthToken('model-token');
    final data = PhoneBackend().store();
    await tester.runAsync(() => data.ready);
    final phone = MiniPhoneSession(worldId: 'W_PHONE', data: data);
    addTearDown(phone.dispose);
    final worldCatalog = GemModelCatalog.fromJson(
      _catalogJson(title: 'World model'),
    );
    final worldCache = MemoryModelPageCache()..storeModelCatalog(worldCatalog);
    addTearDown(worldCache.dispose);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMiniPhone(
                context,
                worldId: 'W_PHONE',
                session: phone,
                modelCache: worldCache,
                initialScreen: MiniPhoneScreen.models,
              ),
              child: const Text('Open phone'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open phone'));
    await _settle(tester);
    final queries = transport.matching('gem/model/list');
    expect(queries, isNotEmpty);
    expect(
      queries.every(
        (r) => mapEquals(r.uri.queryParameters, {
          'world_id': 'W_PHONE',
          'biz': 'phone_dm',
        }),
      ),
      isTrue,
    );
    expect(find.text('Phone DM model'), findsOneWidget);
    expect(find.text('World model'), findsNothing);
    expect(worldCache.modelCatalog, same(worldCatalog));
    expect(
      phone.modelSettings.pageCache.memorySettings!.memoryUsedTokens,
      3000,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reject in [false, true]) {
    testWidgets(
      'phone uses LocationChat saves and ${reject ? 'rolls back failures' : 'refreshes confirmed changes'}',
      (tester) async {
        final collect = MiniPhoneCollectProbe();
        addTearDown(collect.dispose);
        final transport = _ModelTransport()..rejectWrites = reject;
        final api = GenesisApi(
          useMock: false,
          apiClient: ApiClient(
            baseUrl: 'https://api.example/api/',
            transport: transport,
          ),
        );
        final services = _services(api);
        await services.sessionStore.saveUid('model-user');
        await services.sessionStore.saveAuthToken('model-token');
        final settings = MiniPhoneModelSettings()
          ..configure(
            worldId: 'W_PHONE',
            loader: () =>
                api.v1.gem.models(worldId: 'W_PHONE', biz: 'phone_dm'),
          );
        addTearDown(settings.dispose);
        final analytics = MiniPhoneAnalytics(
          worldId: 'W_PHONE',
          enabled: () => true,
          generation: () => 0,
        )..beginOpen();
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              home: MiniPhoneModelSettingsPage(
                settings: settings,
                analytics: analytics,
                onBack: () {},
              ),
            ),
          ),
        );
        await _settle(tester);
        final memory = settings.pageCache.memorySettings!;
        expect(memory.memoryUsedTokens, 3000);
        expect(memory.minMemoryTokens, 2000);
        expect(
          transport.matching('user/memory-settings').single.uri.queryParameters,
          {'world_id': 'W_PHONE'},
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('gem-model-phone_pro')),
        );
        await tester.tap(find.byKey(const ValueKey('gem-model-phone_pro')));
        await _settle(tester);
        expect(
          transport.body(transport.matching('gem/model/select', 'POST').single),
          {'world_id': 'W_PHONE', 'model_code': 'phone_pro'},
        );
        final userInfo = await services.sessionStore.readUserInfo();
        expect(userInfo?['selected_model_code'], reject ? isNull : 'phone_pro');
        expect(
          settings.pageCache.modelCatalog!.selectedModelCode,
          reject ? 'phone_model' : 'phone_pro',
        );
        await tester.ensureVisible(find.byType(Slider));
        tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
        await tester.pump(const Duration(milliseconds: 500));
        await _settle(tester);
        expect(
          transport.body(
            transport.matching('user/memory-settings', 'POST').single,
          ),
          {'memory_tokens': 64000},
        );
        expect(
          settings.pageCache.memorySettings!.memoryTokens,
          reject ? 8000 : 64000,
        );
        expect(
          settings
              .pageCache
              .modelCatalog!
              .groups
              .first
              .models
              .first
              .minMemoryTokens,
          reject ? 8000 : 64000,
        );
        expect(
          transport
              .matching('gem/model/list')
              .every((r) => r.uri.queryParameters['biz'] == 'phone_dm'),
          isTrue,
        );
        if (!reject) expect(transport.matching('gem/model/list'), hasLength(2));
        final events = (await tester.runAsync(collect.take))!;
        if (reject) {
          expect(events, isEmpty);
        } else {
          expect(events.map((e) => e.action), [
            'mini_phone_model_change',
            'mini_phone_memory_change',
          ]);
          expect(
            events.every((e) => jsonDecode(e.extData)['scope'] == 'server'),
            isTrue,
          );
        }
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
        expect(transport.matching('gem/model/select', 'POST'), hasLength(1));
        expect(
          transport.matching('user/memory-settings', 'POST'),
          hasLength(1),
        );
      },
    );
  }
}
