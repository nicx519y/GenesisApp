import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/startup/startup_app_config.dart';
import 'package:genesis_flutter_android/app/startup/startup_uid_resolution.dart';
import 'package:genesis_flutter_android/l10n/app_language_controller.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import '../../support/membership_fixtures.dart';

class _Device implements DeviceIdService {
  @override
  Future<String> getDeviceId() async => 'test-device';
}

class _Store extends InAppPurchasePlatform {
  @override
  Future<bool> isAvailable() async => false;
}

class _Transport extends HttpTransport {
  final requests = <TransportRequest>[];
  bool configFails = false;
  @override
  Future<TransportResponse> send(TransportRequest r) async {
    requests.add(r);
    final Object data;
    if (r.uri.path.endsWith('/app/config')) {
      if (configFails) throw StateError('test config offline');
      data = {'language': 'zh-TW'};
    } else if (r.uri.path.endsWith('/user/info')) {
      data = {
        'user': {'uid': 'test-user', 'language': 'ja'},
        'relation': {'is_self': true},
      };
    } else if (r.uri.path.endsWith('/membership/products')) {
      data = {
        'list_premium': [
          membershipProduct(provider: MembershipProvider.apple).toJson(),
        ],
      };
    } else if (r.uri.path.endsWith('/gem/products')) {
      data = {
        'list': [
          {
            'product_id': 'test-pack',
            'apple_product_id': 'test-apple-pack',
            'google_product_id': 'test-google-pack',
            'base_gems_cent': 100,
            'bonus_gems_cent': 0,
            'price_amount': 100,
            'price_currency_code': 'USD',
            'can_purchase': true,
          },
        ],
      };
    } else {
      throw StateError('Unexpected test path ${r.uri.path}');
    }
    return TransportResponse(
      statusCode: 200,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'ok', 'data': data}),
    );
  }

  List<TransportRequest> get products =>
      requests.where((r) => r.uri.path.endsWith('/products')).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppServices base, services;
  late MemoryUserSessionStore session;
  late _Transport transport;
  late Completer<void> ready;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appLanguageController.load();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    InAppPurchasePlatform.instance = _Store();
    session = MemoryUserSessionStore();
    base = ServiceRegistry.build(
      config: const AppConfig(useMock: true),
      sessionStoreOverride: session,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    transport = _Transport();
    ready = Completer<void>();
    final api = GenesisApi(
      transport: transport,
      useMock: false,
      deviceIdService: _Device(),
      sessionStore: session,
      languageController: appLanguageController,
      appHeaderProvider: () async => {
        if (appLanguageController.settingLanguage != null)
          'x-setting-language': appLanguageController.settingLanguage!,
      },
    );
    services = AppServices(
      config: base.config,
      platformConfig: base.platformConfig,
      deviceId: _Device(),
      sessionStore: session,
      identityAuth: base.identityAuth,
      backendAuth: base.backendAuth,
      api: api,
      chatroom: base.chatroom,
      chatroomMessages: base.chatroomMessages,
      directMessageConversations: base.directMessageConversations,
      directMessageMessages: base.directMessageMessages,
      appVersionCheck: base.appVersionCheck,
      externalUrlOpener: base.externalUrlOpener,
      purchaseCatalogReady: ready.future,
    );
  });
  tearDown(() async {
    if (!ready.isCompleted) ready.complete();
    await pumpEventQueue();
    services.dispose();
    base.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  Future<void> config() => loadStartupAppConfig(
    store: services.appGlobalConfig,
    uidResolution: Future.value(
      const StartupUidResolution(uid: null, status: 'signed_out'),
    ),
    collectReady: Future.value(),
  );
  test(
    'startup and onboarding share one product load after config language',
    () async {
      services.startPurchaseServices();
      final first = services.membershipCatalog.preload();
      final onboarding = services.membershipCatalog.preload();
      await pumpEventQueue();
      expect(transport.products, isEmpty);
      await config();
      expect(appLanguageController.settingLanguage, 'zh-TW');
      expect(transport.products, isEmpty);
      ready.complete();
      await Future.wait([first, onboarding]);
      expect(transport.products, hasLength(1));
      expect(transport.products.single.headers['x-setting-language'], 'zh-TW');
      await services.membershipCatalog.preload();
      expect(transport.products, hasLength(1));
      await services.membershipCatalog.loadForEntry();
      expect(transport.products, hasLength(2));
    },
  );
  test('signed-in subscriptions and Gems wait for user language too', () async {
    await session.saveUid('test-user');
    await session.saveAuthToken('test-token');
    services.startPurchaseServices();
    final subscription = services.membershipCatalog.preload();
    final gems = services.gemStoreCatalog.preload();
    await config();
    await pumpEventQueue();
    expect(transport.products, isEmpty);
    await services.api.v1.user.info();
    expect(appLanguageController.settingLanguage, 'ja');
    ready.complete();
    await Future.wait([subscription, gems]);
    expect(transport.products, hasLength(2));
    expect(
      transport.products.every((r) => r.headers['x-setting-language'] == 'ja'),
      true,
    );
  });
  test('failed config releases products using cached language', () async {
    appLanguageController.applyConfigLanguage(
      'en',
      requestRevision: appLanguageController.revision,
    );
    transport.configFails = true;
    final products = services.membershipCatalog.preload();
    await config().whenComplete(() => ready.complete());
    await products;
    expect(transport.products, hasLength(1));
    expect(transport.products.single.headers['x-setting-language'], 'en');
  });
  test(
    'retired startup work cannot send a product request after release',
    () async {
      final products = services.membershipCatalog.preload();
      await pumpEventQueue();
      services.retireAuthentication();
      ready.complete();
      await products;
      expect(transport.products, isEmpty);
    },
  );
}
