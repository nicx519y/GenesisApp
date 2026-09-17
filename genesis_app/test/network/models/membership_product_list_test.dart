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
  test('catalog response contains only the product list', () {
    final parsed = MembershipProductList.fromJson({
      'list': [product],
    });
    expect(parsed.products.single.toJson(), product);
    expect(parsed.toJson(), {
      'list': [product],
    });
  });
  test('last account UUID is top-level, normalized and not cached', () {
    const uuid = '8b74ec68-7abc-4cce-a223-e997e31dc811';
    final parsed = MembershipProductList.fromJson({
      'list': [product],
      'last_account_uuid': ' ${uuid.toUpperCase()} ',
    });
    expect(parsed.lastAccountUuid, uuid);
    expect(parsed.toJson(), {
      'list': [product],
    });
    for (final empty in [null, '', '   ']) {
      expect(
        MembershipProductList.fromJson({
          'list': [product],
          'last_account_uuid': empty,
        }).lastAccountUuid,
        isNull,
      );
    }
    for (final invalid in ['invalid', 123, false]) {
      expect(
        () => MembershipProductList.fromJson({
          'list': [product],
          'last_account_uuid': invalid,
        }),
        throwsFormatException,
      );
    }
  });
  test('subscription order flag is top-level and is not cached', () {
    for (final flag in [true, false, null]) {
      final parsed = MembershipProductList.fromJson({
        'list': [product],
        'has_subscription_order': flag,
      });
      expect(parsed.hasSubscriptionOrder, flag == true);
      expect(parsed.toJson().containsKey('has_subscription_order'), isFalse);
    }
    expect(
      MembershipProductList.fromJson({
        'list': [product],
      }).hasSubscriptionOrder,
      isFalse,
    );
    for (final invalid in ['true', 1, [], {}]) {
      expect(
        () => MembershipProductList.fromJson({
          'list': [product],
          'has_subscription_order': invalid,
        }),
        throwsFormatException,
      );
    }
  });
  test('removed product fields have no effect and are never serialized', () {
    final parsed = MembershipProductList.fromJson({
      'list': [
        {
          ...product,
          'can_purchase': false,
          'purchase_block_reason': 'already_subscribed',
          'purchase_action': 'upgrade',
          'account_uuid': 'ignored',
          'purchase_token': 'ignored',
        },
      ],
    });
    expect(parsed.lastAccountUuid, isNull);
    expect(parsed.products.single.toJson(), product);
  });
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
  test('list parses with per-product titles and benefits', () {
    expect(MembershipProductList.fromJson({'list': []}).products, isEmpty);
    final result = MembershipProductList.fromJson({
      'list': [product],
    });
    expect(result.products.single.title, 'Server monthly title');
    expect(result.products.single.benefits.single.title, 'Server title');
    expect(
      MembershipProduct.fromJson({...product, 'benefits': []}).benefits,
      isEmpty,
    );
  });
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
