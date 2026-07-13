import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/gateway_auth.dart';
import 'package:genesis_flutter_android/network/models/gem_purchase_report.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/v1/upload_api.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/platform/auth/auth_session.dart';
import 'package:genesis_flutter_android/platform/auth/backend_auth_coordinator.dart';
import 'package:genesis_flutter_android/platform/auth/identity_auth_service.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

class _FakeTransport implements HttpTransport {
  _FakeTransport({required this.handler});

  final FutureOr<TransportResponse> Function(TransportRequest request) handler;
  TransportRequest? lastRequest;
  final List<TransportRequest> requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    lastRequest = request;
    return handler(request);
  }
}

class _TestPlatformConfig implements PlatformConfig {
  const _TestPlatformConfig({this.apiBaseUrl = 'http://localhost:8080/api/'});

  @override
  final String apiBaseUrl;

  @override
  String get assetBaseUrl => GenesisApi.defaultAssetBaseUrl;
}

class _FakeGatewayKeyStore implements GatewayDeviceKeyStore {
  @override
  Future<String> publicKeyBase64Url() async => 'AQID';

  @override
  Future<void> reset() async {}

  @override
  Future<String> signCanonical(String canonical) async => 'fake-signature';
}

class _MemoryGatewayRegistrationStore implements GatewayRegistrationStore {
  String? keyId;

  @override
  Future<void> clearKeyId() async {
    keyId = null;
  }

  @override
  Future<String?> readKeyId() async => keyId;

  @override
  Future<void> saveKeyId(String keyId) async {
    this.keyId = keyId;
  }
}

GenesisApi _apiWith(
  _FakeTransport apiTransport,
  _FakeTransport healthTransport,
) {
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/',
    defaultHeaders: const {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    transport: apiTransport,
    responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
  );

  final healthClient = ApiClient(
    baseUrl: 'http://localhost:8080/',
    defaultHeaders: const {'accept': 'application/json'},
    transport: healthTransport,
    responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
  );

  final sessionStore = MemoryUserSessionStore();
  sessionStore.saveUid('u_1');
  return GenesisApi(
    apiClient: apiClient,
    healthClient: healthClient,
    deviceIdService: const _TestDeviceIdService(),
    sessionStore: sessionStore,
  );
}

