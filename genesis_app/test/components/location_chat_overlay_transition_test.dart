import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/location_chat_overlay_transition.dart';

void main() {
  testWidgets('iOS location chat overlay fades during open and close', (
    WidgetTester tester,
  ) async {
    var active = false;
    Widget? child;

    await tester.pumpWidget(
      _OverlayTransitionHarness(active: active, child: child),
    );

    expect(_cupertinoFadeTransitionFinder(), findsNothing);

    active = true;
    child = const ColoredBox(color: Colors.red);
    await tester.pumpWidget(
      _OverlayTransitionHarness(active: active, child: child),
    );
    await tester.pump(const Duration(milliseconds: 75));

    expect(_cupertinoFadeTransitionFinder(), findsOneWidget);
    final openingFade = tester.widget<FadeTransition>(
      _cupertinoFadeTransitionFinder(),
    );
    expect(openingFade.opacity.value, greaterThan(0));
    expect(openingFade.opacity.value, lessThan(1));

    await tester.pumpAndSettle();

    active = false;
    child = null;
    await tester.pumpWidget(
      _OverlayTransitionHarness(active: active, child: child),
    );
    await tester.pump(const Duration(milliseconds: 75));

    expect(_cupertinoFadeTransitionFinder(), findsOneWidget);
    final closingFade = tester.widget<FadeTransition>(
      _cupertinoFadeTransitionFinder(),
    );
    expect(closingFade.opacity.value, greaterThan(0));
    expect(closingFade.opacity.value, lessThan(1));

    await tester.pumpAndSettle();

    expect(_cupertinoFadeTransitionFinder(), findsNothing);
  });
}

Finder _cupertinoFadeTransitionFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is FadeTransition && widget.child is CupertinoPageTransition,
  );
}

class _OverlayTransitionHarness extends StatelessWidget {
  const _OverlayTransitionHarness({required this.active, required this.child});

  final bool active;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: Stack(
          children: [
            const ColoredBox(color: Colors.blue),
            LocationChatOverlayTransition(active: active, child: child),
          ],
        ),
      ),
    );
  }
}
