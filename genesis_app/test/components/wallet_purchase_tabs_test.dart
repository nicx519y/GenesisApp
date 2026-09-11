import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/wallet_purchase_tabs.dart';
import 'package:genesis_flutter_android/ui/components/genesis_fixed_underline_indicator.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
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
