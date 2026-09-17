import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'membership_purchase_service_test.dart' as support;
import '../../support/membership_fixtures.dart';

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'prewarming only queries product; click loads identity while sharing query',
    () async {
      final product = membershipProduct(yearly: true);
      final catalog = MembershipProductList(products: [product]);
      final h = support.Harness(checkoutProducts: () async => catalog);
      final native = Completer<void>();
      final identity = Completer<String>();
      var nativeCalls = 0;
      var identityCalls = 0;
      h.platform.onPrepare = () {
        nativeCalls++;
        return native.future;
      };
      h.accountUuidHandler = () {
        identityCalls++;
        return identity.future;
      };
      final preparation = h.service.prepareCheckout(product)!;
      addTearDown(preparation.invalidate);
      await settle();
      expect(nativeCalls, 1);
      expect(identityCalls, 0);
      expect(h.platform.launches, 0);
      expect(h.store.records, isEmpty);
      final checkout = h.service.purchase(product, preparation: preparation);
      await settle();
      expect(nativeCalls, 1);
      expect(identityCalls, 1);
      native.complete();
      identity.complete(support.accountUuid);
      await checkout;
      expect(h.platform.launches, 1);
      expect(nativeCalls, 1);
      expect(identityCalls, 1);
    },
  );

  test(
    'cold Google checkout also runs product and identity in parallel',
    () async {
      final h = support.Harness();
      final gate = Completer<void>();
      var identityCalls = 0;
      h.platform.onPrepare = () => gate.future;
      h.accountUuidHandler = () async {
        identityCalls++;
        return support.accountUuid;
      };
      final checkout = h.service.purchase(h.product(yearly: true));
      await settle();
      expect(identityCalls, 1);
      expect(h.platform.launches, 0);
      gate.complete();
      await checkout;
      expect(h.platform.launches, 1);
    },
  );

  test('invalidated page preparation is not reused', () async {
    final p = membershipProduct(yearly: true);
    final catalog = MembershipProductList(
      products: [p],
      lastAccountUuid: support.accountUuid,
    );
    final h = support.Harness(checkoutProducts: () async => catalog);
    var calls = 0;
    h.platform.onPrepare = () async {
      calls++;
    };
    final ticket = h.service.prepareCheckout(p)!;
    await settle();
    ticket.invalidate();
    await h.service.purchase(p, preparation: ticket);
    expect(calls, 2);
    expect(h.platform.launches, 1);
  });

  test(
    'click loads the current owner identity after product prewarming',
    () async {
      final p = membershipProduct(yearly: true);
      final catalog = MembershipProductList(products: [p]);
      final h = support.Harness(checkoutProducts: () async => catalog);
      var calls = 0;
      h.accountUuidHandler = () async {
        calls++;
        return h.uid == 'new-user'
            ? 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
            : support.accountUuid;
      };
      final ticket = h.service.prepareCheckout(p)!;
      addTearDown(ticket.invalidate);
      await settle();
      h.uid = 'new-user';
      await h.service.purchase(p, preparation: ticket);
      expect(calls, 1);
      expect(h.platform.uuid, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    },
  );

  test(
    'catalog refresh during in-flight preparation cannot launch old product',
    () async {
      final p = membershipProduct(yearly: true);
      var catalog = MembershipProductList(products: [p]);
      final h = support.Harness(checkoutProducts: () async => catalog);
      final gate = Completer<void>();
      h.platform.onPrepare = () => gate.future;
      final ticket = h.service.prepareCheckout(p)!;
      addTearDown(ticket.invalidate);
      await settle();
      final checkout = h.service.purchase(p, preparation: ticket);
      await settle();
      catalog = MembershipProductList(
        products: [membershipProduct(yearly: true, offerId: 'changed')],
      );
      gate.complete();
      await checkout;
      expect(h.platform.launches, 0);
    },
  );

  test(
    'background preparation failure is silent and click can retry',
    () async {
      final p = membershipProduct(yearly: true);
      final catalog = MembershipProductList(products: [p]);
      final h = support.Harness(checkoutProducts: () async => catalog);
      var calls = 0;
      h.platform.onPrepare = () async {
        if (++calls == 1) throw StateError('unavailable');
      };
      final ticket = h.service.prepareCheckout(p)!;
      addTearDown(ticket.invalidate);
      await settle();
      expect(h.platform.launches, 0);
      await h.service.purchase(p, preparation: ticket);
      expect(calls, 2);
      expect(h.platform.launches, 1);
    },
  );

  testWidgets('prepared product expires two minutes after query completes', (
    tester,
  ) async {
    final p = membershipProduct(yearly: true);
    final catalog = MembershipProductList(
      products: [p],
      lastAccountUuid: support.accountUuid,
    );
    final h = support.Harness(checkoutProducts: () async => catalog);
    final gate = Completer<void>();
    var calls = 0;
    var expirations = 0;
    h.platform.onPrepare = () {
      calls++;
      return gate.future;
    };
    final ticket = h.service.prepareCheckout(
      p,
      onExpired: () => expirations++,
    )!;
    addTearDown(ticket.invalidate);
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(minutes: 3));
    expect(expirations, 0);
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 119));
    expect(expirations, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(expirations, 1);
    final checkout = h.service.purchase(p, preparation: ticket);
    await tester.pump();
    await checkout;
    expect(calls, 2);
    expect(h.platform.launches, 1);
  });

  testWidgets(
    'invalidated query cannot arm an expiry callback after completion',
    (tester) async {
      final p = membershipProduct(yearly: true);
      final catalog = MembershipProductList(products: [p]);
      final h = support.Harness(checkoutProducts: () async => catalog);
      final gate = Completer<void>();
      h.platform.onPrepare = () => gate.future;
      var expirations = 0;
      final ticket = h.service.prepareCheckout(
        p,
        onExpired: () => expirations++,
      )!;
      await tester.pump();
      ticket.invalidate();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(minutes: 3));
      expect(expirations, 0);
      expect(h.platform.launches, 0);
    },
  );

  test(
    'cold preparation cannot launch a product changed during query',
    () async {
      final p = membershipProduct(yearly: true);
      var catalog = MembershipProductList(products: [p]);
      final h = support.Harness(checkoutProducts: () async => catalog);
      final gate = Completer<void>();
      h.platform.onPrepare = () => gate.future;
      final checkout = h.service.purchase(p);
      await settle();
      catalog = MembershipProductList(
        products: [membershipProduct(yearly: true, offerId: 'changed')],
      );
      gate.complete();
      await checkout;
      expect(h.platform.launches, 0);
    },
  );

  testWidgets('timed out click cannot launch when prewarm later completes', (
    tester,
  ) async {
    final p = membershipProduct(yearly: true);
    final catalog = MembershipProductList(products: [p]);
    final h = support.Harness(
      checkoutProducts: () async => catalog,
      attemptTimeout: const Duration(seconds: 1),
    );
    final gate = Completer<void>();
    var calls = 0;
    h.platform.onPrepare = () {
      calls++;
      return gate.future;
    };
    final ticket = h.service.prepareCheckout(p)!;
    addTearDown(ticket.invalidate);
    await tester.pump();
    final checkout = h.service.purchase(p, preparation: ticket);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await checkout;
    gate.complete();
    await tester.pump();
    expect(calls, 1);
    expect(h.platform.launches, 0);
  });

  test(
    'Apple uses the shared preparation without launching or reporting',
    () async {
      final h = support.Harness(provider: MembershipProvider.apple);
      final ticket = h.service.prepareCheckout(h.product());
      expect(ticket, isNotNull);
      ticket!.invalidate();
      await Future<void>.delayed(Duration.zero);
      expect(h.platform.launches, 0);
      expect(h.reports, isEmpty);
    },
  );
}
