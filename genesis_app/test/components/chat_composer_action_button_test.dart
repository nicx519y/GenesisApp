import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_scene_plate_tokens.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_type.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';

void main() {
  testWidgets('text send label uses the shared action and still submits', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Draft');
    addTearDown(controller.dispose);
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: true,
            sending: false,
            sendLabel: 'Send',
            onSend: () async => sends++,
          ),
        ),
      ),
    );
    expect(find.byType(ChatComposerActionButton), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-composer-send-button')));
    await tester.pump();
    expect(sends, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('action selection is independent of taps and loading', (
    tester,
  ) async {
    var taps = 0;
    final style = kLocationChatStyle;
    Future<void> render({
      required bool active,
      bool enabled = true,
      bool loading = false,
      bool animate = true,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChatComposerActionButton(
              icon: const Icon(Icons.send),
              active: active,
              onPressed: enabled ? () => taps++ : null,
              loading: loading,
              animate: animate,
              style: style,
            ),
          ),
        ),
      ),
    );
    Color? background() =>
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(ChatComposerActionButton),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color;

    for (final active in [false, true]) {
      for (final enabled in [false, true]) {
        await render(active: active, enabled: enabled);
        expect(
          background(),
          active
              ? style.composerSendButtonColor
              : style.composerSendButtonDisabledColor,
        );
        final before = taps;
        await tester.tap(find.byType(TextButton));
        await tester.pump();
        expect(taps, before + (enabled ? 1 : 0));
      }
    }
    await render(active: true);
    final before = taps;
    final press = await tester.startGesture(
      tester.getCenter(find.byType(TextButton)),
    );
    await tester.pump();
    expect(taps, before);
    await press.cancel();
    await tester.pump();
    expect(taps, before);
    for (final animate in [false, true]) {
      await render(active: true, loading: true, animate: animate);
      expect(background(), style.composerSendButtonColor);
      expect(
        find.byType(CircularProgressIndicator),
        animate ? findsOneWidget : findsNothing,
      );
      expect(find.byIcon(Icons.send), animate ? findsNothing : findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(taps, before);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'narration toggle keeps draft, focus and symmetric narrow layout',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LocationChatMentionEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var selected = false;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return LocationChatComposerInput(
                    controller: controller,
                    focusNode: focus,
                    inputEnabled: enabled,
                    sendEnabled: false,
                    sending: false,
                    onSend: () async {},
                    style: kLocationChatStyle,
                    bottomSafeAreaInset: 0,
                    messageType: selected
                        ? chatroomNarrationMessageType
                        : chatroomTextMessageType,
                    onToggleMessageType: () =>
                        setState(() => selected = !selected),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final toggle = find.byKey(
        const ValueKey('location-chat-message-type-toggle'),
      );
      final send = find.byKey(const ValueKey('chat-composer-send-button'));
      final input = find.byKey(const ValueKey('chat-composer-input-surface'));
      // Only Send stays outside the input; the toggle sits inside it.
      expect(find.byType(ChatComposerActionButton), findsOneWidget);
      Finder mark(String key) =>
          find.descendant(of: toggle, matching: find.byKey(ValueKey(key)));
      expect(mark('speaker-character'), findsOneWidget);
      expect(mark('speaker-narrator'), findsNothing);
      // An empty draft disables Send, but must still allow mode selection.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(mark('speaker-narrator'), findsOneWidget);
      // The narrator mark: the composer's grey plate, the user's own red.
      final plate = tester.widget<Container>(mark('speaker-narrator'));
      expect(
        (plate.decoration! as BoxDecoration).color,
        kLocationChatStyle.composerSendButtonDisabledColor,
      );
      final svg = tester.widget<SvgPicture>(
        find.descendant(
          of: mark('speaker-narrator'),
          matching: find.byType(SvgPicture),
        ),
      );
      expect((svg.bytesLoader as SvgAssetLoader).assetName, paragraphIconAsset);
      expect(svg.width, 14);
      expect(svg.height, 14);
      expect(
        svg.colorFilter,
        const ColorFilter.mode(kChatSelfAccentColor, BlendMode.srcIn),
      );
      expect(
        tester.getSemantics(toggle),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'First line\nSecond line\nThird line',
      );
      await tester.pump();
      final value = controller.value;
      final keyboardVisible = tester.testTextInput.isVisible;
      final height = tester.getSize(find.byType(ChatComposer)).height;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selected, isFalse);
      expect(focus.hasFocus, isTrue);
      expect(controller.value, value);
      expect(tester.testTextInput.isVisible, keyboardVisible);
      expect(tester.getSize(find.byType(ChatComposer)).height, height);
      expect(tester.getSize(toggle), const Size(40, 40));
      expect(tester.getSize(send), const Size(40, 40));
      expect(tester.getRect(toggle).left, tester.getRect(input).left);
      expect(tester.getRect(toggle).top, tester.getRect(input).top);
      expect(tester.getRect(send).left - tester.getRect(input).right, 9);
      expect(tester.getRect(input).bottom, tester.getRect(send).bottom);
      update(() => enabled = false);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      expect(selected, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
