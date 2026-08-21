import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

void main() {
  testWidgets(
    'critical shared controls expose labelled semantics and 44 point targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'world');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.worldoDark(),
          home: DefaultTabController(
            length: 2,
            child: GenesisPageScaffold.secondary(
              title: 'Accessibility',
              body: ListView(
                children: [
                  GenesisSearchField.editable(
                    controller: controller,
                    hintText: 'Search worlds',
                    onClear: controller.clear,
                  ),
                  const SizedBox(height: 12),
                  const GenesisTabBar(labels: ['Overview', 'Members']),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GenesisBackButton(onPressed: () {}),
                      const SizedBox(width: 24),
                      GenesisBottomSheetCloseButton(onPressed: () {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GenesisPrimaryButton(label: 'Continue', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.semantics.byLabel('Back'), findsWidgets);
      expect(find.semantics.byLabel('Close'), findsWidgets);
      expect(find.semantics.byLabel('Clear search'), findsWidgets);
      expect(find.semantics.byLabel('Continue'), findsWidgets);

      expect(
        tester.getRect(find.byType(GenesisSearchField)).height,
        greaterThanOrEqualTo(GenesisControlMetrics.minimumTapTarget),
      );
      expect(
        tester.getRect(find.byType(GenesisTabBar)).height,
        greaterThanOrEqualTo(GenesisControlMetrics.minimumTapTarget),
      );
      semantics.dispose();
    },
  );

  testWidgets('tabs announce the selected state and preserve selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoLight(),
        home: const DefaultTabController(
          length: 2,
          child: Scaffold(body: GenesisTabBar(labels: ['Overview', 'Members'])),
        ),
      ),
    );

    final tabs = find.byType(Tab);
    expect(
      tester.getSemantics(tabs.first).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.text('Members'));
    await tester.pump();
    expect(
      tester.getSemantics(tabs.at(1)).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });
}
