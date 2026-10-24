import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_generation_wait_overlay.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ae467a08aa46c19c80bd9/observation.dart';

void main() {
  const rootKey = ValueKey('owned-world');
  testWidgets('observes all animated title phases and disappears after removal', (tester) async {
    try {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
        SizedBox.expand(key: rootKey, child: GenesisGenerationWaitOverlay(
          title: 'Progressing the World',
        )),
      )));
      for (var dots = 1; dots <= 6; dots++) {
        expect(find.text('Progressing the World${List.filled(dots, '.').join()}'), findsOneWidget);
        expect(progressWaitVisible(tester.element(find.byKey(rootKey))), isTrue);
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox(key: rootKey)));
      expect(progressWaitVisible(tester.element(find.byKey(rootKey))), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
  testWidgets('rejects unrelated text, hidden overlay and a different world', (tester) async {
    try {
      await tester.pumpWidget(const MaterialApp(home: Stack(children: [
        SizedBox.expand(key: rootKey, child: Text('Progressing the World...')),
        GenesisGenerationWaitOverlay(title: 'Progressing the World'),
      ])));
      expect(progressWaitVisible(tester.element(find.byKey(rootKey))), isFalse);
      await tester.pumpWidget(const MaterialApp(home: SizedBox(key: rootKey,
        child: Offstage(child: GenesisGenerationWaitOverlay(title: 'Progressing the World')),
      )));
      expect(progressWaitVisible(tester.element(find.byKey(rootKey))), isFalse);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.expand(key: rootKey,
        child: GenesisGenerationWaitOverlay(title: 'Generating first tick'),
      )));
      expect(progressWaitVisible(tester.element(find.byKey(rootKey))), isFalse);
      expect(progressWaitVisible(null), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
