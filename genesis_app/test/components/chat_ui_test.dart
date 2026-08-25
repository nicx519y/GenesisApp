import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/ai_content_disclaimer.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/components/gems/memory_model_entry_button.dart';
import 'package:genesis_flutter_android/app/config/genesis_image_config.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';
import 'package:genesis_flutter_android/ui/components/genesis_control_icons.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_palette.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';
import 'package:genesis_flutter_android/utils/genesis_message_image.dart';

class _JumpRecordingScrollController extends ScrollController {
  int jumpToCallCount = 0;

  @override
  void jumpTo(double value) {
    jumpToCallCount += 1;
    super.jumpTo(value);
  }

  void resetJumpToCallCount() => jumpToCallCount = 0;
}

void main() {
  testWidgets('chat bubble avatars use the 2.4 DPR cap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatAvatar(
          label: 'P',
          colors: <Color>[Colors.black, Colors.white],
        ),
      ),
    );

    final avatar = tester.widget<GenesisAvatar>(find.byType(GenesisAvatar));
    expect(
      avatar.maxDevicePixelRatio,
      GenesisImageConfig.chatAvatarMaxDevicePixelRatio,
    );
  });

  test('private chat uses a transparent status bar with dark icons', () {
    expect(
      kChatTransparentLightSystemUiOverlayStyle.statusBarColor,
      Colors.transparent,
    );
    expect(
      kChatTransparentLightSystemUiOverlayStyle.statusBarIconBrightness,
      Brightness.dark,
    );
    expect(
      kChatTransparentLightSystemUiOverlayStyle.systemStatusBarContrastEnforced,
      isFalse,
    );
  });

  LocationChatScrollCoordinator locationChatCoordinator(
    ScrollController controller,
  ) {
    final coordinator = LocationChatScrollCoordinator(controller: controller);
    addTearDown(coordinator.dispose);
    return coordinator;
  }

  List<ChatMessageVm> chatMessages(int start, int end) {
    return [
      for (var id = start; id <= end; id += 1)
        ChatMessageVm(
          localId: 'm$id',
          senderId: 'peer',
          senderName: 'Peer',
          text: 'message $id',
          isMe: id.isEven,
          status: 'sent',
          createdAt: DateTime(2026, 5, 29, 10).add(Duration(minutes: id)),
        ),
    ];
  }

  testWidgets('chat message row uses a dedicated component per bubble type', (
    WidgetTester tester,
  ) async {
    final messages = [
      ChatMessageVm(
        localId: 'self',
        senderId: 'self',
        senderName: 'Self',
        text: 'Self message',
        isMe: true,
        status: 'sent',
      ),
      ChatMessageVm(
        localId: 'other',
        senderId: 'other',
        senderName: 'Other',
        text: 'Other message',
        isMe: false,
        status: 'sent',
      ),
      ChatMessageVm.system('System message'),
      ChatMessageVm.aiContentDisclaimer(),
      ChatMessageVm(
        localId: 'narrator',
        senderId: 'nar',
        senderName: 'Narrator',
        text: 'Narrator message',
        isMe: false,
        status: 'sent',
        senderType: 'narrator',
      ),
      ChatMessageVm(
        localId: 'tick',
        senderId: 'tick',
        senderName: 'Time',
        text: 'Day 1',
        isMe: false,
        status: 'sent',
        senderType: 'tick',
        tickNo: 1,
      ),
      ChatMessageVm(
        localId: 'image',
        senderId: 'nar_pic',
        senderName: 'Narrator',
        imageUrl: 'assets/images/default_list_image.png',
        text: '',
        isMe: false,
        status: 'sent',
        senderType: 'image',
      ),
      ChatMessageVm(
        localId: 'user-enter-location',
        senderId: 'sub_tick',
        senderName: 'sub_tick',
        text: 'Alice entered the cafe',
        isMe: false,
        status: 'sent',
        senderType: 'user_enter_location',
        timelinePayload: const ChatUserEnterLocationPayloadVm(
          characterId: 'char_alice',
          toLocationId: 'loc_cafe',
          text: 'Alice entered the cafe',
        ),
      ),
      ChatMessageVm(
        localId: 'story-events',
        senderId: 'sub_tick',
        senderName: 'sub_tick',
        text: 'Alice found a ticket.',
        isMe: false,
        status: 'sent',
        senderType: 'story_events',
        tickNo: 4,
        subTickNo: 1,
        currentTime: 'Day 2, 00:09:15',
        timelinePayload: const ChatStoryEventsPayloadVm(
          locationId: 'loc_station',
          locationName: 'Old Station',
          paragraphs: [
            ChatStoryEventParagraphVm(
              timestamp: 'Day 2, 10:15',
              text: 'Alice found a ticket.',
              clue: 'The date is three years ago.',
              visibilityLabel: 'public',
            ),
          ],
        ),
      ),
      ChatMessageVm(
        localId: 'characters-moved',
        senderId: 'sub_tick',
        senderName: 'sub_tick',
        text: 'Alice → Cafe',
        isMe: false,
        status: 'sent',
        senderType: 'characters_moved',
        timelinePayload: const ChatCharactersMovedPayloadVm(
          movements: [
            ChatCharacterMovementVm(
              characterId: 'char_alice',
              characterName: 'Alice',
              toLocationId: 'loc_cafe',
              toLocationName: 'Cafe',
              isDestinationCurrentLocation: true,
            ),
          ],
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final message in messages)
                  ChatMessageRow(message: message, showDateDivider: false),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChatSelfMessageBubble), findsOneWidget);
    expect(find.byType(ChatOtherMessageBubble), findsOneWidget);
    expect(find.byType(ChatSystemMessage), findsNWidgets(2));
    expect(find.byType(ChatAiContentDisclaimerMessageBubble), findsOneWidget);
    expect(find.byType(ChatNarratorMessageBubble), findsOneWidget);
    expect(find.byType(ChatTickMessageBubble), findsOneWidget);
    expect(find.byType(ChatImageMessage), findsOneWidget);
    expect(find.byType(ChatUserEnterLocationMessageBubble), findsOneWidget);
    expect(find.byType(ChatStoryEventsMessageBubble), findsOneWidget);
    expect(find.byType(ChatCharactersMovedMessageBubble), findsOneWidget);
    expect(find.byType(ChatOtherMessageBubble), findsOneWidget);
  });

  testWidgets(
    'AI content disclaimer uses its dedicated non-interactive bubble',
    (WidgetTester tester) async {
      var longPressCount = 0;
      final message = ChatMessageVm.aiContentDisclaimer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageRow(
              message: message,
              showDateDivider: false,
              onMessageLongPressStart: (_, _, _) => longPressCount += 1,
            ),
          ),
        ),
      );

      expect(message.isAiContentDisclaimer, isTrue);
      expect(message.isSystem, isTrue);
      expect(find.byType(ChatAiContentDisclaimerMessageBubble), findsOneWidget);
      expect(find.byType(AiContentDisclaimer), findsOneWidget);
      expect(find.byType(ChatSystemMessage), findsNothing);
      expect(find.textContaining(kAiContentDisclaimerText), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            'chat-ai-content-disclaimer-message-'
            'location-chat-ai-content-disclaimer',
          ),
        ),
        findsOneWidget,
      );

      await tester.longPress(find.textContaining(kAiContentDisclaimerText));
      await tester.pump();
      expect(longPressCount, 0);
    },
  );

  testWidgets('timeline event bubbles render typed display fields', (
    WidgetTester tester,
  ) async {
    ChatCharacterMovementVm? tappedMovement;
    final messages = [
      ChatMessageVm(
        localId: 'enter',
        senderId: 'sub_tick',
        senderName: 'sub_tick',
        text: 'Alice entered the cafe',
        isMe: false,
        status: 'sent',
        senderType: 'user_enter_location',
        timelinePayload: const ChatUserEnterLocationPayloadVm(
          characterId: 'char_alice',
          toLocationId: 'loc_cafe',
          text: 'Alice entered the cafe',
        ),
      ),
      ChatMessageVm(
        localId: 'story',
        senderId: 'sub_tick',
        senderName: 'sub_tick',
        text: 'Alice found a ticket.',
        isMe: false,
        status: 'sent',
        senderType: 'story_events',
        tickNo: 4,
        subTickNo: 1,
        currentTime: 'Day 2, 00:09:15',
        timelinePayload: const ChatStoryEventsPayloadVm(
          locationId: 'loc_station',
          locationName: 'Old Station',
          paragraphs: [
            ChatStoryEventParagraphVm(
              timestamp: 'Day 2, 10:15',
              text: 'Alice found a ticket.',
              clue: 'The date is three years ago.',
              visibilityLabel: 'Mateo, Iris',
              visibleRoles: [
                ChatStoryEventVisibleRoleVm(
                  roleId: 'char_mateo',
                  name: 'Mateo',
                  isAi: true,
                ),
                ChatStoryEventVisibleRoleVm(
                  roleId: 'char_iris',
                  name: 'Iris',
                  isAi: false,
                ),
              ],
            ),
            ChatStoryEventParagraphVm(
              timestamp: 'Day 2, 10:20',
              text: 'The platform became quiet.',
              clue: '',
              visibilityLabel: 'public',
            ),
          ],
        ),
      ),
      ChatMessageVm(
        localId: 'moved',
        senderId: 'sub_tick',
        senderName: 'sub_tick',
        text: 'Alice → Cafe',
        isMe: false,
        status: 'sent',
        senderType: 'characters_moved',
        timelinePayload: const ChatCharactersMovedPayloadVm(
          movements: [
            ChatCharacterMovementVm(
              characterId: 'char_alice',
              characterName: 'Alice',
              toLocationId: 'loc_cafe',
              toLocationName: 'Cafe',
              isDestinationCurrentLocation: true,
            ),
            ChatCharacterMovementVm(
              characterId: 'char_bob',
              characterName: 'Bob',
              toLocationId: 'loc_harbor',
              toLocationName: 'Harbor',
            ),
          ],
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final message in messages)
                ChatMessageRow(
                  message: message,
                  showDateDivider: false,
                  style: kLocationChatStyle,
                  onCharactersMovedLocationTap: (movement) {
                    tappedMovement = movement;
                  },
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Alice came to the cafe'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Alice came to the cafe')).textAlign,
      TextAlign.left,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-user-enter-location-icon')),
      findsOneWidget,
    );
    final enterBubbleRect = tester.getRect(
      find.byKey(
        const ValueKey<String>('chat-user-enter-location-message-enter'),
      ),
    );
    final enterRowRect = tester.getRect(
      find.ancestor(
        of: find.text('Alice came to the cafe'),
        matching: find.byType(ChatMessageRow),
      ),
    );
    expect(enterBubbleRect.width, lessThan(enterRowRect.width));
    expect(enterBubbleRect.center.dx, closeTo(enterRowRect.center.dx, 1));
    final enterBubble = tester.widget<Container>(
      find.byKey(
        const ValueKey<String>('chat-user-enter-location-message-enter'),
      ),
    );
    final enterDecoration = enterBubble.decoration! as BoxDecoration;
    expect(enterDecoration.color, GenesisPalette.redesignWhite13);
    expect((enterDecoration.borderRadius! as BorderRadius).topLeft.x, 20);
    final enterText = tester.widget<Text>(find.text('Alice came to the cafe'));
    expect(enterText.textSpan?.style?.color, Colors.white);
    expect(enterText.textSpan?.style?.fontWeight, FontWeight.w600);
    expect(find.text('Tick 4-1 · Day 2, 00:09:15'), findsNothing);
    expect(find.text('Old Station'), findsNothing);
    expect(find.text('Event'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(eventsIconAsset),
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(clueIconAsset),
      ),
      findsOneWidget,
    );
    expect(find.text('Day 2, 10:15'), findsOneWidget);
    expect(find.text('Mateo'), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(
              locationChatCharacterIconAsset,
            ),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(userStatIconAsset),
      ),
      findsOneWidget,
    );
    expect(find.text('Alice found a ticket.'), findsOneWidget);
    expect(find.text('The date is three years ago.'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('The date is three years ago.'))
          .textSpan
          ?.style
          ?.color,
      Colors.white.withValues(alpha: 0.72),
    );
    expect(find.text('Day 2, 10:20'), findsOneWidget);
    expect(find.text('public'), findsNothing);
    expect(find.text('The platform became quiet.'), findsOneWidget);
    expect(find.text('Day 2, 10:15 · Mateo, Iris'), findsNothing);
    expect(find.text('Day 2, 10:20 · public'), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-story-event-paragraph-story-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-story-event-paragraph-story-1')),
      findsOneWidget,
    );
    final firstTimestamp = find.byKey(
      const ValueKey('chat-story-event-timestamp-story-0'),
    );
    final firstVisibility = find.byKey(
      const ValueKey('chat-story-event-visibility-story-0'),
    );
    expect(
      tester.getCenter(firstVisibility).dx,
      greaterThan(tester.getCenter(firstTimestamp).dx),
    );
    expect(
      (tester.getCenter(firstVisibility).dy -
              tester.getCenter(firstTimestamp).dy)
          .abs(),
      lessThan(2),
    );
    expect(
      tester.getTopLeft(find.text('Alice found a ticket.')).dy,
      greaterThan(tester.getBottomLeft(firstTimestamp).dy),
    );
    expect(
      tester.getTopLeft(find.text('The date is three years ago.')).dy,
      greaterThan(tester.getBottomLeft(find.text('Alice found a ticket.')).dy),
    );
    final storyBubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat-story-events-message-story')),
    );
    expect(
      (storyBubble.decoration as BoxDecoration).color,
      kLocationChatStyle.systemMessageBackgroundColor,
    );
    expect(find.text('Character destinations'), findsNothing);
    expect(find.byIcon(Icons.directions_walk_rounded), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(routeIconAsset),
      ),
      findsNWidgets(2),
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('has come to'), findsOneWidget);
    expect(find.text('has gone to'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Harbor'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Alice')).style?.fontWeight,
      FontWeight.w400,
    );
    expect(
      tester.widget<Text>(find.text('Cafe')).style?.fontWeight,
      FontWeight.w400,
    );
    final firstMovement = find.byKey(
      const ValueKey<String>('chat-character-movement-moved-0'),
    );
    final secondMovement = find.byKey(
      const ValueKey<String>('chat-character-movement-moved-1'),
    );
    expect(
      tester.getTopLeft(secondMovement).dy -
          tester.getBottomLeft(firstMovement).dy,
      closeTo(10, 0.01),
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(
              const ValueKey<String>('chat-story-event-paragraph-story-1'),
            ),
          )
          .margin,
      const EdgeInsets.only(top: 10),
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('chat-story-events-message-story'),
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 5,
        ),
      ),
      findsNWidgets(3),
    );
    expect(find.text('Alice → Cafe'), findsNothing);
    final movedBubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat-characters-moved-message-moved')),
    );
    expect(
      (movedBubble.decoration as BoxDecoration).color,
      kLocationChatStyle.systemMessageBackgroundColor,
    );
    final locationLabel = tester.widget<Text>(find.text('Harbor'));
    expect(
      locationLabel.style?.color,
      kLocationChatStyle.systemMessageTextStyle.color,
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-character-movement-location-moved-1')),
    );
    expect(tappedMovement?.toLocationId, 'loc_harbor');
    expect(find.text('sub_tick'), findsNothing);
    expect(find.text('char_alice'), findsNothing);
    expect(find.byType(ChatAvatar), findsNothing);
  });

  testWidgets('location entry event matches the Worldo redesign pill', (
    WidgetTester tester,
  ) async {
    var longPressCount = 0;
    final message = ChatMessageVm(
      localId: 'redesign-enter',
      senderId: 'sub_tick',
      senderName: 'sub_tick',
      text: 'Adrian entered Grand Ballroom',
      isMe: false,
      status: 'sent',
      senderType: 'user_enter_location',
      timelinePayload: const ChatUserEnterLocationPayloadVm(
        characterId: 'char_adrian',
        toLocationId: 'grand_ballroom',
        text: 'Adrian entered Grand Ballroom',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: ChatMessageRow(
            message: message,
            showDateDivider: false,
            onMessageLongPressStart: (_, _, _) => longPressCount += 1,
          ),
        ),
      ),
    );

    final bubbleFinder = find.byKey(
      const ValueKey<String>('chat-user-enter-location-message-redesign-enter'),
    );
    final bubble = tester.widget<Container>(bubbleFinder);
    final decoration = bubble.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x21FFFFFF));
    expect((decoration.borderRadius! as BorderRadius).topLeft.x, 20);
    final icon = find.byKey(
      const ValueKey<String>('chat-user-enter-location-icon'),
    );
    expect(tester.getSize(icon), const Size.square(12));
    expect(
      Theme.of(
        tester.element(icon),
      ).extension<GenesisChatTheme>()?.enterLocationIcon,
      GenesisPalette.redesignWhite60,
    );
    expect(find.text('Adrian entered Grand Ballroom'), findsNothing);
    final text = tester.widget<Text>(
      find.text('Adrian came to Grand Ballroom'),
    );
    expect(text.textAlign, TextAlign.left);
    expect(text.textSpan?.style?.color, Colors.white);
    expect(text.textSpan?.style?.fontWeight, FontWeight.w600);
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((span) => span.text), [
      'Adrian',
      ' came to ',
      'Grand Ballroom',
    ]);
    expect(spans[1].style?.color, GenesisPalette.white.withValues(alpha: 0.73));
    expect(spans[1].style?.fontWeight, FontWeight.w400);

    await tester.longPress(find.text('Adrian came to Grand Ballroom'));
    await tester.pump();
    expect(longPressCount, 1);
  });

  testWidgets('tick event visibility uses available width when wrapping', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(520, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const roleNames =
        'Mateo Cruz, Iris, Marcus Aurelius, Alexandra Johnson, River Song, '
        'Theodore Roosevelt, Cassandra Nova';
    final message = ChatMessageVm(
      localId: 'wrapping-tick',
      senderId: 'tick',
      senderName: 'Tick',
      text: 'A narrow-screen event.',
      isMe: false,
      status: 'sent',
      senderType: 'tick',
      tickNo: 2,
      timelinePayload: const ChatTickPayloadVm(
        storyEvents: ChatStoryEventsPayloadVm(
          locationId: 'loc_station',
          locationName: 'Old Station',
          paragraphs: [
            ChatStoryEventParagraphVm(
              timestamp: 'Day 2, 10:15',
              text: 'A narrow-screen event.',
              clue: '',
              visibilityLabel: roleNames,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: message,
            showDateDivider: false,
            style: kLocationChatStyle,
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('chat-story-event-visibility-wrapping-tick-tick-0'),
      ),
      findsNothing,
    );
    expect(find.text(roleNames), findsOneWidget);
    expect(tester.getSize(find.text(roleNames)).width, greaterThan(224));
    expect(tester.getSize(find.text(roleNames)).height, greaterThan(20));
    expect(
      tester.getTopLeft(find.text(roleNames)).dy,
      greaterThan(tester.getBottomLeft(find.text('Day 2, 10:15')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat message list can render an oldest-edge notice', (
    WidgetTester tester,
  ) async {
    const notice = 'Oldest edge notice';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            controller: ScrollController(),
            topTitle: '',
            oldestEdgeNotice: notice,
            showDateDividers: false,
            messages: [
              ChatMessageVm(
                localId: 'tick-1',
                senderId: 'tick',
                senderName: 'Tick',
                senderType: 'tick',
                text: '',
                isMe: false,
                status: 'sent',
                tickNo: 1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining(notice), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining(notice)).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('chat-tick-message-bubble')))
            .dy,
      ),
    );
  });

  testWidgets('failed self message can be tapped to retry', (tester) async {
    var retryCount = 0;
    final message = ChatMessageVm(
      localId: 'failed-message',
      clientMsgId: 'failed-client-id',
      senderId: 'me',
      senderName: 'Me',
      text: 'Retry me',
      isMe: true,
      status: 'failed',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            controller: ScrollController(),
            messages: [message],
            topTitle: '',
            showDateDividers: false,
            onFailedMessageTap: (_) => retryCount += 1,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('chat-message-retry-failed-message')),
    );
    await tester.pump();
    expect(retryCount, 1);

    await tester.tap(find.text('Retry me'));
    await tester.pump();
    expect(retryCount, 2);
  });

  testWidgets('chat header can show Memory & Model entry', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHeader(
            title: 'Moonlit Market',
            subtitle: '2 characters',
            connected: true,
            connecting: false,
            onBack: () {},
            trailing: TextButton(
              key: const ValueKey('memory-model-entry'),
              onPressed: () => tapped = true,
              child: const Text('CC4.5'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('memory-model-entry')), findsOneWidget);
    expect(find.text('CC4.5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('memory-model-entry')));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('chat header constrains long model entry beside title', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHeader(
            title: 'The Wisteria Terrace (1)',
            subtitle: 'kitchen maid',
            connected: true,
            connecting: false,
            onBack: () {},
            showSubtitle: false,
            trailing: MemoryModelEntryButton(
              modelLabel: 'top_pick_v3_5',
              darkHeader: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(find.text('The Wisteria Terrace (1)'));
    final modelRect = tester.getRect(
      find.byKey(const ValueKey('memory-model-entry')),
    );

    expect(modelRect.width, lessThanOrEqualTo(kMemoryModelEntryMaxWidth));
    expect(titleRect.right, lessThanOrEqualTo(modelRect.left + 1));
  });

  testWidgets('location model entry matches the room header design', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Center(
          child: MemoryModelEntryButton(
            modelLabel: 'Miranda',
            variant: MemoryModelEntryButtonVariant.roomHeader,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('memory-model-entry'));
    final material = tester.widget<Material>(button);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(tester.getSize(button).height, 28);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(62));
    expect(material.color, Colors.white.withValues(alpha: 0.13));
    expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, 9);
    expect(shape.side.color, Colors.white.withValues(alpha: 0.18));
    expect(
      find.descendant(of: button, matching: find.byType(SvgPicture)),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('memory-model-entry-icon'))),
      const Size.square(12),
    );

    await tester.tap(button);
    await tester.pump();
    expect(tapped, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Center(
          child: MemoryModelEntryButton(
            modelLabel: 'top_pick_v3_5',
            variant: MemoryModelEntryButtonVariant.roomHeader,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('memory-model-entry'))).width,
      greaterThan(104),
    );
    final fullModelName = tester.widget<Text>(find.text('top_pick_v3_5'));
    expect(fullModelName.overflow, isNull);
    expect(fullModelName.softWrap, isFalse);
  });

  testWidgets('anchored message list keeps oldest notice while loading', (
    WidgetTester tester,
  ) async {
    const notice = 'Oldest edge notice';
    final coordinator = locationChatCoordinator(ScrollController());
    Widget build({required bool loading}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              oldestEdgeNotice: notice,
              oldestEdgeLoading: loading,
              showDateDividers: false,
              messages: chatMessages(1, 5),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(loading: false));
    await tester.pumpAndSettle();
    coordinator.deactivate();
    final noticeSize = tester.getSize(find.byType(ChatOldestEdgeContent));
    final firstMessage = find.byKey(const ValueKey<String>('m1'));
    final firstMessageTop = tester.getTopLeft(firstMessage).dy;

    await tester.pumpWidget(build(loading: true));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining(notice), findsOneWidget);
    expect(tester.getSize(find.byType(ChatOldestEdgeContent)), noticeSize);
    expect(tester.getTopLeft(firstMessage).dy, firstMessageTop);
  });

  testWidgets('location chat keeps glass surfaces grouped at the bottom edge', (
    WidgetTester tester,
  ) async {
    final coordinator = locationChatCoordinator(ScrollController());
    final messages = <ChatMessageVm>[
      for (var index = 0; index < 16; index += 1)
        ChatMessageVm(
          localId: 'glass-$index',
          senderId: 'character-$index',
          senderName: 'Character $index',
          text: 'Glass message $index',
          isMe: false,
          status: 'sent',
          senderType: 'character',
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark().copyWith(
          platform: TargetPlatform.android,
        ),
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              topTitle: '',
              showDateDividers: false,
              messages: messages,
              style: GenesisChatTheme.worldoDark().locationChat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackdropGroup), findsOneWidget);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    final backdropKey = tester
        .widget<BackdropGroup>(find.byType(BackdropGroup))
        .backdropKey;
    expect(find.byType(BackdropFilter), findsNWidgets(messages.length));

    final scrollable = find.byType(Scrollable).first;
    final gesture = await tester.startGesture(tester.getCenter(scrollable));
    await gesture.moveBy(const Offset(0, -240));
    await tester.pump();

    expect(find.byType(BackdropGroup), findsOneWidget);
    expect(
      tester.widget<BackdropGroup>(find.byType(BackdropGroup)).backdropKey,
      same(backdropKey),
    );
    expect(find.byType(BackdropFilter), findsNWidgets(messages.length));
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(
                      const ValueKey<String>('chat-message-bubble-glass-15'),
                    ),
                  )
                  .decoration!
              as BoxDecoration)
          .color,
      const Color(0x993A3942),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNWidgets(messages.length));
  });

  testWidgets(
    'anchored message list stops at the oldest message before the notice',
    (WidgetTester tester) async {
      final coordinator = locationChatCoordinator(ScrollController());
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  topTitle: '',
                  oldestEdgeNotice: 'Oldest edge notice',
                  oldestEdgeNoticeRequiresSecondScroll: true,
                  showDateDividers: false,
                  messages: chatMessages(1, 30),
                  style: style,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final scrollableRect = tester.getRect(scrollable);
      final position = coordinator.controller.position;
      expect(position.maxScrollExtent, greaterThan(scrollableRect.height));
      expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));

      await tester.drag(scrollable, const Offset(0, 2000));
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('m1'))).dy,
        closeTo(scrollableRect.top + 18, 1),
      );
      expect(
        tester.getBottomLeft(find.textContaining('Oldest edge notice')).dy,
        lessThanOrEqualTo(scrollableRect.top + 18),
      );

      await tester.drag(scrollable, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(position.pixels, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('m1'))).dy,
        closeTo(
          tester.getBottomLeft(find.textContaining('Oldest edge notice')).dy + 16,
          1,
        ),
      );
    },
  );

  testWidgets('short messages start at their top with the notice just above', (
    WidgetTester tester,
  ) async {
    final coordinator = locationChatCoordinator(ScrollController());
    final style = ChatUiStyleConfig.standard.copyWith(
      messageListPadding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: NotificationListener<ScrollNotification>(
              onNotification: coordinator.handleScrollNotification,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                oldestEdgeNotice: 'Oldest edge notice',
                oldestEdgeNoticeRequiresSecondScroll: true,
                showDateDividers: false,
                messages: chatMessages(1, 3),
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    final scrollableRect = tester.getRect(scrollable);
    final position = coordinator.controller.position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.maxScrollExtent, lessThan(scrollableRect.height / 2));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('m1'))).dy,
      closeTo(scrollableRect.top + 18, 1),
    );

    await tester.drag(scrollable, const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(position.pixels, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('m1'))).dy,
      closeTo(tester.getBottomLeft(find.textContaining('Oldest edge notice')).dy + 16, 1),
    );
  });

  testWidgets('notice is shown directly when there are no messages', (
    WidgetTester tester,
  ) async {
    final coordinator = locationChatCoordinator(ScrollController());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationChatAnchoredMessageList(
            coordinator: coordinator,
            topTitle: '',
            oldestEdgeNotice: 'Oldest edge notice',
            oldestEdgeNoticeRequiresSecondScroll: true,
            showDateDividers: false,
            messages: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coordinator.controller.position.maxScrollExtent, 0);
    expect(find.textContaining('Oldest edge notice'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Oldest edge notice')).dy,
      greaterThanOrEqualTo(tester.getTopLeft(find.byType(Scrollable).first).dy),
    );
  });

  testWidgets(
    'anchored message list does not scroll short notice and message content',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                oldestEdgeNotice: 'Oldest edge notice',
                showDateDividers: false,
                messages: chatMessages(1, 3),
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final firstMessageTop = tester
          .getTopLeft(find.byKey(const ValueKey('m1')))
          .dy;

      expect(position.minScrollExtent, 0);
      expect(position.maxScrollExtent, 0);

      await tester.drag(scrollable, const Offset(0, -80));
      await tester.pump();

      expect(position.pixels, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('m1'))).dy,
        firstMessageTop,
      );
    },
  );

  testWidgets(
    'anchored message list stays linear when only system messages precede center',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
      );

      final messages = [
        ChatMessageVm(
          localId: 'tick-1',
          senderId: 'tick',
          senderName: 'Tick',
          senderType: 'tick',
          text: '',
          isMe: false,
          status: 'sent',
          tickNo: 1,
          currentTime: 'Match Day, 14:00',
        ),
        ChatMessageVm(
          localId: 'm1',
          senderId: 'me',
          senderName: 'Me',
          text: 'first message',
          isMe: true,
          status: 'sent',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                oldestEdgeNotice: 'Oldest edge notice',
                showDateDividers: false,
                messages: messages,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final noticeTop = tester.getTopLeft(find.textContaining('Oldest edge notice')).dy;

      expect(position.minScrollExtent, 0);
      expect(position.maxScrollExtent, 0);

      await tester.drag(scrollable, const Offset(0, -80));
      await tester.pump();

      expect(position.pixels, 0);
      expect(tester.getTopLeft(find.textContaining('Oldest edge notice')).dy, noticeTop);
    },
  );

  testWidgets(
    'anchored message list does not scroll short content before center',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                topTitle: '',
                oldestEdgeNotice: 'Oldest edge notice',
                showDateDividers: false,
                messages: chatMessages(1, 3),
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final firstMessageTop = tester
          .getTopLeft(find.byKey(const ValueKey('m1')))
          .dy;

      expect(position.minScrollExtent, 0);
      expect(position.maxScrollExtent, 0);

      await tester.drag(scrollable, const Offset(0, -80));
      await tester.pump();

      expect(position.pixels, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('m1'))).dy,
        firstMessageTop,
      );
    },
  );

  testWidgets('anchored message list pins bottom while last bubble grows', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    final coordinator = locationChatCoordinator(controller);
    final messages = chatMessages(1, 24);
    final style = ChatUiStyleConfig.standard.copyWith(
      messageListPadding: EdgeInsets.zero,
    );

    Widget build() {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: LocationChatAnchoredMessageList(
              coordinator: coordinator,
              messages: messages,
              topTitle: '',
              showDateDividers: false,
              style: style,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    final lastMessage = find.byKey(const ValueKey<String>('m24'));
    final bottomBefore = tester.getBottomLeft(lastMessage).dy;

    messages.last.text = List.filled(
      16,
      'streaming content keeps growing',
    ).join('\n');
    await tester.pumpWidget(build());

    expect(
      controller.position.pixels,
      closeTo(controller.position.maxScrollExtent, 0.1),
    );
    expect(tester.getBottomLeft(lastMessage).dy, closeTo(bottomBefore, 1));
  });

  testWidgets(
    'anchored message list preserves position when last bubble grows away from bottom',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final messages = chatMessages(1, 24);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build() {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent - 120);
      coordinator.deactivate();
      await tester.pump();
      final pixelsBefore = controller.position.pixels;
      final observedOffsets = <double>[];
      void recordOffset() => observedOffsets.add(controller.position.pixels);
      controller.addListener(recordOffset);

      messages.last.text = List.filled(
        16,
        'streaming content keeps growing',
      ).join('\n');
      await tester.pumpWidget(build());
      controller.removeListener(recordOffset);

      expect(controller.position.pixels, closeTo(pixelsBefore, 0.1));
      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent),
      );
      expect(
        observedOffsets,
        everyElement(inInclusiveRange(pixelsBefore - 0.1, pixelsBefore + 0.1)),
      );
    },
  );

  testWidgets(
    'anchored message list skips geometry while a transform is unlaid out',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final listKey = GlobalKey();
      final messages = chatMessages(1, 24);
      var width = 360.0;

      Widget build() {
        return MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 360,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Transform.scale(
                      key: ValueKey<double>(constraints.maxWidth),
                      alignment: Alignment.topLeft,
                      scale: 1,
                      child: LocationChatAnchoredMessageList(
                        key: listKey,
                        coordinator: coordinator,
                        messages: messages,
                        topTitle: '',
                        showDateDividers: false,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent - 120);
      await tester.pump();

      messages.last.text = List.filled(8, 'updated message').join('\n');
      width = 320;
      await tester.pumpWidget(build());

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat message list shows first divider and long gaps', (
    WidgetTester tester,
  ) async {
    final start = DateTime(2026, 5, 29, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            controller: ScrollController(),
            topTitle: '',
            messages: [
              ChatMessageVm(
                localId: 'm1',
                senderId: 'peer',
                senderName: 'Peer',
                text: 'first',
                isMe: false,
                status: 'sent',
                createdAt: start,
              ),
              ChatMessageVm(
                localId: 'm2',
                senderId: 'peer',
                senderName: 'Peer',
                text: 'second',
                isMe: false,
                status: 'sent',
                createdAt: start.add(const Duration(minutes: 30)),
              ),
              ChatMessageVm(
                localId: 'm3',
                senderId: 'peer',
                senderName: 'Peer',
                text: 'third',
                isMe: false,
                status: 'sent',
                createdAt: start.add(const Duration(minutes: 61)),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ChatDateDivider), findsNWidgets(2));
  });

  testWidgets('chat message list can hide date dividers', (
    WidgetTester tester,
  ) async {
    final start = DateTime(2026, 5, 29, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            controller: ScrollController(),
            topTitle: '',
            showDateDividers: false,
            messages: [
              ChatMessageVm(
                localId: 'm1',
                senderId: 'peer',
                senderName: 'Peer',
                text: 'first',
                isMe: false,
                status: 'sent',
                createdAt: start,
              ),
              ChatMessageVm(
                localId: 'm2',
                senderId: 'peer',
                senderName: 'Peer',
                text: 'second',
                isMe: false,
                status: 'sent',
                createdAt: start.add(const Duration(hours: 1)),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ChatDateDivider), findsNothing);
  });

  testWidgets(
    'anchored message list keeps center stable when history prepends',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build(List<ChatMessageVm> messages) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(chatMessages(21, 80)));
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      coordinator.deactivate();
      await tester.pumpAndSettle();

      final centerFinder = find.byKey(const ValueKey<String>('m21'));
      expect(centerFinder, findsOneWidget);
      final before = tester.getTopLeft(centerFinder).dy;

      await tester.pumpWidget(build(chatMessages(1, 80)));
      await tester.pumpAndSettle();

      expect(centerFinder, findsOneWidget);
      final after = tester.getTopLeft(centerFinder).dy;
      expect(after, closeTo(before, 1));
    },
  );

  testWidgets(
    'history waits for the loading collapse before prepending without a jump',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );
      var collapseCount = 0;

      Widget build({
        required List<ChatMessageVm> messages,
        required bool loading,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                oldestEdgeLoading: loading,
                onOldestEdgeLoadingCollapsed: () => collapseCount += 1,
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        build(messages: chatMessages(21, 80), loading: false),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      coordinator.deactivate();
      await tester.pump();
      controller.resetJumpToCallCount();

      final retainedMessage = find.byKey(const ValueKey<String>('m21'));
      final prependedMessage = find.byKey(const ValueKey<String>('m1'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(
        build(messages: chatMessages(21, 80), loading: true),
      );
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration * 0.5);
      final expandingTop = tester.getTopLeft(retainedMessage).dy;
      expect(expandingTop, greaterThan(baselineTop));

      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration * 0.5);
      final expandedTop = tester.getTopLeft(retainedMessage).dy;
      expect(expandedTop, greaterThan(expandingTop));

      await tester.pumpWidget(
        build(messages: chatMessages(1, 80), loading: false),
      );
      expect(prependedMessage, findsNothing);
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration * 0.5);
      expect(prependedMessage, findsNothing);
      final collapsingTop = tester.getTopLeft(retainedMessage).dy;
      expect(collapsingTop, lessThan(expandedTop));
      expect(collapsingTop, greaterThan(baselineTop));

      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration * 0.5);
      await tester.pump(const Duration(milliseconds: 1));
      expect(prependedMessage, findsNothing);
      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));

      await tester.pump();
      expect(prependedMessage, findsOneWidget);
      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
      expect(collapseCount, 1);
    },
  );

  testWidgets(
    'AI disclaimer is a normal anchored first row without a second-scroll stop',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build(List<ChatMessageVm> messages) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: NotificationListener<ScrollNotification>(
                onNotification: coordinator.handleScrollNotification,
                child: LocationChatAnchoredMessageList(
                  coordinator: coordinator,
                  messages: messages,
                  topTitle: '',
                  showDateDividers: false,
                  style: style,
                ),
              ),
            ),
          ),
        );
      }

      final ordinaryMessages = chatMessages(1, 30);
      await tester.pumpWidget(build(ordinaryMessages));
      await tester.pumpAndSettle();
      controller.jumpTo(120);
      coordinator.deactivate();
      await tester.pump();
      controller.resetJumpToCallCount();

      final retainedMessage = find.byKey(const ValueKey<String>('m1'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;
      await tester.pumpWidget(
        build([ChatMessageVm.aiContentDisclaimer(), ...ordinaryMessages]),
      );

      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
      expect(coordinator.oldestMessageStopOffset, isNull);

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, 2000));
      await tester.pumpAndSettle();

      expect(controller.position.pixels, 0);
      expect(find.textContaining(kAiContentDisclaimerText), findsOneWidget);
    },
  );

  testWidgets(
    'history layout transaction ignores a simultaneous live tail append',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build({
        required List<ChatMessageVm> messages,
        required bool loading,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                oldestEdgeLoading: loading,
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        build(messages: chatMessages(21, 80), loading: false),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      coordinator.deactivate();
      await tester.pump();
      controller.resetJumpToCallCount();

      final retainedMessage = find.byKey(const ValueKey<String>('m21'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(
        build(messages: chatMessages(21, 80), loading: true),
      );
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration);
      await tester.pumpWidget(
        build(messages: chatMessages(1, 81), loading: false),
      );
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey<String>('m1')), findsNothing);

      await tester.pump();

      expect(find.byKey(const ValueKey<String>('m1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('m81')), findsOneWidget);
      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
    },
  );

  testWidgets(
    'history layout transaction survives a replaced display boundary row',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );
      final initialMessages = <ChatMessageVm>[
        ChatMessageVm(
          localId: 'tick-old',
          senderId: 'tick',
          senderName: 'Time',
          text: 'Old Tick',
          isMe: false,
          status: 'sent',
          senderType: 'tick',
        ),
        ...chatMessages(22, 80),
      ];
      final nextMessages = <ChatMessageVm>[
        ...chatMessages(1, 20),
        ChatMessageVm(
          localId: 'tick-new',
          senderId: 'tick',
          senderName: 'Time',
          text: 'New Tick',
          isMe: false,
          status: 'sent',
          senderType: 'tick',
        ),
        ...chatMessages(22, 80),
      ];

      Widget build({
        required List<ChatMessageVm> messages,
        required bool loading,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                oldestEdgeLoading: loading,
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(messages: initialMessages, loading: false));
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      coordinator.deactivate();
      await tester.pump();
      controller.resetJumpToCallCount();

      final retainedMessage = find.byKey(const ValueKey<String>('m22'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(build(messages: initialMessages, loading: true));
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration);
      await tester.pumpWidget(build(messages: nextMessages, loading: false));
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('tick-old')), findsNothing);
      expect(find.byKey(const ValueKey<String>('tick-new')), findsOneWidget);
      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
    },
  );

  testWidgets(
    'later history prepend stays anchored after the loading transaction',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build({
        required List<ChatMessageVm> messages,
        required bool loading,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                oldestEdgeLoading: loading,
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        build(messages: chatMessages(21, 80), loading: false),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      coordinator.deactivate();
      await tester.pump();

      final retainedMessage = find.byKey(const ValueKey<String>('m21'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(
        build(messages: chatMessages(21, 80), loading: true),
      );
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration);
      await tester.pumpWidget(
        build(messages: chatMessages(11, 80), loading: false),
      );
      await tester.pump(locationChatOldestEdgeLoadingAnimationDuration);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      controller.resetJumpToCallCount();

      await tester.pumpWidget(
        build(messages: chatMessages(1, 80), loading: false),
      );

      expect(find.byKey(const ValueKey<String>('m1')), findsOneWidget);
      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
    },
  );

  testWidgets(
    'history prepend without a painted loading state corrects before paint',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build(List<ChatMessageVm> messages) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(chatMessages(21, 80)));
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      coordinator.deactivate();
      await tester.pump();
      controller.resetJumpToCallCount();

      final retainedMessage = find.byKey(const ValueKey<String>('m21'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(build(chatMessages(1, 80)));

      expect(find.byKey(const ValueKey<String>('m1')), findsOneWidget);
      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
    },
  );

  testWidgets(
    'detached anchor survives a later height change above the viewport',
    (WidgetTester tester) async {
      final controller = _JumpRecordingScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build(List<ChatMessageVm> messages) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      final shortHistory = <ChatMessageVm>[
        ChatMessageVm(
          localId: 'history-changing-height',
          senderId: 'peer',
          senderName: 'Peer',
          text: 'short history',
          isMe: false,
          status: 'sent',
        ),
        ...chatMessages(21, 80),
      ];
      final tallHistory = <ChatMessageVm>[
        ChatMessageVm(
          localId: 'history-changing-height',
          senderId: 'peer',
          senderName: 'Peer',
          text: List<String>.filled(20, 'history expanded').join('\n'),
          isMe: false,
          status: 'sent',
        ),
        ...chatMessages(21, 80),
      ];

      await tester.pumpWidget(build(shortHistory));
      await tester.pumpAndSettle();
      controller.jumpTo(80);
      coordinator.deactivate();
      await tester.pump();
      controller.resetJumpToCallCount();

      final retainedMessage = find.byKey(const ValueKey<String>('m21'));
      final baselineTop = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(build(tallHistory));

      expect(tester.getTopLeft(retainedMessage).dy, closeTo(baselineTop, 1));
      expect(controller.jumpToCallCount, 0);
    },
  );

  testWidgets(
    'anchored message list keeps viewport stable when rolling window evicts head',
    (WidgetTester tester) async {
      final controller = ScrollController();
      final coordinator = locationChatCoordinator(controller);
      final style = ChatUiStyleConfig.standard.copyWith(
        messageListPadding: EdgeInsets.zero,
      );

      Widget build(List<ChatMessageVm> messages) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 360,
              child: LocationChatAnchoredMessageList(
                coordinator: coordinator,
                messages: messages,
                topTitle: '',
                showDateDividers: false,
                style: style,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build(chatMessages(1, 80)));
      await tester.pumpAndSettle();
      final retainedMessage = find.byKey(const ValueKey<String>('m30'));
      await tester.ensureVisible(retainedMessage);
      await tester.pumpAndSettle();
      coordinator.deactivate();
      expect(
        controller.position.maxScrollExtent - controller.position.pixels,
        greaterThan(24),
      );
      final before = tester.getTopLeft(retainedMessage).dy;

      await tester.pumpWidget(build(chatMessages(2, 81)));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(retainedMessage).dy, closeTo(before, 1));
    },
  );

  test('chat date divider rule includes first message only plus long gaps', () {
    final start = DateTime(2026, 5, 29, 10);

    expect(shouldShowChatDateDivider(null, start), isTrue);
    expect(
      shouldShowChatDateDivider(start, start.add(const Duration(minutes: 30))),
      isFalse,
    );
    expect(
      shouldShowChatDateDivider(start, start.add(const Duration(minutes: 31))),
      isTrue,
    );
  });

  testWidgets(
    'chat header uses location title icon and character subtitle icon',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatHeader(
              title: 'Market',
              subtitle: 'Alice, Bob',
              connected: true,
              connecting: false,
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader.toString().contains(characterStatIconAsset),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('location chat header uses white character subtitle icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHeader(
            title: 'Market',
            subtitle: 'Alice, Bob',
            connected: true,
            connecting: false,
            onBack: () {},
            style: kLocationChatStyle,
            subtitleIconAsset: locationChatCharacterIconAsset,
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(
              locationChatCharacterIconAsset,
            ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('redesign location chat header keeps the scene overlay visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ChatHeader(
              title: 'Market',
              subtitle: 'Alice, Bob',
              connected: true,
              connecting: false,
              onBack: () {},
              style: context.genesisChatTheme.locationChat,
            ),
          ),
        ),
      ),
    );

    final style = tester.widget<ChatHeader>(find.byType(ChatHeader)).style!;
    expect(style.headerBackdropBlurSigma, 0);
    expect(style.headerBackgroundGradient, isNull);
    expect(style.headerBackgroundColor, Colors.transparent);
    final headerBackButton = find.descendant(
      of: find.byType(ChatHeader),
      matching: find.byType(GenesisBackButton),
    );
    expect(headerBackButton, findsOneWidget);
    expect(
      find.descendant(
        of: headerBackButton,
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('location chat composer uses 90 percent glass with blur four', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: TextEditingController(),
            inputEnabled: true,
            sendEnabled: false,
            sending: false,
            onSend: () async {},
            style: kLocationChatStyle,
          ),
        ),
      ),
    );

    expect(kLocationChatStyle.composerBackdropBlurSigma, 4);
    expect(kLocationChatStyle.composerBackgroundGradient, isNull);
    expect(kLocationChatStyle.composerBackgroundColor.a, closeTo(0.9, 0.01));
    expect(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });

  testWidgets('location chat header left aligns title and subtitle rows', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ChatHeader(
              title: 'Grand Ballroom',
              titleSuffix: '(1)',
              subtitle: 'Vivienne Ashford, Sebastian, Dorian',
              connected: true,
              connecting: false,
              onBack: () {},
              alignContentLeft: true,
              showTitleIcon: false,
              showSubtitleIcon: false,
              style: context.genesisChatTheme.locationChat,
              backButtonVariant: ChatHeaderBackButtonVariant.compactGlass,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: MemoryModelEntryButton(
                  modelLabel: 'Miranda',
                  variant: MemoryModelEntryButtonVariant.roomHeader,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(find.text('Grand Ballroom'));
    final subtitleRect = tester.getRect(
      find.text('Vivienne Ashford, Sebastian, Dorian'),
    );
    final modelRect = tester.getRect(
      find.byKey(const ValueKey('memory-model-entry')),
    );
    final headerRect = tester.getRect(find.byType(ChatHeader));
    final backRect = tester.getRect(
      find.byKey(const ValueKey<String>('chat-header-compact-back-button')),
    );
    expect(titleRect.left, closeTo(56, 0.01));
    expect(subtitleRect.left, closeTo(titleRect.left, 0.01));
    expect(subtitleRect.top - titleRect.bottom, closeTo(3, 0.01));
    expect(modelRect.right, closeTo(headerRect.right - 16, 0.01));
    expect(modelRect.center.dy, closeTo(headerRect.center.dy, 0.01));
    expect(modelRect.center.dy, closeTo(backRect.center.dy, 0.01));
    expect(
      modelRect.center.dy,
      closeTo((titleRect.top + subtitleRect.bottom) / 2, 0.01),
    );
    expect(subtitleRect.right, lessThanOrEqualTo(modelRect.left));
  });

  testWidgets('location chat compact back button matches the redesign', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHeader(
            title: 'Grand Ballroom (1)',
            subtitle: 'Adrian',
            connected: true,
            connecting: false,
            onBack: () => backCount += 1,
            alignContentLeft: true,
            showTitleIcon: false,
            style: kLocationChatStyle,
            backButtonVariant: ChatHeaderBackButtonVariant.compactGlass,
          ),
        ),
      ),
    );

    final headerRect = tester.getRect(find.byType(ChatHeader));
    final backButton = find.byKey(
      const ValueKey<String>('chat-header-compact-back-button'),
    );
    final backRect = tester.getRect(backButton);
    expect(backRect.size, const Size.square(30));
    expect(backRect.left, closeTo(headerRect.left + 16, 0.01));
    expect(tester.getRect(find.text('Grand Ballroom (1)')).left, 56);
    expect(
      find.descendant(
        of: backButton,
        matching: find.byWidgetPredicate(
          (widget) => widget is GenesisBackIcon && widget.size == 14,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(backButton);
    await tester.pump();
    expect(backCount, 1);
  });

  testWidgets('location chat title uses the model entry intrinsic width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHeader(
            title: 'The Wisteria Terrace With A Long Name (1)',
            subtitle: '',
            connected: true,
            connecting: false,
            onBack: () {},
            showSubtitle: false,
            alignContentLeft: true,
            style: kLocationChatStyle,
            trailing: MemoryModelEntryButton(
              modelLabel: 'M',
              darkHeader: true,
              compact: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(
      find.text('The Wisteria Terrace With A Long Name (1)'),
    );
    final modelRect = tester.getRect(
      find.byKey(const ValueKey('memory-model-entry')),
    );

    expect(modelRect.width, kMemoryModelEntryMinWidth);
    expect(titleRect.right, lessThanOrEqualTo(modelRect.left - 10));
  });

  testWidgets('private chat style hides peer name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer Name',
              text: 'hello',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
            style: kPrivateChatStyle,
          ),
        ),
      ),
    );

    expect(find.text('Peer Name'), findsNothing);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('chat row sanitizes malformed UTF-16 text before layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'bad-utf16',
              senderId: 'peer',
              senderName: 'bad \uD800 name',
              text: 'hello \uD800 world',
              currentTime: 'time \uDC00',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('bad \uFFFD name'), findsOneWidget);
    expect(find.text('time \uFFFD'), findsOneWidget);
  });

  testWidgets('player controlled chat avatar carries no accent ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer Name',
              text: 'hello',
              isMe: false,
              isPlayerControlledRole: true,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    // Message avatars dropped the red player ring; the highlighted sender
    // name is what marks a human-played role in the list now.
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return border.top.color == GenesisPalette.redesignAccent;
      }),
      findsNothing,
    );
  });

  testWidgets('player controlled chat sender name uses highlighted color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer Name',
              text: 'hello',
              isMe: false,
              isPlayerControlledRole: true,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final name = tester.widget<Text>(find.text('Peer Name'));
    expect(name.style?.color, GenesisPalette.redesignAccent);
  });

  testWidgets(
    'location chat places the timestamp directly after the sender name',
    (WidgetTester tester) async {
      const messageId = 'location-message-metadata';
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.worldoDark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ChatMessageRow(
                message: ChatMessageVm(
                  localId: messageId,
                  senderId: 'character-sebastian',
                  senderName: 'Sebastian',
                  text: 'A quiet reply.',
                  currentTime: '23:04 | 01/07/2026',
                  isMe: false,
                  status: 'sent',
                  senderType: 'character',
                ),
                showDateDivider: false,
                style: context.genesisChatTheme.locationChat,
              ),
            ),
          ),
        ),
      );

      final nameFinder = find.byKey(
        const ValueKey<String>('chat-sender-name-$messageId'),
      );
      final timeFinder = find.byKey(
        const ValueKey<String>('chat-sender-time-$messageId'),
      );
      final name = tester.widget<Text>(nameFinder);
      final time = tester.widget<Text>(timeFinder);
      final nameRect = tester.getRect(nameFinder);
      final timeRect = tester.getRect(timeFinder);

      expect(timeRect.left - nameRect.right, closeTo(8, 0.01));
      expect(name.style?.fontFamily, GenesisTypography.fontFamily);
      expect(name.style?.fontSize, 11);
      expect(name.style?.fontWeight, FontWeight.w600);
      expect(name.style?.color, GenesisPalette.redesignSoftWhite);
      expect(time.style?.fontFamily, GenesisTypography.fontFamily);
      expect(time.style?.fontSize, 9.5);
      expect(time.style?.fontWeight, FontWeight.w400);
      expect(time.style?.color, GenesisPalette.redesignWhite45);
    },
  );

  testWidgets('self chat message places avatar on the right', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'me',
              senderName: 'Me',
              text: 'hello',
              isMe: true,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final bubbleRight = tester.getTopRight(find.byType(ChatMessageBubble)).dx;
    final avatarLeft = tester.getTopLeft(find.byType(ChatAvatar)).dx;
    expect(avatarLeft, greaterThan(bubbleRight));
  });

  testWidgets('chat message avatar renders image url before fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer',
              avatarUrl: 'assets/images/default_list_image.png',
              text: 'hello',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/default_list_image.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('chat message avatar renders generated fallback for empty url', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer Name',
              text: 'hello',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.text('PN'), findsOneWidget);
  });

  testWidgets('char npc message renders fixed NPC avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'char_npc',
              senderName: 'Village Guide',
              text: 'hello',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
            style: kLocationChatStyle,
          ),
        ),
      ),
    );

    final avatarFinder = find.byKey(const ValueKey('chat-npc-avatar'));
    expect(avatarFinder, findsOneWidget);
    expect(tester.getSize(avatarFinder), const Size(36, 36));
    expect(find.text('NPC'), findsOneWidget);
    expect(find.text('VG'), findsNothing);

    final avatarBox = tester.widget<DecoratedBox>(
      find.descendant(of: avatarFinder, matching: find.byType(DecoratedBox)),
    );
    final decoration = avatarBox.decoration as BoxDecoration;
    expect(decoration.color, GenesisPalette.redesignWhite14);
    // Rounded square like the role and user avatars, not a circle.
    expect(decoration.shape, BoxShape.rectangle);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(kLocationChatStyle.avatarBorderRadius),
    );
    expect(decoration.border?.top.color, GenesisPalette.redesignWhite18);

    final label = tester.widget<Text>(find.text('NPC'));
    expect(label.style?.color, Colors.white);
    expect(label.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('redesign NPC avatar stays legible on the dark background', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: const Scaffold(body: Center(child: ChatNpcAvatar())),
      ),
    );

    final avatarFinder = find.byKey(const ValueKey('chat-npc-avatar'));
    final avatarBox = tester.widget<DecoratedBox>(
      find.descendant(of: avatarFinder, matching: find.byType(DecoratedBox)),
    );
    final decoration = avatarBox.decoration as BoxDecoration;
    expect(decoration.color, const Color(0x24FFFFFF));
    expect(decoration.border?.top.color, const Color(0x2EFFFFFF));
    // Rounded square like every other avatar in the room, not a circle.
    expect(decoration.shape, BoxShape.rectangle);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(
        GenesisChatTheme.worldoDark().standard.avatarBorderRadius,
      ),
    );
    expect(tester.widget<Text>(find.text('NPC')).style?.color, Colors.white);
  });

  testWidgets('chat message bubble parses markdown italic text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer',
              text: 'hello *quietly*',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.text('hello quietly'), findsOneWidget);
    final bubbleText = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(Text),
      ),
    );
    expect(_textHasItalicFragment(bubbleText, 'quietly'), isTrue);
    expect(
      _textFragmentColor(bubbleText, 'quietly'),
      GenesisPalette.redesignInk50,
    );
  });

  testWidgets('self chat markdown uses the AI emphasis color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'me',
              senderName: 'Me',
              text: '*historical role message*',
              isMe: true,
              status: 'sent',
              senderType: 'character',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final bubbleText = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(Text),
      ),
    );
    expect(
      _textFragmentColor(bubbleText, 'historical role message'),
      GenesisPalette.redesignInk50,
    );
  });

  testWidgets('chat markdown preserves backslash text', (
    WidgetTester tester,
  ) async {
    const raw = r'value\tend\\slash\u1234\*';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: ChatMessageVm(
              localId: 'escaped-message',
              senderId: 'me',
              senderName: 'Me',
              text: raw,
              isMe: true,
              status: 'sent',
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(Text),
      ),
    );
    expect(text.textSpan?.toPlainText(), raw);
  });

  testWidgets(
    'chat message bubble uses decorative unicode visual fallback text',
    (WidgetTester tester) async {
      const raw = '☛ ˙۵ও⃢♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀〬𓈒ֹ⁠꙳';
      const rendered = '☛ ˙۵▤▤▤♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀°ₒ✩';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: ChatMessageVm(
                localId: 'unicode-message',
                senderId: 'me',
                senderName: 'Me',
                text: raw,
                isMe: true,
                status: 'sent',
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(ChatMessageBubble),
          matching: find.byType(Text),
        ),
      );
      expect(text.textSpan?.toPlainText(), rendered);
      expect(text.textSpan?.style?.fontFamily, GenesisTypography.fontFamily);
      expect(
        text.textSpan?.style?.fontFamilyFallback,
        GenesisTypography.fontFamilyFallback,
      );
    },
  );

  testWidgets('chat message bubble uses soft markdown emphasis on iOS', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer',
              text: 'hello *quietly*',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final style = _firstSkewedWidgetFragmentStyle(
      tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ChatMessageBubble),
          matching: find.byType(Text),
        ),
      ),
      'quietly',
    );
    expect(style?.fontStyle, FontStyle.normal);
    expect(style?.color, GenesisPalette.redesignInk50);
  });

  testWidgets('chat message bubble skews iOS markdown emphasis per token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'peer',
              senderName: 'Peer',
              text: 'hello *quietly now*',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final pieces = _skewedWidgetFragmentTexts(
      tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ChatMessageBubble),
          matching: find.byType(Text),
        ),
      ),
    );

    expect(pieces, containsAll(<String>['quietly', 'now']));
    expect(pieces, isNot(contains('quietly now')));
  });

  testWidgets('chat rows reserve matching avatar space on both sides', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Column(
              children: [
                ChatMessageRow(
                  message: ChatMessageVm(
                    localId: 'other',
                    senderId: 'peer',
                    senderName: 'Peer',
                    text: 'left',
                    isMe: false,
                    status: 'sent',
                  ),
                  showDateDivider: false,
                ),
                ChatMessageRow(
                  message: ChatMessageVm(
                    localId: 'me',
                    senderId: 'me',
                    senderName: 'Me',
                    text: 'right',
                    isMe: true,
                    status: 'sent',
                  ),
                  showDateDivider: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final rows = find.byType(ChatMessageRow);
    final otherRow = tester.getRect(rows.at(0));
    final meRow = tester.getRect(rows.at(1));
    final bubbles = find.byType(ChatMessageBubble);
    final otherBubble = tester.getRect(bubbles.at(0));
    final meBubble = tester.getRect(bubbles.at(1));
    final reservedWidth =
        ChatUiStyleConfig.standard.avatarSize +
        ChatUiStyleConfig.standard.avatarBubbleGap;

    expect(
      otherBubble.right,
      lessThanOrEqualTo(otherRow.right - reservedWidth),
    );
    expect(meBubble.left, greaterThanOrEqualTo(meRow.left + reservedWidth));
  });

  testWidgets('character chat avatar omits redstar icon badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'character',
              senderName: 'Guide',
              text: 'hello',
              isMe: false,
              status: 'sent',
              senderType: 'character',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.byType(ChatAiBadge), findsNothing);
  });

  testWidgets('AI role bubble uses the Worldo translucent scene surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: ChatMessageBubble(
            message: ChatMessageVm(
              localId: 'ai-role',
              senderId: 'character-sebastian',
              senderName: 'Sebastian',
              text: 'A quiet reply.',
              isMe: false,
              status: 'sent',
              senderType: 'character',
            ),
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      find.byKey(const ValueKey<String>('chat-message-bubble-ai-role')),
    );
    final decoration = bubble.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x993A3942));
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 6);
    expect(radius.topRight.x, 14);
    expect(radius.bottomRight.x, 14);
    expect(radius.bottomLeft.x, 14);
    expect(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    final backdropFilter = tester.widget<BackdropFilter>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(BackdropFilter),
      ),
    );
    expect(backdropFilter.blendMode, BlendMode.srcOver);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('chat-message-bubble-ai-role')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: ChatMessageBubble(
            message: ChatMessageVm(
              localId: 'real-user',
              senderId: 'user-peer',
              senderName: 'Peer',
              text: 'A user reply.',
              isMe: false,
              status: 'sent',
              senderType: 'user',
            ),
          ),
        ),
      ),
    );

    final userBubble = tester.widget<Container>(
      find.byKey(const ValueKey<String>('chat-message-bubble-real-user')),
    );
    expect(
      (userBubble.decoration! as BoxDecoration).color,
      const Color(0x993A3942),
    );
    expect(
      ((userBubble.decoration! as BoxDecoration).borderRadius! as BorderRadius)
          .topLeft,
      Radius.zero,
    );
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: ChatMessageBubble(
            message: ChatMessageVm(
              localId: 'player-controlled-role',
              senderId: 'character-player',
              senderName: 'Player role',
              text: 'A player-controlled reply.',
              isMe: false,
              status: 'sent',
              senderType: 'character',
              isPlayerControlledRole: true,
            ),
          ),
        ),
      ),
    );

    final playerRoleBubble = tester.widget<Container>(
      find.byKey(
        const ValueKey<String>('chat-message-bubble-player-controlled-role'),
      ),
    );
    expect(
      (playerRoleBubble.decoration! as BoxDecoration).color,
      const Color(0x993A3942),
    );
    expect(
      ((playerRoleBubble.decoration! as BoxDecoration).borderRadius!
              as BorderRadius)
          .topLeft,
      Radius.zero,
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('self role bubble matches the Worldo red scene plate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Scaffold(
          body: ChatMessageBubble(
            style: GenesisChatTheme.worldoDark().locationChat,
            message: ChatMessageVm(
              localId: 'self-role',
              senderId: 'character-adrian',
              senderName: 'Adrian',
              text: 'A measured reply.',
              isMe: true,
              status: 'sent',
              senderType: 'character',
            ),
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      find.byKey(const ValueKey<String>('chat-message-bubble-self-role')),
    );
    expect(
      bubble.padding,
      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    );
    final decoration = bubble.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0x99C41F2E));
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 14);
    expect(radius.topRight.x, 6);
    expect(radius.bottomRight.x, 14);
    expect(radius.bottomLeft.x, 14);
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(Text),
      ),
    );
    expect(text.textSpan?.style?.fontSize, 13);
    expect(text.textSpan?.style?.height, kChatBodyLineHeight);
    // The self bubble now carries the same backdrop glass as the AI bubbles.
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('system chat message uses normal bubble width and centers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm.system(
              'A long narrator message that should be constrained like normal chat bubbles.',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final systemBox = tester.getRect(find.byType(ChatSystemMessage));
    final bubbleBox = tester.getRect(
      find.byKey(const ValueKey('chat-system-message-bubble')),
    );
    final reservedWidth =
        ChatUiStyleConfig.standard.avatarSize +
        ChatUiStyleConfig.standard.avatarBubbleGap;
    expect(bubbleBox.width, lessThanOrEqualTo(400 - reservedWidth * 2 + 1));
    expect(bubbleBox.center.dx, closeTo(systemBox.center.dx, 1));
    final text = tester.widget<Text>(
      find.text(
        'A long narrator message that should be constrained like normal chat bubbles.',
      ),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
  });

  testWidgets('narrator system message parses star markdown italic text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'narrator',
              senderName: 'Narrator',
              text: 'The room grows *cold*.',
              isMe: false,
              status: 'sent',
              senderType: 'narrator',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.text('The room grows cold.'), findsOneWidget);
    final systemText = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatSystemMessage),
        matching: find.byType(Text),
      ),
    );
    expect(_textHasItalicFragment(systemText, 'cold'), isTrue);
    expect(
      _textFragmentColor(systemText, 'cold'),
      GenesisPalette.redesignInk50,
    );
  });

  testWidgets('tick plate spans the bubble column, narrator the full width', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark().copyWith(
          platform: TargetPlatform.android,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: ChatMessageList(
              controller: controller,
              topTitle: '',
              reverse: false,
              showDateDividers: false,
              style: context.genesisChatTheme.locationChat,
              messages: [
                // Long enough that both bubbles hit their max width, so their
                // outer edges mark the bubble column's true limits.
                ChatMessageVm(
                  localId: 'role-1',
                  senderId: 'peer',
                  senderName: 'Vivienne',
                  text:
                      'The doors are still open, and the whole board is '
                      'watching to see which of us walks through them first '
                      'tonight, so choose carefully before you move.',
                  isMe: false,
                  status: 'sent',
                ),
                ChatMessageVm(
                  localId: 'self-1',
                  senderId: 'me',
                  senderName: 'Adrian',
                  text:
                      'Then we should go through them together and let the '
                      'board watch all it likes, because there is nothing '
                      'left in this room worth staying for anyway.',
                  isMe: true,
                  status: 'sent',
                ),
                ChatMessageVm(
                  localId: 'narrator-1',
                  senderId: 'narrator',
                  senderName: 'Narrator',
                  text: 'The doors open again.',
                  isMe: false,
                  status: 'sent',
                  senderType: 'narrator',
                ),
                ChatMessageVm(
                  localId: 'tick-1',
                  senderId: 'tick',
                  senderName: 'Tick',
                  text: '',
                  isMe: false,
                  status: 'sent',
                  senderType: 'tick',
                  timelinePayload: const ChatTickPayloadVm(
                    globalText: 'The room has started keeping score.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Rect rectOf(String key) =>
        tester.getRect(find.byKey(ValueKey<String>(key)));

    final role = rectOf('chat-message-bubble-role-1');
    final self = rectOf('chat-message-bubble-self-1');
    final narrator = rectOf('chat-system-message-bubble');
    final tick = rectOf('chat-tick-message-surface');

    // The tick plate spans the bubble column: from a full-width self bubble's
    // left edge to a full-width AI bubble's right edge.
    expect(tick.left, closeTo(self.left, 0.01));
    expect(tick.right, closeTo(role.right, 0.01));

    // Narrator is the widest tier, the tick sits inside it, and even a
    // max-width bubble is narrower still.
    expect(tick.width, lessThan(narrator.width));
    expect(role.width, lessThan(tick.width));
    expect(self.width, lessThan(tick.width));
    expect(narrator.left, lessThan(tick.left));
    expect(narrator.right, greaterThan(tick.right));
  });

  testWidgets('narrator icon starts at the same gutter as the role avatar', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark().copyWith(
          platform: TargetPlatform.android,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: ChatMessageList(
              controller: controller,
              topTitle: '',
              reverse: false,
              showDateDividers: false,
              style: context.genesisChatTheme.locationChat,
              messages: [
                ChatMessageVm(
                  localId: 'role-1',
                  senderId: 'peer',
                  senderName: 'Vivienne',
                  text: 'The doors are still open.',
                  isMe: false,
                  status: 'sent',
                ),
                ChatMessageVm(
                  localId: 'narrator-1',
                  senderId: 'narrator',
                  senderName: 'Narrator',
                  text: 'The doors open again.',
                  isMe: false,
                  status: 'sent',
                  senderType: 'narrator',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final style = tester
        .widget<ChatMessageList>(find.byType(ChatMessageList))
        .style!;
    final listPadding = style.messageListPadding;
    final avatarLeft = tester.getTopLeft(find.byType(ChatAvatar)).dx;
    final narratorPlateLeft = tester
        .getTopLeft(find.byKey(const ValueKey('chat-system-message-bubble')))
        .dx;
    final narratorIconLeft = tester
        .getTopLeft(
          find.byWidgetPredicate(
            (widget) =>
                widget is SvgPicture &&
                widget.bytesLoader.toString().contains(paragraphIconAsset),
          ),
        )
        .dx;

    // The plate itself starts at the message list gutter, level with the role
    // avatars; its text then takes the same inner gutter as the tick and story
    // plates instead of running flush against the plate border.
    expect(listPadding.left, 10);
    expect(avatarLeft, listPadding.left);
    expect(narratorPlateLeft, avatarLeft);
    expect(
      narratorIconLeft,
      narratorPlateLeft + style.systemMessagePadding.left,
    );
  });

  testWidgets('Worldo narrator matches the transparent scene-plate design', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark().copyWith(
          platform: TargetPlatform.android,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: ChatMessageRow(
              message: ChatMessageVm(
                localId: 'worldo-narrator',
                senderId: 'narrator',
                senderName: 'Narrator',
                text: 'The doors open again.',
                isMe: false,
                status: 'sent',
                senderType: 'narrator',
              ),
              showDateDivider: false,
              style: context.genesisChatTheme.locationChat,
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('chat-system-message-bubble')),
    );
    // The narrator sits on a 50% page-colour plate: invisible on the solid
    // background, a scrim over a scene photo.
    expect(
      (surface.decoration! as BoxDecoration).color,
      const Color(0x80151517),
    );

    final text = tester.widget<Text>(find.text('The doors open again.'));
    final textStyle = text.textSpan!.style!;
    expect(textStyle.color, const Color(0xBAFFFFFF));
    expect(textStyle.fontSize, 13);
    expect(textStyle.fontWeight, FontWeight.w400);
    expect(textStyle.fontStyle, FontStyle.italic);
    expect(textStyle.height, kChatBodyLineHeight);
  });

  testWidgets('location chat keeps avatars aligned and bars one-third in', (
    WidgetTester tester,
  ) async {
    final style = kLocationChatStyle;
    final expectedOuterPadding = 16.0;
    // The system/tick bars stay one 40px-avatar-third inside the gutter; that
    // spacer is a fixed location-chat constant, not derived from avatarSize.
    final expectedInnerPadding = 40 / 3;
    final expectedBubbleEdge = expectedOuterPadding + expectedInnerPadding;

    expect(style.conversationBackgroundColor, const Color(0xFF111111));
    expect(style.conversationBackgroundColor.a, 1);
    expect(style.messageListPadding.left, expectedOuterPadding);
    expect(style.messageListPadding.right, expectedOuterPadding);
    expect(style.avatarSideSpacerWidth, closeTo(expectedInnerPadding, 0.01));
    expect(style.systemMessageMargin.left, closeTo(expectedInnerPadding, 0.01));
    expect(
      style.systemMessageMargin.right,
      closeTo(expectedInnerPadding, 0.01),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Padding(
              padding: style.messageListPadding,
              child: Column(
                children: [
                  ChatMessageRow(
                    message: ChatMessageVm(
                      localId: 'me',
                      senderId: 'me',
                      senderName: 'Me',
                      text: List.filled(24, 'wide').join(' '),
                      isMe: true,
                      status: 'sent',
                    ),
                    showDateDivider: false,
                    style: style,
                  ),
                  ChatMessageRow(
                    message: ChatMessageVm(
                      localId: 'other',
                      senderId: 'peer',
                      senderName: 'Peer',
                      text: List.filled(24, 'wide').join(' '),
                      isMe: false,
                      status: 'sent',
                    ),
                    showDateDivider: false,
                    style: style,
                  ),
                  ChatMessageRow(
                    message: ChatMessageVm(
                      localId: 'narrator',
                      senderId: 'nar',
                      senderName: '旁白',
                      text: 'A full width narrator bar.',
                      isMe: false,
                      status: 'sent',
                      senderType: 'narrator',
                    ),
                    showDateDivider: false,
                    style: style,
                  ),
                  ChatMessageRow(
                    message: ChatMessageVm(
                      localId: 'tick',
                      senderId: 'tick',
                      senderName: 'Time',
                      text: 'Day 45, 19:34',
                      isMe: false,
                      status: 'sent',
                      senderType: 'tick',
                      tickNo: 7,
                    ),
                    showDateDivider: false,
                    style: style,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final avatars = find.byType(ChatAvatar);
    final bubbles = find.byType(ChatMessageBubble);
    final meAvatar = tester.getRect(avatars.at(0));
    final otherAvatar = tester.getRect(avatars.at(1));
    final meBubble = tester.getRect(bubbles.at(0));
    final otherBubble = tester.getRect(bubbles.at(1));
    final narratorBar = tester.getRect(
      find.byKey(const ValueKey('chat-system-message-bubble')),
    );
    final tickBar = tester.getRect(
      find.byKey(const ValueKey('chat-tick-message-bubble')),
    );
    final narratorText = tester.getRect(
      find.text('A full width narrator bar.'),
    );
    final tickText = tester.getRect(find.text('Tick 7 · Day 45, 19:34'));

    expect(meAvatar.right, closeTo(400 - expectedOuterPadding, 1));
    expect(otherAvatar.left, closeTo(expectedOuterPadding, 1));
    expect(meBubble.left, closeTo(expectedBubbleEdge, 1));
    expect(otherBubble.right, closeTo(400 - expectedBubbleEdge, 1));
    expect(narratorBar.left, closeTo(expectedOuterPadding, 1));
    expect(narratorBar.right, closeTo(400 - expectedOuterPadding, 1));
    expect(tickBar.left, closeTo(expectedOuterPadding, 1));
    expect(tickBar.right, closeTo(400 - expectedOuterPadding, 1));
    expect(
      narratorText.left,
      closeTo(expectedBubbleEdge + style.systemMessagePadding.left + 22, 1),
    );
    expect(tickText.left, closeTo(expectedBubbleEdge + 14, 1));
  });

  testWidgets('underscore markdown remains plain text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'narrator',
              senderName: 'Narrator',
              text: 'The room grows _cold_.',
              isMe: false,
              status: 'sent',
              senderType: 'narrator',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.text('The room grows _cold_.'), findsOneWidget);
  });

  testWidgets('narrator system message text is left aligned', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'nar-1',
              senderId: 'nar',
              senderName: '旁白',
              text: 'A narrator paragraph can wrap across multiple lines.',
              isMe: false,
              status: 'sent',
              senderType: 'narrator',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.text('A narrator paragraph can wrap across multiple lines.'),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(text.textAlign, TextAlign.left);
  });

  testWidgets('real newlines render in user and narrator messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageRow(
                message: ChatMessageVm(
                  localId: 'peer-1',
                  senderId: 'peer',
                  senderName: 'Peer',
                  text: 'First\n\nSecond',
                  isMe: false,
                  status: 'sent',
                ),
                showDateDivider: false,
              ),
              ChatMessageRow(
                message: ChatMessageVm(
                  localId: 'nar-1',
                  senderId: 'narrator',
                  senderName: 'Narrator',
                  text: 'Aside\n\nContinues',
                  isMe: false,
                  status: 'sent',
                  senderType: 'narrator',
                ),
                showDateDivider: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('First\n\nSecond'), findsOneWidget);
    expect(find.text('Aside\n\nContinues'), findsOneWidget);
  });

  testWidgets('chat markdown does not restore escaped backslash layers', (
    WidgetTester tester,
  ) async {
    const raw = r'double\\n stays literal';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: ChatMessageVm(
              localId: 'double-backslash-message',
              senderId: 'me',
              senderName: 'Me',
              text: raw,
              isMe: true,
              status: 'sent',
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(Text),
      ),
    );
    expect(text.textSpan?.toPlainText(), raw);
  });

  testWidgets('message and narrator bubbles report long press starts', (
    WidgetTester tester,
  ) async {
    final pressed = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageRow(
                message: ChatMessageVm(
                  localId: 'peer-1',
                  senderId: 'peer',
                  senderName: 'Peer',
                  text: 'Peer message',
                  isMe: false,
                  status: 'sent',
                ),
                showDateDivider: false,
                onMessageLongPressStart: (_, message, _) {
                  pressed.add(message.localId);
                },
              ),
              ChatMessageRow(
                message: ChatMessageVm(
                  localId: 'nar-1',
                  senderId: 'narrator',
                  senderName: 'Narrator',
                  text: 'Narrator message',
                  isMe: false,
                  status: 'sent',
                  senderType: 'narrator',
                ),
                showDateDivider: false,
                onMessageLongPressStart: (_, message, _) {
                  pressed.add(message.localId);
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Peer message'));
    await tester.pump();
    await tester.longPress(find.text('Narrator message'));
    await tester.pump();

    expect(pressed, ['peer-1', 'nar-1']);
  });

  testWidgets('tick system message spans avatar-edge width with tick label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ChatMessageRow(
              message: ChatMessageVm(
                localId: 'tick-112',
                senderId: 'tick',
                senderName: 'Time',
                text: 'Day 45, 19:34',
                isMe: false,
                status: 'sent',
                senderType: 'tick',
                roundId: '1455',
                tickNo: 7,
                subTickNo: 1,
              ),
              showDateDivider: false,
            ),
          ),
        ),
      ),
    );

    final rowBox = tester.getRect(find.byType(ChatMessageRow));
    final bubbleBox = tester.getRect(
      find.byKey(const ValueKey('chat-tick-message-bubble')),
    );

    expect(find.text('Tick 7-1 · Day 45, 19:34'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Tick 7-1 · Day 45, 19:34'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.left);
    expect(bubbleBox.left, closeTo(rowBox.left, 1));
    expect(bubbleBox.right, closeTo(rowBox.right, 1));
  });

  testWidgets('tick system message includes zero tick number', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'tick-zero-one',
              senderId: 'tick',
              senderName: 'Time',
              text: 'Day 1, 20:25',
              isMe: false,
              status: 'sent',
              senderType: 'tick',
              tickNo: 0,
              subTickNo: 1,
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.text('Tick 0-1 · Day 1, 20:25'), findsOneWidget);
  });

  testWidgets(
    'tick progress uses the tick surface with title and avatars only',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageRow(
              message: ChatMessageVm(
                localId: 'tick-progress',
                senderId: 'tick',
                senderName: 'Time',
                text: '',
                isMe: false,
                status: 'progressing',
                senderType: 'tick',
                timelinePayload: const ChatTickProgressPayloadVm(
                  title: 'Progressing the World',
                  avatars: [
                    ChatTickProgressAvatarVm(
                      name: 'Guide',
                      url: 'assets/images/default_list_image.png',
                    ),
                  ],
                ),
              ),
              showDateDivider: false,
              style: kLocationChatStyle,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('chat-tick-message-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-tick-message-accent')),
        findsNothing,
      );
      expect(find.textContaining('Progressing the World'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('chat-tick-progress-title')),
            )
            .style
            ?.fontSize,
        13,
      );
      expect(
        find.image(const AssetImage('assets/images/default_list_image.png')),
        findsOneWidget,
      );
      expect(find.textContaining('Compressing recent memories'), findsNothing);
      expect(find.textContaining('Advancing the world timeline'), findsNothing);
      expect(
        find.textContaining('Generating the next story beat'),
        findsNothing,
      );
      expect(find.textContaining('Updating character locations'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'composite tick renders every non-empty section in order and forwards actions',
    (WidgetTester tester) async {
      ChatCharacterMovementVm? tappedMovement;
      ChatMessageVm? longPressedMessage;
      final message = ChatMessageVm(
        localId: 'tick-composite',
        globalMessageId: 8702,
        messageId: 101,
        locationMessageId: 29,
        roundId: '7359',
        tickNo: 1,
        subTickNo: 2,
        senderId: 'tick',
        senderName: 'SubTick',
        text: '',
        currentTime: 'Day 1, 13:50',
        isMe: false,
        status: 'sent',
        senderType: 'tick',
        timelinePayload: const ChatTickPayloadVm(
          globalText: 'The promise-shaped key pulses.',
          storyEvents: ChatStoryEventsPayloadVm(
            locationId: 'loc_vault',
            locationName: 'Vault',
            paragraphs: [
              ChatStoryEventParagraphVm(
                timestamp: 'Day 1, 13:30',
                text: 'Frost creeps toward Room 0.',
                clue: 'It spells Elara.',
                visibilityLabel: 'public',
              ),
            ],
          ),
          charactersMoved: ChatCharactersMovedPayloadVm(
            movements: [
              ChatCharacterMovementVm(
                characterId: 'char_2',
                characterName: 'Elara',
                toLocationId: 'loc_room_0',
                toLocationName: 'Room 0',
              ),
              ChatCharacterMovementVm(
                characterId: 'char_3',
                characterName: 'Lyra',
                toLocationId: 'loc_room_0',
                toLocationName: 'Room 0',
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ChatMessageRow(
                message: message,
                showDateDivider: false,
                style: kLocationChatStyle,
                onMessageLongPressStart: (_, pressedMessage, _) {
                  longPressedMessage = pressedMessage;
                },
                onCharactersMovedLocationTap: (movement) {
                  tappedMovement = movement;
                },
              ),
            ),
          ),
        ),
      );

      final header = find.text('Tick 1-2');
      final globalSection = find.byKey(
        const ValueKey<String>('chat-tick-global-section'),
      );
      final globalText = find.descendant(
        of: globalSection,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.textSpan != null,
        ),
      );
      final eventText = find.text('Frost creeps toward Room 0.');
      final routeIcon = find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(routeIconAsset),
      );
      expect(
        find.byKey(const ValueKey<String>('chat-tick-message-bubble')),
        findsOneWidget,
      );
      expect(header, findsOneWidget);
      expect(find.text('Global'), findsNothing);
      expect(globalText, findsOneWidget);
      expect(
        _skewedWidgetFragmentTexts(
          tester.widgetList<Text>(
            find.descendant(of: globalSection, matching: find.byType(Text)),
          ),
        ),
        containsAll(<String>['The', 'promise-shaped', 'key', 'pulses.']),
      );
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      final tickBubble = tester.widget<Container>(
        find.byKey(const ValueKey<String>('chat-tick-message-surface')),
      );
      final tickDecoration = tickBubble.decoration! as BoxDecoration;
      expect(tickDecoration.color, GenesisPalette.redesignInk60);
      expect(tickDecoration.borderRadius, BorderRadius.circular(10));
      expect(
        (tickDecoration.border! as Border).top.color,
        GenesisPalette.redesignWhite20,
      );
      final tickAccent = find.byKey(
        const ValueKey<String>('chat-tick-message-accent'),
      );
      expect(tickAccent, findsNothing);
      expect(tester.widget<Text>(header).style?.color, Colors.white);
      expect(
        find.descendant(
          of: globalSection,
          matching: find.byIcon(Icons.public_rounded),
        ),
        findsNothing,
      );
      expect(tester.widget<Text>(header).style?.fontWeight, FontWeight.w800);
      expect(
        find.descendant(
          of: globalSection,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SvgPicture &&
                widget.bytesLoader.toString().contains(paragraphIconAsset),
          ),
        ),
        findsNothing,
      );
      // Tick body tracks the narrator tier for whichever theme is active.
      expect(
        tester.widget<Text>(globalText).textSpan?.style?.color,
        GenesisPalette.redesignWhite85,
      );
      expect(
        tester.widget<Text>(globalText).textSpan?.style?.fontStyle,
        FontStyle.normal,
      );
      expect(
        find.ancestor(
          of: globalText,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Transform &&
                _matchesIosInlineEmphasisSkew(widget.transform),
          ),
        ),
        findsNothing,
      );
      expect(find.text('Event'), findsNothing);
      expect(find.text('Vault'), findsNothing);
      expect(find.text('public'), findsNothing);
      // The tick time row leads with the drawn Beat record glyph now, so the
      // shared events asset must not appear anywhere in the bubble.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader.toString().contains(eventsIconAsset),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('chat-tick-message-bubble')),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );
      expect(eventText, findsOneWidget);
      final clueText = find.text('It spells Elara.');
      expect(clueText, findsOneWidget);
      expect(
        tester.widget<Text>(clueText).textSpan?.style?.fontStyle,
        FontStyle.normal,
      );
      expect(
        find.ancestor(
          of: clueText,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Transform &&
                _matchesIosInlineEmphasisSkew(widget.transform),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Character destinations'), findsNothing);
      expect(routeIcon, findsNothing);
      expect(find.text('Elara, Lyra'), findsOneWidget);
      expect(find.text('went to'), findsOneWidget);
      expect(find.text('Room 0'), findsOneWidget);
      expect(
        tester.getTopLeft(header).dy,
        lessThan(tester.getTopLeft(globalSection).dy),
      );
      expect(
        tester.getTopLeft(globalSection).dy,
        lessThan(tester.getTopLeft(eventText).dy),
      );
      expect(
        tester.getTopLeft(eventText).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  const ValueKey<String>(
                    'chat-character-movement-location-tick-composite-tick-0',
                  ),
                ),
              )
              .dy,
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'chat-character-movement-location-tick-composite-tick-0',
          ),
        ),
      );
      expect(tappedMovement?.toLocationId, 'loc_room_0');

      await tester.longPress(
        find.byKey(const ValueKey<String>('chat-tick-message-bubble')),
      );
      await tester.pump();
      expect(longPressedMessage, same(message));
      expect(
        chatTickMessageCopyText(message),
        'Tick 1-2 · Day 1, 13:50\n'
        'Global\n'
        'The promise-shaped key pulses.\n'
        'Event\n'
        'Day 1, 13:30 · public\n'
        'Frost creeps toward Room 0.\n'
        'It spells Elara.\n'
        'Character destinations\n'
        'Elara, Lyra went to Room 0',
      );
    },
  );

  testWidgets('Worldo tick uses the Figma scene plate surface', (
    WidgetTester tester,
  ) async {
    ChatCharacterMovementVm? tappedMovement;
    final message = ChatMessageVm(
      localId: 'worldo-tick',
      senderId: 'tick',
      senderName: 'Tick',
      text: '',
      isMe: false,
      status: 'sent',
      senderType: 'tick',
      tickNo: 1,
      subTickNo: 2,
      timelinePayload: const ChatTickPayloadVm(
        globalText: 'The room has started keeping score.',
        storyEvents: ChatStoryEventsPayloadVm(
          locationId: 'grand-ballroom',
          locationName: 'Grand Ballroom',
          paragraphs: [
            ChatStoryEventParagraphVm(
              timestamp: '22:40 | 01/07/2026',
              text:
                  "Vivienne's grandfather signals for her from the head of "
                  'the room; the merger papers are already on the table behind him.',
              clue:
                  'Keep Vivienne away from the board table until the dance ends.',
              visibilityLabel: 'public',
              visibleRoles: [
                ChatStoryEventVisibleRoleVm(
                  roleId: 'vivienne',
                  name: 'Vivienne',
                  isAi: true,
                  avatarUrl: 'assets/images/default_list_image.png',
                ),
                ChatStoryEventVisibleRoleVm(
                  roleId: 'adrian',
                  name: 'Adrian',
                  isAi: false,
                ),
              ],
            ),
          ],
        ),
        charactersMoved: ChatCharactersMovedPayloadVm(
          movements: [
            ChatCharacterMovementVm(
              characterId: 'vivienne',
              characterName: 'Vivienne Ashford',
              toLocationId: 'library',
              toLocationName: 'The Library',
            ),
            ChatCharacterMovementVm(
              characterId: 'dorian',
              characterName: 'Dorian',
              toLocationId: 'library',
              toLocationName: 'The Library',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.worldoDark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ChatMessageRow(
              message: message,
              showDateDivider: false,
              style: context.genesisChatTheme.locationChat,
              onCharactersMovedLocationTap: (movement) {
                tappedMovement = movement;
              },
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('chat-tick-message-surface')),
    );
    final surfaceDecoration = surface.decoration! as BoxDecoration;
    expect(surfaceDecoration.color, const Color(0x99151517));
    expect(surfaceDecoration.borderRadius, BorderRadius.circular(10));
    expect(
      (surfaceDecoration.border! as Border).top.color,
      const Color(0x33FFFFFF),
    );
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(
      tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .any((filter) => filter.blendMode == BlendMode.srcOver),
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('chat-tick-message-surface')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-tick-message-accent')),
      findsNothing,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('chat-tick-header-dot')),
      ),
      const Size.square(5),
    );
    final headerText = tester.widget<Text>(find.text('Tick 1-2'));
    expect(headerText.style?.fontSize, 13);
    expect(headerText.style?.fontWeight, FontWeight.w800);
    final header = tester.widget<Container>(
      find.byKey(const ValueKey<String>('chat-tick-header-worldo-tick')),
    );
    final headerBorder =
        (header.decoration! as BoxDecoration).border! as Border;
    expect(headerBorder.bottom.color, const Color(0x29FFFFFF));

    final globalText = tester.widget<Text>(
      find.text('The room has started keeping score.'),
    );
    expect(globalText.textSpan?.style?.fontSize, 13);
    expect(globalText.textSpan?.style?.height, kChatBodyLineHeight);
    // Tick body now shares the narrator tier.
    expect(globalText.textSpan?.style?.color, GenesisPalette.redesignWhite73);

    // Beat record glyph, drawn not loaded, sized to the 13px body run.
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('chat-story-event-icon-worldo-tick-tick-0'),
        ),
      ),
      const Size.square(13),
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('chat-story-event-icon-worldo-tick-tick-0'),
        ),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    final timestamp = tester.widget<Text>(
      find.byKey(
        const ValueKey<String>('chat-story-event-timestamp-worldo-tick-tick-0'),
      ),
    );
    expect(timestamp.style?.fontSize, 11);
    expect(timestamp.style?.height, 1);
    expect(
      timestamp.style?.color,
      GenesisPalette.redesignSoftWhite.withValues(alpha: 0.45),
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey<String>('chat-tick-visible-role-avatar-vivienne'),
        ),
      ),
      const Size.square(18),
    );
    expect(
      tester
          .widget<GenesisAvatar>(
            find.descendant(
              of: find.byKey(
                const ValueKey<String>(
                  'chat-tick-visible-role-avatar-vivienne',
                ),
              ),
              matching: find.byType(GenesisAvatar),
            ),
          )
          .url,
      'assets/images/default_list_image.png',
    );
    final playerAvatar = tester.widget<Container>(
      find.byKey(
        const ValueKey<String>('chat-tick-visible-role-avatar-adrian'),
      ),
    );
    final playerBorder =
        (playerAvatar.foregroundDecoration! as BoxDecoration).border! as Border;
    expect(playerBorder.top.color, const Color(0xFFF82B3C));
    expect(playerBorder.top.width, 1.5);
    expect(tester.widget<Text>(find.text('Vivienne')).style?.fontSize, 11);
    expect(
      tester.widget<Text>(find.text('Vivienne')).style?.color,
      GenesisPalette.redesignSoftWhite.withValues(alpha: 0.72),
    );
    expect(
      tester.widget<Text>(find.text('Adrian')).style?.color,
      GenesisPalette.redesignSoftWhite,
    );

    final eventText = tester.widget<Text>(
      find.textContaining("Vivienne's grandfather signals"),
    );
    expect(eventText.textSpan?.style?.fontSize, 13);
    expect(eventText.textSpan?.style?.height, kChatBodyLineHeight);
    expect(
      eventText.textSpan?.style?.color,
      GenesisPalette.redesignSoftWhite.withValues(alpha: 0.73),
    );
    final clueText = tester.widget<Text>(
      find.textContaining('Keep Vivienne away'),
    );
    expect(clueText.textSpan?.style?.fontSize, 13);
    expect(clueText.textSpan?.style?.height, kChatBodyLineHeight);
    expect(
      clueText.textSpan?.style?.color,
      GenesisPalette.redesignSoftWhite.withValues(alpha: 0.72),
    );

    final movementSection = tester.widget<Container>(
      find.byKey(const ValueKey<String>('chat-tick-movement-section')),
    );
    final movementBorder =
        (movementSection.decoration! as BoxDecoration).border! as Border;
    expect(movementBorder.top.color, const Color(0x29FFFFFF));
    final movementName = tester.widget<Text>(
      find.text('Vivienne Ashford, Dorian'),
    );
    expect(movementName.style?.fontSize, 13);
    expect(movementName.style?.height, 1.3);
    expect(movementName.style?.fontWeight, FontWeight.w600);
    expect(movementName.style?.color, GenesisPalette.redesignSoftWhite);
    final location = tester.widget<Text>(find.text('The Library'));
    expect(location.style?.color, const Color(0xFFFF8A9A));
    expect(location.style?.decoration, TextDecoration.underline);
    expect(
      location.style?.decorationColor,
      const Color(0xFFFF8A9A).withValues(alpha: 0.45),
    );
    // The movement glyph is painted to the design spec now, not an SVG asset.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains(routeIconAsset),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'chat-character-movement-location-worldo-tick-tick-0',
        ),
      ),
    );
    expect(tappedMovement?.toLocationId, 'library');
  });

  testWidgets(
    'composite tick omits empty sections and renders fallback content',
    (WidgetTester tester) async {
      final message = ChatMessageVm(
        localId: 'tick-fallback',
        senderId: 'tick',
        senderName: 'SubTick',
        text: 'Original tick content',
        isMe: false,
        status: 'sent',
        senderType: 'tick',
        timelinePayload: const ChatTickPayloadVm(
          fallbackContent: 'Original tick content',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageRow(message: message, showDateDivider: false),
          ),
        ),
      );

      expect(find.text('Tick 0'), findsOneWidget);
      expect(find.text('Original tick content'), findsOneWidget);
      expect(find.text('Global'), findsNothing);
      expect(find.text('Event'), findsNothing);
      expect(find.text('Character destinations'), findsNothing);
      expect(chatTickMessageCopyText(message), 'Tick 0\nOriginal tick content');
    },
  );

  testWidgets('tick global skews iOS multiline content per token', (
    WidgetTester tester,
  ) async {
    const globalValue =
        'First signal crosses the valley while the second signal follows.';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: ChatMessageRow(
              message: ChatMessageVm(
                localId: 'tick-global-multiline',
                senderId: 'tick',
                senderName: 'Tick',
                text: '',
                isMe: false,
                status: 'sent',
                senderType: 'tick',
                timelinePayload: const ChatTickPayloadVm(
                  globalText: globalValue,
                ),
              ),
              showDateDivider: false,
              style: kLocationChatStyle,
            ),
          ),
        ),
      ),
    );

    final globalSection = find.byKey(
      const ValueKey<String>('chat-tick-global-section'),
    );
    final richText = find.descendant(
      of: globalSection,
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan != null,
      ),
    );
    expect(richText, findsOneWidget);
    expect(tester.getSize(richText).height, greaterThan(30));
    expect(tester.widget<Text>(richText).semanticsLabel, globalValue);
    expect(
      find.ancestor(
        of: richText,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              _matchesIosInlineEmphasisSkew(widget.transform),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: globalSection,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              _matchesIosInlineEmphasisSkew(widget.transform),
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('chat composer grows with text up to ten lines', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    final reportedHeights = <double>[];
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              controller: controller,
              inputEnabled: true,
              sendEnabled: true,
              sending: false,
              onSend: () async {},
              onHeightChanged: reportedHeights.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final initialHeight = tester.getSize(find.byType(ChatComposer)).height;

    await tester.enterText(find.byType(TextField), 'one\ntwo\nthree');
    await tester.pump();
    await tester.pump();
    final threeLineHeight = tester.getSize(find.byType(ChatComposer)).height;

    await tester.enterText(
      find.byType(TextField),
      List.filled(10, 'x').join('\n'),
    );
    await tester.pump();
    await tester.pump();
    final tenLineHeight = tester.getSize(find.byType(ChatComposer)).height;

    await tester.enterText(
      find.byType(TextField),
      List.filled(12, 'x').join('\n'),
    );
    await tester.pump();
    await tester.pump();
    final twelveLineHeight = tester.getSize(find.byType(ChatComposer)).height;

    expect(threeLineHeight, greaterThan(initialHeight));
    expect(tenLineHeight, greaterThan(threeLineHeight));
    expect(twelveLineHeight, closeTo(tenLineHeight, 1));
    expect(reportedHeights.first, initialHeight);
    expect(reportedHeights, contains(threeLineHeight));
    expect(reportedHeights.last, closeTo(tenLineHeight, 1));
  });

  testWidgets('room composer caret is white, other composers keep the theme', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);

    Future<TextField> inputFor(ChatUiStyleConfig style) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              controller: controller,
              inputEnabled: true,
              sendEnabled: true,
              sending: false,
              onSend: () async {},
              style: style,
            ),
          ),
        ),
      );
      return tester.widget<TextField>(find.byType(TextField));
    }

    TextSelectionThemeData? selectionThemeAround(TextField field) {
      final scope = find.ancestor(
        of: find.byWidget(field),
        matching: find.byType(TextSelectionTheme),
      );
      if (scope.evaluate().isEmpty) return null;
      return tester.widget<TextSelectionTheme>(scope.first).data;
    }

    // The room is drawn over scene artwork, where the app theme's accent caret,
    // handles and highlight all read as stray red marks.
    final room = await inputFor(GenesisChatTheme.worldoDark().locationChat);
    expect(room.cursorColor, GenesisPalette.white);
    final roomSelection = selectionThemeAround(room)!;
    expect(roomSelection.cursorColor, GenesisPalette.white);
    expect(roomSelection.selectionHandleColor, GenesisPalette.white);
    expect(
      roomSelection.selectionColor,
      GenesisPalette.white.withValues(alpha: 0.32),
    );

    // Everything else keeps deferring to the app theme.
    final standard = await inputFor(GenesisChatTheme.worldoDark().standard);
    expect(standard.cursorColor, isNull);
    expect(selectionThemeAround(standard), isNull);
  });

  testWidgets('chat composer default only shows send action button', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final style = GenesisChatTheme.worldoLight().standard;
    var sendCount = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: true,
            sending: false,
            onSend: () async {
              sendCount += 1;
            },
            style: style,
          ),
        ),
      ),
    );

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.keyboardType, TextInputType.multiline);
    expect(input.textInputAction, TextInputAction.newline);
    expect(input.onSubmitted, isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('chat-composer-send-button'))),
      Size(style.composerSendButtonWidth, style.composerSendButtonHeight),
    );
    expect(
      find.byKey(const ValueKey('chat-composer-send-button')),
      findsOneWidget,
    );
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chat-composer-send-button')),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(style.composerSendButtonColor, GenesisPalette.redesignAccent);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                style.composerSendButtonColor;
      }),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('chat-composer-send-button')));
    await tester.pump();

    expect(sendCount, 1);
  });

  testWidgets('chat composer preserves decorative unicode input', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    const raw = '☛ ˙۵ও⃢♥︎ ━  𝙏ᶦⁿᶦᵗᵃ 🍓|🎀〬𓈒ֹ⁠꙳';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: true,
            sending: false,
            onSend: () async {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), raw);
    await tester.pump();

    expect(controller.text, raw);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.style?.fontFamily, GenesisTypography.fontFamily);
    expect(
      input.style?.fontFamilyFallback,
      GenesisTypography.fontFamilyFallback,
    );
  });

  testWidgets('chat composer send button keeps text field focused', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final style = GenesisChatTheme.worldoLight().standard;
    var sendCount = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: true,
            sending: false,
            onSend: () async {
              sendCount += 1;
            },
            style: style,
          ),
        ),
      ),
    );

    await tester.showKeyboard(find.byType(TextField));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(const ValueKey('chat-composer-send-button')));
    await tester.pump();

    expect(sendCount, 1);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('chat composer keyboard sends when send button is hidden', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final style = ChatUiStyleConfig.standard.copyWith(
      showComposerSendButton: false,
    );
    var sendCount = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: true,
            sending: false,
            onSend: () async {
              sendCount += 1;
            },
            style: style,
          ),
        ),
      ),
    );

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.keyboardType, TextInputType.text);
    expect(input.textInputAction, TextInputAction.send);
    expect(input.onSubmitted, isNotNull);
    expect(
      find.byKey(const ValueKey('chat-composer-send-button')),
      findsNothing,
    );

    input.onSubmitted?.call('hello');
    await tester.pump();

    expect(sendCount, 1);
  });

  testWidgets('chat composer disables send action without showing spinner', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final style = GenesisChatTheme.worldoLight().standard;
    var sendCount = 0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: false,
            sending: false,
            onSend: () async {
              sendCount += 1;
            },
            style: style,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('chat-composer-send-button')));
    await tester.pump();

    expect(sendCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                style.composerSendButtonDisabledColor;
      }),
      findsOneWidget,
    );
  });

  testWidgets('chat composer send button shows spinner while sending', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    final style = GenesisChatTheme.worldoLight().standard;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            controller: controller,
            inputEnabled: true,
            sendEnabled: false,
            sending: true,
            onSend: () async {},
            style: style,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.send), findsNothing);
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                style.composerSendButtonColor;
      }),
      findsOneWidget,
    );
  });

  testWidgets('sending self message shows centered loading badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'm1',
              senderId: 'me',
              senderName: 'Me',
              text: 'hello',
              isMe: true,
              status: 'sending',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.text('sending'), findsNothing);
    expect(find.byType(ChatSendingBadge), findsOneWidget);
    expect(find.byType(ChatFailedBadge), findsNothing);

    final progressFinder = find.descendant(
      of: find.byType(ChatSendingBadge),
      matching: find.byType(CircularProgressIndicator),
    );
    final progress = tester.widget<CircularProgressIndicator>(progressFinder);
    expect(tester.getSize(progressFinder), const Size.square(12));
    expect(progress.strokeWidth, 2);

    final badgeCenter = tester.getCenter(find.byType(ChatSendingBadge));
    final bubbleCenter = tester.getCenter(find.byType(ChatMessageBubble));
    expect(badgeCenter.dy, closeTo(bubbleCenter.dy, 1));
  });

  testWidgets('nar_pic chat message renders as an image instead of URL text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'opening-image',
              senderId: 'nar_pic',
              senderName: 'Narrator',
              senderType: 'image',
              imageUrl: 'assets/images/default_list_image.png',
              text: 'assets/images/default_list_image.png',
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    expect(find.byType(ChatImageMessage), findsOneWidget);
    expect(find.byType(ChatMessageBubble), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('chat-image-message-opening-image')),
      findsOneWidget,
    );
    expect(find.text('assets/images/default_list_image.png'), findsNothing);
  });

  testWidgets('chat image thumbnail uses its layout width and OSS tier', (
    WidgetTester tester,
  ) async {
    const source = 'https://cdn-001.worldo.ai/chat/chat.png?old=true#fragment';
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() {
      debugGenesisMessageImageInfoLoader = null;
      clearGenesisMessageImageSizeCache();
    });
    debugGenesisMessageImageInfoLoader = (_) async => {
      'ImageWidth': {'value': '1600'},
      'ImageHeight': {'value': '800'},
    };

    for (final expectation in const <(double, int)>[
      (1, 1080),
      (2, 1440),
      (3, 1440),
      (4, 1440),
    ]) {
      clearGenesisMessageImageSizeCache();
      tester.view.devicePixelRatio = expectation.$1;
      tester.view.physicalSize = Size(
        800 * expectation.$1,
        600 * expectation.$1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageRow(
              message: ChatMessageVm(
                localId: 'remote-image-${expectation.$1}',
                senderId: 'nar_pic',
                senderName: 'Narrator',
                senderType: 'image',
                imageUrl: source,
                text: source,
                isMe: false,
                status: 'sent',
              ),
              showDateDivider: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final image = tester.widget<ChatThumbnailImage>(
        find.byType(ChatThumbnailImage),
      );
      expect(image.maxWidth, 750);
      final provider = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byType(ChatThumbnailImage),
              matching: find.byType(Image),
            ),
          )
          .map((image) => image.image)
          .whereType<GenesisStaticNetworkImageProvider>()
          .single;
      expect(
        provider.imageUrl,
        'https://cdn-001.worldo.ai/chat/chat.png'
        '?x-oss-process=image/resize,m_lfit,'
        'w_${expectation.$2},h_${expectation.$2 * 2}/format,webp',
      );
      expect(image.borderRadius, BorderRadius.circular(8));
    }
  });

  testWidgets('location chat image width matches narrator message width', (
    WidgetTester tester,
  ) async {
    final style = kLocationChatStyle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Padding(
              padding: style.messageListPadding,
              child: ChatMessageRow(
                message: ChatMessageVm(
                  localId: 'location-image-width',
                  senderId: 'nar_pic',
                  senderName: 'Narrator',
                  senderType: 'image',
                  imageUrl: 'assets/images/my_worlds_empty_worldo_launch.jpg',
                  text: 'assets/images/my_worlds_empty_worldo_launch.jpg',
                  isMe: false,
                  status: 'sent',
                ),
                showDateDivider: false,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<ChatThumbnailImage>(
      find.byType(ChatThumbnailImage),
    );
    final narratorContentWidth =
        400 -
        style.messageListPadding.horizontal -
        style.systemMessageMargin.horizontal;
    expect(image.maxWidth, closeTo(narratorContentWidth, 0.01));
  });

  testWidgets('resolved remote image keeps its geometry when rebuilt', (
    WidgetTester tester,
  ) async {
    const source = 'https://cdn-001.worldo.ai/chat/rebuild.webp';
    addTearDown(() {
      debugGenesisMessageImageInfoLoader = null;
      clearGenesisMessageImageSizeCache();
    });
    debugGenesisMessageImageInfoLoader = (_) async => {
      'ImageWidth': {'value': '400'},
      'ImageHeight': {'value': '800'},
    };

    Widget image() => const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: ChatThumbnailImage(imageUrl: source, maxWidth: 300),
          ),
        ),
      ),
    );

    await tester.pumpWidget(image());
    await tester.pump();
    await tester.pump();
    expect(
      tester.getSize(find.byType(ChatThumbnailImage)),
      const Size(300, 600),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(image());

    expect(
      tester.getSize(find.byType(ChatThumbnailImage)),
      const Size(300, 600),
    );
  });

  testWidgets('chat image keeps its ratio within the available layout width', (
    WidgetTester tester,
  ) async {
    Future<Size> pumpImage(String localId, String imageUrl) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: ChatMessageRow(
                  message: ChatMessageVm(
                    localId: localId,
                    senderId: 'nar_pic',
                    senderName: 'Narrator',
                    senderType: 'image',
                    imageUrl: imageUrl,
                    text: imageUrl,
                    isMe: false,
                    status: 'sent',
                  ),
                  showDateDivider: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          AssetImage(imageUrl),
          tester.element(find.byType(ChatThumbnailImage)),
        );
      });
      await tester.pump();
      return tester.getSize(
        find.byKey(ValueKey<String>('chat-image-message-$localId')),
      );
    }

    final landscape = await pumpImage(
      'landscape',
      'assets/images/my_worlds_empty_worldo_launch.jpg',
    );
    expect(landscape.width, closeTo(250, 0.01));
    expect(landscape.height, closeTo(250 * 619 / 1253, 0.01));

    final portrait = await pumpImage(
      'portrait',
      'assets/images/map_default/root_default.webp',
    );
    expect(portrait.width, closeTo(250, 0.01));
    expect(portrait.height, closeTo(250 * 1536 / 1024, 0.01));

    final small = await pumpImage(
      'small',
      'assets/custom-icons/png/discuss_like_outline.png',
    );
    expect(small, const Size.square(96));

    final renderedImage = tester.widget<Image>(
      find.descendant(
        of: find.byType(ChatThumbnailImage),
        matching: find.byType(Image),
      ),
    );
    expect(renderedImage.fit, BoxFit.contain);
  });

  testWidgets('chat image opens all loaded images at the tapped message', (
    WidgetTester tester,
  ) async {
    final start = DateTime(2026, 7, 29, 10);
    const firstImage = 'assets/images/map_default/root_default.webp';
    const secondImage = 'assets/images/map_default/l1_default.webp';
    final messages = <ChatMessageVm>[
      ChatMessageVm(
        localId: 'image-later',
        senderId: 'nar_pic',
        senderName: 'Narrator',
        senderType: 'image',
        imageUrl: secondImage,
        text: secondImage,
        isMe: false,
        status: 'sent',
        createdAt: start.add(const Duration(minutes: 2)),
      ),
      ChatMessageVm(
        localId: 'text-between',
        senderId: 'peer',
        senderName: 'Peer',
        text: 'not an image',
        isMe: false,
        status: 'sent',
        createdAt: start.add(const Duration(minutes: 1)),
      ),
      ChatMessageVm(
        localId: 'image-earlier',
        senderId: 'nar_pic',
        senderName: 'Narrator',
        senderType: 'image',
        imageUrl: firstImage,
        text: firstImage,
        isMe: false,
        status: 'sent',
        createdAt: start,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            controller: ScrollController(),
            messages: messages,
            topTitle: '',
            reverse: false,
            showDateDividers: false,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-image-message-image-later')),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<GenesisImageViewerOverlay>(
      find.byType(GenesisImageViewerOverlay),
    );
    expect(viewer.imageUrls, const <String>[firstImage, secondImage]);
    expect(viewer.initialIndex, 1);
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-dots')),
      findsOneWidget,
    );
  });

  testWidgets('standalone chat image viewer falls back to current image', (
    WidgetTester tester,
  ) async {
    const image = 'assets/images/map_default/root_default.webp';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(
            message: ChatMessageVm(
              localId: 'standalone-image',
              senderId: 'nar_pic',
              senderName: 'Narrator',
              senderType: 'image',
              imageUrl: image,
              text: image,
              isMe: false,
              status: 'sent',
            ),
            showDateDivider: false,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-image-message-standalone-image')),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<GenesisImageViewerOverlay>(
      find.byType(GenesisImageViewerOverlay),
    );
    expect(viewer.imageUrls, const <String>[image]);
    expect(viewer.initialIndex, 0);
  });
}

