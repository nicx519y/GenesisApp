import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/components/gems/memory_membership_style.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/wallet_purchase_tabs.dart';
import 'package:genesis_flutter_android/ui/components/genesis_fixed_underline_indicator.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  Color indicatorColor(WidgetTester tester) =>
      (tester.widget<TabBar>(find.byType(TabBar)).indicator!
              as GenesisFixedUnderlineIndicator)
          .color;

  testWidgets(
    'membership changes interpolate both ways rather than replacing the underline color',
    (tester) async {
      final controller = TabController(length: 1, vsync: tester);
      final selected = ValueNotifier<Color>(
        MemoryMembershipTier.premium.accent,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Scaffold(
            body: ValueListenableBuilder<Color>(
              valueListenable: selected,
              builder: (_, color, _) => WalletPurchaseTabs(
                controller: controller,
                membershipColor: color,
              ),
            ),
          ),
        ),
      );
      expect(indicatorColor(tester), MemoryMembershipTier.premium.accent);
      for (final target in [
        MemoryMembershipTier.deluxe.accent,
        MemoryMembershipTier.premium.accent,
      ]) {
        final before = indicatorColor(tester);
        selected.value = target;
        await tester.pump();
        expect(indicatorColor(tester), before);
        await tester.pump(const Duration(milliseconds: 100));
        expect(indicatorColor(tester), isNot(before));
        expect(indicatorColor(tester), isNot(target));
        await tester.pumpAndSettle();
        expect(indicatorColor(tester), target);
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      selected.dispose();
    },
  );

  for (final lateCatalog in [false, true]) {
    testWidgets(
      'Gems returns to the cached Deluxe color without gold, late catalog=$lateCatalog',
      (tester) async {
        var hasPurchased = !lateCatalog;
        final catalog = MembershipCatalog(
          provider: MembershipProvider.google,
          loadProducts: (_) async => MembershipProductList(
            products: const [],
            hasPurchased: hasPurchased,
          ),
        );
        await catalog.load();
        final controller = TabController(
          length: 2,
          initialIndex: 1,
          vsync: tester,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: GenesisTheme.dark(),
            home: Scaffold(
              body: WalletPurchaseTabs(
                controller: controller,
                membershipCatalog: catalog,
              ),
            ),
          ),
        );
        expect(indicatorColor(tester), GenesisColors.redPrimary);
        if (lateCatalog) {
          hasPurchased = true;
          await catalog.loadForEntry();
          await tester.pump();
        }
        controller.animateTo(0, duration: const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final progress = controller.animation!.value;
        expect(progress, greaterThan(0));
        expect(progress, lessThan(1));
        expect(
          indicatorColor(tester),
          Color.lerp(
            MemoryMembershipTier.deluxe.accent,
            GenesisColors.redPrimary,
            progress,
          ),
        );
        await tester.pumpAndSettle();
        expect(indicatorColor(tester), MemoryMembershipTier.deluxe.accent);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }

  testWidgets(
    'an explicitly opened Deluxe card overrides Premium history before the page loads',
    (tester) async {
      final controller = TabController(
        length: 2,
        initialIndex: 1,
        vsync: tester,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Scaffold(
            body: WalletPurchaseTabs(
              controller: controller,
              initialMembershipType: MemoryMembershipTier.deluxe,
            ),
          ),
        ),
      );
      controller.animateTo(0);
      await tester.pumpAndSettle();
      expect(indicatorColor(tester), MemoryMembershipTier.deluxe.accent);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('wallet underline centres on text in $direction at $scale', (
        tester,
      ) async {
        for (final count in [1, 2]) {
          final controller = TabController(length: count, vsync: tester);
          await tester.pumpWidget(
            MaterialApp(
              theme: GenesisTheme.dark(),
              home: Scaffold(
                body: Directionality(
                  textDirection: direction,
                  child: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Center(
                      child: SizedBox(
                        width: 320,
                        child: WalletPurchaseTabs(controller: controller),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (var index = 0; index < count; index++) {
            controller.animateTo(index);
            await tester.pumpAndSettle();
            final tab = tester.getRect(
              find.byKey(
                ValueKey(
                  index == 0
                      ? 'wallet-subscription-tab'
                      : 'wallet-buy-gems-tab',
                ),
              ),
            );
            final text = tester.getRect(
              find.text(index == 0 ? 'Subscription' : 'Buy Gems'),
            );
            final indicator =
                tester.widget<TabBar>(find.byType(TabBar)).indicator!
                    as GenesisFixedUnderlineIndicator;
            expect(
              tab.center.dx + indicator.horizontalOffset,
              closeTo(text.center.dx, 0.01),
            );
            expect(indicator.width, lessThanOrEqualTo(text.width));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      });
    }
  }
}
