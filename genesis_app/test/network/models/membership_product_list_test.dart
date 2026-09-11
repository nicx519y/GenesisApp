import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';

void main() {
  const benefit = {
    'code': 'server_benefit',
    'title': 'Server title',
    'icon_key': 'future_icon',
    'display_type': 'included',
  };
  const product = {
    'title': 'Server monthly title',
    'benefits': [benefit],
    'provider': 'apple',
    'plan_code': 'pro_monthly',
    'store_product_id': 'test_month',
    'billing_months': 1,
    'monthly_gems_cent': 30000,
    'price_currency_code': 'USD',
    'price_amount': 1234,
  };
  for (final raw in ['none', '', 'monthly', 'yearly']) {
    test('root vip_status=$raw is parsed and cached', () {
      final parsed = MembershipProductList.fromJson({
        'vip_status': raw,
        'list': [product],
      });
      expect(parsed.vipStatus.name, raw.isEmpty ? 'none' : raw);
      expect(parsed.toJson()['vip_status'], raw.isEmpty ? 'none' : raw);
      expect(parsed.products.single.toJson(), isNot(contains('vip_status')));
    });
  }
  test('missing or invalid root status never authorizes a purchase', () {
    for (final raw in [null, 'active', false, 1]) {
      expect(
        () => MembershipProductList.fromJson({
          'vip_status': raw,
          'list': [product],
        }),
        throwsFormatException,
      );
    }
    expect(
      () => MembershipProductList.fromJson({
        'list': [product],
      }),
      throwsFormatException,
    );
  });
  test('obsolete eligibility fields cannot override root status', () {
    final parsed = MembershipProductList.fromJson({
      'vip_status': 'none',
      'list': [
        {
          ...product,
          'can_purchase': false,
          'purchase_block_reason': 'already_subscribed',
        },
      ],
    });
    expect(parsed.vipStatus, MembershipVipStatus.none);
    expect(parsed.products.single.toJson(), product);
  });
  test(
    'catalog identity and upgrade proof are optional and never serialized',
    () {
      const uuid = '8b74ec68-7abc-4cce-a223-e997e31dc811';
      final yearly = {
        ...product,
        'plan_code': 'pro_yearly',
        'billing_months': 12,
      };
      final google = {
        ...yearly,
        'provider': 'google',
        'base_plan_id': 'yearly',
      };
      final appleUpgrade = MembershipProduct.fromJson({
        ...yearly,
        'account_uuid': uuid,
      });
      final googleUpgrade = MembershipProduct.fromJson({
        ...google,
        'account_uuid': uuid.toUpperCase(),
        'purchase_token': 'old-token',
      });
      expect(appleUpgrade.accountUuid, uuid);
      expect(appleUpgrade.upgradePurchaseToken, isNull);
      expect(googleUpgrade.accountUuid, uuid);
      expect(googleUpgrade.upgradePurchaseToken, 'old-token');
      for (final parsed in [appleUpgrade, googleUpgrade]) {
        expect(parsed.toJson(), isNot(contains('account_uuid')));
        expect(parsed.toJson(), isNot(contains('purchase_token')));
        expect(parsed.toOrderJson(), isNot(contains('account_uuid')));
        expect(parsed.toOrderJson(), isNot(contains('purchase_token')));
      }
      expect(MembershipProduct.fromJson(google).accountUuid, isNull);
      for (final allowed in [
        {...google, 'account_uuid': uuid},
        {...product, 'account_uuid': uuid},
      ]) {
        expect(MembershipProduct.fromJson(allowed).accountUuid, uuid);
      }
      for (final invalid in [
        {...google, 'purchase_token': 'old-token'},
        {...google, 'account_uuid': uuid, 'purchase_token': ''},
        {...google, 'account_uuid': uuid, 'purchase_token': null},
        {...google, 'account_uuid': null, 'purchase_token': 'old-token'},
        {...yearly, 'account_uuid': 'invalid'},
        {...yearly, 'account_uuid': ''},
        {...yearly, 'account_uuid': null},
        {...yearly, 'account_uuid': uuid, 'purchase_token': 'old-token'},
        {
          ...google,
          'plan_code': 'pro_monthly',
          'billing_months': 1,
          'account_uuid': uuid,
          'purchase_token': 'old-token',
        },
      ]) {
        expect(
          () => MembershipProduct.fromJson(invalid),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'Google catalog still requires and preserves the checkout base plan',
    () {
      final google = {
        ...product,
        'provider': 'google',
        'base_plan_id': 'test-month',
      };
      expect(MembershipProduct.fromJson(google).basePlanId, 'test-month');
      expect(
        MembershipProduct.fromJson(google).toJson()['base_plan_id'],
        'test-month',
      );
      for (final value in [null, '', '   ']) {
        expect(
          () => MembershipProduct.fromJson({...google, 'base_plan_id': value}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'list and account status parse with per-product titles and benefits',
    () {
      expect(
        MembershipProductList.fromJson({
          'vip_status': 'none',
          'list': [],
        }).products,
        isEmpty,
      );
      final result = MembershipProductList.fromJson({
        'vip_status': 'none',
        'list': [product],
      });
      expect(result.products.single.title, 'Server monthly title');
      expect(result.products.single.benefits.single.title, 'Server title');
      expect(
        MembershipProduct.fromJson({...product, 'benefits': []}).benefits,
        isEmpty,
      );
    },
  );
  test('purchase action is ignored and never serialized', () {
    for (final action in [
      'purchase',
      'upgrade',
      'none',
      'unknown',
      null,
      123,
    ]) {
      final parsed = MembershipProductList.fromJson({
        'vip_status': 'none',
        'list': [
          {...product, 'purchase_action': action},
        ],
      }).products.single;
      expect(parsed.toJson(), product);
    }
  });
  test('top-level benefits cannot replace missing product metadata', () {
    for (final field in ['title', 'benefits']) {
      final missing = Map<String, Object?>.from(product)..remove(field);
      expect(
        () => MembershipProductList.fromJson({
          'vip_status': 'none',
          'list': [missing],
          'title': 'Old title',
          'benefits': [benefit],
        }),
        throwsFormatException,
      );
    }
  });
  test(
    'unknown icons preserve server metadata for the generic icon fallback',
    () {
      final result = MembershipProductList.fromJson({
        'vip_status': 'none',
        'list': [product],
      });
      expect(result.products.single.benefits.single.title, 'Server title');
      expect(result.products.single.benefits.single.iconKey, 'future_icon');
    },
  );
  test('invalid or duplicate benefits are rejected', () {
    for (final benefits in [
      'invalid',
      null,
      [benefit, benefit],
      [
        {...benefit, 'title': ''},
      ],
      [
        {...benefit, 'display_type': 'unknown'},
      ],
    ]) {
      expect(
        () => MembershipProduct.fromJson({...product, 'benefits': benefits}),
        throwsFormatException,
      );
    }
  });
  test(
    'current product fields are required and API hundredths are validated',
    () {
      expect(MembershipProduct.fromJson(product).priceAmount, 1234);
      final parsed = MembershipProduct.fromJson(product);
      expect(parsed.toJson(), product);
      for (final key in product.keys) {
        final missing = Map<String, Object?>.from(product)..remove(key);
        expect(
          () => MembershipProduct.fromJson(missing),
          throwsFormatException,
          reason: '$key is required',
        );
      }
      expect(
        MembershipProduct.fromJson({
          ...product,
          'price_currency_code': '',
          'price_amount': null,
        }).priceAmount,
        isNull,
      );
      for (final invalid in [
        {'title': ''},
        {'title': '   '},
        {'title': 123},
        {'price_amount': 12.34},
        {'price_amount': 0},
        {'price_amount': -1},
        {'price_currency_code': 'usd'},
        {'price_currency_code': ''},
        {'price_amount': null},
      ]) {
        expect(
          () => MembershipProduct.fromJson({...product, ...invalid}),
          throwsFormatException,
        );
      }
    },
  );
}
