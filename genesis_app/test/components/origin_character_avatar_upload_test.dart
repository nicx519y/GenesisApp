import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_character_form.dart';
import 'package:genesis_flutter_android/components/origin/origin_role_launch_sheet.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';

void main() {
  testWidgets('shared create and edit character form uses 1080 avatar limit', (
    WidgetTester tester,
  ) async {
    final form = OriginCharacterForm.empty(charId: 'character');
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OriginCharacterFormFields(form: form, onChanged: () {}),
          ),
        ),
      ),
    );

    _expectCharacterAvatarConfiguration(tester);
  });

  testWidgets('shared Origin and World launch form uses 1080 avatar limit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OriginRoleLaunchSheet(characters: [], initialCustomTab: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectCharacterAvatarConfiguration(tester);
  });
}

void _expectCharacterAvatarConfiguration(WidgetTester tester) {
  final upload = tester.widget<CreateUploadBox>(find.byType(CreateUploadBox));
  expect(upload.cropSize, originCharacterAvatarUploadSize);
  expect(upload.maxOutputSize, originCharacterAvatarUploadSize);
  expect(upload.cropSize?.aspectRatio, 1);
}
