import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../network/models/gem_product.dart';
import '../../platform/billing/google_play_billing_platform.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/store_product_access.dart';

/// Display snapshots only; native products and offer tokens are never persisted.
class GemStoreCatalog {
  GemStoreCatalog({
    required this.loadProducts,
    required this.platform,
    required this.namespace,
    required this.readOwner,
  });
  final Future<List<GemProduct>> Function() loadProducts;
  final BillingPlatform platform;
  final String namespace;
  final Future<String?> Function() readOwner;
  List<GemProduct>? cached;
  List<GemProduct>? _serverProducts;
  bool _storeReady = false;
  final Set<String> _storeReadyIds = {};
  int _storeRevision = -1;
  int _generation = 0;
  Future<List<GemProduct>>? _loading;
  Future<List<GemProduct>>? _entryRefresh;
  final ValueNotifier<bool> queryingStore = ValueNotifier(false);
  final ValueNotifier<int> displayRevision = ValueNotifier(0);
  bool _ignorePersistedCache = false;
  DateTime? _loadedAt;
  Future<void> _writes = Future.value();
  void reset() {
    _ignorePersistedCache = false;
    _generation++;
    cached = null;
    _serverProducts = null;
    _storeReady = false;
    _storeReadyIds.clear();
    _loading = null;
    _entryRefresh = null;
    queryingStore.value = false;
    _loadedAt = null;
  }

  String _key(String? owner) =>
      'gem_store_catalog_v1.${Uri.encodeComponent(jsonEncode([namespace, platform.provider.name, owner]))}';
  Future<void> preload() async {
    try {
      if (await readOwner() == null) return;
      if (_loading != null) {
        await _loading;
        return;
      }
      await load();
    } catch (error) {
      debugPrint('[Gems] preload failed: ${error.runtimeType}');
    }
  }

