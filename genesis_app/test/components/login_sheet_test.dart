import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';

void main() {
  testWidgets('login sheet inherits the standard panel title style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoginSheet(onLogin: (_) async => false)),
      ),
    );

    final title = tester.widget<Text>(find.text('Sign in to continue'));
    expect(title.style, GenesisBottomSheetPanel.titleStyle);
  });
}
