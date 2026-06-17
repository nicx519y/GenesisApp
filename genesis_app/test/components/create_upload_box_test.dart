import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';

void main() {
  testWidgets(
    'CreateUploadBox shows preview after external controller update',
    (WidgetTester tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateUploadBox(
              controller: controller,
              label: 'AVATAR\n(Optional)',
              onChanged: () {},
            ),
          ),
        ),
      );

      expect(find.text('AVATAR\n(Optional)'), findsOneWidget);

      controller.text = 'assets/images/mock_avatars/avatar_iris.png';
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      controller.text = 'assets/images/mock_avatars/avatar_crow.png';
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      controller.clear();
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
    },
  );

  testWidgets('CreateUploadBox remove link clears avatar', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(
      text: 'assets/images/mock_avatars/avatar_iris.png',
    );
    var changedCount = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateUploadBox(
            controller: controller,
            label: 'AVATAR\n(Optional)',
            onChanged: () => changedCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('AVATAR\n(Optional)'), findsNothing);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final removeButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('create-upload-remove')),
    );
    expect(
      removeButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
      createFormDanger,
    );

    await tester.tap(find.byKey(const ValueKey('create-upload-remove')));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(changedCount, 1);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('AVATAR\n(Optional)'), findsOneWidget);
  });
}
