import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

void main() {
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
    expect(name.style?.color, const Color(0xFF222222));
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

  testWidgets('character chat avatar uses redstar icon badge', (
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

    expect(find.byIcon(MyFlutterApp.redstarCharIcon), findsOneWidget);
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
        ChatUiStyleConfig.standard.inputMinHeight,
      ),
    );
    expect(
      find.byKey(const ValueKey('chat-composer-send-button')),
      findsOneWidget,
    );
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
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
