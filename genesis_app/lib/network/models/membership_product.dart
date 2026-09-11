import '../../utils/gem_amount.dart';
import '../json_utils.dart';
import 'membership_benefit.dart';
import 'membership_order_product.dart';
import 'membership_purchase.dart';

export 'membership_order_product.dart';

enum MembershipVipStatus {
  none,
  monthly,
  yearly;

  static MembershipVipStatus fromJson(Object? value) => switch (value) {
    'none' || '' => none,
    'monthly' => monthly,
    'yearly' => yearly,
    _ => throw const FormatException('Invalid membership vip_status'),
  };
}

class MembershipProductList {
  const MembershipProductList({
    required this.products,
    required this.vipStatus,
  });

  factory MembershipProductList.fromJson(Map<String, dynamic> json) {
    final list = json['list'];
    if (list is! List || list.any((item) => item is! Map)) {
      throw const FormatException('Invalid membership product list');
    }
    return MembershipProductList(
      vipStatus: MembershipVipStatus.fromJson(json['vip_status']),
      products: List.unmodifiable(
        list.map((item) => MembershipProduct.fromJson(asJsonMap(item))),
      ),
    );
  }

  final List<MembershipProduct> products;
  final MembershipVipStatus vipStatus;

  Map<String, Object?> toJson() => {
    'vip_status': vipStatus.name,
    'list': [for (final product in products) product.toJson()],
  };
}

class MembershipProduct extends MembershipOrderProduct {
  const MembershipProduct({
    required this.title,
    required this.benefits,
    required super.planCode,
    required super.provider,
    required super.storeProductId,
    required this.billingMonths,
    required this.monthlyGemsCent,
    required this.priceCurrencyCode,
    required this.priceAmount,
    this.accountUuid,
    this.upgradePurchaseToken,
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
    if (!((planCode == 'pro_monthly' && months == 1) ||
            (planCode == 'pro_yearly' && months == 12)) ||
        months is! int ||
        storeId.isEmpty ||
        (provider == MembershipProvider.google && basePlan.isEmpty) ||
        gems < 0) {
      throw const FormatException('Invalid membership product configuration');
    }
    final accountUuid = json['account_uuid'];
    final upgradeToken = json['purchase_token'];
    final hasAccountUuid = json.containsKey('account_uuid');
    final hasToken = json.containsKey('purchase_token');
    if (hasAccountUuid &&
        (accountUuid is! String || !isMembershipAccountUuid(accountUuid))) {
      throw const FormatException('Invalid membership account UUID');
    }
    if (hasToken &&
        (provider != MembershipProvider.google ||
            !hasAccountUuid ||
            upgradeToken is! String ||
            upgradeToken.trim().isEmpty ||
            planCode != 'pro_yearly')) {
      throw const FormatException('Invalid membership upgrade credentials');
    }
    return MembershipProduct(
      title: title,
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
      accountUuid: (accountUuid as String?)?.toLowerCase(),
      upgradePurchaseToken: upgradeToken as String?,
    );
  }

  final String title;
  final List<MembershipBenefit> benefits;
  final int billingMonths;
  final int monthlyGemsCent;
  final String priceCurrencyCode;

  /// Preferred purchase identity from the current catalog, for guests or users.
  /// Kept in memory; never included in display/order product snapshots.
  final String? accountUuid;

  /// Original Google token when replacing an existing subscription.
  final String? upgradePurchaseToken;

  /// Full billing cycle price, in hundredths of the currency's main unit.
  final int? priceAmount;

  /// Display metadata only; upgrade credentials must be fetched again at checkout.
  Map<String, Object?> toJson() => {
    'title': title,
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
