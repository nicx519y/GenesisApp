import '../../utils/gem_amount.dart';
import '../json_utils.dart';
import 'membership_benefit.dart';
import 'membership_order_product.dart';
import 'membership_purchase.dart';

export 'membership_order_product.dart';

class MembershipProductList {
  const MembershipProductList({
    required this.products,
    this.lastAccountUuid,
    this.hasSubscriptionOrder = false,
    this.deluxeProducts = const [],
    this.lastAccountUuidDeluxe,
    this.hasPurchased = false,
  });

  factory MembershipProductList.fromJson(Map<String, dynamic> json) {
    final list = json['list_premium'];
    if (list is! List || list.any((item) => item is! Map)) {
      throw const FormatException('Invalid membership product list');
    }
    final rawDeluxe = json['list_deluxe'] ?? const [];
    if (rawDeluxe is! List || rawDeluxe.any((item) => item is! Map)) {
      throw const FormatException('Invalid Deluxe product list');
    }
    final rawDeluxeUuid = json['last_account_uuid_deluxe'];
    if (rawDeluxeUuid != null && rawDeluxeUuid is! String) {
      throw const FormatException('Invalid Deluxe UUID');
    }
    final deluxeUuid = (rawDeluxeUuid as String?)?.trim().toLowerCase();
    if (deluxeUuid != null &&
        deluxeUuid.isNotEmpty &&
        !isMembershipAccountUuid(deluxeUuid)) {
      throw const FormatException('Invalid Deluxe UUID');
    }
    if (json['has_purchased'] != null && json['has_purchased'] is! bool) {
      throw const FormatException('Invalid purchase history flag');
    }
    final rawUuid = json['last_account_uuid'];
    if (rawUuid != null && rawUuid is! String) {
      throw const FormatException('Invalid membership last account UUID');
    }
    final uuid = (rawUuid as String?)?.trim().toLowerCase();
    if (uuid != null && uuid.isNotEmpty && !isMembershipAccountUuid(uuid)) {
      throw const FormatException('Invalid membership last account UUID');
    }
    final hasSubscriptionOrder = json['has_subscription_order'];
    if (hasSubscriptionOrder != null && hasSubscriptionOrder is! bool) {
      throw const FormatException('Invalid membership subscription order flag');
    }
    return MembershipProductList(
      lastAccountUuid: uuid == null || uuid.isEmpty ? null : uuid,
      lastAccountUuidDeluxe: deluxeUuid == null || deluxeUuid.isEmpty
          ? null
          : deluxeUuid,
      hasPurchased: json['has_purchased'] == true,
      deluxeProducts: List.unmodifiable(
        rawDeluxe.map((item) => MembershipProduct.fromJson(asJsonMap(item))),
      ),
      hasSubscriptionOrder: hasSubscriptionOrder == true,
      products: List.unmodifiable(
        list.map((item) => MembershipProduct.fromJson(asJsonMap(item))),
      ),
    );
  }

  final List<MembershipProduct> products;
  final List<MembershipProduct> deluxeProducts;
  final String? lastAccountUuidDeluxe;
  final bool hasPurchased;
  List<MembershipProduct> get allProducts => [...products, ...deluxeProducts];
  String? accountUuidFor(MembershipType type) =>
      type == MembershipType.deluxe ? lastAccountUuidDeluxe : lastAccountUuid;

  /// Store identity from the current response, shared by all plans.
  final String? lastAccountUuid;

  /// Current response's order flag, shared by all plans.
  final bool hasSubscriptionOrder;

  /// Display cache only. Checkout fields must come from a live catalog load.
  Map<String, Object?> toJson() => {
    'list_premium': [for (final product in products) product.toJson()],
    if (deluxeProducts.isNotEmpty)
      'list_deluxe': [for (final product in deluxeProducts) product.toJson()],
    if (hasPurchased) 'has_purchased': true,
  };
}

class MembershipProduct extends MembershipOrderProduct {
  const MembershipProduct({
    required this.title,
    required this.benefits,
    this.monthlyGemsTotal,
    this.monthlyBonusGems,
    this.dailyCheckInBonusGems,
    required super.planCode,
    required super.provider,
    required super.storeProductId,
    required this.billingMonths,
    required this.monthlyGemsCent,
    required this.priceCurrencyCode,
    required this.priceAmount,
    super.basePlanId,
    super.offerId,
  });

