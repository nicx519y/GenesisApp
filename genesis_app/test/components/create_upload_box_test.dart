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

      controller.text = 'assets/images/mock_avatars/avatar_crow.png';
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      controller.clear();
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsOneWidget);
    },
  );
}
