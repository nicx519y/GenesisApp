import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/membership_catalog_cache.dart';

import '../../support/membership_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'display cache persists across instances and excludes upgrade credentials',
    () async {
      final product = membershipProduct(yearly: true, title: 'Cached annual');
      final cache = MembershipCatalogCache(namespace: 'production');
      await cache.save(
        MembershipProvider.google,
        'user-a',
        MembershipProductList(
          products: [product],
          lastAccountUuid: '4b74ec68-7abc-4cce-a223-e997e31dc811',
          hasSubscriptionOrder: true,
        ),
      );
      final loaded = await MembershipCatalogCache(
        namespace: 'production',
      ).load(MembershipProvider.google, 'user-a');

      expect(loaded!.products.single.toJson(), product.toJson());
      expect(loaded.lastAccountUuid, isNull);
      expect(loaded.hasSubscriptionOrder, isFalse);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefs.getKeys().single)!;
      expect(raw, isNot(contains('account_uuid')));
      expect(raw, isNot(contains('has_subscription_order')));
    },
  );

  test(
    'account, provider, and environment each isolate display data',
    () async {
      final cache = MembershipCatalogCache(namespace: 'production');
      await cache.save(
        MembershipProvider.google,
        'user-a',
        MembershipProductList(products: [membershipProduct()]),
      );
      expect(await cache.load(MembershipProvider.google, 'user-b'), isNull);
      expect(await cache.load(MembershipProvider.google, null), isNull);
      expect(await cache.load(MembershipProvider.apple, 'user-a'), isNull);
      expect(
        await MembershipCatalogCache(
          namespace: 'debug',
        ).load(MembershipProvider.google, 'user-a'),
        isNull,
      );
      await cache.save(
        MembershipProvider.google,
        'user-a',
        MembershipProductList(products: []),
      );
      expect(
        (await cache.load(MembershipProvider.google, 'user-a'))!.products,
        isEmpty,
      );
    },
  );

  test('corrupt display cache is a cache miss', () async {
    final cache = MembershipCatalogCache(namespace: 'production');
    await cache.save(
      MembershipProvider.google,
      null,
      MembershipProductList(products: [membershipProduct()]),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefs.getKeys().single, '{invalid');
    expect(await cache.load(MembershipProvider.google, null), isNull);
  });
  test('previous cache versions are ignored', () async {
    final cache = MembershipCatalogCache(namespace: 'production');
    await cache.save(
      MembershipProvider.google,
      null,
      MembershipProductList(products: [membershipProduct()]),
    );
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    final raw = prefs.getString(key)!;
    await prefs.remove(key);
    for (final version in ['v1', 'v2']) {
      await prefs.setString(key.replaceFirst('_v3.', '_$version.'), raw);
    }
    expect(await cache.load(MembershipProvider.google, null), isNull);
  });
}