bool _textHasItalicFragment(Text text, String value) {
  final span = text.textSpan;
  if (span == null) return false;
  var found = false;
  span.visitChildren((child) {
    if (child is TextSpan &&
        child.text == value &&
        child.style?.fontStyle == FontStyle.italic) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Color? _textFragmentColor(Text text, String value) {
  return _textFragmentStyle(text, value)?.color;
}

TextStyle? _textFragmentStyle(Text text, String value) {
  final span = text.textSpan;
  if (span == null) return null;
  TextStyle? style;
  span.visitChildren((child) {
    if (child is TextSpan && child.text == value) {
      style = child.style;
      return false;
    }
    return true;
  });
  return style;
}

TextStyle? _firstSkewedWidgetFragmentStyle(Iterable<Text> texts, String value) {
  for (final text in texts) {
    final style = _skewedWidgetFragmentStyle(text.textSpan, value);
    if (style != null) return style;
  }
  return null;
}

List<String> _skewedWidgetFragmentTexts(Iterable<Text> texts) {
  final values = <String>[];
  for (final text in texts) {
    _collectSkewedWidgetFragmentTexts(text.textSpan, values);
  }
  return values;
}

void _collectSkewedWidgetFragmentTexts(InlineSpan? span, List<String> values) {
  if (span == null) return;
  span.visitChildren((child) {
    if (child is WidgetSpan) {
      final value = _skewedTextValue(child.child);
      if (value != null) values.add(value);
    }
    return true;
  });
}

TextStyle? _skewedWidgetFragmentStyle(InlineSpan? span, String value) {
  if (span == null) return null;
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

String? _skewedTextValue(Widget widget) {
  if (widget is! Transform) return null;
  if (!_matchesIosInlineEmphasisSkew(widget.transform)) return null;
  final child = widget.child;
  if (child is Text) return child.data;
  return null;
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
