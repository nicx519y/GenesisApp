import '../json_utils.dart';
import '../../utils/gem_amount.dart';
import '../../utils/store_price_display_policy.dart';

class GemProductList {
  const GemProductList({required this.products});

  factory GemProductList.fromJson(Map<String, dynamic> json) {
    final products = json['list'] is List
        ? (json['list'] as List)
              .whereType<Map>()
              .map((item) => GemProduct.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemProduct>[];
    return GemProductList(products: products);
  }

  final List<GemProduct> products;
}

class GemProduct {
  const GemProduct({
    required this.productId,
    required this.appleProductId,
    required this.googleProductId,
    required this.baseGemsCent,
    required this.bonusGemsCent,
    required this.priceCurrencyCode,
    required this.priceAmount,
    required this.canPurchase,
    required this.activityType,
    this.activityText = '',
    this.activityColor = '',
    this.billingType = 'consumable',
    this.googlePurchaseOptionId = '',
    this.googleOfferId = '',
    this.storeFormattedPrice,
    this.storeAmountMicros,
    this.storeCurrencyCode,
    this.storeCurrencySymbol,
    this.requiresStorePrice = false,
  });

  factory GemProduct.fromJson(Map<String, dynamic> json) {
    final activityExt = json['activity_ext'] is Map
        ? asJsonMap(json['activity_ext'])
        : const <String, dynamic>{};
    return GemProduct(
      productId: asString(json['product_id']),
      appleProductId: asString(json['apple_product_id']),
      googleProductId: asString(json['google_product_id']),
      baseGemsCent: requireGemCent(
        json['base_gems_cent'],
        fieldName: 'base_gems_cent',
      ),
      bonusGemsCent: requireGemCent(
        json['bonus_gems_cent'],
        fieldName: 'bonus_gems_cent',
      ),
      priceCurrencyCode: asString(
        json['price_currency_code'],
        fallback: 'USD',
      ).toUpperCase(),
      priceAmount: asInt(json['price_amount']),
      canPurchase: asBool(json['can_purchase'], fallback: true),
      activityType: asString(json['activity_type'], fallback: 'none'),
      activityText: asString(json['activity_text']),
      activityColor: asString(json['activity_color']),
      billingType: asString(
        json['billing_type'],
        fallback: 'consumable',
      ).toLowerCase(),
      googlePurchaseOptionId: asString(
        activityExt['google_purchase_option_id'] ??
            json['google_purchase_option_id'] ??
            json['purchase_option_id'],
      ),
      googleOfferId: asString(
        activityExt['google_offer_id'] ??
            json['google_offer_id'] ??
            json['offer_id'],
      ),
    );
  }

  final String productId;
  final String appleProductId;
  final String googleProductId;
  final int baseGemsCent;
  final int bonusGemsCent;
  final String priceCurrencyCode;
  final int priceAmount;
  final bool canPurchase;
  final String activityType;
  final String activityText;
  final String activityColor;
  final String billingType;
  final String googlePurchaseOptionId;
  final String googleOfferId;

  final String? storeFormattedPrice;
  final int? storeAmountMicros;
  final String? storeCurrencyCode;
  final String? storeCurrencySymbol;
  final bool requiresStorePrice;

  bool get displaysStorePrice =>
      storeFormattedPrice != null && useStorePriceForDisplay(storeCurrencyCode);

  Map<String, Object?> toJson() => {
    'product_id': productId,
    'apple_product_id': appleProductId,
    'google_product_id': googleProductId,
    'base_gems_cent': baseGemsCent,
    'bonus_gems_cent': bonusGemsCent,
    'price_currency_code': priceCurrencyCode,
    'price_amount': priceAmount,
    'can_purchase': canPurchase,
    'activity_type': activityType,
    'activity_text': activityText,
    'activity_color': activityColor,
    'billing_type': billingType,
    'google_purchase_option_id': googlePurchaseOptionId,
    'google_offer_id': googleOfferId,
  };

  GemProduct withStorePrice({
    String? formatted,
    int? micros,
    String? currency,
    String? symbol,
  }) => GemProduct(
    productId: productId,
    appleProductId: appleProductId,
    googleProductId: googleProductId,
    baseGemsCent: baseGemsCent,
    bonusGemsCent: bonusGemsCent,
    priceCurrencyCode: priceCurrencyCode,
    priceAmount: priceAmount,
    canPurchase: canPurchase,
    activityType: activityType,
    activityText: activityText,
    activityColor: activityColor,
    billingType: billingType,
    googlePurchaseOptionId: googlePurchaseOptionId,
    googleOfferId: googleOfferId,
    storeFormattedPrice: formatted,
    storeAmountMicros: micros,
    storeCurrencyCode: currency,
    storeCurrencySymbol: symbol,
    requiresStorePrice: true,
  );

  int get totalGemsCent => baseGemsCent + bonusGemsCent;

  String get tagText => activityText.trim();
}
