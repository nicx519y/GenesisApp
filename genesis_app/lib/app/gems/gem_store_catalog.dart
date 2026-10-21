import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../network/models/gem_product.dart';
import '../../platform/billing/google_play_billing_platform.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/store_query_cache.dart';

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
  DateTime? _loadedAt;
  Future<void> _writes = Future.value();
  void reset() {
    _generation++;
    cached = null;
    _serverProducts = null;
    _storeReady = false;
    _storeReadyIds.clear();
    _loading = null;
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
      if (generation != _generation || await readOwner() != owner) return null;
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
        _storeRevision == StoreQueryCache.revision) {
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
    return load();
  }

  Future<List<GemProduct>> _fetch(int generation, {String? productId}) async {
    final owner = await readOwner();
    if (owner == null) {
      throw StateError('Gem products require an authenticated session');
    }
    final products = _serverProducts ?? await loadProducts();
    if (generation != _generation || await readOwner() != owner) {
      throw StateError('Gem catalog session changed');
    }
    _serverProducts = products;
    final storeRevision = StoreQueryCache.revision;
    var available = false;
    try {
      available = await platform.isAvailable();
    } catch (_) {}
    final result = await Future.wait(
      products.map((product) async {
        if (productId != null && product.productId != productId) {
          for (final previous in cached ?? const <GemProduct>[]) {
            if (previous.productId == product.productId) return previous;
          }
          return product.withStorePrice();
        }
        if (!available) return product.withStorePrice();
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
            return product.withStorePrice();
          }
          return product.withStorePrice(
            formatted: price.formattedPrice,
            micros: price.priceAmountMicros,
            currency: price.priceCurrencyCode,
          );
        } catch (_) {
          return product.withStorePrice();
        }
      }),
    );
    if (generation == _generation && await readOwner() == owner) {
      cached = List.unmodifiable(result);
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
    await _loading;
    final ready =
        _storeRevision == StoreQueryCache.revision &&
        _storeReadyIds.contains(displayed.productId);
    final loading = ready && cached != null
        ? Future.value(cached!)
        : _serverProducts == null
        ? load()
        : _fetch(++_generation, productId: displayed.productId);
    final generation = _generation;
    final products = await loading;
    if (_generation != generation || await readOwner() != owner) {
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
