import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_local_message_order.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_presentation.dart';

ChatMessageVm row(
  String id, {
  int location = 0,
  String round = '',
  bool local = false,
}) => ChatMessageVm(
  localId: id,
  clientMsgId: local ? 'client-$id' : '',
  locationMessageId: location,
  globalMessageId: location,
  roundId: round,
  senderId: local ? 'me' : 'narrator',
  senderName: '',
  senderType: local ? 'user' : 'narrator',
  text: id,
  isMe: local,
  status: local ? 'failed' : 'sent',
);

void main() {
  test(
    'later arrivals stay after the failed row, including repeated reconciliation',
    () {
      final order = LocationChatLocalMessageOrder();
      final a = row('a', location: 10);
      final f = row('failed', local: true);
      order.capture(f, before: [a]);
      final b = row('b', location: 11);
      final c = row('c', location: 12);
      for (var frame = 0; frame < 20; frame++) {
        expect(order.apply([a, b, c, f]), [a, f, b, c]);
      }
      expect(f.locationMessageId, 0);
    },
  );

  test(
    'all unconfirmed states use the original slot and retries keep identity',
    () {
      final order = LocationChatLocalMessageOrder();
      final a = row('a', location: 1);
      final f = row('f', local: true);
      order.capture(f, before: [a]);
      final b = row('b', location: 2);
      for (final state in ['sending', 'failed', 'sending', 'sent', 'failed']) {
        f.status = state;
        f.clientMsgId = 'retry-$state';
        order.capture(f, before: [a, b]);
        expect(order.apply([a, b, f]), [a, f, b]);
      }
      f.status = 'sent';
      f.locationMessageId = 3;
      order.retain([a, b, f]);
      expect(order.contains(f), isFalse);
      expect(order.apply([a, b, f]), [a, b, f]);
    },
  );

  test(
    'multiple failed rows retain send order, even when their neighbor retries',
    () {
      final order = LocationChatLocalMessageOrder();
      final a = row('a', location: 1);
      final f = row('f', local: true);
      final g = row('g', local: true);
      order.capture(f, before: [a]);
      order.capture(g, before: [a, f]);
      final b = row('b', location: 2);
      expect(order.apply([a, b, f, g]), [a, f, g, b]);
      f.status = 'sent';
      f.locationMessageId = 3;
      order.retain([a, b, f, g]);
      expect(order.apply([a, b, f, g]), [a, g, b, f]);
    },
  );

  test('neighbor canonical identity replaces its temporary ID', () {
    final order = LocationChatLocalMessageOrder();
    final a = row('temporary', local: true);
    final f = row('f', local: true);
    order.capture(f, before: [a]);
    a.locationMessageId = 10;
    final canonical = row('canonical', location: 10);
    final b = row('b', location: 11);
    expect(order.apply([canonical, b, f]), [canonical, f, b]);
  });

  test(
    'history prepend, eviction and gap refill preserve the server boundary',
    () {
      final order = LocationChatLocalMessageOrder();
      final a = row('a', location: 100);
      final f = row('f', local: true);
      order.capture(f, before: [a]);
      final b = row('b', location: 101);
      final old = row('old', location: 99);
      expect(order.apply([old, a, b, f]), [old, a, f, b]);
      expect(order.apply([b, f]), [f, b]);
      expect(order.apply([old, b, f]), [old, f, b]);
      expect(order.apply([old, a, b, f]), [old, a, f, b]);
      // Even the remembered right neighbor is now outside the loaded window.
      final c = row('c', location: 200);
      expect(order.apply([c, f]), [f, c]);
    },
  );

  test(
    'empty history keeps the local row before future content, after disclaimer',
    () {
      final order = LocationChatLocalMessageOrder();
      final disclaimer = ChatMessageVm.aiContentDisclaimer();
      final f = row('f', local: true);
      order.capture(f, before: [disclaimer]);
      final b = row('b', location: 1);
      expect(order.apply([disclaimer, b, f]), [disclaimer, f, b]);
    },
  );

  test(
    'whole candidate card stays before local row through switch and promotion',
    () {
      final order = LocationChatLocalMessageOrder();
      final a = row('a', location: 1);
      final oldCard = [row('old1', round: '7'), row('old2', round: '7')];
      final f = row('f', local: true);
      order.capture(
        f,
        before: [a, ...oldCard],
        cardMessageIds: {'old1', 'old2'},
      );
      final formalCard = [
        row('formal1', round: '7', location: 2),
        row('formal2', round: '7', location: 3),
      ];
      for (final card in [
        oldCard,
        [row('new1', round: '7'), row('new2', round: '7')],
        formalCard,
      ]) {
        final projected = buildLocationChatReplyPresentation(
          source: [a],
          roundId: '7',
          replyMessageIds: {},
          candidates: card,
        );
        expect(
          order.apply(
            projected,
            localMessages: [f],
            cardMessageIds: card.map((m) => m.localId).toSet(),
          ),
          [a, ...card, f],
        );
      }
      final nextCard = [row('reply1', round: '8'), row('reply2', round: '8')];
      expect(
        order.apply(
          [a, ...formalCard, ...nextCard],
          localMessages: [f],
          cardMessageIds: {'reply1', 'reply2'},
        ),
        [a, ...formalCard, f, ...nextCard],
      );
    },
  );

  test('later card is never split by a local insertion', () {
    final order = LocationChatLocalMessageOrder();
    final first = row('first', location: 1, round: '7');
    final last = row('last', location: 2, round: '7');
    final f = row('f', local: true);
    order.capture(f, before: [first]);
    expect(order.apply([first, last, f], cardMessageIds: {'first', 'last'}), [
      first,
      last,
      f,
    ]);
  });

  test('same-round non-card arrivals do not move a failed row', () {
    final order = LocationChatLocalMessageOrder();
    final card = row('card', location: 10, round: '7');
    final failed = row('failed', local: true);
    order.capture(failed, before: [card], cardMessageIds: {'card'});
    final other = row('other-player', location: 11, round: '7');
    expect(order.apply([card, other, failed], cardMessageIds: {'card'}), [
      card,
      failed,
      other,
    ]);
    // Once the card leaves active presentation, follow its canonical identity.
    final formal = row('formal', location: 10, round: '7');
    expect(order.apply([formal, other, failed]), [formal, failed, other]);
  });

  test('rollback and location change discard only ordering metadata', () {
    final order = LocationChatLocalMessageOrder();
    final f = row('f', local: true);
    order.capture(f, before: []);
    order.remove(f.localId);
    expect(order.contains(f), isFalse);
    order.capture(f, before: []);
    order.clear();
    expect(order.contains(f), isFalse);
    expect(f.status, 'failed');
  });
}
