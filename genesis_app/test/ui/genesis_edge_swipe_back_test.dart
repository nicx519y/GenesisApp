import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_edge_swipe_back.dart';

void main() {
  testWidgets('iOS edge swipe invokes back once from the leading edge', (
    tester,
  ) async {
    var backCount = 0;

    await tester.pumpWidget(
      _EdgeSwipeHarness(
        platform: TargetPlatform.iOS,
        onBack: () => backCount += 1,
      ),
    );

    final gesture = await tester.startGesture(const Offset(2, 100));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(backCount, 1);
  });

  testWidgets('non-iOS platforms do not install the edge swipe gesture', (
    tester,
  ) async {
    var backCount = 0;

    await tester.pumpWidget(
      _EdgeSwipeHarness(
        platform: TargetPlatform.android,
        onBack: () => backCount += 1,
      ),
    );

    final gesture = await tester.startGesture(const Offset(2, 100));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(backCount, 0);
  });

  testWidgets('stable container keeps child state when gesture toggles', (
    tester,
  ) async {
    final enabled = ValueNotifier<bool>(false);
    addTearDown(enabled.dispose);
    final child = StatefulBuilder(builder: (_, _) => const SizedBox.expand());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, isEnabled, _) => GenesisEdgeSwipeBack(
            enabled: isEnabled,
            maintainStackWhenDisabled: true,
            onBack: () {},
            child: child,
          ),
        ),
      ),
    );

    final originalState = tester.state(find.byType(StatefulBuilder));
    enabled.value = true;
    await tester.pump();
    expect(tester.state(find.byType(StatefulBuilder)), same(originalState));
    enabled.value = false;
    await tester.pump();
    expect(tester.state(find.byType(StatefulBuilder)), same(originalState));
  });
}

class _EdgeSwipeHarness extends StatelessWidget {
  const _EdgeSwipeHarness({required this.platform, required this.onBack});

  final TargetPlatform platform;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: GenesisEdgeSwipeBack(
        onBack: onBack,
        child: const Scaffold(body: ColoredBox(color: Colors.white)),
      ),
    );
  }
}
