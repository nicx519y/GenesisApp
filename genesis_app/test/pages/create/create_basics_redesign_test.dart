import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_basics_page.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  testWidgets('Basics matches the Worldo redesign geometry', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoRedesign(),
        home: const CreateBasicsPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.getSize(find.byKey(const ValueKey('basics-back-button'))),
      const Size.square(34),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.padding, const EdgeInsets.fromLTRB(20, 4, 20, 28));

    final upload = tester.widget<CreateUploadBox>(find.byType(CreateUploadBox));
    expect(upload.width, 132);
    expect(upload.height, 176);
    expect(upload.iconSize, 22);
    expect(upload.borderRadius, 13);
    expect(upload.dashStrokeWidth, 1.5);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('time-progress-option-6 hours')))
          .height,
      38,
    );

    final saveRect = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    expect(saveRect.height, 44);
    expect(saveRect.left, 20);
    expect(saveRect.right, 370);
    expect(844 - saveRect.bottom, 30);
  });
}