  Future<List<GemProduct>?> loadCached() async {
    if (cached != null) return cached;
    if (_ignorePersistedCache) return null;
    final generation = _generation;
    await _writes;
    final owner = await readOwner();
    if (owner == null) return null;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key(owner));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map;
      final result = <GemProduct>[];
      for (final entry in json['list'] as List) {
        final product = GemProduct.fromJson(
          Map<String, dynamic>.from(entry as Map),
        );
        final price = entry['store_price'];
        final valid =
            price is Map &&
            price['micros'] is int &&
            price['micros'] > 0 &&
            price['currency'] is String &&
            RegExp(r'^[A-Z]{3}$').hasMatch(price['currency']) &&
            price['formatted'] is String &&
            (price['formatted'] as String).trim().isNotEmpty;
        result.add(
          valid
              ? product.withStorePrice(
                  formatted: price['formatted'],
                  micros: price['micros'],
                  currency: price['currency'],
                )
              : product.withStorePrice(),
        );
      }
      if (generation != _generation ||
          _ignorePersistedCache ||
          await readOwner() != owner) {
        return null;
      }
      _serverProducts ??= List.unmodifiable(result);
      return cached ??= List.unmodifiable(result);
    } catch (_) {
      return null;
    }
  }

  Future<List<GemProduct>> load() {
    final pending = _loading;
    if (pending != null) return pending;
    if (_storeReady &&
        cached != null &&
        _storeRevision == StoreProductAccess.revision) {
      return Future.value(cached!);
    }
    final generation = ++_generation;
    final future = _fetch(generation);
    _loading = future;
    return future.whenComplete(() {
      if (identical(_loading, future)) _loading = null;
    });
  }

  Future<List<GemProduct>> loadForEntry() async {
    await loadCached();
    final pending = _entryRefresh;
    if (pending != null) return pending;
    final generation = ++_generation;
    final future = _fetch(generation, refresh: true, allowCachedFallback: true);
    _entryRefresh = _loading = future;
    try {
      return await future;
    } finally {
      if (identical(_entryRefresh, future)) _entryRefresh = null;
      if (identical(_loading, future)) _loading = null;
      if (generation == _generation) queryingStore.value = false;
    }
  }

  /// Entitlement changed: refresh server eligibility, not just store prices.
  /// Purchase completion discards old eligibility even if the refresh fails.
  Future<List<GemProduct>> refreshAfterPurchase() {
    reset();
    _ignorePersistedCache = true;
    final generation = _generation;
    final future = _reloadPurchasedCatalog(generation);
    _loading = future;
    _entryRefresh = future;
    return future.whenComplete(() {
      if (identical(_loading, future)) _loading = null;
      if (identical(_entryRefresh, future)) _entryRefresh = null;
      if (generation == _generation) queryingStore.value = false;
    });
  }

  Future<List<GemProduct>> _reloadPurchasedCatalog(int generation) async {
    final owner = await readOwner();
    await _writes;
    if (owner == null ||
        generation != _generation ||
        await readOwner() != owner) {
      throw StateError('Gem catalog session changed');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(owner));
    if (generation != _generation || await readOwner() != owner) {
      throw StateError('Gem catalog session changed');
    }
    return _fetch(generation, refresh: true);
  }

  Future<List<GemProduct>> _fetch(
    int generation, {
    String? productId,
    bool refresh = false,
    bool allowCachedFallback = false,
  }) async {
    final owner = await readOwner();
    if (owner == null) {
      throw StateError('Gem products require an authenticated session');
    }
    final refreshStore = refresh || _serverProducts == null;
    final List<GemProduct> products;
    try {
      products = refresh
          ? await loadProducts()
          : _serverProducts ?? await loadProducts();
    } catch (error) {
      if (allowCachedFallback &&
          await readOwner() == owner &&
          generation == _generation &&
          cached != null) {
        debugPrint('[Gems] entry refresh failed: ${error.runtimeType}');
        return cached!;
      }
      rethrow;
    }
    if (generation != _generation || await readOwner() != owner) {
      throw StateError('Gem catalog session changed');
    }
    _serverProducts = products;
    if (cached == null) {
      cached = List.unmodifiable(products.map((p) => p.withStorePrice()));
      displayRevision.value++;
    }
    if (refresh) queryingStore.value = true;
    final storeRevision = StoreProductAccess.revision;
    var available = false;
    try {
      available = await platform.isAvailable();
    } catch (_) {}
    GemProduct fallbackPrice(GemProduct product) {
      final previous = (cached ?? const <GemProduct>[]).where(
        (p) =>
            p.productId == product.productId &&
            p.appleProductId == product.appleProductId &&
            p.googleProductId == product.googleProductId &&
            p.googlePurchaseOptionId == product.googlePurchaseOptionId &&
            p.googleOfferId == product.googleOfferId,
      );
      if (previous.length == 1 && previous.single.storeFormattedPrice != null) {
        final old = previous.single;
        return product.withStorePrice(
          formatted: old.storeFormattedPrice,
          micros: old.storeAmountMicros,
          currency: old.storeCurrencyCode,
        );
      }
      return product.withStorePrice();
    }

    Future<List<GemProduct>> query() => Future.wait(
      products.map((product) async {
        if (productId != null && product.productId != productId) {
          for (final previous in cached ?? const <GemProduct>[]) {
            if (previous.productId == product.productId) return previous;
          }
          return fallbackPrice(product);
        }
        if (!available) return fallbackPrice(product);
        try {
          final google = platform.provider == BillingProvider.googlePlay;
          final discount =
              google &&
              product.googlePurchaseOptionId.isNotEmpty &&
              product.googleOfferId.isNotEmpty;
          final response = await platform.queryProduct(
            google ? product.googleProductId : product.appleProductId,
            BillingStoreProductType.inApp,
            purchaseOptionId: discount ? product.googlePurchaseOptionId : null,
            offerId: discount ? product.googleOfferId : null,
          );
          final price = response.product;
          if (price == null ||
              price.priceAmountMicros <= 0 ||
              price.formattedPrice.isEmpty ||
              !RegExp(r'^[A-Z]{3}$').hasMatch(price.priceCurrencyCode)) {
            return fallbackPrice(product);
          }
          return product.withStorePrice(
            formatted: price.formattedPrice,
            micros: price.priceAmountMicros,
            currency: price.priceCurrencyCode,
          );
        } catch (_) {
          return fallbackPrice(product);
        }
      }),
    );
    final result = await (refreshStore
        ? StoreProductAccess.refresh(query)
        : query());
    if (generation == _generation && await readOwner() == owner) {
      cached = List.unmodifiable(result);
      displayRevision.value++;
      if (_storeRevision != storeRevision) _storeReadyIds.clear();
      for (final p in result) {
        if (productId != null && p.productId != productId) continue;
        if (p.storeFormattedPrice != null) {
          _storeReadyIds.add(p.productId);
        } else {
          _storeReadyIds.remove(p.productId);
        }
      }
      _storeReady = result.every((p) => _storeReadyIds.contains(p.productId));
      _ignorePersistedCache = false;
      _storeRevision = storeRevision;
      _loadedAt = DateTime.now();
      final body = jsonEncode({
        'cached_at': _loadedAt!.toUtc().toIso8601String(),
        'list': [
          for (final p in result)
            {
              ...p.toJson(),
              if (p.storeFormattedPrice != null)
                'store_price': {
                  'formatted': p.storeFormattedPrice,
                  'micros': p.storeAmountMicros,
                  'currency': p.storeCurrencyCode,
                },
            },
        ],
      });
      _writes = _writes
          .then((_) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_key(owner), body);
          })
          .catchError((Object error) {
            debugPrint('[Gems] cache write failed: ${error.runtimeType}');
          });
    }
    return result;
  }

  Future<GemProduct?> confirm(GemProduct displayed) async {
    final owner = await readOwner();
    bool isReady() =>
        _storeRevision == StoreProductAccess.revision &&
        _storeReadyIds.contains(displayed.productId);
    while (!isReady()) {
      final pending = _loading;
      if (pending == null) break;
      await pending;
      if (await readOwner() != owner) return null;
    }
    // A page preload may have prepared this SKU while the click was waiting.
    // Recheck before starting another store lookup.
    final ready = isReady();
    late final Future<List<GemProduct>> loading;
    if (ready && cached != null) {
      loading = Future.value(cached!);
    } else if (_serverProducts == null) {
      loading = load();
    } else {
      final future = _fetch(++_generation, productId: displayed.productId);
      _loading = future;
      loading = future.whenComplete(() {
        if (identical(_loading, future)) _loading = null;
      });
    }
    final generation = _generation;
    final products = await loading;
    if ((!ready && _generation != generation) || await readOwner() != owner) {
      return null;
    }
    for (final p in products) {
      if (p.productId == displayed.productId &&
          p.canPurchase &&
          p.storeFormattedPrice != null &&
          p.displaysStorePrice == displayed.displaysStorePrice &&
          (p.displaysStorePrice
              ? p.storeAmountMicros == displayed.storeAmountMicros &&
                    p.storeCurrencyCode == displayed.storeCurrencyCode
              : p.priceAmount == displayed.priceAmount &&
                    p.priceCurrencyCode == displayed.priceCurrencyCode) &&
          p.appleProductId == displayed.appleProductId &&
          p.googleProductId == displayed.googleProductId &&
          p.googleOfferId == displayed.googleOfferId &&
          p.googlePurchaseOptionId == displayed.googlePurchaseOptionId &&
          p.baseGemsCent == displayed.baseGemsCent &&
          p.bonusGemsCent == displayed.bonusGemsCent &&
          p.billingType == displayed.billingType) {
        return p;
      }
    }
    return null;
  }
}
