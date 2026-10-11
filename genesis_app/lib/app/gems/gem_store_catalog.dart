import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../network/models/gem_product.dart';
import '../../platform/billing/google_play_billing_platform.dart';
import '../../platform/billing/billing_models.dart';

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
  int _generation = 0;
  Future<List<GemProduct>>? _loading;
  DateTime? _loadedAt;
  Future<void> _writes = Future.value();
  void reset() {
    _generation++;
    cached = null;
    _loading = null;
    _loadedAt = null;
  }

  String _key(String? owner) =>
      'gem_store_catalog_v1.${Uri.encodeComponent(jsonEncode([namespace, platform.provider.name, owner]))}';
  Future<void> preload() async {
    try {
      if (_loading != null) {
        await _loading;
        return;
      }
      if (cached != null &&
          cached!.every((p) => p.storeFormattedPrice != null) &&
          _loadedAt != null &&
          DateTime.now().difference(_loadedAt!) < const Duration(minutes: 1)) {
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
      return cached ??= List.unmodifiable(result);
    } catch (_) {
      return null;
    }
  }

  Future<List<GemProduct>> load() {
    final generation = ++_generation;
    final future = _fetch(generation);
    _loading = future;
    return future.whenComplete(() {
      if (identical(_loading, future)) _loading = null;
    });
  }

  Future<List<GemProduct>> _fetch(int generation) async {
    final owner = await readOwner();
    final products = await loadProducts();
    var available = false;
    try {
      available = await platform.isAvailable();
    } catch (_) {}
    final result = await Future.wait(
      products.map((product) async {
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
    final expectedGeneration = _generation + 1;
    final products = await load();
    if (_generation != expectedGeneration || await readOwner() != owner) {
      return null;
    }
    for (final p in products) {
      if (p.productId == displayed.productId &&
          p.canPurchase &&
          p.storeFormattedPrice != null &&
          p.storeAmountMicros == displayed.storeAmountMicros &&
          p.storeCurrencyCode == displayed.storeCurrencyCode &&
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
