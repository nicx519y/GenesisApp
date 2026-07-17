import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_form_widgets.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

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

      controller.text = 'assets/images/default_list_image.png';
      await tester.pump();

      expect(find.text('AVATAR\n(Optional)'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      controller.text = 'assets/images/default_list_image.png';
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
      text: 'assets/images/default_list_image.png',
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

  testWidgets('CreateFormNote uses soft markdown emphasis on iOS', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const Scaffold(
          body: CreateFormNote(note: 'Use *gentle* emphasis', markdown: true),
        ),
      ),
    );

    final style = _firstSkewedWidgetFragmentStyle(
      tester.widgetList<RichText>(find.byType(RichText)),
      'gentle',
    );

    expect(style?.fontStyle, FontStyle.normal);
  });

  testWidgets('CreateTextFieldBlock preserves decorative unicode input', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    const raw = '☛ ˙۵ও⃢♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀〬𓈒ֹ⁠꙳';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateTextFieldBlock(
            label: 'Name',
            controller: controller,
            hintText: 'Worldo Name',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), raw);
    await tester.pump();

    expect(controller.text, raw);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.style?.fontFamily, isNull);
    expect(input.style?.fontFamilyFallback, isNull);
    expect(input.decoration?.hintStyle?.fontFamilyFallback, isNull);

    controller.text = raw;
    await tester.pump();

    expect(controller.text, raw);
  });

  testWidgets('CreateTextFieldBlock advances focus on done', (
    WidgetTester tester,
  ) async {
    final firstController = TextEditingController();
    final secondController = TextEditingController();
    final firstFocusNode = FocusNode();
    final secondFocusNode = FocusNode();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);
    addTearDown(firstFocusNode.dispose);
    addTearDown(secondFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CreateTextFieldBlock(
                label: 'First',
                controller: firstController,
                hintText: 'First',
                focusNode: firstFocusNode,
                nextFocusNode: secondFocusNode,
                onChanged: (_) {},
              ),
              CreateTextFieldBlock(
                label: 'Second',
                controller: secondController,
                hintText: 'Second',
                focusNode: secondFocusNode,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextField, 'First'));
    await tester.pump();
    expect(firstFocusNode.hasFocus, isTrue);

    final firstInput = tester.widget<TextField>(find.byType(TextField).first);
    expect(firstInput.textInputAction, TextInputAction.done);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(firstFocusNode.hasFocus, isFalse);
    expect(secondFocusNode.hasFocus, isTrue);
  });

  testWidgets('CreateTextFieldBlock uses newline action for multiline fields', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateTextFieldBlock(
            label: 'Brief',
            controller: controller,
            hintText: 'Brief',
            minLines: 4,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.textInputAction, TextInputAction.newline);
    expect(input.keyboardType, TextInputType.multiline);
    expect(input.onEditingComplete, isNull);

    await tester.enterText(find.byType(TextField), 'a\n\n\n\nb');
    await tester.pump();

    expect(controller.text, 'a\n\nb');

    controller.text = 'c\n\n\nd';
    await tester.pump();

    expect(controller.text, 'c\n\nd');
  });
}

TextStyle? _firstSkewedWidgetFragmentStyle(
  Iterable<RichText> texts,
  String value,
) {
  for (final text in texts) {
    final style = _skewedWidgetFragmentStyle(text.text, value);
    if (style != null) return style;
  }
  return null;
}

TextStyle? _skewedWidgetFragmentStyle(InlineSpan span, String value) {
  TextStyle? style;
  span.visitChildren((child) {
    if (child is WidgetSpan) {
      final childStyle = _skewedTextStyle(child.child, value);
      if (childStyle != null) {
        style = childStyle;
        return false;
      }
    }
    return true;
  });
  return style;
}

TextStyle? _skewedTextStyle(Widget widget, String value) {
  if (widget is! Transform) return null;
  if (!_matchesIosInlineEmphasisSkew(widget.transform)) return null;
  final child = widget.child;
  if (child is Text && child.data == value) {
    return child.style;
  }
  return null;
}

bool _matchesIosInlineEmphasisSkew(Matrix4 transform) {
  final expected = Matrix4.skewX(GenesisTypography.iosInlineEmphasisSkew);
  for (var index = 0; index < transform.storage.length; index += 1) {
    if ((transform.storage[index] - expected.storage[index]).abs() > 0.0001) {
      return false;
    }
  }
  return true;
}
