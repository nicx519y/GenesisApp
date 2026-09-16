import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/platform/billing/billing_service.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';
import 'package:genesis_flutter_android/platform/billing/pending_purchase_store.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

import '../membership/membership_purchase_service_test.dart' as membership;

class _Store extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  int streamSubscriptions = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    streamSubscriptions++;
    return updates.stream;
  }

  @override
  Future<bool> isAvailable() async => true;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late _Store store;
  late List<String> storageReads;

  setUp(() {
    // Initialize the facade without installing either native store plugin.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = _Store();
    InAppPurchasePlatform.instance = store;
    storageReads = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(storageChannel, (
      call,
    ) async {
      if (call.method == 'read') {
        storageReads.add((call.arguments as Map)['key'] as String);
      }
      if (call.method == 'readAll') return <String, String>{};
      if (call.method == 'containsKey') return false;
      return null;
    });
  });

  tearDown(() async {
    await store.updates.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      storageChannel,
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'config replacement retains purchase listening and receipt recovery',
    () async {
      final original = ServiceRegistry.build(
        config: const AppConfig(useMock: true),
        sessionStoreOverride: MemoryUserSessionStore(),
      );
      original.startPurchaseServices();
      await pumpEventQueue();
      expect(store.updates.hasListener, isTrue);
      storageReads.clear();

      final updated = ServiceRegistry.rebuildFrom(
        original,
        config: const AppConfig(
          useMock: true,
          apiBaseUrl: 'https://example.test/api/',
        ),
      );
      addTearDown(updated.dispose);
      original.dispose();
      await pumpEventQueue();

      expect(store.updates.hasListener, isTrue);
      expect(store.streamSubscriptions, 2);
      expect(storageReads, contains('membership_purchase_records_v1'));
      expect(storageReads, contains('membership_guest_claims_v1'));

      // A real stream failure must reach the replacement membership service,
      // rather than leave its purchase dialog waiting for a missing listener.
      store.updates.addError(
        PlatformException(code: 'test_store_disconnected'),
        StackTrace.current,
      );
      await pumpEventQueue();
      expect(
        updated.membershipPurchases!.state.value,
        MembershipCheckoutState.deferred,
      );

      updated.startPurchaseServices();
      await pumpEventQueue();
      expect(store.streamSubscriptions, 2);
    },
  );

  for (final eagerStart in [true, false]) {
    test(
      'checkout receives purchases with eager startup=$eagerStart',
      () async {
        final base = ServiceRegistry.build(
          config: const AppConfig(useMock: true),
          sessionStoreOverride: MemoryUserSessionStore(),
        );
        addTearDown(base.dispose);
        late final GooglePlayBillingService billing;
        final h = membership.Harness(
          ensureStoreListening: () => billing.start(),
        );
        h.platform.onLaunch = () async {
          expect(store.updates.hasListener, isTrue);
          expect(store.streamSubscriptions, 1);
        };
        billing = GooglePlayBillingService(
          platform: GooglePlayBillingPlatform(),
          pendingPurchaseStore: MemoryBillingPendingPurchaseStore(),
          loadBillingAccountId: () async =>
              throw StateError('not a Gems checkout'),
          loadProductCatalog: () async => [],
          reportPurchase: (_) async => throw StateError('not a Gems report'),
          refreshWallet: () async {},
          readUid: () async => h.uid,
          interceptPurchase: h.service.interceptPurchase,
          onPurchaseStreamError: h.service.handleStreamError,
        );
        final services = AppServices(
          config: base.config,
          platformConfig: base.platformConfig,
          deviceId: base.deviceId,
          sessionStore: base.sessionStore,
          identityAuth: base.identityAuth,
          backendAuth: base.backendAuth,
          api: base.api,
          chatroom: base.chatroom,
          chatroomMessages: base.chatroomMessages,
          directMessageConversations: base.directMessageConversations,
          directMessageMessages: base.directMessageMessages,
          appVersionCheck: base.appVersionCheck,
          externalUrlOpener: base.externalUrlOpener,
          billing: billing,
          membershipPurchases: h.service,
        );
        addTearDown(services.dispose);
        if (eagerStart) services.startPurchaseServices();
        await pumpEventQueue();
        await h.service.purchase(h.product());
        expect(h.service.state.value, MembershipCheckoutState.store);

        store.updates.add([
          PurchaseDetails(
            purchaseID: 'test-transaction',
            productID: h.product().storeProductId,
            verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: 'test-token',
              source: 'google_play',
            ),
            transactionDate: '1000',
            status: PurchaseStatus.purchased,
          ),
        ]);
        await pumpEventQueue();
        expect(h.reports, hasLength(1));
        expect(h.service.state.value, MembershipCheckoutState.completed);
        expect(h.service.isBusy, isFalse);
      },
    );
  }
}