void main() {
  test('AppConfig switches production and mock network environments', () {
    expect(const AppConfig().useMock, false);
    expect(const AppConfig(apiEnvironment: 'mock').useMock, true);
    expect(const AppConfig(apiEnvironment: 'production').useMock, false);
    expect(
      const AppConfig(apiEnvironment: 'production', useMock: true).useMock,
      true,
    );
  });

  test('AppConfig endpoint defaults follow build mode defaults', () {
    expect(const AppConfig().apiBaseUrl, GenesisApi.defaultApiBaseUrl);
    expect(
      const AppConfig().gatewayApiBaseUrl,
      GenesisApi.defaultGatewayApiBaseUrl,
    );
    expect(
      const AppConfig().chatroomHttpBaseUrl,
      GenesisApi.defaultChatroomHttpBaseUrl,
    );
    expect(
      const AppConfig().chatroomWsBaseUrl,
      GenesisApi.defaultChatroomWsBaseUrl,
    );
  });

  test('AppConfig provides default version check app id and channel', () {
    expect(const AppConfig().appId, 'aitown');
    expect(const AppConfig().appChannel, 'default');
  });

  test('AppConfig provides default agent control config', () {
    expect(const AppConfig().agentControlEnabled, false);
    expect(const AppConfig().agentControlPort, 17317);
    expect(const AppConfig().agentControlToken, '');
  });

  test('AppConfig copies agent control config', () {
    final config = const AppConfig().copyWith(
      agentControlEnabled: true,
      agentControlPort: 18080,
      agentControlToken: 'secret',
    );

    expect(config.agentControlEnabled, true);
    expect(config.agentControlPort, 18080);
    expect(config.agentControlToken, 'secret');
  });

  test('AppConfig provides default PostHog config', () {
    expect(
      const AppConfig().postHogProjectToken,
      AppConfig.defaultPostHogProjectToken,
    );
    expect(const AppConfig().postHogHost, AppConfig.defaultPostHogHost);
    expect(const AppConfig().postHogDebug, false);
  });

  test('resolveAssetUrl keeps predata default CDN images as remote URLs', () {
    expect(
      resolveAssetUrl('https://cdn-001.worldo.ai/predata/root_default.webp'),
      'https://cdn-001.worldo.ai/predata/root_default.webp',
    );
    expect(
      resolveAssetUrl('https://cdn-001.worldo.ai/predata/l1_default.webp'),
      'https://cdn-001.worldo.ai/predata/l1_default.webp',
    );
    expect(
      resolveAssetUrl('https://cdn-001.worldo.ai/predata/l2_default.webp'),
      'https://cdn-001.worldo.ai/predata/l2_default.webp',
    );
    expect(
      resolveAssetUrl(
        'https://cdn-001.worldo.ai/predata/location_default.webp',
      ),
      'https://cdn-001.worldo.ai/predata/location_default.webp',
    );
  });

  test(
    'v1 app version check posts documented body and parses response',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"err_no":0,"err_msg":"succ","data":{"need_upgrade":true,"force_upgrade":true,"latest_version_name":"1.1.0","latest_version_code":"10100","min_version_code":"10000","upgrade_type":"2","title":"发现新版本","content":"请升级","download_url":"https://example.com/app.apk","store_url":"https://apps.apple.com/app/id000000","package_size":"0","package_md5":"","can_ignore":false}}',
        ),
      );
      final api = _apiWith(
        apiTransport,
        _FakeTransport(
          handler: (_) => const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"status":"ok"}',
          ),
        ),
      );

      final response = await api.v1.app.versionCheck(
        appId: 'aitown',
        platform: 'ios',
        channel: 'appstore',
        versionName: '1.0.0',
        versionCode: 10000,
        deviceId: 'device_xxx',
        uid: 'u_4LA63V',
      );

      expect(apiTransport.lastRequest!.method, 'POST');
      expect(
        apiTransport.lastRequest!.uri.toString(),
        'http://localhost:8080/api/v1/app/version/check',
      );
      expect(jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!)), {
        'app_id': 'aitown',
        'platform': 'ios',
        'channel': 'appstore',
        'version_name': '1.0.0',
        'version_code': 10000,
        'device_id': 'device_xxx',
        'uid': 'u_4LA63V',
      });
      expect(response.shouldForceUpgrade, true);
      expect(response.latestVersionCode, 10100);
      expect(response.minVersionCode, 10000);
      expect(response.upgradeType, 2);
      expect(response.updateUrl, 'https://apps.apple.com/app/id000000');
    },
  );

  test(
    'v1 app version check throws ApiException for non-zero err_no',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":4004,"err_msg":"ErrorParamInvalid","data":{}}',
        ),
      );
      final api = _apiWith(
        apiTransport,
        _FakeTransport(
          handler: (_) => const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"status":"ok"}',
          ),
        ),
      );

      expect(
        () => api.v1.app.versionCheck(
          appId: 'aitown',
          platform: 'ios',
          channel: 'default',
          versionCode: 1,
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('v1 gem product and task lists parse their independent endpoints', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: request.uri.path.endsWith('/products')
            ? '{"err_no":0,"err_msg":"succ","data":{"list":[{"product_id":"gem_pack_500","apple_product_id":"com.worldo.gems.500","google_product_id":"worldo_gems_500","base_gems":500,"bonus_gems":50,"price_currency_code":"USD","price_amount":149,"can_purchase":true,"activity_type":"first_purchase_bonus","activity_ext":{"google_purchase_option_id":"500-gems-new","google_offer_id":"500-gems-new-discount"}}]}}'
            : '{"err_no":0,"err_msg":"succ","data":{"list":[{"group_code":"daily","group_title":"Daily","tasks":[{"task_code":"send_message","title":"Send a message (0/3)","description":"Send messages in a location chat today.","reward_gems":50,"reward_valid_days":30,"cycle_type":"daily","cycle_key":"today","progress":0,"target_count":3,"progress_text":"0/3","status":"in_progress","action_text":"Go"}]}]}}',
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final products = await api.v1.gem.products();
    final tasks = await api.v1.gem.tasks();

    expect(apiTransport.requests.map((request) => request.uri.path), [
      '/api/v1/gem/products',
      '/api/v1/gem/tasks',
    ]);
    expect(products.products.single.productId, 'gem_pack_500');
    expect(products.products.single.googlePurchaseOptionId, '500-gems-new');
    expect(products.products.single.googleOfferId, '500-gems-new-discount');
    expect(products.products.single.totalGems, 550);
    expect(products.products.single.tagText, 'First top-up');
    expect(tasks.groups.single.groupTitle, 'Daily');
    expect(tasks.groups.single.tasks.single.taskCode, 'send_message');
    expect(tasks.groups.single.tasks.single.cycleKey, 'today');
    expect(tasks.groups.single.tasks.single.actionText, 'Go');
  });

  test('v1 gem wallet parses the server balance', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"wallet":{"balance":980}}}',
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final wallet = await api.v1.gem.wallet();

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/gem/wallet');
    expect(wallet.balance, 980);
  });

  test('v1 gem task report and claim send only task_code', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: request.uri.path.endsWith('/report')
            ? '{"err_no":0,"err_msg":"succ","data":{"status":"claimable"}}'
            : '{"err_no":0,"err_msg":"succ","data":{"status":"claimed"}}',
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final reported = await api.v1.gem.reportTask('discord_follow');
    final claimed = await api.v1.gem.claimTask('discord_follow');

    expect(reported.status, 'claimable');
    expect(claimed.status, 'claimed');
    expect(apiTransport.requests.map((request) => request.uri.path), [
      '/api/v1/gem/task/report',
      '/api/v1/gem/task/claim',
    ]);
    for (final request in apiTransport.requests) {
      expect(jsonDecode(utf8.decode(request.bodyBytes!)), {
        'task_code': 'discord_follow',
      });
    }
  });

  test('v1 gem records parses ledger items and sends scene query', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"list":[{"ledger_id":"gl_1","amount":-20,"scene":"world_tick","reason_code":"world_tick","title":"World progress","subtitle":"#Thorn Haven","created_at":1783586400,"expires_at":0}],"total":1,"pn":1,"rn":20}}',
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final records = await api.v1.gem.records(scene: 'spent', pn: 1, rn: 20);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/gem/records');
    expect(apiTransport.lastRequest!.uri.queryParameters['scene'], 'spent');
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '1');
    expect(records.total, 1);
    expect(records.items.single.ledgerId, 'gl_1');
    expect(records.items.single.amount, -20);
    expect(records.items.single.title, 'World progress');
  });

  test('v1 gem purchase report posts the Google purchase payload', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"report_id":"gpr_1","order_id":"gpo_1","report_status":"verified","order_status":"granted","granted":true,"granted_gems":550,"wallet":{"balance":980}}}',
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final report = await api.v1.gem.reportPurchase(
      const GemPurchaseReportRequest(
        provider: 'google',
        productId: 'gem_pack_500',
        storeProductId: 'worldo_gems_500',
        transactionId: 'GPA.1',
        purchaseToken: 'purchase-token-1',
        requestId: 'pay_1',
      ),
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/gem/purchase/report');
    expect(jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!)), {
      'provider': 'google',
      'environment': 'unknown',
      'product_id': 'gem_pack_500',
      'store_product_id': 'worldo_gems_500',
      'transaction_id': 'GPA.1',
      'purchase_token': 'purchase-token-1',
      'request_id': 'pay_1',
    });
    expect(report.isGranted, isTrue);
    expect(report.grantedGems, 550);
    expect(report.walletBalance, 980);
  });

  test(
    'v1 gem wallet rejects a missing balance instead of using zero',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"wallet":{}}}',
        ),
      );
      final api = _apiWith(
        apiTransport,
        _FakeTransport(
          handler: (_) => const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"status":"ok"}',
          ),
        ),
      );

      await expectLater(api.v1.gem.wallet(), throwsA(isA<FormatException>()));
    },
  );

  test('bindDevice uses GET /v1/user/info', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"user":{"uid":"u_1","name":"n","avatar":"a"},"uuid":"4b74ec68-7abc-4cce-a223-e997e31dc811"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final user = await api.bindDevice(did: 'd1');

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/v1/user/info',
    );
    expect(user.uid, 'u_1');
  });

  test('v1 user info keeps UUID alongside user', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"user":{"uid":"u_1","name":"n"},"uuid":"4b74ec68-7abc-4cce-a223-e997e31dc811"}}',
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final response = await api.v1.user.info();

    expect(response['uuid'], '4b74ec68-7abc-4cce-a223-e997e31dc811');
    expect((response['user'] as Map).containsKey('uuid'), isFalse);
  });

  test('bindDevice does not persist guest uid when user info fails', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 500,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":500,"err_msg":"server error","data":{}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('guest_old');
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8080/api/',
      defaultHeaders: const {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      transport: apiTransport,
      responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
    );
    final healthClient = ApiClient(
      baseUrl: 'http://localhost:8080/',
      defaultHeaders: const {'accept': 'application/json'},
      transport: healthTransport,
      responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
    );
    final api = GenesisApi(
      apiClient: apiClient,
      healthClient: healthClient,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: sessionStore,
    );

    final user = await api.bindDevice(did: 'd1');

    expect(user.uid, isEmpty);
    expect(await sessionStore.readUid(), isNull);
  });

  test('ensureUid throws instead of generating guest uid', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 500,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":500,"err_msg":"server error","data":{}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );
    final sessionStore = MemoryUserSessionStore();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8080/api/',
      defaultHeaders: const {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      transport: apiTransport,
      responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
    );
    final healthClient = ApiClient(
      baseUrl: 'http://localhost:8080/',
      defaultHeaders: const {'accept': 'application/json'},
      transport: healthTransport,
      responseProcessor: (r) => ApiClient.defaultResponseProcessor(r),
    );
    final api = GenesisApi(
      apiClient: apiClient,
      healthClient: healthClient,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: sessionStore,
    );

    expect(api.ensureUid(), throwsA(isA<ApiException>()));
    expect(await sessionStore.readUid(), isNull);
  });

  test('updateUserPosition only posts player scene', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path == '/api/session/set-player-scene') {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{"ok":true}}',
          );
        }
        return TransportResponse(
          statusCode: 404,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'err_no': 404,
            'err_msg': 'unexpected ${request.uri.path}',
            'data': <String, Object?>{},
          }),
        );
      },
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final result = await api.updateUserPosition(
      wid: 'w_1',
      locationId: 'loc_1',
    );

    expect(result, 'ok');
    expect(apiTransport.requests, hasLength(1));
    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/session/set-player-scene');
    expect(jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!)), {
      'location_id': 'loc_1',
    });
  });

  test(
    'v1 err_no 10001 triggers session expired callback with fixed message',
    () async {
      final expired = Completer<String>();
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"err_no":10001,"err_msg":"Your account was logged in elsewhere.","data":{}}',
        ),
      );
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: MemoryUserSessionStore(),
        onSessionExpired: (message) async {
          if (!expired.isCompleted) expired.complete(message);
        },
      );

      await expectLater(
        api.v1.user.info(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', 10001)
              .having(
                (error) => error.message,
                'message',
                'Your account is logged in on another device.',
              ),
        ),
      );
      expect(
        await expired.future,
        'Your account is logged in on another device.',
      );
      expect(apiTransport.lastRequest!.uri.path, '/api/v1/user/info');
    },
  );

  test('v1 err_no 1404 triggers page not found callback', () async {
    final notFound = Completer<String>();
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":1404,"err_msg":"missing","data":{}}',
      ),
    );
    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: MemoryUserSessionStore(),
      onPageNotFound: (message) async {
        if (!notFound.isCompleted) notFound.complete(message);
      },
    );

    await expectLater(
      api.v1.user.info(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 1404)
            .having((error) => error.message, 'message', 'Page not found.'),
      ),
    );
    expect(await notFound.future, 'Page not found.');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/user/info');
  });

  test('HTTP status 1404 triggers page not found callback', () async {
    final notFound = Completer<String>();
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 1404,
        headers: {'content-type': 'application/json'},
        body: '{"error":"missing"}',
      ),
    );
    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: MemoryUserSessionStore(),
      onPageNotFound: (message) async {
        if (!notFound.isCompleted) notFound.complete(message);
      },
    );

    await expectLater(
      api.v1.user.info(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 1404)
            .having((error) => error.message, 'message', 'Page not found.'),
      ),
    );
    expect(await notFound.future, 'Page not found.');
  });

  test('getOrigins uses GET /v1/origin/list for default category', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.getOrigins(category: 'For you', limit: 20, offset: 0);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/list');
    expect(apiTransport.lastRequest!.uri.queryParameters['scene'], 'foryou');
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '1');
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
    expect(apiTransport.lastRequest!.uri.queryParameters['tag'], isNull);
    expect(apiTransport.lastRequest!.uri.queryParameters['tag_name'], isNull);
  });

  test('getOrigins maps non-default category to scene tag', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.getOrigins(category: 'Billionare', limit: 20, offset: 0);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/list');
    expect(apiTransport.lastRequest!.uri.queryParameters['scene'], 'tag');
    expect(apiTransport.lastRequest!.uri.queryParameters['tag'], 'Billionare');
    expect(apiTransport.lastRequest!.uri.queryParameters['tag_name'], isNull);
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
  });

  test('profile list facades use Apifox origin and world list endpoints', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/v1/origin/list')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"list":[{"info":{"origin_id":"o_1","origin_name":"Origin One","owner_name":"Origin Owner","brief":"origin brief","cover":"","tags":["tag"],"created_at":1716000000},"stats":{"copy_cnt":2,"connect_cnt":3}}],"total":1}}',
          );
        }
        if (request.uri.path.endsWith('/v1/world/list')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"list":[{"info":{"world_id":"w_1","world_name":"World One","cover":"","created_at":1716000000},"stats":{"tick_cnt":4,"player_cnt":5}}],"total":1}}',
          );
        }
        return const TransportResponse(
          statusCode: 404,
          headers: {'content-type': 'application/json'},
          body: '{"error":"unexpected path"}',
        );
      },
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final origins = await api.getMyLaunchedOrigins(
      uid: 'u_2',
      scene: 'mine',
      limit: 10,
      offset: 10,
    );
    final worlds = await api.getMyWorlds(
      uid: 'u_2',
      scene: 'mine',
      limit: 10,
      offset: 10,
    );
    await api.getMyLaunchedOrigins(
      uid: 'u_2',
      scene: 'uid',
      limit: 10,
      offset: 0,
    );
    await api.getMyWorlds(uid: 'u_2', scene: 'uid', limit: 10, offset: 0);

    expect(origins.data.single.oid, 'o_1');
    expect(origins.data.single.originator, 'Origin Owner');
    expect(worlds.single.wid, 'w_1');
    expect(apiTransport.requests[0].uri.path, '/api/v1/origin/list');
    expect(apiTransport.requests[0].uri.queryParameters['scene'], 'mine');
    expect(
      apiTransport.requests[0].uri.queryParameters.containsKey('owner_uid'),
      false,
    );
    expect(
      apiTransport.requests[0].uri.queryParameters.containsKey('uid'),
      false,
    );
    expect(apiTransport.requests[0].uri.queryParameters['pn'], '2');
    expect(apiTransport.requests[0].uri.queryParameters['rn'], '10');
    expect(apiTransport.requests[1].uri.path, '/api/v1/world/list');
    expect(apiTransport.requests[1].uri.queryParameters['scene'], 'mine');
    expect(
      apiTransport.requests[1].uri.queryParameters.containsKey('owner_uid'),
      false,
    );
    expect(
      apiTransport.requests[1].uri.queryParameters.containsKey('uid'),
      false,
    );
    expect(apiTransport.requests[1].uri.queryParameters['pn'], '2');
    expect(apiTransport.requests[1].uri.queryParameters['rn'], '10');
    expect(apiTransport.requests[2].uri.path, '/api/v1/origin/list');
    expect(apiTransport.requests[2].uri.queryParameters['scene'], 'uid');
    expect(apiTransport.requests[2].uri.queryParameters['uid'], 'u_2');
    expect(
      apiTransport.requests[2].uri.queryParameters.containsKey('owner_uid'),
      false,
    );
    expect(apiTransport.requests[3].uri.path, '/api/v1/world/list');
    expect(apiTransport.requests[3].uri.queryParameters['scene'], 'uid');
    expect(apiTransport.requests[3].uri.queryParameters['uid'], 'u_2');
    expect(
      apiTransport.requests[3].uri.queryParameters.containsKey('owner_uid'),
      false,
    );
  });

  test('getOrigin maps detail preview fields from v1 detail', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {
              'origin_id': 'o_1',
              'origin_name': 'Origin One',
              'origin_version': '1',
              'owner_uid': 'u_1',
              'owner_name': 'Tester',
              'brief': 'Brief shown in World View.',
              'setting': 'Internal setting text.',
              'events': const <Object?>[],
              'tags': const <Object?>[],
              'metric': const <String, Object?>{'unit': '%'},
              'created_at': 1716000000,
              'started_at': 'Day 1',
              'tick_duration_days': 30,
              'cover': '',
              'map_url': '',
              'status': 10,
            },
            'stats': const <String, Object?>{},
            'characters': const <Object?>[],
            'locations': const [
              {
                'location_id': 'loc_1',
                'location_name': 'Gate',
                'location_description': 'Gate fallback description.',
                'location_paragraph': 'Gate launch paragraph.',
              },
            ],
            'ticks': const [
              {
                'tick_no': 1,
                'created_at': 1716000000,
                'tick_result': {
                  'current_time': 'Day 1, 08:30',
                  'narrator': 'Narrator from origin tick result.',
                  'paragraphs': <Object?>[],
                },
              },
            ],
          },
        }),
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final origin = await api.getOrigin('o_1');

    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/detail');
    expect(apiTransport.requests, hasLength(1));
    expect(apiTransport.lastRequest!.uri.queryParameters['origin_id'], 'o_1');
    expect(origin.worldView, 'Brief shown in World View.');
    expect(origin.worldView, isNot('Internal setting text.'));
    expect(origin.ticks.single['tick_result'], isA<Map>());
    expect(
      (origin.ticks.single['tick_result'] as Map)['narrator'],
      'Narrator from origin tick result.',
    );
    expect(
      (origin.ticks.single['tick_result'] as Map)['current_time'],
      'Day 1, 08:30',
    );
    expect(origin.metric['unit'], '%');
    expect(origin.locations.single.locationParagraph, 'Gate launch paragraph.');
  });

  test('getOriginInfo uses lightweight origin info contract', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {
              'origin_id': 'o_info_1',
              'origin_name': 'Origin Info',
              'origin_version': '2',
              'owner_uid': 'u_1',
              'owner_name': 'Tester',
              'brief': 'Lightweight brief.',
              'tags': ['light'],
              'created_at': 1716000000,
              'cover': const <String, Object?>{
                'sm_url': 'https://cdn.example.com/origin_400.webp',
                'xl_url': 'https://cdn.example.com/origin_800.webp',
                'object_key': 'uploads/origin_800.webp',
              },
              'map_url': 'https://cdn.example.com/map.png',
              'status': 10,
            },
            'stats': {
              'copy_cnt': 3,
              'discuss_cnt': 4,
              'character_cnt': 5,
              'connect_cnt': 6,
              'location_cnt': 7,
              'max_tick_cnt': 8,
            },
          },
        }),
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final origin = await api.getOriginInfo('o_info_1');

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/info');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['origin_id'],
      'o_info_1',
    );
    expect(origin.oid, 'o_info_1');
    expect(origin.name, 'Origin Info');
    expect(origin.worldView, 'Lightweight brief.');
    expect(origin.copyCount, 3);
    expect(origin.discussCount, 4);
    expect(origin.interactCount, 6);
    expect(origin.characterCount, 5);
    expect(origin.characters, isEmpty);
    expect(origin.allLocations, isEmpty);
    expect(origin.ticks, isEmpty);
  });

  test('v1 origin forEdit uses Apifox query and flat edit response', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'origin_id': 'o_edit_1',
            'origin_name': 'Editable Origin',
            'brief': 'Editable public view.',
            'setting': 'Editable rules.',
            'events': ['The archive opens.'],
            'tags': ['archive'],
            'metric': const <String, Object?>{
              'label': 'Influence',
              'label_note': 'Tracks archive trust.',
            },
            'started_at': 'Day 1',
            'tick_duration_time': '30 days',
            'cover': 'cover.png',
            'map_url': 'map.png',
            'characters': const <Object?>[],
            'locations': const <Object?>[],
          },
        }),
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final edit = await api.v1.origin.forEdit(originId: 'o_edit_1');

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/foredit');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['origin_id'],
      'o_edit_1',
    );
    expect(edit['origin_id'], 'o_edit_1');
    expect(edit['tick_duration_time'], '30 days');
    expect((edit['metric'] as Map)['label_note'], 'Tracks archive trust.');
    expect(edit['stats'], isNull);
    expect(edit['ticks'], isNull);
  });

  test('createOrigin posts latest Apifox origin create body', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {'origin_id': 'o_created_1'},
            'stats': const <String, Object?>{},
            'characters': const <Object?>[],
            'locations': const <Object?>[],
            'ticks': const <Object?>[],
          },
        }),
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.createOrigin(
      payload: {
        'name': 'Crystal City',
        'origin_version': 'draft-2',
        'world_view': 'A public world view.',
        'world_setting': 'Hidden rules.',
        'event_list': const [
          {'content': 'The gate opens.'},
        ],
        'tags': const ['city'],
        'metric': const <String, Object?>{
          'label': 'Influence',
          'label_note': 'Tracks public influence.',
        },
        'started_at': 'Day 1',
        'tick_duration_days': 30,
        'cover': 'cover.png',
        'map_url': 'map.png',
        'character_list': const [
          {
            'char_id': 'char_tmp_1',
            'name': 'Ari',
            'identity': 'Guide',
            'tagline': 'Calm',
            'description': 'Keeps the route.',
            'goal': 'Open the city.',
            'avatar': 'ari.png',
          },
        ],
        'location_list': const [
          {
            'location_id': 'loc_tmp_1',
            'location_pid': '',
            'name': 'Gate',
            'description': 'Entry point.',
            'image': 'gate.png',
            'initial_character_ids': ['char_tmp_1'],
          },
        ],
      },
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/create');
    final body =
        jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!))
            as Map<String, dynamic>;
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('world_view'), isFalse);
    expect(body.containsKey('world_setting'), isFalse);
    expect(body.containsKey('character_list'), isFalse);
    expect(body.containsKey('location_list'), isFalse);
    expect(body.containsKey('event_list'), isFalse);
    expect(body['origin_name'], 'Crystal City');
    expect(body['origin_version'], 'draft-2');
    expect(body['brief'], 'A public world view.');
    expect(body['setting'], 'Hidden rules.');
    expect(body['events'], ['The gate opens.']);
    expect(body['tags'], ['city']);
    expect(body['metric'], {
      'label': 'Influence',
      'label_note': 'Tracks public influence.',
    });
    expect(body['started_at'], 'Day 1');
    expect(body.containsKey('tick_duration_days'), isFalse);
    expect(body['tick_duration_time'], '30 days');
    expect(body['cover'], 'cover.png');
    expect(body.containsKey('map_url'), isFalse);

    final characters = body['characters'] as List;
    expect(characters, hasLength(1));
    expect(characters.single['char_id'], 'char_tmp_1');
    expect(characters.single['personality'], 'Calm');
    expect(characters.single['bio'], 'Keeps the route.');
    expect(characters.single['initial_location_id'], 'loc_tmp_1');

    final locations = body['locations'] as List;
    expect(locations, hasLength(1));
    expect(locations.single['location_id'], 'loc_tmp_1');
    expect(locations.single.containsKey('location_pid'), isFalse);
    expect(locations.single['location_name'], 'Gate');
    expect(locations.single['location_description'], 'Entry point.');
  });

  test('updateOrigin posts latest Apifox origin update body', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {'origin_id': 'o_update_1'},
            'stats': const <String, Object?>{},
            'characters': const <Object?>[],
            'locations': const <Object?>[],
            'ticks': const <Object?>[],
          },
        }),
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.updateOrigin(
      oid: 'o_update_1',
      payload: {
        'origin_id': 'o_update_1',
        'origin_version': 'draft-3',
        'name': 'Updated Origin',
        'world_view': 'Updated brief.',
        'world_setting': 'Updated setting.',
        'event_list': const [
          {'content': 'The map changes.'},
        ],
        'tags': const ['updated'],
        'metric': const <String, Object?>{
          'mode': 'qualitative',
          'label': 'Progress',
          'label_note': 'Tracks story progress.',
          'unit': '%',
          'range': [0, 100],
          'default': 0,
        },
        'started_at': 'Day 2',
        'tick_duration_days': 7,
        'cover': 'updated-cover.png',
        'map_url': 'updated-map.png',
        'character_list': const [
          {
            'char_id': 'char_keep',
            'name': 'Mira',
            'identity': 'Archivist',
            'personality': 'Patient',
            'bio': 'Keeps the records.',
            'goal': 'Find the first page.',
            'avatar': 'mira.png',
            'initial_location_id': 'loc_keep',
          },
        ],
        'location_list': const [
          {
            'location_id': 'loc_keep',
            'name': 'Archive',
            'description': 'A quiet tower.',
            'image': 'archive.png',
          },
        ],
        'deleted_char_ids': const ['char_removed'],
        'deleted_location_ids': const ['loc_removed'],
        'update_notes': 'Adjusted archive.',
      },
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/update');
    final body =
        jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!))
            as Map<String, dynamic>;
    expect(body.containsKey('oid'), isFalse);
    expect(body.containsKey('name'), isFalse);
    expect(body.containsKey('world_view'), isFalse);
    expect(body.containsKey('world_setting'), isFalse);
    expect(body.containsKey('character_list'), isFalse);
    expect(body.containsKey('location_list'), isFalse);
    expect(body.containsKey('event_list'), isFalse);
    expect(body['origin_id'], 'o_update_1');
    expect(body['origin_version'], 'draft-3');
    expect(body['origin_name'], 'Updated Origin');
    expect(body['brief'], 'Updated brief.');
    expect(body['setting'], 'Updated setting.');
    expect(body['events'], ['The map changes.']);
    expect(body['tags'], ['updated']);
    expect(body['metric'], {
      'mode': 'qualitative',
      'label': 'Progress',
      'label_note': 'Tracks story progress.',
      'unit': '%',
      'range': [0, 100],
      'default': 0,
    });
    final metric = body['metric'] as Map;
    expect(metric.containsKey('progress_metric'), isFalse);
    expect(metric.containsKey('starting_value'), isFalse);
    expect(metric.containsKey('start_time'), isFalse);
    expect(metric.containsKey('time_per_progress'), isFalse);
    expect(body['started_at'], 'Day 2');
    expect(body.containsKey('tick_duration_days'), isFalse);
    expect(body['tick_duration_time'], '7 days');
    expect(body['cover'], 'updated-cover.png');
    expect(body.containsKey('map_url'), isFalse);
    expect(body['update_notes'], 'Adjusted archive.');
    expect(body['deleted_char_ids'], ['char_removed']);
    expect(body['deleted_location_ids'], ['loc_removed']);

    final characters = body['characters'] as List;
    expect(characters.single['char_id'], 'char_keep');
    expect(characters.single['personality'], 'Patient');
    expect(characters.single['bio'], 'Keeps the records.');
    expect(characters.single['initial_location_id'], 'loc_keep');

    final locations = body['locations'] as List;
    expect(locations.single['location_id'], 'loc_keep');
    expect(locations.single.containsKey('location_pid'), isFalse);
    expect(locations.single['location_name'], 'Archive');
    expect(locations.single['location_description'], 'A quiet tower.');
  });

  test('getWorld maps tick_result narrator paragraphs from detail', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {
              'world_id': 'w_1',
              'world_name': 'World One',
              'origin_id': 'o_1',
              'owner_uid': 'u_1',
              'owner_name': 'Tester',
              'metric': const <String, Object?>{
                'mode': 'qualitative',
                'label': 'Goal Progress',
                'unit': '%',
                'range': <int>[0, 100],
                'default': 0,
              },
              'created_at': '2026-05-01T00:00:00Z',
              'updated_at': '2026-05-02T00:00:00Z',
              'status': 1,
            },
            'stats': {
              'tick_cnt': 1,
              'connect_cnt': 0,
              'character_cnt': 0,
              'player_cnt': 0,
            },
            'characters': const <Object?>[],
            'relation_status': 'owner',
            'locations': [
              {
                'location_id': 'loc_1',
                'location_name': 'Gate',
                'location_summary': '',
                'location_description': 'Gate fallback description.',
              },
            ],
            'ticks': [
              {
                'tick_no': 1,
                'created_at': '2026-05-02T00:00:00Z',
                'tick_result': {
                  'narrator': 'Narrator from tick result.',
                  'paragraphs': [
                    {
                      'location_id': 'loc_1',
                      'text': 'Location paragraph text.',
                      'character_deltas': [
                        {'name': 'Iris Vale', 'delta': '+3 focus'},
                      ],
                    },
                  ],
                },
              },
            ],
          },
        }),
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final world = await api.getWorld('w_1');
    final location = world.locations
        .where((item) => item['location_id'] == 'loc_1')
        .single;
    final tickResult = world.ticks.single['tick_result'] as Map;
    final paragraph = (tickResult['paragraphs'] as List).single as Map;

    expect(apiTransport.lastRequest!.uri.path, '/api/v1/world/detail');
    expect(apiTransport.lastRequest!.uri.queryParameters['world_id'], 'w_1');
    expect(location['location_summary'], '');
    expect(location['location_description'], 'Gate fallback description.');
    expect(world.relationStatus, 'owner');
    expect(world.metric['label'], 'Goal Progress');
    expect(world.latestNarrator, 'Narrator from tick result.');
    expect(tickResult['narrator'], 'Narrator from tick result.');
    expect(paragraph['location_id'], 'loc_1');
    expect(paragraph['text'], 'Location paragraph text.');
    expect((paragraph['character_deltas'] as List).single, {
      'name': 'Iris Vale',
      'delta': '+3 focus',
    });
  });

  test('getWorldInfo uses lightweight world info contract', () async {
    final apiTransport = _FakeTransport(
      handler: (request) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {
              'world_id': 'w_info_1',
              'world_name': 'World Info',
              'origin_id': 'o_info_1',
              'origin_version': '3',
              'current_time': 'Day 7, 19:10',
              'owner_uid': 'u_1',
              'owner_name': 'Tester',
              'brief': 'World brief.',
              'tags': ['light'],
              'created_at': 1716000000,
              'cover': const <String, Object?>{
                'sm_url': 'https://cdn.example.com/world_400.webp',
                'xl_url': 'https://cdn.example.com/world_800.webp',
                'object_key': 'uploads/world_800.webp',
              },
              'map_url': 'https://cdn.example.com/world-map.png',
              'status': 10,
            },
            'stats': {
              'character_cnt': 2,
              'connect_cnt': 3,
              'location_cnt': 4,
              'tick_cnt': 5,
              'player_cnt': 6,
            },
          },
        }),
      ),
    );
    final api = _apiWith(
      apiTransport,
      _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      ),
    );

    final world = await api.getWorldInfo('w_info_1');

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/world/info');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['world_id'],
      'w_info_1',
    );
    expect(world.worldId, 'w_info_1');
    expect(world.name, 'World Info');
    expect(world.ownerName, 'Tester');
    expect(world.brief, 'World brief.');
    expect(world.cover, 'https://cdn.example.com/world_800.webp');
    expect(world.origin.oid, 'o_info_1');
    expect(world.currentTime, 'Day 7, 19:10');
    expect(world.tickCount, 5);
    expect(world.connectCount, 3);
    expect(world.characterCount, 2);
    expect(world.playerCount, 6);
    expect(world.relationStatus, '');
    expect(world.characters, isEmpty);
    expect(world.locations, isEmpty);
    expect(world.ticks, isEmpty);
  });

  test('getWorld treats missing detail metric as empty map', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'info': {
              'world_id': 'w_1',
              'world_name': 'World One',
              'origin_id': 'o_1',
              'owner_uid': 'u_1',
              'owner_name': 'Tester',
              'created_at': 1716000000,
              'status': 10,
            },
            'stats': const <String, Object?>{},
            'relation_status': 'anonymous',
            'characters': const <Object?>[],
            'locations': const <Object?>[],
            'ticks': const <Object?>[],
          },
        }),
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final world = await api.getWorld('w_1');

    expect(world.metric, isEmpty);
  });

  test(
    'getWorld accepts Apifox image objects except location map url',
    () async {
      Map<String, Object?> image(String name) => {
        'sm_url': 'https://cdn.example.com/${name}_400_300.webp',
        'xl_url': 'https://cdn.example.com/${name}_800_600.webp',
        'object_key': 'uploads/${name}_800_600.webp',
      };

      final apiTransport = _FakeTransport(
        handler: (_) => TransportResponse(
          statusCode: 200,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'err_no': 0,
            'err_msg': 'succ',
            'data': {
              'info': {
                'world_id': 'w_1',
                'world_name': 'World One',
                'origin_id': 'o_1',
                'owner_uid': 'u_1',
                'owner_name': 'Tester',
                'brief': 'Brief.',
                'setting': 'Setting.',
                'events': const <Object?>[],
                'tags': const <Object?>[],
                'metric': const <String, Object?>{},
                'created_at': 1716000000,
                'cover': image('world_cover'),
                'map_url': 'https://cdn.example.com/location_map.png',
                'status': 10,
              },
              'stats': const <String, Object?>{},
              'relation_status': 'owner',
              'characters': [
                {
                  'char_id': 'c_1',
                  'type': 'player',
                  'player_uid': 'u_1',
                  'player_username': 'Tester',
                  'player_deleted': 0,
                  'name': 'Iris',
                  'avatar': image('avatar'),
                  'location_id': 'loc_1',
                },
              ],
              'locations': [
                {
                  'location_id': 'loc_1',
                  'location_name': 'Gate',
                  'image': image('location'),
                  'map_url': 'https://cdn.example.com/location_map.png',
                },
              ],
              'ticks': const <Object?>[],
            },
          }),
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      final world = await api.getWorld('w_1');
      final character = world.characters.single;
      final mapCharacter =
          world.characterPositions.single['character'] as Map<String, dynamic>;
      final location = world.locations.single;

      expect(
        world.origin.mapImage,
        'https://cdn.example.com/world_cover_800_600.webp',
      );
      expect(
        character['avatar'],
        'https://cdn.example.com/avatar_800_600.webp',
      );
      expect(mapCharacter['player_uid'], 'u_1');
      expect(mapCharacter['player_username'], 'Tester');
      expect(mapCharacter['player_deleted'], false);
      expect(location['icon'], 'https://cdn.example.com/location_800_600.webp');
      expect(location['map_url'], 'https://cdn.example.com/location_map.png');
    },
  );

  test('launchWorld uses POST /worlds/launch with new body', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"ok":true,"wid":"wid_1","wid_str":"W_1"}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.launchWorld(
      originId: 123,
      ownerUid: 'u_1',
      worldviewId: 'wv_1',
      worldName: 'World 1',
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/worlds/launch',
    );

    final body = utf8.decode(
      apiTransport.lastRequest!.bodyBytes ?? const <int>[],
    );
    expect(jsonDecode(body), {
      'user_id': 'u_1',
      'worldview_id': 'wv_1',
      'world_name': 'World 1',
    });
  });

  test('sendMessage uses POST /points/:point_id/messages/enqueue', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"ok":true,"user_message":{"id":"m_1"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.sendMessage(
      wid: 'wid_1',
      uid: 'u_1',
      pointId: 'pt_9',
      locationId: 'loc_3',
      content: 'Hello',
    );

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(
      apiTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/api/points/pt_9/messages/enqueue',
    );

    final body = utf8.decode(
      apiTransport.lastRequest!.bodyBytes ?? const <int>[],
    );
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    expect(decoded['user_id'], 'u_1');
    expect(decoded['wid'], 'wid_1');
    expect(decoded['location_id'], 'loc_3');
    expect(decoded['text'], 'Hello');
    expect(decoded['player_id'], 'player1');
  });

  test('health uses unsigned Gateway heartbeat', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"data":{}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final ok = await api.health();
    expect(ok, true);
    expect(
      healthTransport.lastRequest!.uri.toString(),
      'http://localhost:8080/v1/heartbeat',
    );
  });

  test('search uses GET /search with query', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"origins":[],"worlds":[],"users":[]}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.search(query: 'ori', limit: 10);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/search');
    expect(apiTransport.lastRequest!.uri.queryParameters['q'], 'ori');
    expect(apiTransport.lastRequest!.uri.queryParameters['limit'], '10');
  });

  test(
    'default v1 client keeps business requests on configurable API base URL',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
        ),
      );

      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        platformConfig: const _TestPlatformConfig(
          apiBaseUrl: 'https://example.test/api/',
        ),
        gatewayApiBaseUrl: 'https://gateway.example.test/apix/',
      );
      await api.getOrigins();

      expect(
        apiTransport.lastRequest!.uri.toString(),
        'https://example.test/api/v1/origin/list?scene=foryou&pn=1&rn=20',
      );
    },
  );

  test('default v1 client targets dev API base URL', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );

    final api = GenesisApi(transport: apiTransport, useMock: false);
    await api.getOrigins();

    expect(
      apiTransport.lastRequest!.uri.toString(),
      '${GenesisApi.defaultApiBaseUrl}'
      'v1/origin/list?scene=foryou&pn=1&rn=20',
    );
  });

  test(
    'default v1 business requests are signed when Gateway auth is enabled',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
        ),
      );
      final authTransport = _FakeTransport(handler: _gatewayAuthResponse);
      final interceptor = GatewayRequestInterceptor(
        coordinator: GatewayAuthCoordinator(
          gatewayBaseUrl: 'https://gateway.example.test/apix/',
          appHeaderProvider: () async => const {
            'app-id': 'hashed-app-id',
            'app-platform': 'ios',
            'app-version': '1.2.3',
          },
          deviceIdService: const _TestDeviceIdService(),
          keyStore: _FakeGatewayKeyStore(),
          registrationStore: _MemoryGatewayRegistrationStore(),
          transport: authTransport,
        ),
      );

      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        gatewayRequestInterceptor: interceptor,
      );
      await api.getOrigins();

      final request = apiTransport.lastRequest!;
      expect(request.uri.path, '/api/v1/origin/list');
      expect(request.headers['X-App-ID'], 'hashed-app-id');
      expect(request.headers['X-Platform'], 'ios');
      expect(request.headers['X-Device-ID'], 'test-device-id');
      expect(request.headers['X-App-Version'], '1.2.3');
      expect(request.headers['X-Key-ID'], 'key-registered');
      expect(request.headers['X-Signature-Alg'], gatewaySignatureAlgorithm);
      expect(request.headers['X-Signature'], 'fake-signature');
      expect(request.headers['X-Body-SHA256'], gatewayBodySha256(null));
      expect(request.headers.containsKey('X-Timestamp'), isTrue);
      expect(request.headers.containsKey('X-Nonce'), isTrue);
      expect(
        authTransport.requests.map((request) => request.uri.path),
        containsAllInOrder([
          '/apix/v1/app/device/challenge',
          '/apix/v1/app/device/register',
          '/apix/v1/time',
        ]),
      );
    },
  );

  test(
    'chatroom API HTTP requests are signed when Gateway auth is enabled',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path == '/aitown-chat/api/messages') {
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"err_no":0,"err_msg":"succ","data":{"messages":[],"has_more":false,"newest_message_id":0}}',
            );
          }
          return const TransportResponse(
            statusCode: 404,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":404,"err_msg":"not_found","data":{}}',
          );
        },
      );
      final authTransport = _FakeTransport(handler: _gatewayAuthResponse);
      final interceptor = GatewayRequestInterceptor(
        coordinator: GatewayAuthCoordinator(
          gatewayBaseUrl: 'https://gateway.example.test/apix/',
          appHeaderProvider: () async => const {
            'app-id': 'hashed-app-id',
            'app-platform': 'android',
            'app-version': '1.2.3',
          },
          deviceIdService: const _TestDeviceIdService(),
          keyStore: _FakeGatewayKeyStore(),
          registrationStore: _MemoryGatewayRegistrationStore(),
          transport: authTransport,
        ),
      );

      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        chatroomHttpBaseUrl: 'https://chat.example.test/',
        gatewayRequestInterceptor: interceptor,
      );
      await api.chatroomHttp.getMessages(
        worldId: 'world-1',
        locationId: 'loc-1',
      );

      final request = apiTransport.lastRequest!;
      expect(request.uri.path, '/aitown-chat/api/messages');
      expect(request.headers['X-App-ID'], 'hashed-app-id');
      expect(request.headers['X-Platform'], 'android');
      expect(request.headers['X-Device-ID'], 'test-device-id');
      expect(request.headers['X-App-Version'], '1.2.3');
      expect(request.headers['X-Key-ID'], 'key-registered');
      expect(request.headers['X-Signature-Alg'], gatewaySignatureAlgorithm);
      expect(request.headers['X-Signature'], 'fake-signature');
      expect(request.headers['X-Body-SHA256'], gatewayBodySha256(null));
      expect(request.headers.containsKey('X-Timestamp'), isTrue);
      expect(request.headers.containsKey('X-Nonce'), isTrue);
    },
  );

  test('default client injects user agent and authorization headers', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );
    final sessionStore = MemoryUserSessionStore();
    await sessionStore.saveUid('u_1');
    await sessionStore.saveAuthToken('backend-token');

    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: sessionStore,
      appHeaderProvider: () async => const {
        'user-agent': 'Android 15',
        'app-id': 'legacy-app-id',
        'app-version': '0.1.0',
        'app-platform': 'android',
        'device-id': 'legacy-device-id',
      },
    );
    await api.getOrigins();

    expect(apiTransport.lastRequest!.headers['user-agent'], 'Android 15');
    expect(apiTransport.lastRequest!.headers.containsKey('app-id'), isFalse);
    expect(
      apiTransport.lastRequest!.headers.containsKey('app-version'),
      isFalse,
    );
    expect(
      apiTransport.lastRequest!.headers.containsKey('app-platform'),
      isFalse,
    );
    expect(apiTransport.lastRequest!.headers.containsKey('device-id'), isFalse);
    expect(
      apiTransport.lastRequest!.headers.containsKey('x-platform'),
      isFalse,
    );
    expect(
      apiTransport.lastRequest!.headers.containsKey('x-device-id'),
      isFalse,
    );
    expect(apiTransport.lastRequest!.headers.containsKey('x-user-id'), isFalse);
    expect(
      apiTransport.lastRequest!.headers['authorization'],
      'Bearer backend-token',
    );
  });

  test(
    'loginWithGoogle stores backend token for later default auth header',
    () async {
      late final MemoryUserSessionStore sessionStore;
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/oauth/google')) {
            final body =
                jsonDecode(utf8.decode(request.bodyBytes ?? const [])) as Map;
            expect(body['id_token'], 'google-token');
            expect(body['name'], 'Neo');
            expect(body['avatar'], 'https://cdn/neo.png');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"err_no":0,"err_msg":"succ","data":{"token":"backend-token","user":{"uid":"u_2","name":"Neo"}}}',
            );
          }
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
          );
        },
      );
      sessionStore = MemoryUserSessionStore();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
      );

      await api.loginWithGoogle(
        idToken: 'google-token',
        name: 'Neo',
        avatar: 'https://cdn/neo.png',
      );
      expect(await sessionStore.readUid(), 'u_2');
      expect(await sessionStore.readAuthToken(), 'backend-token');
      expect(await sessionStore.readUserInfo(), containsPair('uid', 'u_2'));
      expect(await sessionStore.readUserInfo(), containsPair('name', 'Neo'));

      await api.getOrigins();
      expect(
        apiTransport.lastRequest!.headers['authorization'],
        'Bearer backend-token',
      );
    },
  );

  test('loginWithIdentity posts Apple tokens and stores backend token', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/v1/user/oauth/apple')) {
          final body =
              jsonDecode(utf8.decode(request.bodyBytes ?? const [])) as Map;
          expect(body['id_token'], 'apple-token');
          expect(body.containsKey('firebase_id_token'), isFalse);
          expect(body['name'], 'Ava');
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"token":"apple-backend-token","user":{"uid":"apple_uid","name":"Ava"}}}',
          );
        }
        return const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
        );
      },
    );
    final sessionStore = MemoryUserSessionStore();
    final api = GenesisApi(
      transport: apiTransport,
      useMock: false,
      deviceIdService: const _TestDeviceIdService(),
      sessionStore: sessionStore,
    );

    await api.loginWithIdentity(
      const AuthSession(
        provider: IdentityProvider.apple,
        providerIdToken: 'apple-token',
        firebaseIdToken: 'firebase-token',
        identityUid: 'firebase-uid',
        email: 'ava@example.com',
        displayName: 'Ava',
        photoUrl: '',
      ),
    );

    expect(await sessionStore.readUid(), 'apple_uid');
    expect(await sessionStore.readAuthToken(), 'apple-backend-token');
    expect(await sessionStore.readUserInfo(), containsPair('uid', 'apple_uid'));
  });

  test(
    'loginWithIdentity does not persist uid when backend omits user id',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/oauth/apple')) {
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body:
                  '{"err_no":0,"err_msg":"succ","data":{"token":"apple-backend-token","user":{}}}',
            );
          }
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
          );
        },
      );
      final sessionStore = MemoryUserSessionStore();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
      );

      await expectLater(
        api.loginWithIdentity(
          const AuthSession(
            provider: IdentityProvider.apple,
            providerIdToken: 'apple-token',
            firebaseIdToken: 'firebase-token',
            identityUid: 'firebase-uid',
            email: 'ava@example.com',
            displayName: 'Ava',
            photoUrl: '',
          ),
        ),
        throwsA(isA<ApiException>()),
      );

      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);
    },
  );

  test(
    'backend login failure clears identity session for provider retry',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/oauth/google')) {
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"err_no":10013,"err_msg":"user banned","data":{}}',
            );
          }
          return const TransportResponse(
            statusCode: 404,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":404,"err_msg":"not_found","data":{}}',
          );
        },
      );
      final sessionStore = MemoryUserSessionStore();
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await expectLater(
        coordinator.loginWithIdentity(
          const AuthSession(
            provider: IdentityProvider.google,
            providerIdToken: 'google-token',
            firebaseIdToken: 'firebase-token',
            identityUid: 'firebase-uid',
            email: 'user@example.com',
            displayName: 'User',
            photoUrl: '',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', 10013)
              .having((error) => error.message, 'message', 'user banned'),
        ),
      );

      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
    },
  );

  test(
    'backend signOut posts logout then clears identity and local session',
    () async {
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/logout')) {
            expect(request.method, 'POST');
            expect(request.headers['authorization'], 'Bearer backend-token');
            return const TransportResponse(
              statusCode: 200,
              headers: {'content-type': 'application/json'},
              body: '{"err_no":0,"err_msg":"succ","data":{}}',
            );
          }
          return const TransportResponse(
            statusCode: 404,
            headers: {'content-type': 'application/json'},
            body: '{"error":"not_found"}',
          );
        },
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_2');
      await sessionStore.saveAuthToken('backend-token');
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await coordinator.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(apiTransport.requests.single.uri.path, '/api/v1/user/logout');
      expect(
        apiTransport.requests.single.headers['authorization'],
        'Bearer backend-token',
      );
      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);
    },
  );

  test(
    'backend signOut clears local session without waiting for logout response',
    () async {
      final logoutResponse = Completer<TransportResponse>();
      final apiTransport = _FakeTransport(
        handler: (_) => logoutResponse.future,
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_2');
      await sessionStore.saveAuthToken('backend-token');
      await sessionStore.saveUserInfo({'uid': 'u_2'});
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await coordinator.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(logoutResponse.isCompleted, isFalse);
      expect(apiTransport.requests.single.uri.path, '/api/v1/user/logout');
      expect(
        apiTransport.requests.single.headers['authorization'],
        'Bearer backend-token',
      );
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);

      logoutResponse.complete(
        const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{}}',
        ),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'backend signOut still clears local session when logout endpoint fails',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 500,
          headers: {'content-type': 'application/json'},
          body: '{"error":"server_error"}',
        ),
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_2');
      await sessionStore.saveAuthToken('backend-token');
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await coordinator.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);
    },
  );

  test(
    'backend deleteAccount posts user delete then clears local session',
    () async {
      final deleteResponse = Completer<TransportResponse>();
      final apiTransport = _FakeTransport(
        handler: (request) {
          if (request.uri.path.endsWith('/v1/user/delete')) {
            expect(request.method, 'POST');
            expect(request.headers['authorization'], 'Bearer backend-token');
            return deleteResponse.future;
          }
          return const TransportResponse(
            statusCode: 404,
            headers: {'content-type': 'application/json'},
            body: '{"error":"not_found"}',
          );
        },
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveUid('u_2');
      await sessionStore.saveAuthToken('backend-token');
      await sessionStore.saveUserInfo({'uid': 'u_2'});
      final identityAuth = _FakeIdentityAuthService();
      final api = GenesisApi(
        transport: apiTransport,
        useMock: false,
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        identityAuthService: identityAuth,
      );
      final coordinator = GenesisBackendAuthCoordinator(
        api: api,
        identityAuth: identityAuth,
        sessionStore: sessionStore,
      );

      await coordinator.deleteAccount();
      await Future<void>.delayed(Duration.zero);

      expect(deleteResponse.isCompleted, isFalse);
      expect(apiTransport.requests.single.uri.path, '/api/v1/user/delete');
      expect(
        apiTransport.requests.single.headers['authorization'],
        'Bearer backend-token',
      );
      expect(identityAuth.signOutCount, 1);
      expect(await sessionStore.readUid(), isNull);
      expect(await sessionStore.readAuthToken(), isNull);
      expect(await sessionStore.readUserInfo(), isNull);

      deleteResponse.complete(
        const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{}}',
        ),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('v1 origin list uses Apifox query format', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final result = await api.v1.origin.list(
      scene: 'tag',
      tag: 'politics',
      keyword: 'steam',
      pn: 2,
      rn: 10,
    );

    expect(result['total'], 0);
    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/list');
    expect(apiTransport.lastRequest!.uri.queryParameters['scene'], 'tag');
    expect(apiTransport.lastRequest!.uri.queryParameters['tag'], 'politics');
    expect(apiTransport.lastRequest!.uri.queryParameters['keyword'], 'steam');
    expect(
      apiTransport.lastRequest!.uri.queryParameters.containsKey('tag_name'),
      false,
    );
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '2');
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '10');
  });

  test('v1 origin hot tags uses Apifox response format', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"list":["校园","恋爱","校园"]}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final result = await api.v1.origin.hotTags();

    expect(result, <String>['校园', '恋爱', '校园']);
    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/origin/hot_tags');
  });

  test('v1 direct message send posts Apifox JSON body', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"message":{"msg_id":"m1"}}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.v1.dm.send(peerUid: 'U_2', content: 'hello');

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/direct_message/send');
    final body = jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!));
    expect(body['peer_uid'], 'U_2');
    expect(body['content'], 'hello');
    expect(body.containsKey('targetUid'), isFalse);
    expect(body.containsKey('peerUid'), isFalse);
    expect(body.containsKey('target_uid'), isFalse);
    expect(body.containsKey('client_msg_id'), isFalse);
  });

  test('v1 message notifications uses Apifox block query', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"list":[],"total":0,"pn":1,"rn":20}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.v1.messages.notifications(block: 'interaction', pn: 1, rn: 20);

    expect(apiTransport.lastRequest!.method, 'GET');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/message/notifications');
    expect(
      apiTransport.lastRequest!.uri.queryParameters['block'],
      'interaction',
    );
    expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '1');
    expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
    expect(
      apiTransport.lastRequest!.uri.queryParameters.containsKey('category'),
      isFalse,
    );
  });

  test('v1 mark notifications read posts Apifox block body', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    await api.v1.messages.markNotificationsRead(block: 'world_apply');

    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/message/read');
    final body = jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!));
    expect(body['block'], 'world_apply');
    expect(body.containsKey('category'), isFalse);
    expect(body.containsKey('notification_ids'), isFalse);
  });

  test(
    'v1 direct message conversations supports after_message_id cursor',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{"list":[]}}',
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      await api.v1.dm.conversations(
        pn: 2,
        rn: 20,
        afterMessageId: 'DM_CURSOR_001',
      );

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(
        apiTransport.lastRequest!.uri.path,
        '/api/v1/direct_message/conversations',
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('pn'),
        isFalse,
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('rn'),
        isFalse,
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters['after_message_id'],
        'DM_CURSOR_001',
      );
    },
  );

  test('v1 API throws ApiException when err_no is non-zero', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":1001,"err_msg":"bad request","data":{}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);

    expect(
      () => api.v1.user.info(),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'bad request'),
      ),
    );
  });

  test(
    'v1 discuss list uses Apifox query and normalizes response keys',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"errNo":0,"errStr":"success","data":{"list":[{"comment":{"discussId":"dis_001","isLiked":true,"likeCnt":11},"latestReplies":[{"discussId":"dis_002","rootDiscussId":"dis_001"}]}],"topTotal":1,"totalAll":2,"pn":1,"rn":20}}',
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      final result = await api.v1.discuss.list(bizId: 'ori_001', pn: 1, rn: 20);

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/list');
      expect(apiTransport.lastRequest!.uri.queryParameters['biz_type'], '1');
      expect(
        apiTransport.lastRequest!.uri.queryParameters['biz_id'],
        'ori_001',
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('bizType'),
        isFalse,
      );
      final item = (result['list'] as List).first as Map<String, dynamic>;
      final comment = item['comment'] as Map<String, dynamic>;
      expect(comment['discuss_id'], 'dis_001');
      expect(comment['is_liked'], isTrue);
      expect(comment['like_cnt'], 11);
      expect(comment.containsKey('discussId'), isFalse);
      final replies = item['latest_replies'] as List;
      expect((replies.first as Map)['discuss_id'], 'dis_002');
      expect(result['top_total'], 1);
      expect(result['total_all'], 2);
    },
  );

  test(
    'v1 discuss replies uses Apifox root query and normalizes response keys',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"errNo":0,"errStr":"success","data":{"list":[{"discussId":"dis_reply_001","rootDiscussId":"dis_root","parentDiscussId":"dis_parent","isLiked":false,"likeCnt":3}],"total":1,"pn":2,"rn":20}}',
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      final result = await api.v1.discuss.replies(
        rootDiscussId: 'dis_root',
        pn: 2,
        rn: 20,
      );

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/replies');
      expect(
        apiTransport.lastRequest!.uri.queryParameters['root_discuss_id'],
        'dis_root',
      );
      expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '2');
      expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '20');
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey(
          'rootDiscussId',
        ),
        isFalse,
      );
      final reply = (result['list'] as List).first as Map<String, dynamic>;
      expect(reply['discuss_id'], 'dis_reply_001');
      expect(reply['root_discuss_id'], 'dis_root');
      expect(reply['parent_discuss_id'], 'dis_parent');
      expect(reply['is_liked'], isFalse);
      expect(reply['like_cnt'], 3);
      expect(result['total'], 1);
    },
  );

  test(
    'v1 world origin progress uses Apifox query and normalizes response',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"errNo":0,"errStr":"success","data":{"worldId":"w_a1b2c3","tickCnt":12}}',
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      final result = await api.v1.world.originProgress(
        uid: 'u_a1b2c3',
        originId: 'ori_a1b2c3',
      );

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(
        apiTransport.lastRequest!.uri.path,
        '/api/v1/world/origin_progress',
      );
      expect(apiTransport.lastRequest!.uri.queryParameters['uid'], 'u_a1b2c3');
      expect(
        apiTransport.lastRequest!.uri.queryParameters['origin_id'],
        'ori_a1b2c3',
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('originId'),
        isFalse,
      );
      expect(result['world_id'], 'w_a1b2c3');
      expect(result['tick_cnt'], 12);
      expect(result.containsKey('worldId'), isFalse);
    },
  );

  test(
    'latest world summaries use Apifox query and normalize response',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"errNo":0,"errStr":"success","data":{"list":[{"worldId":"w_peer","originId":"o_1","tickNo":12,"summary":"latest summary","tickTime":1780000000,"createdAt":1780000010}]}}',
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      final result = await api.getLatestWorldSummaries(
        originId: 'o_1',
        worldId: 'w_self',
      );

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(
        apiTransport.lastRequest!.uri.path,
        '/api/v1/world/summary/latest',
      );
      expect(apiTransport.lastRequest!.uri.queryParameters['origin_id'], 'o_1');
      expect(
        apiTransport.lastRequest!.uri.queryParameters['world_id'],
        'w_self',
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('originId'),
        isFalse,
      );
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('worldId'),
        isFalse,
      );
      expect(result.single.worldId, 'w_peer');
      expect(result.single.originId, 'o_1');
      expect(result.single.tickNo, 12);
      expect(result.single.summary, 'latest summary');
      expect(result.single.tickTime, 1780000000);
      expect(result.single.createdAt, 1780000010);
    },
  );

  test(
    'getWorldTicks uses Apifox tick list query and normalizes ticks',
    () async {
      final apiTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body:
              '{"errNo":0,"errStr":"success","data":{"list":[{"tickId":"tick_2","tickNo":2,"status":10,"tickResult":{"narrator":"latest","paragraphs":[{"locationId":"loc_1","text":"paragraph"}],"locationGroups":[]},"createdAt":1779271200}],"total":3,"pn":1,"rn":2}}',
        ),
      );
      final healthTransport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"status":"ok"}',
        ),
      );

      final api = _apiWith(apiTransport, healthTransport);
      final result = await api.getWorldTicks(wid: 'w_a1b2c3', limit: 2);

      expect(apiTransport.lastRequest!.method, 'GET');
      expect(apiTransport.lastRequest!.uri.path, '/api/v1/world/tick/list');
      expect(
        apiTransport.lastRequest!.uri.queryParameters['world_id'],
        'w_a1b2c3',
      );
      expect(apiTransport.lastRequest!.uri.queryParameters['pn'], '1');
      expect(apiTransport.lastRequest!.uri.queryParameters['rn'], '2');
      expect(
        apiTransport.lastRequest!.uri.queryParameters.containsKey('worldId'),
        isFalse,
      );
      expect(result.total, 3);
      expect(result.data.single['tick_id'], 'tick_2');
      expect(result.data.single['tick_no'], 2);
      final tickResult = result.data.single['tick_result'] as Map;
      expect(tickResult['narrator'], 'latest');
      final paragraphs = tickResult['paragraphs'] as List;
      expect((paragraphs.single as Map)['location_id'], 'loc_1');
    },
  );

  test('v1 discuss write APIs use Apifox paths and body fields', () async {
    final apiTransport = _FakeTransport(
      handler: (request) {
        if (request.uri.path.endsWith('/discuss/post')) {
          return const TransportResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            body:
                '{"err_no":0,"err_msg":"succ","data":{"discuss_id":"dis_new","root_discuss_id":"dis_root","level":2}}',
          );
        }
        return const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":0,"err_msg":"succ","data":{}}',
        );
      },
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final created = await api.v1.discuss.post(
      bizId: 'ori_001',
      content: 'reply',
      images: const ['https://cdn.example.com/discuss/a.jpg'],
      rootDiscussId: 'dis_root',
      parentDiscussId: 'dis_parent',
    );

    expect(created['discuss_id'], 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/post');
    final postBody = jsonDecode(
      utf8.decode(apiTransport.lastRequest!.bodyBytes!),
    );
    expect(postBody['biz_type'], 1);
    expect(postBody['biz_id'], 'ori_001');
    expect(postBody['root_discuss_id'], 'dis_root');
    expect(postBody['parent_discuss_id'], 'dis_parent');
    expect(postBody.containsKey('rootDiscussId'), isFalse);

    await api.v1.discuss.like(discussId: 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/like');
    final likeBody = jsonDecode(
      utf8.decode(apiTransport.lastRequest!.bodyBytes!),
    );
    expect(likeBody, {'discuss_id': 'dis_new'});

    await api.v1.discuss.unlike(discussId: 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/unlike');

    await api.v1.discuss.delete(discussId: 'dis_new');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/discuss/delete');
    final deleteBody = jsonDecode(
      utf8.decode(apiTransport.lastRequest!.bodyBytes!),
    );
    expect(deleteBody, {'discuss_id': 'dis_new'});
  });

  test('v1 upload uses multipart body through ApiClient transport', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_str":"success","data":{"file_url":"https://cdn/x.png"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final result = await api.v1.common.uploadFile(
      bytes: utf8.encode('abc'),
      bizType: 'avatar',
      filename: 'a.txt',
      contentType: 'text/plain',
    );

    expect(result['file_url'], 'https://cdn/x.png');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/common/upload');
    expect(apiTransport.lastRequest!.timeoutMs, 15000);
    expect(
      apiTransport.lastRequest!.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final body = utf8.decode(apiTransport.lastRequest!.bodyBytes!);
    expect(body, contains('name="biz_type"'));
    expect(body, contains('avatar'));
    expect(body, contains('filename="a.txt"'));
    expect(body, contains('abc'));
  });

  test('v1 upload image uses Apifox multipart contract', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"sm_url":"https://cdn.example.com/uploads/20260526/123_400_300.jpg","xl_url":"https://cdn.example.com/uploads/20260526/123_800_600.jpg","object_key":"uploads/20260526/123_800_600.jpg"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final result = await api.v1.upload.image(
      bytes: utf8.encode('image-bytes'),
      filename: 'avatar.png',
      contentType: 'image/png',
    );

    expect(
      result['sm_url'],
      'https://cdn.example.com/uploads/20260526/123_400_300.jpg',
    );
    expect(
      result['xl_url'],
      'https://cdn.example.com/uploads/20260526/123_800_600.jpg',
    );
    expect(result['object_key'], 'uploads/20260526/123_800_600.jpg');
    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/upload/image');
    expect(
      apiTransport.lastRequest!.timeoutMs,
      UploadV1Api.imageUploadTimeoutMs,
    );
    expect(
      apiTransport.lastRequest!.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final body = utf8.decode(apiTransport.lastRequest!.bodyBytes!);
    expect(body, contains('name="file"; filename="avatar.png"'));
    expect(body, contains('Content-Type: image/png'));
    expect(body, isNot(contains('name="biz_type"')));
  });

  test('v1 report create posts Apifox body and parses report id', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"report_id":"rpt_X9KQ4M2A1B2C"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final result = await api.v1.report.create(
      targetType: 'origin',
      targetId: 'o_A1B2C3',
      content: '内容疑似违规',
    );

    expect(result['report_id'], 'rpt_X9KQ4M2A1B2C');
    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/report/create');
    expect(jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!)), {
      'target_type': 'origin',
      'target_id': 'o_A1B2C3',
      'content': '内容疑似违规',
    });
  });

  test('v1 feedback create posts Apifox body and parses feedback id', () async {
    final apiTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"feedback_id":"fbk_X9KQ4M2A1B2C"}}',
      ),
    );
    final healthTransport = _FakeTransport(
      handler: (_) => const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"status":"ok"}',
      ),
    );

    final api = _apiWith(apiTransport, healthTransport);
    final result = await api.v1.feedback.create(content: '希望增加夜间模式');

    expect(result['feedback_id'], 'fbk_X9KQ4M2A1B2C');
    expect(apiTransport.lastRequest!.method, 'POST');
    expect(apiTransport.lastRequest!.uri.path, '/api/v1/feedback/create');
    expect(jsonDecode(utf8.decode(apiTransport.lastRequest!.bodyBytes!)), {
      'content': '希望增加夜间模式',
    });
  });

  test(
    'user followers 1404 stays in list error path without page-not-found callback',
    () async {
      var pageNotFoundCount = 0;
      final transport = _FakeTransport(
        handler: (_) => const TransportResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: '{"err_no":1404,"err_msg":"Page not found","data":{}}',
        ),
      );
      final sessionStore = MemoryUserSessionStore();
      await sessionStore.saveAuthToken('token');
      final api = GenesisApi(
        useMock: false,
        transport: transport,
        platformConfig: const _TestPlatformConfig(),
        deviceIdService: const _TestDeviceIdService(),
        sessionStore: sessionStore,
        onPageNotFound: (_) async {
          pageNotFoundCount += 1;
        },
      );

      await expectLater(
        api.v1.follow.followers(uid: 'u_peer', pn: 1, rn: 50),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', 1404)
              .having((error) => error.kind, 'kind', ApiExceptionKind.business),
        ),
      );

      expect(transport.lastRequest!.uri.path, '/api/v1/user/followers');
      expect(pageNotFoundCount, 0);
    },
  );
}

TransportResponse _gatewayAuthResponse(TransportRequest request) {
  switch (request.uri.path) {
    case '/apix/v1/time':
      return const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"err_no":0,"err_msg":"succ","data":{"server_time_ms":1}}',
      );
    case '/apix/v1/app/device/challenge':
      return const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"register_id":"reg-1","challenge":"challenge","expires_in":300}}',
      );
    case '/apix/v1/app/device/register':
      return const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"key_id":"key-registered"}}',
      );
  }
  return const TransportResponse(
    statusCode: 404,
    headers: {'content-type': 'application/json'},
    body: '{"err_no":404,"err_msg":"unexpected","data":{}}',
  );
}

class _TestDeviceIdService implements DeviceIdService {
  const _TestDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  int signOutCount = 0;

  @override
  IdentityProfile? currentProfile() => null;

  @override
  bool hasLocalIdentitySession() => false;

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn(IdentityProvider provider) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOutIdentity() async {
    signOutCount += 1;
  }
}
