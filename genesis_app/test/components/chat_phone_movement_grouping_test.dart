import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';

ChatCharacterMovementVm move(String name, String to, {String from = 'old'}) =>
    ChatCharacterMovementVm(
      characterId: name,
      characterName: name,
      oldLocationId: from,
      toLocationId: to,
      toLocationName: to.trim(),
      isDestinationCurrentLocation: to.trim() == 'room',
    );

ChatMessageVm message(
  String id,
  String type,
  List<ChatCharacterMovementVm> moves,
) {
  final payload = ChatCharactersMovedPayloadVm(movements: moves);
  return ChatMessageVm(
    localId: id,
    senderId: '',
    senderName: '',
    text: '',
    isMe: false,
    status: 'sent',
    senderType: type,
    timelinePayload: type == 'tick'
        ? ChatTickPayloadVm(charactersMoved: payload)
        : payload,
  );
}

void main() {
  for (final type in ['phone_characters_moved', 'tick', 'characters_moved']) {
    testWidgets('$type movement grouping preserves destination and name order', (
      tester,
    ) async {
      final moves = [
        move('Alice', 'garden', from: 'a'),
        move('Bob', 'room'),
        move('Carol', ' garden ', from: 'b'),
        move('Alice', 'garden', from: 'c'),
      ];
      ChatCharacterMovementVm? tapped;
      final row = message('first', type, moves);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatMessageRow(
                message: row,
                showDateDivider: false,
                onCharactersMovedLocationTap: (value) => tapped = value,
              ),
            ),
          ),
        ),
      );
      final cards = tester
          .widgetList<ChatLocationJumpCard>(find.byType(ChatLocationJumpCard))
          .toList();
      final grouped = type != 'characters_moved';
      expect(
        cards.map((c) => c.names),
        grouped
            ? ['Alice, Carol, Alice', 'Bob']
            : ['Alice', 'Bob', 'Carol', 'Alice'],
      );
      expect(cards.first.locationName, 'garden');
      expect(cards[1].locationName, 'room');
      expect(cards[1].onTap, isNull);
      await tester.tap(
        find.byKey(
          ValueKey(
            'chat-character-movement-location-first${type == 'tick' ? '-tick' : ''}-0',
          ),
        ),
      );
      expect(tapped?.toLocationId, 'garden');
      expect(tapped?.characterName, grouped ? 'Alice, Carol, Alice' : 'Alice');
      expect(
        (type == 'tick'
                ? (row.timelinePayload as ChatTickPayloadVm).charactersMoved!
                : row.timelinePayload as ChatCharactersMovedPayloadVm)
            .movements,
        hasLength(4),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone movement grouping never crosses message boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatMessageRow(
                message: message('one', 'phone_characters_moved', [
                  move('Alice', 'garden'),
                  move('Bob', 'garden'),
                ]),
                showDateDivider: false,
              ),
              ChatMessageRow(
                message: message('two', 'phone_characters_moved', [
                  move('Carol', 'garden'),
                ]),
                showDateDivider: false,
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<ChatLocationJumpCard>(find.byType(ChatLocationJumpCard))
          .map((c) => c.names),
      ['Alice, Bob', 'Carol'],
    );
  });
}
