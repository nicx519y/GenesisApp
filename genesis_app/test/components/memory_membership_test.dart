import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_offer_card.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_carousel.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_style.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_wallet_content.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  double width = 350,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: GenesisTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
  });
  for (final tier in MemoryMembershipTier.values) {
    testWidgets('${tier.name} card edge only shows below the top sheen', (
      tester,
    ) async {
      const key = ValueKey('edge-card');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 314,
                height: 400,
                child: MemoryMembershipSurface(
                  tier: tier,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!;
      });
      int brightness(int x, int y) {
        final at = (y * 314 + x) * 4;
        return pixels!.getUint8(at) +
            pixels.getUint8(at + 1) +
            pixels.getUint8(at + 2);
      }

      int lift(int y) => brightness(0, y) - brightness(6, y);
      expect(lift(56), lessThan(30));
      expect(lift(300), greaterThan(100));
    });
  }

  testWidgets('Deluxe lists Timeline, Cast and Bonds as separate benefits', (
    tester,
  ) async {
    await mount(
      tester,
      MemoryMembershipSubscriptionCarousel(
        onPremiumSubscribe: () {},
        onDeluxeSubscribe: () {},
      ),
    );
    expect(find.text('Timeline: every key event, in order'), findsOneWidget);
    expect(find.text('Cast: a living profile of everyone'), findsOneWidget);
    expect(
      find.text('Bonds: how everyone feels about each other'),
      findsOneWidget,
    );
    expect(find.textContaining('Timeline, Cast and Bonds'), findsNothing);
  });

  testWidgets('every lock card shows the current copy and prices', (
    tester,
  ) async {
    await mount(
      tester,
      SingleChildScrollView(
        child: MemoryMembershipOfferCard(
          tier: MemoryMembershipTier.deluxe,
          onSubscribe: () {},
          onDetails: () {},
        ),
      ),
    );
    expect(
      find.textContaining('a memory that updates as you play'),
      findsOneWidget,
    );
    expect(find.text(r'$449'), findsOneWidget);
    expect(find.text(r'$44.90'), findsOneWidget);
    expect(find.text('Save 17%'), findsOneWidget);
    expect(find.text('Deluxe is not available yet.'), findsNothing);
  });

  testWidgets('card title holds its place while the benefits scroll', (
    tester,
  ) async {
    await mount(
      tester,
      MemoryMembershipSubscriptionCarousel(
        initialTier: MemoryMembershipTier.deluxe,
        deluxeActive: true,
        deluxeExpiry: DateTime(2027, 11, 3),
        onPremiumSubscribe: () {},
        onDeluxeSubscribe: () {},
      ),
      width: 390,
    );
    final title = find.text('Worldo Deluxe');
    final expires = find.text('Expires 2027-11-03');
    final benefit = find.text('Timeline: every key event, in order');
    final titleTop = tester.getTopLeft(title).dy;
    final titleLeft = tester.getTopLeft(title).dx;
    final expiresTop = tester.getTopLeft(expires).dy;
    final benefitTop = tester.getTopLeft(benefit).dy;
    // The same stroke as a quick upward swipe on a phone: straight, 213 logical
    // pixels in 300ms.
    await tester.timedDrag(
      benefit,
      const Offset(0, -213),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(benefit).dy, lessThan(benefitTop));
    expect(tester.getTopLeft(title).dy, titleTop);
    expect(tester.getTopLeft(expires).dy, expiresTop);
    // Scrolling a card never changes which card is in view.
    expect(tester.getTopLeft(title).dx, titleLeft);
    expect(
      find.byKey(const ValueKey('membership-deluxe-yearly')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('membership-premium-yearly')),
      findsNothing,
    );
  });

  testWidgets('Me wordmark gradient spans only the words', (tester) async {
    await mount(
      tester,
      MemoryMembershipProfileCarousel(
        deluxeActive: true,
        deluxeExpiry: DateTime(2027, 11, 3),
        onPremiumSubscribe: () {},
        onDeluxeSubscribe: () {},
      ),
      width: 390,
    );
    final title = find.text('Worldo Deluxe');
    final mask = find.ancestor(of: title, matching: find.byType(ShaderMask));
    expect(tester.getSize(mask.first).width, tester.getSize(title).width);
    final active = find.descendant(
      of: find.byKey(const ValueKey('membership-profile-deluxe')),
      matching: find.byType(MemoryMembershipStatus),
    );
    expect(tester.getTopLeft(active).dx - tester.getTopRight(title).dx, 8);
  });

  testWidgets('card edge stays whole around the fade at the bottom', (
    tester,
  ) async {
    const key = ValueKey('edge-whole');
    await mount(
      tester,
      RepaintBoundary(
        key: key,
        child: MemoryMembershipSubscriptionCarousel(
          initialTier: MemoryMembershipTier.deluxe,
          onPremiumSubscribe: () {},
          onDeluxeSubscribe: () {},
        ),
      ),
      width: 390,
    );
    await tester.pumpAndSettle();
    final surface = find.byType(MemoryMembershipSurface).first;
    final rect = tester.getRect(surface);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final origin = boundary.localToGlobal(Offset.zero);
    final width = boundary.size.width.toInt();
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      image.dispose();
      return bytes!;
    });
    int brightness(double x, double y) {
      final at =
          ((y - origin.dy).floor() * width + (x - origin.dx).floor()) * 4;
      return pixels!.getUint8(at) +
          pixels.getUint8(at + 1) +
          pixels.getUint8(at + 2);
    }

    // One unbroken line along the bottom, with nothing drawn across it.
    final bottom = rect.bottom - 1;
    final line = [
      for (var x = rect.left + 24; x < rect.right - 24; x += 2)
        brightness(x, bottom),
    ];
    final lowest = line.reduce((a, b) => a < b ? a : b);
    final highest = line.reduce((a, b) => a > b ? a : b);
    expect(lowest, greaterThan(150));
    expect(highest - lowest, lessThan(30));
    // And it carries on round the corner the fade used to cover.
    var corner = 0;
    for (var y = rect.bottom - 12; y < rect.bottom - 3; y += 1) {
      for (var x = rect.left; x < rect.left + 14; x += 1) {
        final value = brightness(x, y);
        if (value > corner) corner = value;
      }
    }
    expect(corner, greaterThan(150));
  });

  test('Deluxe leads unless Premium is the only subscription', () {
    const deluxeFirst = [
      MemoryMembershipTier.deluxe,
      MemoryMembershipTier.premium,
    ];
    expect(
      memoryMembershipOrder(premiumActive: false, deluxeActive: false),
      deluxeFirst,
    );
    expect(
      memoryMembershipOrder(premiumActive: false, deluxeActive: true),
      deluxeFirst,
    );
    expect(
      memoryMembershipOrder(premiumActive: true, deluxeActive: true),
      deluxeFirst,
    );
    expect(memoryMembershipOrder(premiumActive: true, deluxeActive: false), [
      MemoryMembershipTier.premium,
      MemoryMembershipTier.deluxe,
    ]);
  });

  for (final (premium, lead) in [
    (false, MemoryMembershipTier.deluxe),
    (true, MemoryMembershipTier.premium),
  ]) {
    testWidgets('subscription opens on ${lead.name} when premium=$premium', (
      tester,
    ) async {
      await mount(
        tester,
        MemoryMembershipSubscriptionCarousel(
          premiumActive: premium,
          onPremiumSubscribe: () {},
          onDeluxeSubscribe: () {},
        ),
      );
      expect(
        find.byKey(ValueKey('membership-subscribe-${lead.name}')),
        findsOneWidget,
      );
    });
  }

  testWidgets('an entry that names a card still opens on it', (tester) async {
    await mount(
      tester,
      MemoryMembershipSubscriptionCarousel(
        initialTier: MemoryMembershipTier.premium,
        onPremiumSubscribe: () {},
        onDeluxeSubscribe: () {},
      ),
    );
    expect(
      find.byKey(const ValueKey('membership-subscribe-premium')),
      findsOneWidget,
    );
  });

  testWidgets('Me compact row uses 314px cards and 82x30 side actions', (
    tester,
  ) async {
    await mount(
      tester,
      MemoryMembershipProfileCarousel(
        onPremiumSubscribe: () {},
        onDeluxeSubscribe: () {},
      ),
      width: 390,
    );
    final card = find.byKey(const ValueKey('membership-profile-deluxe'));
    expect(tester.getTopLeft(card).dx, 16);
    final button = find.byKey(const ValueKey('membership-subscribe-deluxe'));
    final title = find.text('Worldo Deluxe');
    expect(tester.getSize(card).width, 314);
    expect(tester.getSize(card).height, 82);
    expect(tester.getSize(button), const Size(82, 30));
    expect(
      tester.getTopLeft(button).dx,
      greaterThan(tester.getTopLeft(title).dx),
    );
    expect(tester.widget<Text>(title).style!.fontSize, 16);
    expect(find.textContaining('18,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscription source geometry and owned purchase guard', (
    tester,
  ) async {
    var purchases = 0;
    await mount(
      tester,
      MemoryMembershipSubscriptionCarousel(
        premiumActive: true,
        onPremiumSubscribe: () => purchases++,
        onDeluxeSubscribe: () {},
      ),
      width: 390,
    );
    final surfaces = find.byType(MemoryMembershipSurface);
    expect(tester.getSize(surfaces.first).width, 314);
    expect(tester.getTopLeft(surfaces.first).dx, 16);
    expect(tester.getTopLeft(surfaces.last).dx, 340);
    final yearly = find.byKey(const ValueKey('membership-premium-yearly'));
    final monthly = find.byKey(const ValueKey('membership-premium-monthly'));
    expect(tester.getTopLeft(yearly).dy, tester.getTopLeft(monthly).dy);
    expect(tester.getSize(yearly).height, tester.getSize(monthly).height);
    await tester.tap(
      find.byKey(const ValueKey('membership-subscribe-premium')),
    );
    expect(purchases, 0);
    await tester.drag(
      find.byKey(const ValueKey('membership-subscription-pages')),
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(surfaces.first).dx, -264);
    expect(tester.getTopLeft(surfaces.last).dx, 60);
    expect(
      find.byKey(const ValueKey('membership-subscribe-deluxe')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Me active cards stay 82px tall and expose an arrow instead of Subscribe',
    (tester) async {
      await mount(
        tester,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MemoryMembershipProfileCarousel(
            premiumActive: true,
            deluxeActive: true,
            premiumExpiry: DateTime(2027, 9, 7),
            deluxeExpiry: DateTime(2027, 11, 3),
            onPremiumSubscribe: () {},
            onDeluxeSubscribe: () {},
          ),
        ),
        width: 390,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('membership-profile-premium')))
            .height,
        82,
      );
      expect(
        find.byKey(const ValueKey('membership-subscribe-premium')),
        findsNothing,
      );
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Me leads with Premium only when it is the sole active subscription',
    (tester) async {
      for (final premiumState in [0, 1, 2]) {
        for (final deluxeState in [0, 1, 2]) {
          await mount(
            tester,
            MemoryMembershipProfileCarousel(
              premiumActive: premiumState == 0,
              premiumExpired: premiumState == 1,
              deluxeActive: deluxeState == 0,
              deluxeExpired: deluxeState == 1,
              onPremiumSubscribe: () {},
              onDeluxeSubscribe: () {},
            ),
          );
          final premiumX = tester
              .getTopLeft(
                find.byKey(const ValueKey('membership-profile-premium')),
              )
              .dx;
          final deluxeX = tester
              .getTopLeft(
                find.byKey(const ValueKey('membership-profile-deluxe')),
              )
              .dx;
          expect(
            premiumX < deluxeX,
            premiumState == 0 && deluxeState != 0,
            reason: 'Premium=$premiumState, Deluxe=$deluxeState',
          );
        }
      }
    },
  );

  testWidgets('Me large text grows naturally', (tester) async {
    await mount(
      tester,
      SingleChildScrollView(
        child: MemoryMembershipProfileCarousel(
          onPremiumSubscribe: () {},
          onDeluxeSubscribe: () {},
        ),
      ),
      scale: 1.5,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('membership-profile-premium')))
          .height,
      greaterThan(82),
    );
    expect(find.textContaining('18,000'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('membership-profile-pages')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await mount(
      tester,
      SingleChildScrollView(
        child: MemoryMembershipProfileCarousel(
          onPremiumSubscribe: () {},
          onDeluxeSubscribe: () {},
        ),
      ),
    );
    expect(find.textContaining('18,000'), findsOneWidget);
    await mount(
      tester,
      MemoryMembershipSubscriptionCarousel(
        initialTier: MemoryMembershipTier.deluxe,
        onPremiumSubscribe: () {},
        onDeluxeSubscribe: () {},
      ),
    );
    expect(find.textContaining('18,000'), findsOneWidget);
  });

  testWidgets('lock plans pick locally and carry the choice when they can', (
    tester,
  ) async {
    bool? selectedYearly;
    var details = 0;
    await mount(
      tester,
      SingleChildScrollView(
        child: MemoryMembershipOfferCard(
          tier: MemoryMembershipTier.premium,
          onSubscribe: () {},
          onDetails: () => details++,
        ),
      ),
    );
    expect(find.byType(MemoryMembershipPlanSelector), findsOneWidget);
    expect(find.text(r'$99'), findsOneWidget);
    expect(find.text(r'$9.90'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('membership-premium-monthly')));
    await tester.pump();
    expect(details, 0);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('membership-premium-monthly')),
          )
          .properties
          .selected,
      isTrue,
    );
    await mount(
      tester,
      SingleChildScrollView(
        child: MemoryMembershipOfferCard(
          tier: MemoryMembershipTier.premium,
          onSubscribe: () => fail('Plan callback must take precedence'),
          onDetails: () {},
          onPlanSubscribe: (yearly) => selectedYearly = yearly,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('membership-premium-monthly')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('membership-subscribe-premium')),
    );
    expect(selectedYearly, isFalse);
  });
  testWidgets(
    'wallet loads current prices and carries Monthly into original checkout',
    (tester) async {
      var loads = 0;
      final offers = [
        for (final yearly in [true, false])
          MembershipOffer(
            product: MembershipProduct(
              title: 'Premium',
              benefits: const [],
              planCode: yearly ? 'pro_yearly' : 'pro_monthly',
              provider: MembershipProvider.apple,
              storeProductId: yearly ? 'test.year' : 'test.month',
              billingMonths: yearly ? 12 : 1,
              monthlyGemsCent: 350000,
              priceCurrencyCode: 'USD',
              priceAmount: yearly ? 12300 : 1500,
            ),
          ),
      ];
      await mount(
        tester,
        MemoryMembershipWalletContent(
          initialTier: MemoryMembershipTier.premium,
          productsLoader: () async {
            loads++;
            return MembershipCatalogData(offers: offers);
          },
        ),
      );
      expect(loads, 1);
      expect(find.text(r'$123'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('membership-premium-monthly')),
      );
      await tester.tap(
        find.byKey(const ValueKey('membership-subscribe-premium')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProSubscriptionContent), findsOneWidget);
      final monthlySemantics = find
          .ancestor(
            of: find.byKey(const ValueKey('pro-plan-monthly')),
            matching: find.byType(Semantics),
          )
          .first;
      expect(
        tester.widget<Semantics>(monthlySemantics).properties.selected,
        isTrue,
      );
      expect(loads, greaterThanOrEqualTo(2));
    },
  );

  testWidgets('Deluxe production action never opens Premium checkout', (
    tester,
  ) async {
    await mount(
      tester,
      MemoryMembershipWalletContent(
        initialTier: MemoryMembershipTier.deluxe,
        productsLoader: () async => const MembershipCatalogData(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('membership-subscribe-deluxe')));
    await tester.pumpAndSettle();
    expect(find.byType(ProSubscriptionContent), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('offer keeps subscribe and matching details callbacks separate', (
    tester,
  ) async {
    var subscriptions = 0;
    var details = 0;
    await mount(
      tester,
      SingleChildScrollView(
        child: MemoryMembershipOfferCard(
          tier: MemoryMembershipTier.deluxe,
          onSubscribe: () => subscriptions++,
          onDetails: () => details++,
        ),
      ),
      scale: 1.5,
    );
    await tester.tap(find.byKey(const ValueKey('membership-details-deluxe')));
    expect(details, 1);
    expect(subscriptions, 0);
    await tester.tap(find.byKey(const ValueKey('membership-subscribe-deluxe')));
    expect(subscriptions, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'slides keep independent local plan choices and purchase callbacks',
    (tester) async {
      var premium = 0;
      var deluxe = 0;
      await mount(
        tester,
        MemoryMembershipSubscriptionCarousel(
          initialTier: MemoryMembershipTier.premium,
          onPremiumSubscribe: () => premium++,
          onDeluxeSubscribe: () => deluxe++,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('membership-premium-monthly')),
      );
      await tester.drag(
        find.byKey(const ValueKey('membership-subscription-pages')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('membership-deluxe-yearly')),
            )
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('membership-subscribe-deluxe')),
      );
      expect(deluxe, 1);
      expect(premium, 0);
      await tester.drag(
        find.byKey(const ValueKey('membership-subscription-pages')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('membership-premium-monthly')),
            )
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('membership-subscribe-premium')),
      );
      expect(premium, 1);
    },
  );

  for (final premium in [false, true]) {
    for (final deluxe in [false, true]) {
      testWidgets('350px 1.5x subscription ownership $premium/$deluxe', (
        tester,
      ) async {
        await mount(
          tester,
          MemoryMembershipSubscriptionCarousel(
            premiumActive: premium,
            deluxeActive: deluxe,
            initialTier: MemoryMembershipTier.deluxe,
            onPremiumSubscribe: () {},
            onDeluxeSubscribe: () {},
          ),
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byKey(const ValueKey('membership-subscription-pages')),
          const Offset(300, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Me places Deluxe-only ownership first without unlocking Premium',
    (tester) async {
      var premium = 0;
      var deluxe = 0;
      await mount(
        tester,
        SingleChildScrollView(
          child: MemoryMembershipProfileCarousel(
            deluxeActive: true,
            deluxeExpiry: DateTime(2027, 11, 3),
            onPremiumSubscribe: () => premium++,
            onDeluxeSubscribe: () => deluxe++,
          ),
        ),
        scale: 1.5,
      );
      await tester.tap(find.byKey(const ValueKey('membership-profile-deluxe')));
      expect(deluxe, 1);
      expect(premium, 0);
      await tester.drag(
        find.byKey(const ValueKey('membership-profile-pages')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const ValueKey('membership-subscribe-premium'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
