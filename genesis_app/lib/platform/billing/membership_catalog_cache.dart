import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../network/models/membership_product.dart';
import 'membership_product_store.dart';

class MembershipCatalogSnapshot {
  const MembershipCatalogSnapshot(this.products, this.prices);
  final MembershipProductList products;
  final Map<String, MembershipStorePrice> prices;
}

/// Display snapshots only. Purchase identities are excluded by MembershipProductList.toJson.
class MembershipCatalogCache {
  MembershipCatalogCache({required this.namespace});

  final String namespace;
  Future<void> _writes = Future.value();

  String _key(MembershipProvider provider, String? ownerUid) =>
      'membership_catalog_v3.${Uri.encodeComponent(jsonEncode([namespace, provider.name, ownerUid]))}';

  Future<MembershipProductList?> load(
    MembershipProvider provider,
    String? ownerUid,
  ) async => (await loadSnapshot(provider, ownerUid))?.products;

  Future<MembershipCatalogSnapshot?> loadSnapshot(
    MembershipProvider provider,
    String? ownerUid,
  ) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(provider, ownerUid));
    if (raw == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final products = MembershipProductList.fromJson(json);
      final prices = <String, MembershipStorePrice>{};
      final cachedPrices = json['store_prices'];
      if (cachedPrices is Map) {
        for (final product in products.products) {
          try {
            final entry = cachedPrices[product.planCode];
            if (entry is! Map ||
                entry['store_product_id'] != product.storeProductId ||
                entry['base_plan_id'] != product.basePlanId ||
                entry['offer_id'] != product.offerId ||
                entry['billing_months'] != product.billingMonths) {
              continue;
            }
            final amount = entry['amount_micros'];
            final currency = entry['currency_code'];
            final formatted = entry['formatted_price'];
            final symbol = entry['currency_symbol'];
            if (amount is! int ||
                amount <= 0 ||
                currency is! String ||
                !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
                formatted is! String ||
                formatted.trim().isEmpty ||
                symbol is! String) {
              continue;
            }
            prices[product.planCode] = MembershipStorePrice(
              formattedPrice: formatted,
              amountMicros: amount,
              currencyCode: currency,
              currencySymbol: symbol,
              hasIntroductoryPrice: entry['has_introductory_price'] == true,
            );
          } catch (_) {
            // A corrupt price does not discard the remaining display catalog.
          }
        }
      }
      return MembershipCatalogSnapshot(products, Map.unmodifiable(prices));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    MembershipProvider provider,
    String? ownerUid,
    MembershipProductList products, {
    Map<String, MembershipStorePrice> prices = const {},
  }) {
    final body = jsonEncode({
      ...products.toJson(),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'store_prices': {
        for (final product in products.products)
          if (prices[product.planCode] case final price?)
            product.planCode: {
              'store_product_id': product.storeProductId,
              'base_plan_id': product.basePlanId,
              'offer_id': product.offerId,
              'billing_months': product.billingMonths,
              'formatted_price': price.formattedPrice,
              'amount_micros': price.amountMicros,
              'currency_code': price.currencyCode,
              'currency_symbol': price.currencySymbol,
              'has_introductory_price': price.hasIntroductoryPrice,
            },
      },
    });
    final operation = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(provider, ownerUid), body);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}
