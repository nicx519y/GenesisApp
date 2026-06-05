import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_center_toast.dart';

void main() {
  testWidgets('shows centered translucent toast with 12px text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showGenesisToast(context, 'Network failed'),
              child: const Text('Show'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final toastText = find.text('Network failed');
    expect(toastText, findsOneWidget);

    final text = tester.widget<Text>(toastText);
    expect(text.style?.inherit, isFalse);
    expect(text.style?.fontSize, 12);
    expect(text.style?.color, Colors.white);
    expect(text.style?.decoration, TextDecoration.none);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.ancestor(of: toastText, matching: find.byType(DecoratedBox)).first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, Colors.black.withValues(alpha: 0.72));

    final screenCenter = tester.getCenter(find.byType(MaterialApp));
    final toastCenter = tester.getCenter(toastText);
    expect((toastCenter.dx - screenCenter.dx).abs(), lessThan(1));
    expect((toastCenter.dy - screenCenter.dy).abs(), lessThan(1));

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();

    expect(toastText, findsNothing);
  });
}
