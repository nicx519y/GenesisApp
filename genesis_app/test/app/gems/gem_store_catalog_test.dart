import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/gems/gem_store_catalog.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

class Store implements BillingPlatform {
  Store(this.provider);
  @override
  final BillingProvider provider;
  int calls = 0;
  int amount = 12000000000;
  String currency = 'KRW';
  String formatted = '₩12,000';
  bool available = true;
  Completer<void>? queryGate;
  String? option;
  String? offer;
  String? id;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<BillingProductQueryResult> queryProduct(
    String storeProductId,
    BillingStoreProductType expectedType, {
    String? purchaseOptionId,
    String? offerId,
  }) async {
    calls++;
    await queryGate?.future;
    option = purchaseOptionId;
    offer = offerId;
    id = storeProductId;
    return BillingProductQueryResult.success(
      BillingStoreProduct(
        id: storeProductId,
        type: expectedType,
        nativeProduct: Object(),
        formattedPrice: formatted,
        priceAmountMicros: amount,
        priceCurrencyCode: currency,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GemProduct product() => GemProduct.fromJson({
  'product_id': 'pack',
  'apple_product_id': 'apple-pack',
  'google_product_id': 'google-pack',
  'base_gems_cent': 10000,
  'bonus_gems_cent': 0,
  'price_currency_code': 'USD',
  'price_amount': 999,
  'can_purchase': true,
  'google_purchase_option_id': 'option',
  'google_offer_id': 'offer',
});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'entry keeps checkout cache during API then refreshes the store',
    () async {
      final response = Completer<List<GemProduct>>();
      final store = Store(BillingProvider.appStore);
      var calls = 0;
      final catalog = GemStoreCatalog(
        loadProducts: () async => ++calls == 1 ? [product()] : response.future,
        platform: store,
        namespace: 'entry',
        readOwner: () async => 'a',
      );
      await catalog.preload();
      final old = catalog.cached!.single;
      final refresh = catalog.loadForEntry();
      await pumpEventQueue();
      expect(calls, 2);
      expect(catalog.queryingStore.value, isFalse);
      expect(
        await catalog.confirm(old).timeout(const Duration(seconds: 1)),
        same(old),
      );
      expect(store.calls, 1);
      store.queryGate = Completer<void>();
      response.complete([product()]);
      await pumpEventQueue();
      expect(catalog.queryingStore.value, isTrue);
      expect(store.calls, 2);
      store.queryGate!.complete();
      await refresh;
      expect(catalog.queryingStore.value, isFalse);
      expect(await catalog.confirm(catalog.cached!.single), isNotNull);
      expect(calls, 2);
      expect(store.calls, 2);
    },
  );
  GemProduct tagged(String tag) => GemProduct.fromJson({
    ...product().toJson(),
    'activity_text': tag,
    'bonus_gems_cent': tag.isEmpty ? 0 : 10000,
  });

  test(
    'purchase refresh reloads server eligibility and shares in-flight entry loads',
    () async {
      var calls = 0;
      final fresh = Completer<List<GemProduct>>();
      final requested = Completer<void>();
      final catalog = GemStoreCatalog(
        loadProducts: () async {
          if (++calls == 1) return [tagged('New User')];
          if (!requested.isCompleted) requested.complete();
          return fresh.future;
        },
        platform: Store(BillingProvider.googlePlay),
        namespace: 'test',
        readOwner: () async => 'a',
      );
      expect((await catalog.loadForEntry()).single.tagText, 'New User');
      final refresh = catalog.refreshAfterPurchase();
      final entry = catalog.loadForEntry();
      await requested.future;
      expect(calls, 2);
      expect(await catalog.loadCached(), isNull);
      fresh.complete([tagged('')]);
      for (final result in await Future.wait([refresh, entry])) {
        expect(result.single.tagText, isEmpty);
        expect(result.single.bonusGemsCent, 0);
      }
      expect(calls, 2);
      await catalog.loadForEntry();
      expect(calls, 3);
      final restored = GemStoreCatalog(
        loadProducts: () async => [],
        platform: Store(BillingProvider.googlePlay),
        namespace: 'test',
        readOwner: () async => 'a',
      );
      expect((await restored.loadCached())!.single.tagText, isEmpty);
    },
  );

  test(
    'failed purchase refresh cannot restore stale new-user disk cache',
    () async {
      var calls = 0;
      final catalog = GemStoreCatalog(
        loadProducts: () async {
          if (++calls == 1) return [tagged('New User')];
          throw StateError('offline');
        },
        platform: Store(BillingProvider.googlePlay),
        namespace: 'test',
        readOwner: () async => 'a',
      );
      await catalog.loadForEntry();
      await expectLater(catalog.refreshAfterPurchase(), throwsStateError);
      expect(await catalog.loadCached(), isNull);
      final restored = GemStoreCatalog(
        loadProducts: () async => [],
        platform: Store(BillingProvider.googlePlay),
        namespace: 'test',
        readOwner: () async => 'a',
      );
      expect(await restored.loadCached(), isNull);
      await expectLater(catalog.loadForEntry(), throwsStateError);
      expect(calls, 3);
    },
  );

  test(
    'late pre-purchase response cannot overwrite refreshed products',
    () async {
      var calls = 0;
      final stale = Completer<List<GemProduct>>();
      final started = Completer<void>();
      final catalog = GemStoreCatalog(
        loadProducts: () async {
          if (++calls == 1) {
            started.complete();
            return stale.future;
          }
          return [tagged('')];
        },
        platform: Store(BillingProvider.googlePlay),
        namespace: 'test',
        readOwner: () async => 'a',
      );
      final old = catalog.load();
      final oldFailed = expectLater(old, throwsStateError);
      await started.future;
      expect((await catalog.refreshAfterPurchase()).single.tagText, isEmpty);
      stale.complete([tagged('New User')]);
      await oldFailed;
      expect(catalog.cached!.single.tagText, isEmpty);
      expect(calls, 2);
    },
  );
  for (final provider in BillingProvider.values) {
    test(
      '$provider preload stores prices and restart reads disk without checkout tokens',
      () async {
        final store = Store(provider);
        GemStoreCatalog create([String owner = 'a']) => GemStoreCatalog(
          loadProducts: () async => [product()],
          platform: store,
          namespace: 'test',
          readOwner: () async => owner,
        );
        final source = create();
        await source.preload();
        expect(source.cached!.single.storeFormattedPrice, '₩12,000');
        expect(
          store.id,
          provider == BillingProvider.googlePlay ? 'google-pack' : 'apple-pack',
        );
        expect(
          store.offer,
          provider == BillingProvider.googlePlay ? 'offer' : null,
        );
        await source.preload();
        expect(store.calls, 1);
        final restored = await create().loadCached();
        expect(restored!.single.storeAmountMicros, 12000000000);
        expect(store.calls, 1);
        expect(await create('b').loadCached(), isNull);
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(prefs.getKeys().single)!;
        expect(raw, contains('cached_at'));
        expect(raw, isNot(contains('offer_token')));
        expect(raw, isNot(contains('nativeProduct')));
      },
    );
  }
  test('guest skips product requests and loads after login', () async {
    final store = Store(BillingProvider.googlePlay);
    String? owner;
    var productRequests = 0;
    final catalog = GemStoreCatalog(
      loadProducts: () async {
        productRequests++;
        return [product()];
      },
      platform: store,
      namespace: 'test',
      readOwner: () async => owner,
    );

    await catalog.preload();
    expect(productRequests, 0);
    expect(await catalog.loadCached(), isNull);
    await expectLater(catalog.load(), throwsStateError);
    expect(productRequests, 0);

    owner = 'signed-in-user';
    await catalog.preload();
    expect(productRequests, 1);
    expect(catalog.cached, isNotNull);
  });
  test('failed store lookup never uses API price and can retry', () async {
    final store = Store(BillingProvider.googlePlay)..available = false;
    final source = GemStoreCatalog(
      loadProducts: () async => [product()],
      platform: store,
      namespace: 'test',
      readOwner: () async => 'a',
    );
    expect((await source.load()).single.storeFormattedPrice, isNull);
    expect(source.cached!.single.requiresStorePrice, isTrue);
    store.available = true;
    expect((await source.load()).single.storeCurrencyCode, 'KRW');
  });
  test(
    'cached checkout does not query products again; reset requires confirmation',
    () async {
      final store = Store(BillingProvider.googlePlay)
        ..currency = 'EUR'
        ..formatted = '€12.00';
      final source = GemStoreCatalog(
        loadProducts: () async => [product()],
        platform: store,
        namespace: 'test',
        readOwner: () async => 'a',
      );
      final displayed = (await source.load()).single;
      expect(await source.confirm(displayed), isNotNull);
      store.amount = 13000000000;
      store.formatted = '€13.00';
      expect(await source.confirm(displayed), isNotNull);
      expect(store.calls, 1);
      source.reset();
      expect(await source.confirm(displayed), isNull);
      expect(source.cached!.single.storeFormattedPrice, '€13.00');
      store.currency = 'GBP';
      source.reset();
      expect(await source.confirm(displayed), isNull);
    },
  );
  test(
    'missing store result retries store without reloading server products',
    () async {
      var serverCalls = 0;
      final store = Store(BillingProvider.googlePlay)..available = false;
      final source = GemStoreCatalog(
        loadProducts: () async {
          serverCalls++;
          return [product()];
        },
        platform: store,
        namespace: 'test',
        readOwner: () async => 'a',
      );
      final displayed = (await source.load()).single;
      store.available = true;
      expect(await source.confirm(displayed), isNotNull);
      expect(serverCalls, 1);
      expect(store.calls, 1);
      await source.loadForEntry();
      expect(serverCalls, 2);
      expect(store.calls, 2);
    },
  );
}
