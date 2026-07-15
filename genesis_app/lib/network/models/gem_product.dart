import '../json_utils.dart';

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
    required this.baseGems,
    required this.bonusGems,
    required this.priceCurrencyCode,
    required this.priceAmount,
    required this.canPurchase,
    required this.activityType,
    this.activityText = '',
    this.activityColor = '',
    this.billingType = 'consumable',
    this.googlePurchaseOptionId = '',
    this.googleOfferId = '',
  });

  factory GemProduct.fromJson(Map<String, dynamic> json) {
    final activityExt = json['activity_ext'] is Map
        ? asJsonMap(json['activity_ext'])
        : const <String, dynamic>{};
    return GemProduct(
      productId: asString(json['product_id']),
      appleProductId: asString(json['apple_product_id']),
      googleProductId: asString(json['google_product_id']),
      baseGems: asInt(json['base_gems']),
      bonusGems: asInt(json['bonus_gems']),
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
  final int baseGems;
  final int bonusGems;
  final String priceCurrencyCode;
  final int priceAmount;
  final bool canPurchase;
  final String activityType;
  final String activityText;
  final String activityColor;
  final String billingType;
  final String googlePurchaseOptionId;
  final String googleOfferId;

  int get totalGems => baseGems + bonusGems;

  String get tagText => activityText.trim();
}
