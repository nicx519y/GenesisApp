import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets('GenesisScrollBehavior removes Material stretch overscroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.light(),
        scrollBehavior: const GenesisScrollBehavior(),
        home: Scaffold(
          body: ListView(children: const [SizedBox(height: 1200)]),
        ),
      ),
    );

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(
      ScrollConfiguration.of(tester.element(find.byType(ListView))),
      isA<GenesisScrollBehavior>(),
    );
  });

  testWidgets('GenesisScrollBehavior preserves explicit bouncing physics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.light(),
        scrollBehavior: const GenesisScrollBehavior(),
        home: ListView(
          physics: const BouncingScrollPhysics(),
          children: const [SizedBox(height: 1200)],
        ),
      ),
    );

    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<BouncingScrollPhysics>(),
    );
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
  });
}
