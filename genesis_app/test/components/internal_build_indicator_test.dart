import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/internal_build_indicator.dart';

void main() {
  testWidgets('production renders the child without an internal indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InternalBuildIndicator(
          isInternal: false,
          child: Scaffold(body: Text('content')),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(find.text('INTERNAL'), findsNothing);
    expect(find.byKey(InternalBuildIndicator.indicatorKey), findsNothing);
  });

  testWidgets('internal renders the corner indicator below the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 32)),
          child: InternalBuildIndicator(
            isInternal: true,
            child: Scaffold(body: Text('content')),
          ),
        ),
      ),
    );

    expect(find.text('INTERNAL'), findsOneWidget);
    final topLeft = tester.getTopLeft(
      find.byKey(InternalBuildIndicator.indicatorKey),
    );
    final size = tester.getSize(
      find.byKey(InternalBuildIndicator.indicatorKey),
    );
    expect(topLeft.dy, 32);
    expect(size, const Size(64, 42));
  });

  testWidgets('internal indicator does not intercept child taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: InternalBuildIndicator(
          isInternal: true,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 96,
                height: 64,
                child: TextButton(
                  key: const ValueKey<String>('under-indicator-button'),
                  onPressed: () => taps += 1,
                  child: const Text('tap'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('under-indicator-button')));
    expect(taps, 1);
  });
}
