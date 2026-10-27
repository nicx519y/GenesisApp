import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/privacy/privacy_choices_dialog.dart';

void main() {
  testWidgets('load failure is returned without presenting a consent dialog', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, home: const Scaffold()),
    );
    final result = showPrivacyChoicesDialog(
      key.currentContext!,
      loadChoices: () async => throw StateError('storage unavailable'),
    );
    await tester.pump();
    expect(await result, PrivacyDialogResult.failed);
    expect(find.text('Consent'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
