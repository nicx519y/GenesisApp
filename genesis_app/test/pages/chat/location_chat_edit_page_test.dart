import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/components/common/genesis_center_toast.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

ChatMessageVm message(
  String id, {
  String round = '',
  bool self = false,
  String type = 'character',
  String? text,
}) => ChatMessageVm(
  localId: id,
  roundId: round,
  senderId: self ? 'user' : 'alice',
  senderName: self ? 'You' : 'Alice',
  text: text ?? id,
  isMe: self,
  status: 'sent',
  senderType: type,
);

Future<void> openEditor(
  WidgetTester tester, {
  required Future<void> Function(LocationChatEditResult) onSave,
  List<ChatMessageVm>? messages,
  int? cardId,
  bool canEdit = true,
  bool canDelete = true,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      scrollBehavior: const GenesisScrollBehavior(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<LocationChatEditResult>(
                builder: (_) => LocationChatEditPage(
                  args: LocationChatEditPageArgs(
                    worldId: 'world',
                    locationId: 'location',
                    roundId: 2,
                    cardId: cardId,
                    canEdit: canEdit,
                    canDelete: canDelete,
                    messages:
                        messages ??
                        [
                          message('reply', round: '2', text: 'Original reply.'),
                          message(
                            'narrator',
                            round: '2',
                            type: 'narrator',
                            text: 'Original narration.',
                          ),
                        ],
                    style: kLocationChatStyle,
                    onSave: onSave,
                  ),
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ordinary narrator bubble has no editor outline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatNarratorMessageBubble(
            message: message('normal', type: 'narrator'),
            style: kLocationChatStyle,
          ),
        ),
      ),
    );
    final bubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat-system-message-bubble')),
    );
    expect((bubble.decoration! as BoxDecoration).border, isNull);
  });

  test(
    'latest round selection keeps AI replies and narrator but excludes users',
    () {
      final messages = [
        message('old', round: 'round-1'),
        message('user', round: 'round-2', self: true),
        message('other-user', round: 'round-2', type: 'user'),
        message('player-role', round: 'round-2')..isPlayerControlledRole = true,
        message('reply', round: 'round-2'),
        message('narrator', round: 'round-2', type: 'narrator'),
        ChatMessageVm.system('status'),
      ];
      expect(locationChatLatestEditableRound(messages).map((m) => m.localId), [
        'reply',
        'narrator',
      ]);
    },
  );

  test('missing round identities do not guess a contiguous reply block', () {
    expect(
      locationChatLatestEditableRound([
        message('old'),
        message('user', self: true),
        message('reply'),
        message('narrator', type: 'narrator'),
      ]),
      isEmpty,
    );
  });

  for (final longBubble in [false, true]) {
    testWidgets(
      'editor puts caret at end and reveals ${longBubble ? "the end of a tall bubble" : "the full bubble"} above the keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetViewInsets();
          tester.view.resetDevicePixelRatio();
          return tester.binding.setSurfaceSize(null);
        });
        final targetText = List.filled(
          longBubble ? 35 : 7,
          'A line of editable dialogue.',
        ).join('\n');
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const GenesisScrollBehavior(),
            home: LocationChatEditPage(
              args: LocationChatEditPageArgs(
                worldId: 'world',
                locationId: 'location',
                roundId: 2,
                onSave: (_) async {},
                style: kLocationChatStyle,
                messages: [
                  message(
                    'before',
                    round: '2',
                    text: List.filled(12, 'Earlier dialogue.').join('\n'),
                  ),
                  message('target', round: '2', text: targetText),
                  message('after', round: '2', text: 'Another reply.'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('chat-message-editor-target'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        final fieldRect = tester.getRect(field);
        final list = find.byKey(const ValueKey('location-chat-edit-messages'));
        final visible = fieldRect.intersect(tester.getRect(list));
        await tester.tapAt(visible.topLeft + const Offset(10, 8));
        await tester.pump();
        final controller = tester.widget<TextField>(field).controller!;
        expect(
          controller.selection,
          TextSelection.collapsed(offset: targetText.length),
        );
        for (final inset in [100.0, 220.0, 320.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final bubble = tester.getRect(
          find.byKey(const ValueKey('chat-message-bubble-target')),
        );
        final viewport = tester.getRect(list);
        expect(bubble.bottom, lessThanOrEqualTo(viewport.bottom));
        if (!longBubble) {
          expect(bubble.top, greaterThanOrEqualTo(viewport.top));
          // Once focused, tapping the first line should still reposition the caret.
          await tester.tapAt(tester.getTopLeft(field) + const Offset(2, 5));
          await tester.pumpAndSettle();
          expect(controller.selection.baseOffset, lessThan(targetText.length));
        } else {
          expect(bubble.bottom, greaterThan(viewport.bottom - 60));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'edit route preserves chat surfaces, saves on Done, and cancels on back',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = [
        message('old', round: '1'),
        message('user', round: '2', self: true, text: 'Hello'),
        message('reply', round: '2', text: 'Welcome back.'),
        message(
          'narrator',
          round: '2',
          type: 'narrator',
          text: 'The room falls silent.',
        ),
      ];
      LocationChatEditResult? result;
      final args = LocationChatEditPageArgs(
        worldId: 'world',
        locationId: 'location',
        roundId: 2,
        onSave: (_) async {},
        messages: source,
        style: kLocationChatStyle,
        selfMessageBubbleMaxWidthCap: 230,
        otherMessageBubbleMaxWidthCap: 230,
      );
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const GenesisScrollBehavior(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .pushNamed<LocationChatEditResult>(
                        RouteNames.locationChatEdit,
                        arguments: args,
                      );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('chat-message-editor-old')),
        findsNothing,
      );
      expect(find.byType(ChatComposer), findsNothing);
      expect(
        find.byKey(const ValueKey('edit-subscription-prompt')),
        findsNothing,
      );
      final deleteDecoration =
          tester
                  .widget<Container>(
                    find.byKey(
                      const ValueKey(
                        'location-chat-edit-delete-decoration-reply',
                      ),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(deleteDecoration.color, GenesisColors.darkFaintSurface);
      expect(deleteDecoration.borderRadius, BorderRadius.circular(6));
      expect(
        deleteDecoration.border,
        Border.all(color: GenesisColors.darkFaintFill),
      );
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('location-chat-edit-delete-reply')),
          matching: find.byType(ChatStableBackdropSurface),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('location-chat-background-overlay')),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(ChatHeader)).height,
        kLocationChatStyle.headerHeight,
      );
      expect(
        tester
            .getBottomRight(
              find.byKey(const ValueKey('location-chat-edit-messages')),
            )
            .dy,
        844,
      );
      expect(
        find.byKey(const ValueKey('chat-message-editor-user')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('location-chat-edit-row-user')),
        findsNothing,
      );
      final replyBubble = tester.widget<Container>(
        find.byKey(const ValueKey('chat-message-bubble-reply')),
      );
      expect(
        (replyBubble.decoration! as BoxDecoration).color,
        kLocationChatStyle.otherBubbleColor,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        GenesisColors.darkBackground,
      );
      final narratorBubble = tester.widget<Container>(
        find.byKey(const ValueKey('chat-system-message-bubble')),
      );
      expect(
        (narratorBubble.decoration! as BoxDecoration).color,
        chatNarratorMessageBackgroundColor(kLocationChatStyle),
      );
      expect(
        (narratorBubble.decoration! as BoxDecoration).border,
        chatNarratorEditorBorder,
      );
      expect(chatNarratorEditorBorder.top.width, 1);
      expect(
        chatNarratorEditorBorder.top.color,
        GenesisColors.darkFaintFill.withValues(alpha: 0.06),
      );

      await tester.enterText(
        find.byKey(const ValueKey('chat-message-editor-reply')),
        'An edited reply.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat-message-editor-narrator')),
        'A new narration.',
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        source[2].text,
        'Welcome back.',
        reason: 'Edits stay in a draft until Done.',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      expect(result!.texts, {
        'reply': 'An edited reply.',
        'narrator': 'A new narration.',
      });
      expect(find.byType(LocationChatEditPage), findsNothing);
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chat-message-editor-reply')),
        'Discard me',
      );
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(source[2].text, 'Welcome back.');
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final replyRow = tester.getRect(
        find.byKey(const ValueKey('location-chat-edit-row-reply')),
      );
      final replyButton = find.byKey(
        const ValueKey('location-chat-edit-delete-reply'),
      );
      final replyButtonRect = tester.getRect(replyButton);
      expect(replyButtonRect.size, const Size(24, 24));
      expect(replyButtonRect.top, closeTo(replyRow.top - 8, 0.01));
      expect(replyButtonRect.right, closeTo(replyRow.right, 0.01));
      // The protruding top of the button must also respond to taps.
      await tester.tapAt(
        Offset(replyButtonRect.center.dx, replyButtonRect.top + 2),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('location-chat-edit-row-reply')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('location-chat-edit-delete-narrator')),
      );
      await tester.pump();
      expect(find.text('At least one message must remain.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('location-chat-edit-row-narrator')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(result, isNull, reason: 'Back cancels draft deletions.');
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('location-chat-edit-delete-reply')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
      await tester.pumpAndSettle();
      expect(result!.deletedMessageIds, {'reply'});
      expect(result!.texts, {'narrator': 'The room falls silent.'});
      expect(source[2].text, 'Welcome back.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'business save failure only shows the global toast and retains the draft',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await openEditor(
        tester,
        navigatorKey: navigatorKey,
        onSave: (_) async {
          showGenesisToastInOverlay(
            navigatorKey.currentState!.overlay!,
            '服务端编辑失败提示',
          );
          throw ApiException(
            message: '服务端编辑失败提示',
            code: 2012,
            kind: ApiExceptionKind.business,
          );
        },
      );
      final field = find.byKey(const ValueKey('chat-message-editor-reply'));
      await tester.enterText(field, 'Keep this draft.');
      await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
      await tester.pumpAndSettle();
      expect(find.text('服务端编辑失败提示'), findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
      expect(
        find.byKey(const ValueKey('location-chat-edit-status')),
        findsNothing,
      );
      expect(find.byType(LocationChatEditPage), findsOneWidget);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Keep this draft.',
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('服务端编辑失败提示'), findsNothing);
      expect(find.textContaining('2012'), findsNothing);
    },
  );

  testWidgets('closing an in-flight save does not affect the next editor', (
    tester,
  ) async {
    final firstCompletion = Completer<void>();
    final secondCompletion = Completer<void>();
    var saves = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await openEditor(
      tester,
      navigatorKey: navigatorKey,
      onSave: (_) {
        saves++;
        return saves == 1 ? firstCompletion.future : secondCompletion.future;
      },
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-message-editor-reply')),
      'Saved reply.',
    );
    final save = find.byKey(const ValueKey('location-chat-edit-done'));
    await tester.tap(save);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(save);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.byType(LocationChatEditPage), findsNothing);

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-message-editor-reply')),
          )
          .controller!
          .text,
      'Original reply.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-message-editor-reply')),
      'Second independent edit.',
    );
    await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
    await tester.pump();
    expect(saves, 2);
    expect(find.byType(LocationChatEditPage), findsOneWidget);

    firstCompletion.complete();
    await tester.pump();
    expect(find.byType(LocationChatEditPage), findsOneWidget);
    secondCompletion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LocationChatEditPage), findsNothing);
  });

  testWidgets(
    'save failure retains text and deletions for a deliberate retry',
    (tester) async {
      final saved = <LocationChatEditResult>[];
      await openEditor(
        tester,
        onSave: (result) async {
          saved.add(result);
          if (saved.length == 1) {
            throw Exception('The reply could not be saved.');
          }
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat-message-editor-reply')),
        'Edited line.\nAnother line.',
      );
      await tester.tap(
        find.byKey(const ValueKey('location-chat-edit-delete-narrator')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
      await tester.pumpAndSettle();
      expect(find.byType(LocationChatEditPage), findsOneWidget);
      expect(
        find.text('Exception: The reply could not be saved.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('location-chat-edit-status')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('chat-message-editor-reply')),
            )
            .controller!
            .text,
        'Edited line.\nAnother line.',
      );
      expect(
        find.byKey(const ValueKey('location-chat-edit-row-narrator')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
      await tester.pumpAndSettle();
      expect(saved.length, 2);
      expect(saved.last.texts, saved.first.texts);
      expect(saved.last.deletedMessageIds, saved.first.deletedMessageIds);
      expect(find.byType(LocationChatEditPage), findsNothing);
    },
  );

  for (final cardId in <int?>[null, 20]) {
    testWidgets(
      '${cardId == null ? 'formal' : 'candidate'} Save rejects explicit and blank deletion of every bubble',
      (tester) async {
        LocationChatEditResult? saved;
        await openEditor(
          tester,
          cardId: cardId,
          onSave: (result) async => saved = result,
        );
        await tester.tap(
          find.byKey(const ValueKey('location-chat-edit-delete-reply')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('chat-message-editor-narrator')),
          '  \n ',
        );
        await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
        await tester.pump();
        expect(find.text('At least one message must remain.'), findsOneWidget);
        expect(saved, isNull);
        expect(find.byType(LocationChatEditPage), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('chat-message-editor-narrator')),
          'Kept narration.',
        );
        await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
        await tester.pumpAndSettle();
        expect(saved!.deletedMessageIds, {'reply'});
        expect(saved!.texts, {'narrator': 'Kept narration.'});
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets(
    'unchanged Save avoids requests and read-only permissions are enforced',
    (tester) async {
      var saves = 0;
      await openEditor(
        tester,
        canEdit: false,
        canDelete: false,
        onSave: (_) async {
          saves++;
        },
      );
      expect(find.byType(TextField), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('location-chat-edit-delete-reply')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('location-chat-edit-done')));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.byType(LocationChatEditPage), findsNothing);
    },
  );
}