  factory MembershipProduct.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Invalid membership product title');
    }
    final rawBenefits = json['benefits'];
    if (rawBenefits is! List || rawBenefits.any((item) => item is! Map)) {
      throw const FormatException('Invalid membership benefits');
    }
    final benefits = rawBenefits
        .map((item) => MembershipBenefit.fromJson(asJsonMap(item)))
        .toList();
    if (benefits.map((benefit) => benefit.code).toSet().length !=
        benefits.length) {
      throw const FormatException('Duplicate membership benefit code');
    }
    final planCode = asString(json['plan_code']);
    final provider = switch (json['provider']) {
      'apple' => MembershipProvider.apple,
      'google' => MembershipProvider.google,
      _ => throw const FormatException('Invalid membership provider'),
    };
    final months = json['billing_months'];
    final gems = requireGemCent(
      json['monthly_gems_cent'],
      fieldName: 'monthly_gems_cent',
    );
    final storeId = asString(json['store_product_id']).trim();
    final basePlan = asString(json['base_plan_id']).trim();
    final currency = json['price_currency_code'];
    final amount = json['price_amount'];
    if (currency is! String ||
        !json.containsKey('price_amount') ||
        !RegExp(r'^([A-Z]{3})?$').hasMatch(currency) ||
        (amount != null && (amount is! int || amount <= 0)) ||
        (currency.isEmpty != (amount == null))) {
      throw const FormatException('Invalid membership display price');
    }
    if (!((const ['pro_monthly', 'deluxe_monthly'].contains(planCode) &&
                months == 1) ||
            (const ['pro_yearly', 'deluxe_yearly'].contains(planCode) &&
                months == 12)) ||
        months is! int ||
        storeId.isEmpty ||
        (provider == MembershipProvider.google && basePlan.isEmpty) ||
        gems < 0) {
      throw const FormatException('Invalid membership product configuration');
    }
    return MembershipProduct(
      title: title,
      monthlyGemsTotal: MembershipGemsTotal.fromJson(
        json['monthly_gems_total'],
      ),
      monthlyBonusGems: MembershipGemsCard.fromJson(json['monthly_bonus_gems']),
      dailyCheckInBonusGems: MembershipGemsCard.fromJson(
        json['daily_check_in_bonus_gems'],
      ),
      benefits: List.unmodifiable(benefits),
      planCode: planCode,
      provider: provider,
      storeProductId: storeId,
      basePlanId: basePlan,
      offerId: asString(json['offer_id']).trim(),
      billingMonths: months,
      monthlyGemsCent: gems,
      priceCurrencyCode: currency,
      priceAmount: amount as int?,
    );
  }

  final String title;
  final MembershipGemsTotal? monthlyGemsTotal;
  final MembershipGemsCard? monthlyBonusGems;
  final MembershipGemsCard? dailyCheckInBonusGems;
  final List<MembershipBenefit> benefits;
  final int billingMonths;
  final int monthlyGemsCent;
  final String priceCurrencyCode;

  /// Full billing cycle price, in hundredths of the currency's main unit.
  final int? priceAmount;

  /// Display metadata only; checkout uses credentials from the page's API load.
  Map<String, Object?> toJson() => {
    'title': title,
    if (monthlyGemsTotal != null)
      'monthly_gems_total': monthlyGemsTotal!.toJson(),
    if (monthlyBonusGems != null)
      'monthly_bonus_gems': monthlyBonusGems!.toJson(),
    if (dailyCheckInBonusGems != null)
      'daily_check_in_bonus_gems': dailyCheckInBonusGems!.toJson(),
    'benefits': [for (final benefit in benefits) benefit.toJson()],
    'provider': provider.name,
    'plan_code': planCode,
    'store_product_id': storeProductId,
    if (provider == MembershipProvider.google) 'base_plan_id': basePlanId,
    if (offerId.isNotEmpty) 'offer_id': offerId,
    'billing_months': billingMonths,
    'monthly_gems_cent': monthlyGemsCent,
    'price_currency_code': priceCurrencyCode,
    'price_amount': priceAmount,
  };

  @override
  bool get isYearly => billingMonths == 12;
  String get label => isYearly ? 'Yearly' : 'Monthly';
}

class MembershipGemsTotal {
  const MembershipGemsTotal({
    required this.title,
    required this.amount,
    required this.iconKey,
  });

  static MembershipGemsTotal? fromJson(Object? value) {
    if (value == null) return null;
    final json = asJsonMap(value);
    return MembershipGemsTotal(
      title: asString(json['title']),
      amount: asString(json['amount']),
      iconKey: asString(json['icon_key']),
    );
  }

  final String title;
  final String amount;
  final String iconKey;

  Map<String, Object?> toJson() => {
    'title': title,
    'amount': amount,
    'icon_key': iconKey,
  };
}

class MembershipGemsCard {
  const MembershipGemsCard({
    required this.value,
    this.valueSuffix = '',
    required this.title,
    required this.description,
    required this.iconKey,
  });

  static MembershipGemsCard? fromJson(Object? value) {
    if (value == null) return null;
    final json = asJsonMap(value);
    return MembershipGemsCard(
      value: asString(json['value']),
      valueSuffix: asString(json['value_suffix']),
      title: asString(json['title']),
      description: asString(json['description']),
      iconKey: asString(json['icon_key']),
    );
  }

  final String value;
  final String valueSuffix;
  final String title;
  final String description;
  final String iconKey;

  Map<String, Object?> toJson() => {
    'value': value,
    if (valueSuffix.isNotEmpty) 'value_suffix': valueSuffix,
    'title': title,
    'description': description,
    'icon_key': iconKey,
  };
}
