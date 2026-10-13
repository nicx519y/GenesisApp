import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';

void main() {
  testWidgets('long price shrinks without truncating its currency or amount', (
    tester,
  ) async {
    const label = 'CA\$123,456,789.99';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              child: GenesisPrimaryButton(
                label: label,
                onPressed: () {},
                shrinkLabelToFit: true,
                fontSize: 14,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(label));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    final fit = find.ancestor(
      of: find.text(label),
      matching: find.byType(FittedBox),
    );
    expect(fit, findsOneWidget);
    expect(
      tester.getSize(find.text(label)).width,
      greaterThan(tester.getSize(fit).width),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('ordinary buttons retain their original overflow behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenesisPrimaryButton(
            label: 'Ordinary action',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Ordinary action')).overflow,
      TextOverflow.ellipsis,
    );
  });
}
