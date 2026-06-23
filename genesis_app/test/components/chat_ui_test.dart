import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
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

    expect(find.text(notice), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(notice)).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('chat-tick-message-bubble')))
            .dy,
      ),
    );
  });

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

  testWidgets('chat peer name uses dark text', (WidgetTester tester) async {
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

    final name = tester.widget<Text>(find.text('Peer Name'));
    expect(
      name.style?.color,
      ChatUiStyleConfig.standard.senderNameTextStyle.color,
    );
  });

  testWidgets('player controlled chat avatar uses highlighted border', (
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

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return border.top.color == const Color(0xFF338960);
      }),
      findsOneWidget,
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
    expect(name.style?.color, GenesisColors.brand);
  });

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
              avatarUrl: 'assets/images/mock_avatars/avatar_iris.png',
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
                'assets/images/mock_avatars/avatar_iris.png',
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
    expect(_textFragmentColor(bubbleText, 'quietly'), const Color(0xFF888888));
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
    expect(_textFragmentColor(systemText, 'cold'), const Color(0xFF888888));
  });

  testWidgets('location chat keeps avatars aligned and bars one-third in', (
    WidgetTester tester,
  ) async {
    final style = kLocationChatStyle;
    final expectedOuterPadding = 10.0;
    final expectedInnerPadding = ChatUiStyleConfig.standard.avatarSize / 3;
    final expectedBubbleEdge = expectedOuterPadding + expectedInnerPadding;

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
      closeTo(expectedBubbleEdge + style.systemMessagePadding.left, 1),
    );
    expect(
      tickText.left,
      closeTo(expectedBubbleEdge + style.systemMessagePadding.left, 1),
    );
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

    expect(find.text('Tick 7 · Day 45, 19:34'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Tick 7 · Day 45, 19:34'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.left);
    expect(bubbleBox.left, closeTo(rowBox.left, 1));
    expect(bubbleBox.right, closeTo(rowBox.right, 1));
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

  testWidgets('chat composer default only shows send action button', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
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
      Size(
        ChatUiStyleConfig.standard.composerSendButtonWidth,
        ChatUiStyleConfig.standard.composerSendButtonHeight,
      ),
    );
    expect(
      find.byKey(const ValueKey('chat-composer-send-button')),
      findsOneWidget,
    );
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(
      ChatUiStyleConfig.standard.composerSendButtonColor,
      GenesisColors.brand,
    );
    expect(
      find.byWidgetPredicate((widget) {
        return widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                ChatUiStyleConfig.standard.composerSendButtonColor;
      }),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(sendCount, 1);
  });

  testWidgets('chat composer send button keeps text field focused', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
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
          ),
        ),
      ),
    );

    await tester.showKeyboard(find.byType(TextField));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byIcon(Icons.send));
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
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(sendCount, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                ChatUiStyleConfig.standard.composerSendButtonDisabledColor;
      }),
      findsOneWidget,
    );
  });

  testWidgets('chat composer send button shows spinner while sending', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
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
                ChatUiStyleConfig.standard.composerSendButtonColor;
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

    final badgeCenter = tester.getCenter(find.byType(ChatSendingBadge));
    final bubbleCenter = tester.getCenter(find.byType(ChatMessageBubble));
    expect(badgeCenter.dy, closeTo(bubbleCenter.dy, 1));
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
  final span = text.textSpan;
  if (span == null) return null;
  Color? color;
  span.visitChildren((child) {
    if (child is TextSpan && child.text == value) {
      color = child.style?.color;
      return false;
    }
    return true;
  });
  return color;
}
