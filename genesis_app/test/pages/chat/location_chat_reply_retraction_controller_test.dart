import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_card.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_retraction_controller.dart';
import 'package:genesis_flutter_android/utils/llm_generation.dart';

ChatMessageVm message(LlmAttempt attempt, String id, [String text = 'body']) =>
    ChatMessageVm(
      localId: id,
      llmAttempt: attempt,
      senderId: 'c',
      senderName: 'Character',
      text: text,
      isMe: false,
      status: 'sent',
    );

void update(
  LocationChatReplyRetractionController controller, {
  List<ChatMessageVm> messages = const [],
  List<LocationChatReplyCard> cards = const [],
  int card = 0,
  Object binding = 'round',
  Object session = 'location',
  Object operation = 'send',
  int revision = 0,
  bool regenerating = false,
}) => controller.update(
  messages: messages,
  cards: cards,
  currentCardId: card,
  cardBindingIdentity: binding,
  sessionIdentity: session,
  operationIdentity: operation,
  regenerationRevision: revision,
  regenerationInProgress: regenerating,
  readOnly: false,
);

void main() {
  const generation = LlmGenerationId('w', 'l', 'r', 'go-on');

  test(
    'all containers buffer until the last outgoing row; handoff happens once',
    () {
      final controller = LocationChatReplyRetractionController(
        onRetract: (_) {},
      );
      addTearDown(controller.dispose);
      final old = LlmAttempt(generation, 1);
      final next = LlmAttempt(generation, 2);
      final upper = message(old, '1'), lower = message(old, '2');
      update(controller, messages: [upper, lower], card: 501);
      old.retract(animate: true);
      controller.beginRetraction(
        old,
        snapshots: [upper, lower],
        index: 0,
        cardId: null,
      );
      final replacement = message(next, '1', 'replacement');
      update(
        controller,
        messages: [replacement],
        cards: [
          LocationChatReplyCard(id: 0, messages: [replacement]),
        ],
        binding: 'next-round',
      );
      expect(controller.messages, [upper, lower]);
      expect(controller.currentCard!.messages, isEmpty);
      expect(controller.currentCardMessageIds, isEmpty);
      expect(controller.finishMessage(old, lower), (
        changed: true,
        generationFinished: false,
      ));
      expect(old.presentationPending, isTrue);
      expect(controller.currentCard!.messages, isEmpty);
      expect(controller.finishMessage(old, upper), (
        changed: true,
        generationFinished: true,
      ));
      expect(old.presentationPending, isFalse);
      expect(controller.currentCard!.messages, [replacement]);
      expect(controller.finishMessage(old, upper), (
        changed: false,
        generationFinished: false,
      ));
    },
  );

  test('repeated retry buffers only the latest incoming attempt', () {
    late LocationChatReplyRetractionController controller;
    controller = LocationChatReplyRetractionController(
      onRetract: (a) {
        controller.beginRetraction(a, snapshots: [], index: 0, cardId: null);
      },
    );
    addTearDown(controller.dispose);
    final first = LlmAttempt(generation, 1);
    final old = message(first, '1');
    update(controller, messages: [old]);
    first.retract(animate: true);
    controller.beginRetraction(first, snapshots: [old], index: 0, cardId: null);
    final second = LlmAttempt(generation, 2);
    update(controller, messages: [message(second, '1', 'superseded')]);
    controller.observeAttempts();
    second.retract(animate: true);
    final latest = message(LlmAttempt(generation, 3), '1', 'latest');
    update(controller, messages: [latest]);
    expect(controller.messages, [old]);
    controller.finishMessage(first, old);
    expect(controller.messages, [latest]);
    expect(controller.waitingGeneration, isNull);
    expect(second.presentationPending, isFalse);
  });

  test(
    'ordinary retry waits only without content, terminal or expired state',
    () {
      final controller = LocationChatReplyRetractionController(
        onRetract: (_) {},
      );
      addTearDown(controller.dispose);
      final old = LlmAttempt(generation, 1)..retract(animate: true);
      update(controller);
      controller.beginRetraction(old, snapshots: [], index: 0, cardId: null);
      expect(controller.waitingGeneration, generation);
      old.waitingExpired = true;
      expect(controller.waitingGeneration, isNull);
      old.waitingExpired = false;
      old.terminal = true;
      expect(controller.waitingGeneration, isNull);
      old.terminal = false;
      final next = message(LlmAttempt(generation, 2), 'new', '');
      update(
        controller,
        cards: [
          LocationChatReplyCard(id: 0, messages: [next]),
        ],
      );
      expect(controller.waitingGeneration, generation);
      next.text = 'card-only content';
      update(
        controller,
        cards: [
          LocationChatReplyCard(id: 0, messages: [next]),
        ],
      );
      expect(controller.waitingGeneration, isNull);
      update(controller, operation: 'next-send');
      expect(controller.waitingGeneration, isNull);
      expect(controller.suppressWaiting(layoutPending: false), isFalse);
    },
  );

  test(
    'Regenerate wait suppression outlives completion and resets for next operation',
    () {
      final controller = LocationChatReplyRetractionController(
        onRetract: (_) {},
      );
      addTearDown(controller.dispose);
      update(controller, operation: 'regen', revision: 1, regenerating: true);
      expect(controller.suppressWaiting(layoutPending: false), isTrue);
      update(controller, operation: 'regen', revision: 1);
      expect(controller.suppressWaiting(layoutPending: false), isTrue);
      update(controller, operation: 'go-on', revision: 1);
      expect(controller.suppressWaiting(layoutPending: false), isFalse);
      expect(controller.suppressWaiting(layoutPending: true), isTrue);
    },
  );

  test(
    'candidate retry without visible rows also suppresses waiting until new operation',
    () {
      final controller = LocationChatReplyRetractionController(
        onRetract: (_) {},
      );
      addTearDown(controller.dispose);
      update(controller);
      final attempt = LlmAttempt(
        const LlmGenerationId('w', 'l', 'r', 'regen', 42),
        1,
      )..retract(animate: true);
      controller.beginRetraction(attempt, snapshots: [], index: 0, cardId: 42);
      attempt.terminal = true;
      update(controller);
      expect(controller.suppressWaiting(layoutPending: false), isTrue);
      update(controller, operation: 'next');
      expect(controller.suppressWaiting(layoutPending: false), isFalse);
    },
  );

  test(
    'projection is reused, inactive cards stay lazy, old lazy projections stay stable',
    () {
      final controller = LocationChatReplyRetractionController(
        onRetract: (_) {},
      );
      addTearDown(controller.dispose);
      final old = LlmAttempt(generation, 1)..retract(animate: true);
      final row = message(old, 'old');
      final next = message(LlmAttempt(generation, 2), 'next');
      var resolutions = 0;
      final cards = [
        LocationChatReplyCard(id: 0, messages: [next]),
        LocationChatReplyCard.lazy(
          id: 1,
          resolveMessages: () {
            resolutions++;
            return [next];
          },
        ),
      ];
      update(controller, messages: [next], cards: cards);
      controller.beginRetraction(old, snapshots: [row], index: 0, cardId: null);
      final oldCards = controller.cards;
      expect(identical(controller.cards, oldCards), isTrue);
      expect(identical(controller.messages, controller.messages), isTrue);
      expect(controller.currentCard!.messages, isEmpty);
      expect(resolutions, 0);
      controller.finishMessage(old, row);
      // A retained lazy card still uses its own revision's gate, even if first
      // resolved after the controller has finished that retraction.
      expect(oldCards.last.messages, isEmpty);
      expect(oldCards.last.messages, isEmpty);
      expect(resolutions, 1);
      expect(controller.currentCard!.messages, [next]);
      final incoming = [next];
      update(controller, messages: incoming);
      expect(controller.messages, [next]);
      incoming.clear();
      update(controller, messages: incoming);
      expect(controller.messages, isEmpty);
    },
  );

  for (final change in ['binding', 'session', 'dispose']) {
    test('$change releases leases and ignores late animation callbacks', () {
      var notifications = 0;
      final controller = LocationChatReplyRetractionController(
        onRetract: (_) => notifications++,
      );
      addTearDown(controller.dispose);
      final attempt = LlmAttempt(
        const LlmGenerationId('w', 'l', 'r', 'regen', 42),
        1,
      );
      final row = message(attempt, 'old');
      update(controller, messages: [row], card: 42);
      controller.observeAttempts();
      attempt.retract(animate: true);
      expect(notifications, 1);
      controller.beginRetraction(
        attempt,
        snapshots: [row],
        index: 0,
        cardId: 42,
      );
      expect(attempt.presentationPending, isTrue);
      final active = LlmAttempt(generation, 2);
      update(controller, messages: [message(active, 'new')], card: 42);
      controller.observeAttempts();
      if (change == 'dispose') {
        controller.dispose();
      } else {
        update(
          controller,
          card: 42,
          binding: change == 'binding' ? 'other' : 'round',
          session: change == 'session' ? 'other' : 'location',
        );
        controller.observeAttempts();
      }
      expect(attempt.presentationPending, isFalse);
      expect(controller.finishMessage(attempt, row).changed, isFalse);
      active.retract(animate: true);
      expect(notifications, 1);
    });
  }
}
