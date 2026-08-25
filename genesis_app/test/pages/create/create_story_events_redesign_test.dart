import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/create/genesis_create_theme.dart';
import 'package:genesis_flutter_android/pages/create/create_story_events_page.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('Story Events matches the Worldo 5f geometry', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: const CreateStoryEventsPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('story-events-back-button')),
      ),
      const Size.square(34),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.padding, const EdgeInsets.fromLTRB(20, 4, 20, 28));

    final addButton = find.byKey(
      const ValueKey<String>('story-events-add-button-border'),
    );
    expect(tester.getSize(addButton).height, 44);
    expect(tester.getSize(addButton).width, 350);
    final customPaint = tester.widget<CustomPaint>(addButton);
    final painter = customPaint.painter! as CreateDashedRRectPainter;
    expect(painter.radius, 13);
    expect(painter.strokeWidth, 1.5);

    final addLabel = tester.widget<Text>(find.text('Add Event'));
    expect(addLabel.style?.color, GenesisCreateColors.worldoDark().successText);
    expect(addLabel.style?.fontSize, 13);
    expect(addLabel.style?.fontWeight, FontWeight.w800);

    // 子页 Save 统一为 40 高、底部留白 24。
    final saveRect = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    expect(saveRect.height, 40);
    expect(saveRect.left, 20);
    expect(saveRect.right, 370);
    expect(844 - saveRect.bottom, 24);
  });
}
