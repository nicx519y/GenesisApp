import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../network/models/membership_product.dart';
import '../../platform/billing/membership_catalog_cache.dart';

class MembershipPlatformUnavailable implements Exception {}

class MembershipOffer {
  const MembershipOffer({required this.product});
  final MembershipProduct product;
  MembershipDisplayPrice? get price => product.priceAmount == null
      ? null
      : MembershipDisplayPrice(
          amountCent: product.priceAmount!,
          currencyCode: product.priceCurrencyCode,
        );
  bool get available => price != null;
}

class MembershipDisplayPrice {
  const MembershipDisplayPrice({
    required this.amountCent,
    required this.currencyCode,
  });
  final int amountCent;
  final String currencyCode;

  String get formattedPrice => NumberFormat.simpleCurrency(
    name: currencyCode,
    decimalDigits: 2,
  ).format(amountCent / 100);
}

class MembershipCatalogData {
  const MembershipCatalogData({this.offers = const []});
  final List<MembershipOffer> offers;
}

typedef MembershipCatalogLoader = Future<MembershipCatalogData> Function();

class MembershipCatalog {
  MembershipCatalog({
    required this.loadProducts,
    required this.provider,
    this.cacheStore,
    this.readOwnerUid,
  });

  final Future<MembershipProductList> Function(MembershipProvider provider)
  loadProducts;
  final MembershipProvider? provider;
  final MembershipCatalogCache? cacheStore;
  final Future<String?> Function()? readOwnerUid;
  MembershipCatalogData? _cached;
  MembershipProductList? _checkoutProducts;
  String? _checkoutOwner;
  Future<MembershipCatalogData>? _loading;
  int _session = 0;
  int _loadGeneration = 0;

  MembershipCatalogData? get cached => _cached;

  void resetForSession() {
    _session++;
    _loadGeneration++;
    _cached = null;
    _checkoutProducts = null;
    _checkoutOwner = null;
    _loading = null;
  }

  Future<MembershipCatalogData?> loadCached() async {
    if (_cached != null) return _cached;
    final platform = provider;
    if (platform == null || cacheStore == null) return null;
    final session = _session;
    try {
      final owner = await readOwnerUid?.call();
      final response = await cacheStore!.load(platform, owner);
      if (session != _session) return null;
      // A slow disk read must not replace an already returned API response.
      if (_cached != null) return _cached;
      if (response == null) return null;
      return _cached = _catalog(response, platform);
    } catch (error) {
      debugPrint(
        '[Membership] catalog cache read failed: ${error.runtimeType}',
      );
      return null;
    }
  }

  static MembershipProvider? get currentProvider => kIsWeb
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => MembershipProvider.google,
          TargetPlatform.iOS => MembershipProvider.apple,
          _ => null,
        };

  Future<MembershipCatalogData> load() {
    final generation = ++_loadGeneration;
    _checkoutProducts = null;
    _checkoutOwner = null;
    return _loading = _load(_session, generation);
  }

  /// Reuses the page's API response, including its in-memory upgrade credentials.
  /// Disk/display cache alone cannot prepare a purchase. Never starts a request.
  Future<MembershipProductList> readCheckoutProducts() async {
    final session = _session;
    final generation = _loadGeneration;
    await _loading;
    final owner = await readOwnerUid?.call();
    final products = _checkoutProducts;
    if (session != _session ||
        generation != _loadGeneration ||
        owner != _checkoutOwner ||
        products == null) {
      throw StateError('membership_catalog_unavailable');
    }
    return products;
  }

  Future<MembershipCatalogData> _load(int session, int generation) async {
    try {
      return await _fetch(session, generation);
    } finally {
      if (session == _session && generation == _loadGeneration) {
        _loading = null;
      }
    }
  }

  Future<MembershipCatalogData> _fetch(int session, int generation) async {
    final platform = provider;
    if (platform == null) throw MembershipPlatformUnavailable();
    final owner = await readOwnerUid?.call();
    final response = await loadProducts(platform);
    final result = _catalog(response, platform);
    if (session == _session && generation == _loadGeneration) {
      _checkoutProducts = MembershipProductList(
        products: List.unmodifiable(response.products),
      );
      _checkoutOwner = owner;
      // Cache display fields without account UUIDs or upgrade purchase tokens.
      _cached = _catalog(
        MembershipProductList(
          products: [
            for (final product in response.products)
              MembershipProduct.fromJson(
                Map<String, dynamic>.from(product.toJson()),
              ),
          ],
        ),
        platform,
      );
      unawaited(_saveCache(platform, owner, response));
    }
    return result;
  }

  Future<void> _saveCache(
    MembershipProvider platform,
    String? owner,
    MembershipProductList products,
  ) async {
    try {
      await cacheStore?.save(platform, owner, products);
    } catch (error) {
      debugPrint(
        '[Membership] catalog cache write failed: ${error.runtimeType}',
      );
    }
  }

  MembershipCatalogData _catalog(
    MembershipProductList response,
    MembershipProvider platform,
  ) {
    final products = response.products.toList();
    if (products.any((product) => product.provider != platform) ||
        products.map((product) => product.planCode).toSet().length !=
            products.length) {
      throw const FormatException('Invalid membership catalog');
    }
    products.sort((a, b) => b.billingMonths.compareTo(a.billingMonths));
    return MembershipCatalogData(
      offers: List.unmodifiable([
        for (final product in products) MembershipOffer(product: product),
      ]),
    );
  }
}

int? membershipYearlySavings(
  MembershipOffer yearly,
  List<MembershipOffer> offers,
) {
  if (yearly.price == null || !yearly.product.isYearly) {
    return null;
  }
  for (final monthly in offers) {
    if (monthly.price == null ||
        monthly.product.isYearly ||
        monthly.price!.currencyCode != yearly.price!.currencyCode ||
        monthly.product.monthlyGemsCent != yearly.product.monthlyGemsCent) {
      continue;
    }
    final fullYear = monthly.price!.amountCent * 12;
    if (fullYear <= yearly.price!.amountCent) return null;
    final savings = ((fullYear - yearly.price!.amountCent) * 100 / fullYear)
        .round();
    return savings > 0 && savings < 100 ? savings : null;
  }
  return null;
}
