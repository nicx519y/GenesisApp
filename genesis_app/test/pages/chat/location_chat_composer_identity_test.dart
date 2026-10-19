import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'composer displays the decoded Origin avatar on its first frame',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.red, BlendMode.src);
      final picture = recorder.endRecording();
      final snapshot = picture.toImageSync(16, 16);
      picture.dispose();
      addTearDown(snapshot.dispose);
      final outgoing = ChatMessageVm(
        localId: 'origin-snapshot',
        senderId: 'role-1',
        senderName: 'Lilith',
        avatarSnapshot: snapshot,
        text: 'Hello',
        isMe: true,
        isPlayerControlledRole: true,
        status: 'sending',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'world-1',
            locationId: 'location-1',
            active: false,
            initialOutgoingMessage: outgoing,
          ),
        ),
      );
      final input = tester.widget<LocationChatComposerInput>(
        find.byType(LocationChatComposerInput),
      );
      expect(input.showSpeakerIdentity, isTrue);
      expect(input.selfAvatarSnapshot, isNotNull);
      expect(identical(input.selfAvatarSnapshot, snapshot), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      final controller = LocationChatMentionEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationChatComposerInput(
              controller: controller,
              focusNode: focus,
              inputEnabled: true,
              sendEnabled: false,
              sending: false,
              onSend: () async {},
              onToggleMessageType: () {},
              selfName: 'Lilith',
              selfAvatarSnapshot: snapshot,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('speaker-character-snapshot')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('speaker-character')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Origin role is visible on first frame and survives message reconciliation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final outgoing = ChatMessageVm(
        localId: 'origin-pending',
        senderId: 'role-1',
        senderName: 'Lilith',
        avatarUrl: 'https://example.com/role.png',
        text: 'Hello',
        isMe: true,
        isPlayerControlledRole: true,
        status: 'sending',
      );
      Widget page() => MaterialApp(
        home: LocationChatPanel(
          worldId: 'world-1',
          locationId: 'location-1',
          active: false,
          initialOutgoingMessage: outgoing,
        ),
      );
      await tester.pumpWidget(page());
      var input = tester.widget<LocationChatComposerInput>(
        find.byType(LocationChatComposerInput),
      );
      expect(input.showSpeakerIdentity, isTrue);
      expect(input.selfName, 'Lilith');
      expect(input.selfAvatarUrl, 'https://example.com/role.png');
      outgoing.senderName = 'Account name';
      outgoing.avatarUrl = 'https://example.com/account.png';
      await tester.pumpWidget(page());
      input = tester.widget<LocationChatComposerInput>(
        find.byType(LocationChatComposerInput),
      );
      expect(input.selfName, 'Lilith');
      expect(input.selfAvatarUrl, 'https://example.com/role.png');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('speaker avatar and hint stay hidden until identity is ready', (
    tester,
  ) async {
    final controller = LocationChatMentionEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Future<void> show(bool ready, String name) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationChatComposerInput(
            controller: controller,
            focusNode: focus,
            inputEnabled: true,
            sendEnabled: false,
            sending: false,
            onSend: () async {},
            onToggleMessageType: () {},
            showSpeakerIdentity: ready,
            selfName: name,
            selfAvatarUrl: '',
          ),
        ),
      ),
    );
    await show(false, 'Account name');
    expect(
      find.byKey(const ValueKey('location-chat-message-type-toggle')),
      findsNothing,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      '',
    );
    await show(false, 'Intermediate identity');
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      '',
    );
    await show(true, 'Lilith');
    expect(
      find.byKey(const ValueKey('location-chat-message-type-toggle')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
      contains('Lilith'),
    );
  });
}
