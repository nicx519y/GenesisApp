import 'dart:async';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_reply_action_storage.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/pages/chat/message_parsers/location_chat_message_parse_support.dart';

const _round = 9007199254740993;
const _messageId = _round + 10;

ChatroomV2Message _v2(
  String type, {
  int round = _round,
  int id = _messageId,
  String user = 'u',
  String conversationType = 'user_message',
  String? triggerUid,
  String content = 'Original',
}) => ChatroomV2Message(
  type: type,
  worldId: 'w',
  locationId: 'l',
  userId: user,
  conversationType: conversationType,
  triggerUid: triggerUid ?? user,
  globalMessageId: id,
  messageId: id,
  locationMessageId: id,
  conversationRoundId: round,
  senderType: type,
  senderId: 'character-id',
  senderName: 'Alice',
  payload: {'content': content},
);
WorldChatroomMessage _formal({
  int round = _round,
  int id = _messageId,
  String user = 'u',
  String type = 'character',
  String conversationType = 'user_message',
  String? triggerUid,
  String content = 'Original',
}) => WorldChatroomMessage.fromHttpMessage(
  ChatroomHttpMessage.fromV2Message(
    _v2(
      type,
      round: round,
      id: id,
      user: user,
      conversationType: conversationType,
      triggerUid: triggerUid,
      content: content,
    ),
  ),
);
ChatroomLlmCard _card(
  int id, {
  int index = 1,
  String content = 'Original',
  String generation = 'succeeded',
  bool canEdit = true,
  bool canDelete = true,
  int messages = 2,
}) => ChatroomLlmCard.fromJson({
  'card_id': id,
  'card_index': index,
  'is_original': index == 1,
  'generation_state': generation,
  'can_edit': canEdit,
  'can_delete': canDelete,
  'messages': generation != 'succeeded'
      ? []
      : List.generate(
          messages,
          (i) => {
            'type': 'character',
            'world_id': 'w',
            'location_id': 'l',
            'user_id': 'u',
            'conversation_type': 'user_message',
            'trigger_uid': 'u',
            'conversation_round_id': _round,
            'global_message_id': _messageId + i,
            'card_id': id,
            'card_message_index': 1 + i * 2,
            'sender_type': 'character',
            'sender_id': 'c',
            'payload': {'content': i == 0 ? content : 'Second'},
          },
        ),
  'billing': {'status': 'not_required'},
  'created_at': '2026-09-08',
}, conversationRoundId: _round);
ChatroomLlmCardsResponse _cards(
  List<ChatroomLlmCard> cards, {
  bool confirmed = false,
  bool canRegenerate = true,
  bool? canConfirm,
  int selected = 0,
  int round = _round,
}) => ChatroomLlmCardsResponse(
  conversationRoundId: round,
  originalCardId: cards.isEmpty ? 0 : cards.first.cardId,
  selectedCardId: selected,
  activeCardId: cards.isEmpty ? 0 : cards.last.cardId,
  confirmed: confirmed,
  canRegenerate: canRegenerate,
  canConfirm: canConfirm ?? cards.isNotEmpty,
  list: cards,
  total: cards.length,
  rawJson: const {},
);

class _Api extends ChatroomHttpApi {
  _Api() : super(ApiClient(baseUrl: 'https://unused.test'));
  ChatroomLlmCardsResponse cards = _cards([]);
  final history = <int, List<ChatroomHttpMessage>>{
    _round: [ChatroomHttpMessage.fromV2Message(_v2('character'))],
  };
  final calls = <String>[];
  Completer<ChatroomLlmCardsResponse>? cardsBarrier;
  Object? cardsError;
  Completer<void>? saveBarrier;
  Object? batchError;
  Object? selectionError;
  bool selectionApplyBeforeError = true;
  bool applyBeforeError = false;
  @override
  Future<ChatroomLlmCardsResponse> getLlmCards({
    required String worldId,
    required String locationId,
    required int conversationRoundId,
    NetworkCancellationToken? cancellationToken,
  }) async {
    calls.add('cards:$conversationRoundId');
    if (cardsError != null) throw cardsError!;
    if (cardsBarrier != null) {
      final barrier = cardsBarrier!;
      cardsBarrier = null;
      return barrier.future;
    }
    return cards;
  }

  @override
  Future<ChatroomMessageListResponse> getMessages({
    required String worldId,
    required String locationId,
    int? since,
    int? limit,
    int? startConversationRoundId,
    int? endConversationRoundId,
    NetworkCancellationToken? cancellationToken,
  }) async {
    calls.add('history:$startConversationRoundId');
    return ChatroomMessageListResponse(
      messages: history[startConversationRoundId] ?? [],
      hasMore: false,
      newestMessageId: 0,
    );
  }

  @override
  Future<ChatroomCardMutationResult> batchMutateLlmCardMessages({
    required String worldId,
    required String locationId,
    required int conversationRoundId,
    required int cardId,
    required List<ChatroomLlmMessageOperation> operations,
  }) async {
    calls.add('batch-card:$cardId');
    if (saveBarrier != null) await saveBarrier!.future;
    if (batchError != null && !applyBeforeError) throw batchError!;
    final card = cards.list.firstWhere((item) => item.cardId == cardId);
    final raw = Map<String, dynamic>.from(card.rawJson);
    final messages = card.messages
        .map((message) => Map<String, dynamic>.from(message.rawJson))
        .toList();
    for (final operation in operations) {
      final index = messages.indexWhere(
        (message) => message['global_message_id'] == operation.globalMessageId,
      );
      if (operation.action == ChatroomLlmMessageAction.delete) {
        messages.removeAt(index);
      } else {
        messages[index]['payload'] = {'content': operation.content};
      }
    }
    raw['messages'] = messages;
    final saved = ChatroomLlmCard.fromJson(raw, conversationRoundId: _round);
    cards = _cards([
      for (final item in cards.list)
        if (item.cardId == cardId) saved else item,
    ]);
    if (batchError != null) throw batchError!;
    return ChatroomCardMutationResult(conversationRoundId: _round, card: saved);
  }

  @override
  Future<ChatroomMessageMutationResult> batchMutateLlmMessages({
    required String worldId,
    required String locationId,
    required int conversationRoundId,
    required List<ChatroomLlmMessageOperation> operations,
  }) async {
    calls.add('batch-formal');
    if (batchError != null) throw batchError!;
    return const ChatroomMessageMutationResult(
      startConversationRoundId: _round,
      endConversationRoundId: _round,
      newestMessageId: _messageId,
    );
  }

  @override
  Future<ChatroomCardSelection> selectLlmCard({
    required String worldId,
    required String locationId,
    required int conversationRoundId,
    required int cardId,
    required String clientMsgId,
  }) async {
    calls.add('select:$cardId');
    if (selectionError != null && !selectionApplyBeforeError) {
      throw selectionError!;
    }
    cards = _cards(cards.list, confirmed: true, selected: cardId);
    if (selectionError != null) throw selectionError!;
    return ChatroomCardSelection(
      conversationRoundId: conversationRoundId,
      selectedCardId: cardId,
      confirmed: true,
      startConversationRoundId: conversationRoundId,
      endConversationRoundId: conversationRoundId,
      newestMessageId: _messageId,
    );
  }
}

class _Session implements ChatroomSession {
  Future<ChatroomCardRegeneration> Function()? regenerateHandler;
  Future<ChatroomGoOnReceipt> Function(String request)? goOnHandler;
  final requests = <String>[];
  @override
  Future<ChatroomCardRegeneration> regenerateLlmCard({
    required String locationId,
    required int conversationRoundId,
    required String clientMsgId,
  }) {
    requests.add('regenerate:$clientMsgId');
    return regenerateHandler!();
  }

  @override
  Future<ChatroomGoOnReceipt> goOn({
    required String locationId,
    required int sourceConversationRoundId,
    required String clientMsgId,
  }) {
    requests.add('go-on:$clientMsgId');
    return goOnHandler!(clientMsgId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({
    ChatroomReplyActionStorage? storage,
    ChatroomMessageStorage? snapshotStorage,
    String owner = 'u',
    String worldCreatorUid = '',
    String conversationType = 'user_message',
    String? triggerUid,
    DateTime Function()? now,
    Duration regenerationStreamStartTimeout = const Duration(seconds: 30),
    Duration regenerationStreamEndTimeout = const Duration(seconds: 120),
    Duration goOnStreamStartTimeout = const Duration(seconds: 30),
    Duration goOnStreamEndTimeout = const Duration(seconds: 120),
  }) {
    controller = ChatroomReplyActionsController(
      worldId: 'w',
      ownerUid: owner,
      worldCreatorUid: () => worldCreatorUid,
      httpApi: api,
      session: () => session,
      isReady: (_) => ready,
      isTickLocked: () => locked,
      refreshWallet: () async {
        walletRefreshes++;
      },
      storage: storage ?? MemoryChatroomReplyActionStorage(),
      snapshotStorage: snapshotStorage,
      now: now,
      regenerationStreamStartTimeout: regenerationStreamStartTimeout,
      regenerationStreamEndTimeout: regenerationStreamEndTimeout,
      goOnStreamStartTimeout: goOnStreamStartTimeout,
      goOnStreamEndTimeout: goOnStreamEndTimeout,
    );
    controller.observeMessages('l', [
      _formal(
        user: owner,
        conversationType: conversationType,
        triggerUid: triggerUid ?? owner,
      ),
    ]);
  }
  Future<ChatroomReplyEditorTarget> prepareEditor() async {
    await controller.restoreLocationCards('l');
    return controller.prepareEditor('l');
  }

  final api = _Api();
  final session = _Session();
  late ChatroomReplyActionsController controller;
  bool ready = true, locked = false;
  int walletRefreshes = 0;
  ChatroomReplyRoundState get state => controller.stateForRound('l', _round)!;
}

Future<void> _settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ChatroomLlmCardStream _stream(
  String stream, {
  int seq = 1,
  String content = '',
  int id = _messageId,
}) => ChatroomLlmCardStream.fromV2Message(
  ChatroomV2Message(
    type: 'llm_card_stream',
    streamType: stream,
    worldId: 'w',
    locationId: 'l',
    userId: 'u',
    triggerUid: 'u',
    conversationRoundId: _round,
    globalMessageId: id,
    senderType: 'character',
    senderId: 'c',
    payload: {
      'card_id': 102,
      'card_message_index': id == _messageId ? 1 : 3,
      'seq': seq,
      'content': content,
    },
  ),
);
ChatroomLlmCardGenerationEnd _terminal(
  String state, {
  int errNo = 0,
  String errMsg = '',
  Object? error,
}) => ChatroomLlmCardGenerationEnd.fromV2Message(
  ChatroomV2Message(
    type: 'llm_card_generation_end',
    errNo: errNo,
    errMsg: errMsg,
    worldId: 'w',
    locationId: 'l',
    userId: 'u',
    triggerUid: 'u',
    conversationRoundId: _round,
    payload: {
      'card_id': 102,
      'generation_state': state,
      if (error != null) 'error': error,
      'billing': {'status': 'not_required'},
    },
  ),
);

void main() {
  test(
    'inspiration tail changes controls without replacing formal reply bodies',
    () {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final formal = h.state.formalReplyMessages;
      final before = h.controller.revisionsForLocation('l');
      var changes = 0;
      h.controller.changesForLocation('l').addListener(() => changes++);
      h.controller.observeMessages('l', [
        ...formal,
        _formal(type: 'user', id: _messageId + 1),
      ]);
      expect(h.state.formalReplyMessages, same(formal));
      expect(h.state.inspirationTailMessageId, _messageId + 1);
      final after = h.controller.revisionsForLocation('l');
      expect(after.contentRevision, before.contentRevision);
      expect(after.structureRevision, before.structureRevision);
      expect(after.controlsRevision, before.controlsRevision + 1);
      expect(changes, 1);
    },
  );

  test(
    'location notifications batch synchronously and ignore rewrapped history',
    () {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      var global = 0;
      var local = 0;
      var other = 0;
      h.controller.addListener(() => global++);
      h.controller.changesForLocation('l').addListener(() => local++);
      h.controller.changesForLocation('other').addListener(() => other++);
      final formal = h.state.formalReplyMessages;
      final before = h.controller.revisionsForLocation('l');
      h.controller.observeMessages('l', [...formal]);
      expect(h.state.formalReplyMessages, same(formal));
      expect(h.controller.revisionsForLocation('l'), same(before));
      expect(global, 0);
      h.controller.batchChanges(() {
        h.controller.observeMessages('l', [_formal(content: 'one')]);
        h.controller.observeMessages('l', [_formal(content: 'two')]);
        h.controller.observeMessages('other', [
          _formal().copyWith(locationId: 'other'),
        ]);
        expect(global, 0);
      });
      expect(global, 1);
      expect(local, 1);
      expect(other, 1);
      expect(h.state.formalReplyMessages.single.content, 'two');
      expect(
        h.controller.revisionsForLocation('l').structureRevision,
        before.structureRevision,
      );
      expect(
        h.controller.revisionsForLocation('l').contentRevision,
        before.contentRevision + 1,
      );
      final afterContent = h.controller.revisionsForLocation('l');
      h.ready = false;
      h.controller.refreshAvailability();
      final afterAvailability = h.controller.revisionsForLocation('l');
      expect(afterAvailability.contentRevision, afterContent.contentRevision);
      expect(
        afterAvailability.structureRevision,
        afterContent.structureRevision,
      );
      expect(
        afterAvailability.controlsRevision,
        afterContent.controlsRevision + 1,
      );
    },
  );

  test(
    'candidate snapshots reuse lists and unaffected rows across chunks',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      await h.controller.restoreLocationCards('l');
      var local = 0;
      var other = 0;
      h.controller.changesForLocation('l').addListener(() => local++);
      h.controller.changesForLocation('other').addListener(() => other++);
      final original = h.state.messagesForCard(101);
      h.controller.receiveEvent(_stream('chunk', content: 'A'));
      h.controller.receiveEvent(
        _stream('chunk', content: 'second', id: _messageId + 1),
      );
      final first = h.state.messagesForCard(102);
      expect(h.state.messagesForCard(102), same(first));
      final revision = h.state.cardContentRevision(102);
      final structure = h.state.structureRevision;
      final controls = h.state.controlsRevision;
      final unchangedMessageRevision = h.state.messageContentRevision(
        102,
        _messageId + 1,
      );
      h.controller.receiveEvent(_stream('chunk', seq: 2, content: 'B'));
      final second = h.state.messagesForCard(102);
      expect(second, isNot(same(first)));
      expect(second.first.content, 'AB');
      expect(second.last, same(first.last));
      expect(h.state.cardContentRevision(102), revision + 1);
      expect(h.state.structureRevision, structure);
      expect(h.state.controlsRevision, controls);
      expect(
        h.state.messageContentRevision(102, _messageId + 1),
        unchangedMessageRevision,
      );
      expect(h.state.messagesForCard(101), same(original));
      final notifications = local;
      h.controller.receiveEvent(_stream('chunk', seq: 2, content: 'duplicate'));
      expect(local, notifications);
      expect(h.state.messagesForCard(102), same(second));
      expect(other, 0);
      h.controller.receiveEvent(_stream('chunk', seq: 4, content: 'D'));
      h.controller.receiveEvent(_stream('chunk', seq: 3, content: 'C'));
      expect(h.state.messagesForCard(102).first.content, 'ABCD');
      h.controller.receiveEvent(_stream('chunk', seq: 5, content: 'E'));
      expect(h.state.messagesForCard(102).first.content, 'ABCDE');
      h.controller.receiveEvent(_stream('end', content: 'authoritative'));
      final ended = h.state.messagesForCard(102);
      expect(ended.first.content, 'authoritative');
      expect(ended.first.streaming, isFalse);
      h.controller.receiveEvent(_stream('chunk', seq: 6, content: 'late'));
      expect(h.state.messagesForCard(102), same(ended));
    },
  );

  test(
    'empty candidate chunks retain content versions and receipt bookkeeping',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      await h.controller.restoreLocationCards('l');
      h.controller.receiveEvent(_stream('start'));
      final messages = h.state.messagesForCard(102);
      final revision = h.state.cardContentRevision(102);
      expect(h.state.hasCandidateChunk(102), isFalse);
      h.controller.receiveEvent(_stream('chunk', content: ''));
      expect(h.state.hasCandidateChunk(102), isTrue);
      expect(h.state.cardContentRevision(102), revision);
      expect(h.state.messagesForCard(102), same(messages));
      expect(messages.single.content, isEmpty);
    },
  );

  test(
    'authoritative card refresh only replaces messages whose values changed',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      final before = h.state.messagesForCard(101);
      final contentRevision = h.state.cardContentRevision(101);
      await h.controller.clearCardsCache('l');
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      expect(h.state.messagesForCard(101), same(before));
      expect(h.state.cardContentRevision(101), contentRevision);
      await h.controller.clearCardsCache('l');
      h.api.cards = _cards([_card(101, content: 'Edited')]);
      await h.controller.restoreLocationCards('l');
      final after = h.state.messagesForCard(101);
      expect(after.first, isNot(same(before.first)));
      expect(after.first.content, 'Edited');
      expect(after.last, same(before.last));
      expect(h.state.cardContentRevision(101), contentRevision + 1);
    },
  );

  test('invalid saved reply metadata cannot block other rounds', () async {
    final storage = MemoryChatroomReplyActionStorage();
    await storage.save(
      ownerUid: 'u',
      worldId: 'w',
      locationId: 'l',
      roundId: _round,
      value: {
        'round_id': _round,
        'draft_baselines': {
          'invalid': {'bad': true},
          '101': {'invalid': true, '12': 'Original'},
        },
        'viewed_card_id': 'invalid',
        'fixed_card_id': 'invalid',
        'drafts': {
          '101': ['invalid operation'],
        },
        'uncertain_batches': 'invalid',
        'go_on': {'round_id': 'invalid'},
      },
    );
    await storage.save(
      ownerUid: 'u',
      worldId: 'w',
      locationId: 'l',
      roundId: _round + 1,
      value: {
        'round_id': _round + 1,
        'viewed_card_id': 102,
        'cards_cached_at': DateTime.now().millisecondsSinceEpoch,
        'cards_cache': {'list': 'invalid'},
      },
    );
    final h = _Harness(storage: storage);
    addTearDown(h.controller.dispose);
    await h.controller.restore('l');
    expect(h.controller.stateForRound('l', _round)?.viewedCardId, 0);
    expect(h.controller.stateForRound('l', _round + 1)?.viewedCardId, 102);
  });

  for (final failed in [true, false]) {
    test(
      'late terminal regeneration receipt resolves timeout without replay: failed=$failed',
      () async {
        final h = _Harness();
        addTearDown(h.controller.dispose);
        const timeout = ChatroomFailureEvent(
          code: 'ack_timeout',
          message: 'No ACK',
        );
        h.session.regenerateHandler = () async => throw timeout;
        await expectLater(h.controller.regenerate('l'), throwsA(same(timeout)));
        final requestId = h.session.requests.single.split(':').last;
        h.api.calls.clear();
        h.api.cards = _cards([
          _card(101),
          _card(
            102,
            index: 2,
            generation: failed ? 'failed' : 'succeeded',
            content: 'Completed late reply',
            canEdit: !failed,
            canDelete: !failed,
          ),
        ]);
        final ack = ChatroomAck(
          sessionId: '',
          worldId: 'w',
          locationId: 'l',
          userId: 'u',
          code: 0,
          codeMsg: '',
          ts: null,
          clientMsgId: requestId,
          cardConversationRoundId: _round,
          regeneration: ChatroomCardRegeneration(
            conversationRoundId: _round,
            originalCardId: 101,
            cardId: 102,
            generationState: failed
                ? ChatroomCardGenerationState.failed
                : ChatroomCardGenerationState.succeeded,
            billing: const ChatroomCardBilling(
              status: ChatroomCardBillingStatus.notRequired,
            ),
            error: failed
                ? {'err_no': 21001, 'err_msg': 'Insufficient balance'}
                : null,
          ),
        );
        h.controller.receiveEvent(ack);
        h.controller.receiveEvent(ack);
        await _settle();
        expect(h.state.generating, isFalse);
        expect(h.state.cardCount, 2);
        expect(h.state.viewedCardId, failed ? 101 : 102);
        expect(
          h.state.displayedMessages.first.content,
          failed ? 'Original' : 'Completed late reply',
        );
        expect(h.walletRefreshes, 1);
        expect(h.api.calls, ['cards:$_round']);

        final next = Completer<ChatroomCardRegeneration>();
        h.session.regenerateHandler = () => next.future;
        final newAction = h.controller.regenerate('l');
        await _settle();
        h.controller.receiveEvent(ack);
        expect(h.state.viewedCardId, -1);
        expect(h.state.generating, isTrue);
        next.complete(
          const ChatroomCardRegeneration(
            conversationRoundId: _round,
            originalCardId: 101,
            cardId: 103,
            generationState: ChatroomCardGenerationState.generating,
            billing: ChatroomCardBilling(
              status: ChatroomCardBillingStatus.reserved,
            ),
          ),
        );
        await newAction;
        expect(h.state.viewedCardId, 103);
        expect(h.session.requests, hasLength(2));
        expect(h.walletRefreshes, 1);
      },
    );
  }

  test(
    'late success receipt supersedes timeout recovery GET and restores view on read error',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      const timeout = ChatroomFailureEvent(
        code: 'ack_timeout',
        message: 'No ACK',
      );
      final staleRead = Completer<ChatroomLlmCardsResponse>();
      h.api.cardsBarrier = staleRead;
      h.session.regenerateHandler = () async => throw timeout;
      final timedOut = h.controller.regenerate('l');
      final rejected = expectLater(timedOut, throwsA(same(timeout)));
      await _settle();
      h.api.cardsError = StateError('New card read unavailable');
      h.controller.receiveEvent(
        ChatroomAck(
          sessionId: '',
          worldId: 'w',
          locationId: 'l',
          userId: 'u',
          code: 0,
          codeMsg: '',
          ts: null,
          clientMsgId: h.session.requests.single.split(':').last,
          cardConversationRoundId: _round,
          regeneration: const ChatroomCardRegeneration(
            conversationRoundId: _round,
            originalCardId: 101,
            cardId: 102,
            generationState: ChatroomCardGenerationState.succeeded,
            billing: ChatroomCardBilling(
              status: ChatroomCardBillingStatus.notRequired,
            ),
          ),
        ),
      );
      await _settle();
      staleRead.complete(_cards([]));
      await rejected;
      await _settle();
      expect(h.state.generating, isFalse);
      expect(h.state.viewedCardId, 101);
      expect(h.state.displayedMessages.first.content, 'Original');
      expect(h.state.cardCount, 2);
      expect(
        h.state.cards.last.generationState,
        ChatroomCardGenerationState.succeeded,
      );
      expect(h.state.error, isA<StateError>());
      expect(h.walletRefreshes, 1);
      expect(h.session.requests, hasLength(1));
    },
  );

  for (final regenerate in [true, false]) {
    test(
      'late balance ACK releases uncertain reply action: regenerate=$regenerate',
      () async {
        final h = _Harness();
        addTearDown(h.controller.dispose);
        const timeout = ChatroomFailureEvent(
          code: 'ack_timeout',
          message: 'No receipt yet',
          sourceType: 'ack',
        );
        h.session.regenerateHandler = () async => throw timeout;
        h.session.goOnHandler = (_) async => throw timeout;
        Future<void> begin() async {
          if (regenerate) {
            await h.controller.regenerate('l');
          } else {
            await h.controller.goOn('l');
          }
        }

        await expectLater(begin(), throwsA(same(timeout)));
        final oldRequest = h.session.requests.last.split(':').last;
        expect(regenerate ? h.state.generating : h.state.goOnPending, isTrue);
        final lateAck = ChatroomAck(
          sessionId: '',
          worldId: 'w',
          locationId: '',
          userId: '',
          code: 3001,
          codeMsg: 'Insufficient balance',
          ts: null,
          clientMsgId: oldRequest,
        );
        h.controller.receiveEvent(lateAck);
        await _settle();
        expect(h.state.generating, isFalse);
        expect(h.state.goOnPending, isFalse);
        expect(h.state.cardCount, 0);
        expect(h.state.displayedMessages.first.content, 'Original');
        expect(h.state.canRegenerate, isTrue);
        expect(h.state.canGoOn, isTrue);
        expect(h.walletRefreshes, 1);

        final regenAck = Completer<ChatroomCardRegeneration>();
        final goAck = Completer<ChatroomGoOnReceipt>();
        h.session.regenerateHandler = () => regenAck.future;
        h.session.goOnHandler = (_) => goAck.future;
        final second = begin();
        final secondRejected = expectLater(second, throwsA(same(timeout)));
        await _settle();
        h.controller.receiveEvent(lateAck);
        await _settle();
        expect(regenerate ? h.state.generating : h.state.goOnPending, isTrue);
        expect(h.walletRefreshes, 1);
        expect(h.session.requests, hasLength(2));
        if (regenerate) {
          regenAck.completeError(timeout);
        } else {
          goAck.completeError(timeout);
        }
        await secondRejected;
      },
    );
  }

  test(
    'succeeded ACK read failure restores complete view and later reads real candidate',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cardsError = StateError('Cards temporarily unavailable');
      h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
        conversationRoundId: _round,
        originalCardId: 101,
        cardId: 102,
        generationState: ChatroomCardGenerationState.succeeded,
        billing: ChatroomCardBilling(
          status: ChatroomCardBillingStatus.notRequired,
        ),
      );
      await expectLater(h.controller.regenerate('l'), throwsStateError);
      expect(h.state.generating, isFalse);
      expect(h.state.viewedCardId, 101);
      expect(h.state.displayedMessages.first.content, 'Original');
      expect(h.state.cardCount, 2);
      expect(h.state.cards.last.cardId, 102);
      expect(
        h.state.cards.last.generationState,
        ChatroomCardGenerationState.succeeded,
      );
      expect(h.state.cards.last.messages, isEmpty);
      expect(h.walletRefreshes, 1);
      h.api.cardsError = null;
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, content: 'Recovered completed reply'),
      ]);
      await h.controller.restoreLocationCards('l');
      await h.controller.browse('l', 1);
      expect(
        h.state.displayedMessages.first.content,
        'Recovered completed reply',
      );
      expect(h.session.requests, hasLength(1));
    },
  );

  for (final withCards in [false, true]) {
    test(
      'regeneration balance precheck preserves existing cards: $withCards',
      () async {
        final h = _Harness();
        addTearDown(h.controller.dispose);
        h.api.cards = _cards(withCards ? [_card(101)] : []);
        await h.controller.restoreLocationCards('l');
        h.api.calls.clear();
        h.session.regenerateHandler = () async =>
            throw const ChatroomFailureEvent(
              code: '3001',
              message: 'Insufficient balance',
              requestType: 'regenerate_llm_card',
            );
        await expectLater(
          h.controller.regenerate('l'),
          throwsA(isA<ChatroomFailureEvent>()),
        );
        await _settle();
        expect(h.state.generating, isFalse);
        expect(h.state.cardCount, withCards ? 1 : 0);
        expect(h.state.displayedMessages.first.content, 'Original');
        expect(h.state.canRegenerate, isTrue);
        expect(h.api.calls, isEmpty);
        expect(h.walletRefreshes, 1);
      },
    );
  }

  test(
    'Go on balance rejection creates no round and releases the source',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.session.goOnHandler = (_) async => throw const ChatroomFailureEvent(
        code: '3001',
        message: 'Insufficient balance',
        requestType: 'go_on',
      );
      await expectLater(
        h.controller.goOn('l'),
        throwsA(isA<ChatroomFailureEvent>()),
      );
      await _settle();
      expect(h.state.goOnPending, isFalse);
      expect(h.state.goOnRoundId, isNull);
      expect(h.state.canGoOn, isTrue);
      expect(h.controller.statesFor('l'), hasLength(1));
      expect(h.state.displayedMessages.first.content, 'Original');
      expect(h.walletRefreshes, 1);
    },
  );

  for (final terminalFirst in [false, true]) {
    test(
      'failed balance candidate reconciles once, terminal first: $terminalFirst',
      () async {
        final h = _Harness();
        addTearDown(h.controller.dispose);
        h.api.cards = _cards([_card(101)]);
        await h.controller.restoreLocationCards('l');
        h.api.calls.clear();
        final ack = Completer<ChatroomCardRegeneration>();
        h.session.regenerateHandler = () => ack.future;
        final action = h.controller.regenerate('l');
        await _settle();
        final terminal = _terminal(
          'failed',
          errNo: 21001,
          errMsg: 'Insufficient balance',
        );
        h.api.cards = _cards([
          _card(101),
          _card(
            102,
            index: 2,
            generation: 'failed',
            canEdit: false,
            canDelete: false,
          ),
        ]);
        if (terminalFirst) {
          h.controller.receiveEvent(terminal);
          expect(h.state.generating, isFalse);
          expect(h.state.displayedMessages.first.content, 'Original');
        }
        ack.complete(
          const ChatroomCardRegeneration(
            conversationRoundId: _round,
            originalCardId: 101,
            cardId: 102,
            generationState: ChatroomCardGenerationState.failed,
            billing: ChatroomCardBilling(
              status: ChatroomCardBillingStatus.cancelled,
            ),
            error: {'err_no': 21001, 'err_msg': 'Insufficient balance'},
          ),
        );
        await action;
        h.controller.receiveEvent(terminal);
        h.controller.receiveEvent(terminal);
        await _settle();
        expect(h.state.generating, isFalse);
        expect(h.state.cardCount, 2);
        expect(h.state.viewedCardId, 101);
        expect(h.state.displayedMessages.first.content, 'Original');
        expect(
          h.state.cards.last.generationState,
          ChatroomCardGenerationState.failed,
        );
        expect(h.state.cards.last.canEdit, isFalse);
        expect(h.state.canRegenerate, isTrue);
        expect(h.api.calls, ['cards:$_round']);
        expect(h.walletRefreshes, 1);
      },
    );
  }

  test(
    'succeeded regeneration ACK loads full content without stream replay',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, content: 'Recovered complete reply'),
      ]);
      h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
        conversationRoundId: _round,
        originalCardId: 101,
        cardId: 102,
        generationState: ChatroomCardGenerationState.succeeded,
        billing: ChatroomCardBilling(
          status: ChatroomCardBillingStatus.notRequired,
        ),
      );
      await h.controller.regenerate('l');
      expect(h.state.generating, isFalse);
      expect(h.state.viewedCardId, 102);
      expect(
        h.state.displayedMessages.first.content,
        'Recovered complete reply',
      );
      expect(h.state.canEdit, isTrue);
      expect(h.api.calls, ['cards:$_round']);
      expect(h.walletRefreshes, 1);
    },
  );

  test(
    'late failed ACK cannot overwrite a new explicit regeneration',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      final firstAck = Completer<ChatroomCardRegeneration>();
      h.session.regenerateHandler = () => firstAck.future;
      final first = h.controller.regenerate('l');
      await _settle();
      h.api.cards = _cards([
        _card(101),
        _card(
          102,
          index: 2,
          generation: 'failed',
          canEdit: false,
          canDelete: false,
        ),
      ]);
      h.controller.receiveEvent(_terminal('failed', errNo: 21001));
      await _settle();
      expect(h.state.canRegenerate, isTrue);
      final secondAck = Completer<ChatroomCardRegeneration>();
      h.session.regenerateHandler = () => secondAck.future;
      final second = h.controller.regenerate('l');
      await _settle();
      firstAck.complete(
        const ChatroomCardRegeneration(
          conversationRoundId: _round,
          originalCardId: 101,
          cardId: 102,
          generationState: ChatroomCardGenerationState.failed,
          billing: ChatroomCardBilling(
            status: ChatroomCardBillingStatus.cancelled,
          ),
          error: {'err_no': 21001, 'err_msg': 'Insufficient balance'},
        ),
      );
      await first;
      expect(h.state.viewedCardId, -1);
      expect(h.state.generating, isTrue);
      secondAck.complete(
        const ChatroomCardRegeneration(
          conversationRoundId: _round,
          originalCardId: 101,
          cardId: 103,
          generationState: ChatroomCardGenerationState.generating,
          billing: ChatroomCardBilling(
            status: ChatroomCardBillingStatus.reserved,
          ),
        ),
      );
      await second;
      expect(h.state.viewedCardId, 103);
      expect(h.state.generating, isTrue);
      expect(h.state.cardCount, 3);
      expect(h.session.requests, hasLength(2));
    },
  );

  for (final type in [
    'opening',
    'user_enter_location',
    'tick',
    'user_message',
  ]) {
    test(
      'persist support without cards response restores an empty deck for $type',
      () async {
        final snapshots = MemoryChatroomMessageStorage();
        await snapshots.upsertMessage(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          message: {
            'msg_id': _messageId,
            'global_msg_id': _messageId,
            'location_msg_id': _messageId,
            'conversation_round_id': _round,
            'location_id': 'l',
            'sender_type': 'character',
            'content': 'Original',
          },
        );
        final first = _Harness(
          conversationType: type,
          worldCreatorUid: 'u',
          snapshotStorage: snapshots,
        );
        addTearDown(first.controller.dispose);
        await first.controller.persistHistorySupport('l');
        expect(first.api.calls, isEmpty);
        final saved = (await snapshots.loadReplySnapshots(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
        )).single;
        expect(saved['cards_resolved'], true);
        await snapshots.saveReplySnapshot(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          roundId: _round,
          value: {
            ...saved,
            'capability_version': 1,
            'supported_actions': {
              'regenerate': false,
              'go_on': false,
              'edit': false,
              'inspiration': false,
            },
          },
        );
        final cached = ChatroomLlmCardsResponse.fromJson(saved['cards_cache']);
        expect(cached.list, isEmpty);
        expect(cached.total, 0);
        final restored = _Harness(
          conversationType: type,
          worldCreatorUid: 'u',
          snapshotStorage: snapshots,
        );
        addTearDown(restored.controller.dispose);
        await restored.controller.restore('l');
        expect(restored.controller.historyCardsResolved('l'), true);
        expect(restored.state.supportsGoOn, true);
        expect(restored.state.supportsRegenerate, type == 'user_message');
        expect(restored.state.supportsEdit, type != 'tick');
        expect(restored.state.supportsInspiration, true);
        final rewritten = (await snapshots.loadReplySnapshots(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
        )).single;
        expect(rewritten['capability_version'], 6);
        expect((rewritten['supported_actions'] as Map)['go_on'], true);
        expect((rewritten['supported_actions'] as Map)['edit'], type != 'tick');
        expect(restored.api.calls, isEmpty);
      },
    );
  }

  Future<void> historyCards(_Harness h, {bool Function()? current}) =>
      h.controller.loadHistoryCards(
        'l',
        roundIds: {_round},
        isCurrent: current ?? () => true,
      );

  for (final sqlite in [false, true]) {
    test(
      'terminal candidate streams persist without GET and partial generation preserves the complete deck sqlite=$sqlite',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'reply-stream-durable-',
        );
        sqfliteFfiInit();
        ChatroomMessageStorage snapshots = sqlite
            ? SqfliteChatroomMessageStorage(
                databasePath: '${directory.path}/messages.db',
                databaseFactoryOverride: databaseFactoryFfi,
              )
            : MemoryChatroomMessageStorage();
        addTearDown(() async {
          if (snapshots is SqfliteChatroomMessageStorage) {
            await snapshots.close();
          }
          await directory.delete(recursive: true);
        });
        await snapshots.upsertMessage(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          message: {
            'msg_id': _messageId,
            'global_msg_id': _messageId,
            'location_msg_id': _messageId,
            'conversation_round_id': _round,
            'location_id': 'l',
            'sender_type': 'character',
            'content': 'Original',
          },
        );
        final storage = MemoryChatroomReplyActionStorage();
        final h = _Harness(storage: storage, snapshotStorage: snapshots);
        await historyCards(h);
        h.api.calls.clear();
        h.session.regenerateHandler = () async =>
            const ChatroomCardRegeneration(
              conversationRoundId: _round,
              originalCardId: 101,
              cardId: 102,
              generationState: ChatroomCardGenerationState.generating,
              billing: ChatroomCardBilling(
                status: ChatroomCardBillingStatus.reserved,
              ),
            );
        await h.controller.regenerate('l');
        h.controller.receiveEvent(
          _stream('end', content: 'Complete local reply'),
        );
        h.controller.receiveEvent(_terminal('succeeded'));
        await _settle();
        await h.controller.browse('l', -1);
        await h.controller.browse('l', 1);
        expect(h.api.calls, isEmpty);
        h.controller.dispose();
        if (sqlite) {
          await (snapshots as SqfliteChatroomMessageStorage).close();
          snapshots = SqfliteChatroomMessageStorage(
            databasePath: '${directory.path}/messages.db',
            databaseFactoryOverride: databaseFactoryFfi,
          );
        }
        final next = _Harness(storage: storage, snapshotStorage: snapshots);
        addTearDown(next.controller.dispose);
        await next.controller.restore('l');
        expect(next.state.cards.map((c) => c.cardId), [101, 102]);
        expect(next.state.viewedCardId, 102);
        expect(
          next.state.displayedMessages.single.content,
          'Complete local reply',
        );
        expect(next.state.cards.last.messages.single.isLlmStreamMessage, true);
        expect(next.state.supportsEdit, true);
        expect(next.api.calls, isEmpty);
        final before = (await snapshots.loadReplySnapshots(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
        )).single;
        next.session.regenerateHandler = () async =>
            const ChatroomCardRegeneration(
              conversationRoundId: _round,
              originalCardId: 101,
              cardId: 103,
              generationState: ChatroomCardGenerationState.generating,
              billing: ChatroomCardBilling(
                status: ChatroomCardBillingStatus.reserved,
              ),
            );
        await next.controller.regenerate('l');
        final after = (await snapshots.loadReplySnapshots(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
        )).single;
        expect(after['cards_cache'], before['cards_cache']);
      },
    );
  }

  test(
    'SQLite card cache survives closing and reopening the database',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'reply-card-cache-',
      );
      final path = '${directory.path}/actions.db';
      final storage = SqfliteChatroomReplyActionStorage(
        databasePath: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      final first = _Harness(storage: storage);
      first.api.cards = _cards([_card(101)]);
      await historyCards(first);
      first.controller.dispose();
      await _settle();
      final reopened = SqfliteChatroomReplyActionStorage(
        databasePath: path,
        databaseFactoryOverride: databaseFactoryFfi,
      );
      final second = _Harness(storage: reopened);
      try {
        await historyCards(second);
        expect(second.api.calls, isEmpty);
        expect(
          second.state.cards.single.messages.first.conversationRoundId,
          _round,
        );
        expect(second.state.cards.single.messages.first.content, 'Original');
        await second.controller.clearCardsCache('l');
        final saved = await reopened.load(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
        );
        expect(saved.single, contains('cards_cache'));
        expect(saved.single, contains('go_on'));
      } finally {
        second.controller.dispose();
        await _settle();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'card history coalesces requests and caches empty and populated groups',
    () async {
      for (final cards in [
        <ChatroomLlmCard>[],
        [_card(101)],
      ]) {
        final h = _Harness();
        addTearDown(h.controller.dispose);
        final barrier = Completer<ChatroomLlmCardsResponse>();
        h.api.cardsBarrier = barrier;
        var oldCurrent = true;
        final first = historyCards(h, current: () => oldCurrent);
        await _settle();
        oldCurrent = false;
        final second = historyCards(h);
        await _settle();
        expect(h.api.calls.where((c) => c.startsWith('cards:')), hasLength(1));
        barrier.complete(_cards(cards));
        await Future.wait([first, second]);
        await historyCards(h);
        expect(h.api.calls.where((c) => c.startsWith('cards:')), hasLength(1));
        expect(h.state.cards.length, cards.length);
      }
    },
  );

  test(
    'cards persist across controllers and clearing preserves operation metadata',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final first = _Harness(storage: storage);
      first.api.cards = _cards([_card(101)]);
      await historyCards(first);
      first.controller.dispose();
      final restored = _Harness(storage: storage);
      addTearDown(restored.controller.dispose);
      await historyCards(restored);
      expect(restored.api.calls, isEmpty);
      expect(restored.state.cards.single.cardId, 101);
      await restored.controller.clearCardsCache('l');
      final saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect(saved, contains('cards_cache'));
      expect(saved['viewed_card_id'], 101);
      expect(saved, contains('drafts'));
      await historyCards(restored);
      expect(restored.api.calls, ['cards:$_round']);
      final other = _Harness(storage: storage, owner: 'other');
      addTearDown(other.controller.dispose);
      await historyCards(other);
      expect(other.api.calls, ['cards:$_round']);
    },
  );

  test('cards remain available after more than 24 hours', () async {
    var now = DateTime.utc(2026, 9, 9);
    final storage = MemoryChatroomReplyActionStorage();
    final first = _Harness(storage: storage, now: () => now);
    first.api.cards = _cards([_card(101)]);
    await historyCards(first);
    now = now.add(const Duration(hours: 23));
    await historyCards(first);
    expect(first.api.calls, ['cards:$_round']);
    first.controller.dispose();
    now = now.add(const Duration(days: 10));
    final next = _Harness(storage: storage, now: () => now);
    addTearDown(next.controller.dispose);
    await next.controller.restore('l');
    final saved = (await storage.load(
      ownerUid: 'u',
      worldId: 'w',
      locationId: 'l',
    )).single;
    expect(saved, contains('cards_cache'));
    await historyCards(next);
    expect(next.api.calls, isEmpty);
  });

  test(
    'invalidated in-flight card responses cannot revive persisted cache',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      addTearDown(h.controller.dispose);
      final barrier = Completer<ChatroomLlmCardsResponse>();
      h.api.cardsBarrier = barrier;
      final old = historyCards(h);
      await _settle();
      await h.controller.clearCardsCache('l', start: _round, end: _round);
      h.api.cards = _cards([_card(102)]);
      await historyCards(h);
      barrier.complete(_cards([_card(101)]));
      await old;
      await historyCards(h);
      expect(h.api.calls, ['cards:$_round', 'cards:$_round']);
      expect(h.state.cards.single.cardId, 102);
      final saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect((saved['cards_cache'] as Map)['original_card_id'], 102);
    },
  );

  test('nonterminal cards and failed reads are not cached', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([_card(101, generation: 'generating')]);
    await historyCards(h);
    await historyCards(h);
    expect(h.api.calls, ['cards:$_round', 'cards:$_round']);
    final barrier = Completer<ChatroomLlmCardsResponse>();
    h.api.cardsBarrier = barrier;
    final failed = historyCards(h);
    final check = expectLater(failed, throwsStateError);
    await _settle();
    barrier.completeError(StateError('offline'));
    await check;
    h.api.cards = _cards([_card(101)]);
    await historyCards(h);
    await historyCards(h);
    expect(h.api.calls, hasLength(4));
  });

  test('new rounds and disconnect retain snapshots and drafts', () async {
    final storage = MemoryChatroomReplyActionStorage();
    final h = _Harness(storage: storage);
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([_card(101)]);
    await historyCards(h);
    h.controller.invalidateCardsOnDisconnect();
    await historyCards(h);
    expect(h.api.calls, hasLength(2));
    h.controller.observeMessages('l', [_formal(round: _round + 1)]);
    await _settle();
    final saved = await storage.load(
      ownerUid: 'u',
      worldId: 'w',
      locationId: 'l',
    );
    expect(saved.single, contains('cards_cache'));
    expect(saved.single, contains('drafts'));
  });

  test(
    'candidate previews read local streams without browsing or persistence',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      await h.controller.restoreLocationCards('l');
      final revision = h.state.presentationRevision;
      final current = h.state.viewedCardId;
      h.api.calls.clear();
      h.controller.receiveEvent(_stream('chunk', content: 'Live preview'));
      expect(h.state.messagesForCard(102).single.content, 'Live preview');
      expect(h.state.messagesForCard(101), isNotEmpty);
      expect(h.state.messagesForCard(-99), isEmpty);
      expect(h.state.viewedCardId, current);
      expect(h.state.presentationRevision, revision);
      expect(h.api.calls, isEmpty);
      expect(h.session.requests, isEmpty);
    },
  );

  test('another user cannot use reply actions and readiness still blocks', () {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.controller.observeMessages('l', [_formal(user: 'another-user')]);
    expect(h.state.inspirationSource, isNull);
    expect(h.state.canRegenerate, isFalse);
    expect(h.state.canGoOn, isFalse);
    expect(h.state.canEdit, isFalse);
    h.ready = false;
    expect(h.state.inspirationSource, isNull);
    h.ready = true;
    h.locked = true;
    expect(h.state.inspirationSource, isNull);
  });

  test(
    'inspiration validates the exact card before and after confirmation',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      await h.controller.restoreLocationCards('l');
      final original = h.state.inspirationSource!;
      expect(original.sourceCardId, 0);
      expect(original.cardId, 101);
      await h.controller.browse('l', 1);
      final candidate = h.state.inspirationSource!;
      expect(candidate.sourceCardId, 102);
      await expectLater(
        h.controller.finalizeBeforeSend('l', expectedSource: original),
        throwsStateError,
      );
      expect(h.api.calls.where((call) => call.startsWith('select:')), isEmpty);
      await h.controller.finalizeBeforeSend('l', expectedSource: candidate);
      expect(h.state.selectedCardId, 102);
      expect(h.state.confirmed, isTrue);
      await h.controller.finalizeBeforeSend('l', expectedSource: candidate);
      expect(h.api.calls.where((call) => call.startsWith('select:')), [
        'select:102',
      ]);
    },
  );

  test('a newer active round never falls back to previous inspiration', () {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    expect(h.state.inspirationSource, isNotNull);
    h.controller.observeMessages(
      'l',
      [_formal(), _formal(round: _round + 1, type: 'user')],
      activeRoundIds: {_round + 1},
    );
    expect(h.state.inspirationSource, isNull);
    expect(h.controller.stateFor('l')!.inspirationSource, isNull);
  });

  test(
    'original card includes same-round narrator and character but not user or tick',
    () {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final messages = [
        for (final (i, type) in [
          'user',
          'character',
          'narrator',
          'tick',
        ].indexed)
          WorldChatroomMessage.fromHttpMessage(
            ChatroomHttpMessage.fromV2Message(_v2(type, id: _messageId + i)),
          ),
        _formal(round: _round - 1, type: 'narrator'),
      ];
      h.controller.observeMessages('l', messages);
      expect(h.state.formalReplyMessages.map((m) => m.globalMessageId), [
        _messageId + 1,
        _messageId + 2,
      ]);
      expect(h.state.displayedMessages.map((m) => m.businessType), [
        'character',
        'narrator',
      ]);
    },
  );

  test('reply eligibility uses trigger UID instead of user ID', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.controller.observeMessages('l', [
      _formal(user: 'u', triggerUid: 'someone-else'),
    ]);
    expect(h.state.canGoOn, isFalse);
    expect(h.state.canRegenerate, isFalse);
    await expectLater(h.prepareEditor(), throwsStateError);
    final own = _Harness();
    addTearDown(own.controller.dispose);
    own.controller.observeMessages('l', [
      _formal(user: 'someone-else', triggerUid: 'u'),
    ]);
    expect(own.state.canRegenerate, isTrue);
    expect(own.state.canGoOn, isTrue);
    expect(own.state.canEdit, isTrue);
    expect(own.state.inspirationSource, isNotNull);
    own.locked = true;
    expect(own.state.canGoOn, isFalse);
    expect(own.state.supportsGoOn, isTrue);
  });

  test(
    'latest conversation action matrix follows type, trigger UID and world creator',
    () async {
      for (final entry in <(String, String, String, bool, bool, bool, bool)>[
        // type, trigger UID, world creator UID, regenerate, go on, edit, inspiration
        ('opening', '', 'u', false, true, true, true),
        ('opening', '', 'another-user', false, false, false, false),
        ('opening', 'u', '', false, false, false, false),
        ('user_enter_location', 'u', '', false, true, true, true),
        (
          'user_enter_location',
          'another-user',
          'u',
          false,
          false,
          false,
          false,
        ),
        ('user_enter_location', '', 'u', false, false, false, false),
        ('tick', '', 'u', false, true, false, true),
        ('tick', 'u', 'u', false, true, false, true),
        ('tick', '', '', false, true, false, true),
        ('tick', 'another-user', 'another-user', false, true, false, true),
        ('user_message', 'u', '', true, true, true, true),
        ('go_on', 'u', '', true, true, true, true),
        ('user_message', 'another-user', 'u', false, false, false, false),
        ('go_on', 'another-user', 'u', false, false, false, false),
        ('user_message', '', 'u', false, false, false, false),
        ('go_on', '', 'u', false, false, false, false),
        ('', 'u', 'u', false, false, false, false),
        ('unknown', 'u', 'u', false, false, false, false),
      ]) {
        final (type, uid, creator, regenerate, goOn, edit, inspiration) = entry;
        final h = _Harness(
          conversationType: type,
          triggerUid: uid,
          worldCreatorUid: creator,
        );
        addTearDown(h.controller.dispose);
        final reason = '$type/$uid/creator=$creator';
        expect(h.state.supportsRegenerate, regenerate, reason: reason);
        expect(h.state.supportsGoOn, goOn, reason: reason);
        expect(h.state.supportsEdit, edit, reason: reason);
        expect(h.state.supportsInspiration, inspiration, reason: reason);
        expect(h.state.canRegenerate, regenerate, reason: reason);
        expect(h.state.canGoOn, goOn, reason: reason);
        expect(h.state.canEdit, edit, reason: reason);
        expect(h.state.inspirationSource != null, inspiration, reason: reason);
        if (inspiration && !regenerate) {
          expect(h.state.inspirationSource!.cardId, isNull, reason: reason);
        }
        if (!goOn) {
          await expectLater(h.controller.goOn('l'), throwsStateError);
        }
        if (!edit) {
          await expectLater(h.prepareEditor(), throwsStateError);
        }
        if (!regenerate) {
          await expectLater(h.controller.regenerate('l'), throwsStateError);
        }
        expect(h.session.requests, isEmpty);
      }
    },
  );

  test('Tick with a nonpositive round cannot replace the current source', () {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    for (final round in [0, -1]) {
      h.controller.observeMessages('l', [
        _formal(),
        _formal(type: 'tick', round: round, conversationType: ''),
      ]);
      expect(h.state.roundId, _round);
      expect(h.state.conversationType, 'user_message');
      expect(h.state.canGoOn, isTrue);
      expect(h.controller.stateForRound('l', round), isNull);
    }
  });

  test('only Tick can use a non-AI message as its action source', () {
    for (final type in ['user_enter_location', 'tick']) {
      final h = _Harness(conversationType: type);
      addTearDown(h.controller.dispose);
      h.controller.observeMessages('l', [
        _formal(type: type, conversationType: type),
      ]);
      h.controller.receiveEvent(
        ChatroomEndConversationRound(
          sessionId: '',
          worldId: 'w',
          locationId: 'l',
          userId: '',
          code: 0,
          codeMsg: '',
          ts: null,
          conversationType: type,
          triggerUid: 'u',
          conversationRoundId: '$_round',
        ),
      );
      expect(h.state.complete, isTrue);
      expect(h.state.supportsGoOn, type == 'tick', reason: type);
      expect(h.state.supportsEdit, isFalse, reason: type);
      expect(h.state.supportsInspiration, type == 'tick', reason: type);
      expect(h.state.inspirationSource != null, type == 'tick', reason: type);
    }
  });

  test(
    'Tick without AI or round-end can dispatch Go On and provide inspiration',
    () async {
      final h = _Harness(conversationType: '', triggerUid: '');
      addTearDown(h.controller.dispose);
      final tick = _formal(type: 'tick', conversationType: '', triggerUid: '');
      h.controller.observeMessages('l', [tick]);
      expect(h.state.formalReplyMessages, isEmpty);
      expect(h.state.complete, isTrue);
      expect(h.state.canGoOn, isTrue);
      expect(h.state.canRegenerate, isFalse);
      expect(h.state.canEdit, isFalse);
      final source = h.state.inspirationSource!;
      expect(source.roundId, _round);
      expect(source.tailMessageId, tick.locationMessageId);
      expect(source.cardId, isNull);
      await h.controller.finalizeBeforeSend('l', expectedSource: source);
      h.locked = true;
      expect(h.state.canGoOn, isFalse);
      expect(h.state.inspirationSource, isNull);
      h.locked = false;
      h.controller.observeMessages('l', [tick], activeRoundIds: {_round});
      expect(h.state.canGoOn, isFalse);
      expect(h.state.inspirationSource, isNull);
      h.controller.observeMessages('l', [tick]);
      h.session.goOnHandler = (request) async => ChatroomGoOnReceipt(
        worldId: 'w',
        locationId: 'l',
        clientMsgId: request,
        conversationRoundId: _round + 1,
        sourceConversationRoundId: _round,
      );
      await h.controller.goOn('l');
      expect(h.session.requests.single, startsWith('go-on:'));
      expect(h.api.calls, isEmpty);
    },
  );

  test(
    'world Tick end works without waiting and preserves generation failure',
    () {
      final h = _Harness(conversationType: 'tick', triggerUid: '');
      addTearDown(h.controller.dispose);
      ChatroomEndConversationRound end(
        String location, {
        int code = 0,
        int round = _round,
      }) => ChatroomEndConversationRound(
        sessionId: '',
        worldId: 'w',
        locationId: location,
        userId: '',
        code: code,
        codeMsg: '',
        ts: null,
        conversationRoundId: '$round',
      );
      h.controller.receiveEvent(end('', round: _round + 1));
      expect(h.controller.stateForRound('l', _round + 1), isNull);
      h.controller.receiveEvent(end(''));
      h.controller.receiveEvent(
        ChatroomWaitingConversationRound(
          sessionId: '',
          worldId: 'w',
          locationId: 'l',
          userId: '',
          code: 0,
          codeMsg: '',
          ts: null,
          conversationRoundId: '$_round',
        ),
      );
      expect(
        h.state.complete,
        isTrue,
        reason: 'A later waiting cannot reopen the ended Tick',
      );
      h.controller.receiveEvent(end('l', code: 5000));
      expect(h.state.supportsInspiration, isFalse);
      h.controller.receiveEvent(end(''));
      expect(h.state.supportsInspiration, isFalse);
      expect(h.controller.locationIds, ['l']);
    },
  );

  test('conflicting round metadata closes every reply action', () {
    final h = _Harness(conversationType: 'user_enter_location');
    addTearDown(h.controller.dispose);
    h.controller.observeMessages('l', [_formal(conversationType: 'tick')]);
    expect(h.state.supportsRegenerate, isFalse);
    expect(h.state.supportsGoOn, isFalse);
    expect(h.state.supportsEdit, isFalse);
    expect(h.state.supportsInspiration, isFalse);
    expect(h.state.inspirationSource, isNull);
  });

  test('canonical Tick does not invalidate its own completed reply', () {
    final h = _Harness(conversationType: 'tick', triggerUid: '');
    addTearDown(h.controller.dispose);
    h.controller.receiveEvent(
      ChatroomTickAdvanceMessage(
        sessionId: '',
        worldId: 'w',
        locationId: 'l',
        userId: '',
        code: 0,
        codeMsg: '',
        ts: null,
        messageId: _messageId + 1,
        globalMessageId: _messageId + 1,
        locationMessageId: _messageId + 1,
        conversationRoundId: '$_round',
        roundOrder: 0,
        senderType: 'tick',
        senderId: 'tick',
        senderName: '',
        content: '',
        broadcast: true,
        tickNo: 1,
        subTickNo: 0,
        currentTime: '',
      ),
    );
    expect(h.state.invalidatedByTick, isFalse);
    expect(h.state.canGoOn, isTrue);
    expect(h.state.canEdit, isFalse);
    expect(h.state.inspirationSource, isNotNull);
  });

  for (final entry in <(String, String, String)>[
    ('literal newline', r'A\nB', 'A\nB'),
    ('escaped backslash', r'A\\nB', r'A\nB'),
    ('real newline', 'A\nB', 'A\nB'),
    ('backslash before newline', 'A\\\nB', 'A\nB'),
    ('unicode and tab', r'\u4F60\tB', '你\tB'),
  ]) {
    for (final terminalFirst in [false, true]) {
      test(
        'candidate escape display survives completion: ${entry.$1}, terminalFirst=$terminalFirst',
        () async {
          final h = _Harness();
          addTearDown(h.controller.dispose);
          h.session.regenerateHandler = () async =>
              const ChatroomCardRegeneration(
                conversationRoundId: _round,
                originalCardId: 101,
                cardId: 102,
                generationState: ChatroomCardGenerationState.generating,
                billing: ChatroomCardBilling(
                  status: ChatroomCardBillingStatus.reserved,
                ),
              );
          // The original card can itself originate from a completed LLM stream.
          h.controller.observeMessages('l', [
            _formal().copyWith(content: entry.$2, isLlmStreamMessage: true),
          ]);
          await h.controller.regenerate('l');
          h.controller.receiveEvent(_stream('chunk', content: entry.$2));
          expect(
            locationChatMessageDisplayText(h.state.displayedMessages.single),
            entry.$3,
          );
          if (terminalFirst) h.controller.receiveEvent(_terminal('succeeded'));
          h.controller.receiveEvent(_stream('end', content: entry.$2));
          if (!terminalFirst) h.controller.receiveEvent(_terminal('succeeded'));
          await _settle();
          expect(h.state.displayedMessages.single.streaming, isFalse);
          expect(
            h.state.displayedMessages.single.content,
            entry.$2,
            reason:
                'Display decoding must not rewrite the submitted source text',
          );
          expect(
            locationChatMessageDisplayText(h.state.displayedMessages.single),
            entry.$3,
          );
          await h.controller.browse('l', -1);
          expect(
            locationChatMessageDisplayText(h.state.displayedMessages.single),
            entry.$3,
          );
          await h.controller.browse('l', 1);
          expect(
            locationChatMessageDisplayText(h.state.displayedMessages.single),
            entry.$3,
          );
          final editor = await h.controller.prepareEditor('l');
          expect(editor.messages.single.content, entry.$2);
          expect(
            locationChatMessageDisplayText(editor.messages.single),
            entry.$3,
          );
          expect(h.api.calls, isEmpty);
        },
      );
    }
  }

  test('HTTP card content retains ordinary server text semantics', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([_card(101, content: r'A\nB')]);
    await h.controller.restoreLocationCards('l');
    final message = h.state.messagesForCard(101).first;
    expect(message.isLlmStreamMessage, isFalse);
    expect(locationChatMessageDisplayText(message), r'A\nB');
  });

  test(
    'regeneration and editing use local cards without GET before ACK or after terminal',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      await h.controller.restoreLocationCards('l');
      h.api.calls.clear();
      final ack = Completer<ChatroomCardRegeneration>();
      h.session.regenerateHandler = () => ack.future;
      final action = h.controller.regenerate('l');
      await _settle();
      expect(h.api.calls, isEmpty);
      expect(h.state.cardPosition, 2);
      expect(h.state.displayedMessages, isEmpty);
      expect(h.state.canSwitchCards, isFalse);
      await h.controller.browse('l', -1);
      expect(h.state.displayedMessages, isEmpty);
      ack.complete(
        const ChatroomCardRegeneration(
          conversationRoundId: _round,
          originalCardId: 101,
          cardId: 102,
          generationState: ChatroomCardGenerationState.generating,
          billing: ChatroomCardBilling(
            status: ChatroomCardBillingStatus.reserved,
          ),
        ),
      );
      await action;
      expect(h.state.viewedCardId, 102);
      expect(h.state.canSwitchCards, isFalse);
      expect(h.state.cards.first.messages.single.content, 'Original');
      expect(h.state.cards.first.isOriginal, isTrue);
      h.controller.receiveEvent(_stream('chunk', content: 'partial'));
      expect(h.state.canSwitchCards, isFalse);
      h.controller.receiveEvent(
        _stream('end', content: 'Complete local reply'),
      );
      h.controller.receiveEvent(_terminal('succeeded'));
      await _settle();
      expect(h.state.canSwitchCards, isTrue);
      await h.controller.browse('l', -1);
      expect(h.state.viewedCardId, 101);
      await h.controller.browse('l', 1);
      final editor = await h.controller.prepareEditor('l');
      expect(editor.cardId, 102);
      expect(editor.messages.single.content, 'Complete local reply');
      expect(editor.messages.single.globalMessageId, _messageId);
      expect(h.state.canEdit, isTrue);
      expect(h.api.calls, isEmpty);
    },
  );

  test(
    'regeneration without a stream start recovers from authoritative cards',
    () async {
      final h = _Harness(
        regenerationStreamStartTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      h.api.calls.clear();
      h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
        conversationRoundId: _round,
        originalCardId: 101,
        cardId: 102,
        generationState: ChatroomCardGenerationState.generating,
        billing: ChatroomCardBilling(
          status: ChatroomCardBillingStatus.reserved,
        ),
      );
      await h.controller.regenerate('l');
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, content: 'Recovered candidate'),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _settle();

      expect(h.api.calls, ['cards:$_round']);
      expect(h.state.generating, isFalse);
      expect(h.state.displayedMessages.first.content, 'Recovered candidate');
      expect(h.session.requests, hasLength(1));
    },
  );

  test(
    'regeneration without a message stream end recovers after the end timeout',
    () async {
      final h = _Harness(
        regenerationStreamEndTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      h.api.calls.clear();
      h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
        conversationRoundId: _round,
        originalCardId: 101,
        cardId: 102,
        generationState: ChatroomCardGenerationState.generating,
        billing: ChatroomCardBilling(
          status: ChatroomCardBillingStatus.reserved,
        ),
      );
      await h.controller.regenerate('l');
      h.controller.receiveEvent(_stream('start'));
      h.controller.receiveEvent(_stream('chunk', content: 'Partial'));
      h.controller.receiveEvent(_terminal('succeeded'));
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, content: 'Recovered after lost end'),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _settle();

      expect(h.api.calls, ['cards:$_round']);
      expect(h.state.generating, isFalse);
      expect(
        h.state.displayedMessages.first.content,
        'Recovered after lost end',
      );
      expect(h.session.requests, hasLength(1));
    },
  );

  test(
    'regeneration recovery failure marks the candidate failed and unlocks retry',
    () async {
      final h = _Harness(
        regenerationStreamStartTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      h.api.calls.clear();
      h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
        conversationRoundId: _round,
        originalCardId: 101,
        cardId: 102,
        generationState: ChatroomCardGenerationState.generating,
        billing: ChatroomCardBilling(
          status: ChatroomCardBillingStatus.reserved,
        ),
      );
      await h.controller.regenerate('l');
      h.api.cardsError = ApiException(
        message: 'Request failed',
        kind: ApiExceptionKind.timeout,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _settle();

      expect(h.api.calls, ['cards:$_round']);
      expect(h.session.requests, hasLength(1));
      expect(h.state.generating, isFalse);
      expect(h.state.canRegenerate, isTrue);
      expect(
        h.state.viewedCard!.generationState,
        ChatroomCardGenerationState.failed,
      );
      expect(h.state.error, isA<ApiException>());
    },
  );

  test(
    'regeneration ACK loss stays locked until cards prove a terminal',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.controller.restoreLocationCards('l');
      h.api.calls.clear();
      h.session.regenerateHandler = () async =>
          throw TimeoutException('lost ACK');

      await expectLater(
        h.controller.regenerate('l'),
        throwsA(isA<TimeoutException>()),
      );

      expect(h.api.calls, ['cards:$_round']);
      expect(h.session.requests, hasLength(1));
      expect(h.state.generating, isTrue);
      expect(h.state.canSwitchCards, isFalse);
      expect(h.state.canRegenerate, isFalse);
      expect(h.state.supportsGoOn, isTrue);
      expect(h.state.supportsEdit, isTrue);
      expect(h.state.supportsInspiration, isTrue);
      expect(h.state.viewedCardId, -1);

      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      h.api.calls.clear();
      await h.controller.reconnect();
      expect(h.api.calls, ['cards:$_round']);
      expect(h.state.generating, isFalse);
      expect(h.state.canSwitchCards, isTrue);
      expect(h.state.viewedCardId, 102);
    },
  );

  test(
    'entry discovers the latest own card group without saved metadata',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      expect(h.state.hasCardGroup, isFalse);
      await h.controller.restoreLocationCards('l');
      expect(h.state.cardCount, 2);
      expect(h.api.calls, ['cards:$_round']);
      h.api.calls.clear();
      await h.controller.prepareEditor('l');
      expect(h.api.calls, isEmpty);
    },
  );

  test(
    'card history follows validity while each editor keeps its own snapshot',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.ready = false;
      var current = true;
      final oldResponse = Completer<ChatroomLlmCardsResponse>();
      h.api.cardsBarrier = oldResponse;
      final oldRead = h.controller.loadHistoryCards(
        'l',
        roundIds: {_round},
        isCurrent: () => current,
      );
      await _settle();
      expect(h.api.calls, ['cards:$_round']);
      current = false;
      oldResponse.complete(_cards([_card(101)]));
      await oldRead;
      expect(h.state.hasCardGroup, isFalse);
      h.ready = true;
      current = true;
      final beforeEdit = Completer<ChatroomLlmCardsResponse>();
      h.api.cardsBarrier = beforeEdit;
      final pendingRead = h.controller.loadHistoryCards(
        'l',
        roundIds: {_round},
        isCurrent: () => current,
      );
      await _settle();
      final editor = await h.controller.prepareEditor('l');
      beforeEdit.complete(_cards([_card(101, content: 'Old server body')]));
      await pendingRead;
      expect(editor.messages.single.content, 'Original');
      expect(h.state.hasCardGroup, isFalse);
      h.api.calls.clear();
      await h.controller.loadHistoryCards(
        'l',
        roundIds: {_round},
        isCurrent: () => current,
      );
      expect(h.api.calls, ['cards:$_round']);
      expect(editor.messages.single.content, 'Original');
    },
  );

  test('entry skips other users and inactive locations', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.ready = false;
    await h.controller.restoreLocationCards('l');
    expect(h.api.calls, isEmpty);
    h.ready = true;
    h.controller.observeMessages('l', [_formal(user: 'another-user')]);
    await h.controller.restoreLocationCards('l');
    expect(h.api.calls, isEmpty);
  });

  test(
    'terminal before the last content end waits and completes locally',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
        conversationRoundId: _round,
        originalCardId: 101,
        cardId: 102,
        generationState: ChatroomCardGenerationState.generating,
        billing: ChatroomCardBilling(
          status: ChatroomCardBillingStatus.reserved,
        ),
      );
      await h.controller.regenerate('l');
      h.controller.receiveEvent(_stream('chunk', content: 'Partial'));
      h.controller.receiveEvent(_terminal('succeeded'));
      await _settle();
      expect(h.state.canEdit, isFalse);
      expect(h.state.error, isNotNull);
      expect(h.state.displayedMessages.single.content, 'Partial');
      h.controller.receiveEvent(_stream('end', content: 'Final reply'));
      await _settle();
      expect(h.state.canEdit, isTrue);
      expect(h.state.error, isNull);
      expect(h.state.displayedMessages.single.content, 'Final reply');
      h.controller.receiveEvent(_terminal('succeeded'));
      await _settle();
      expect(h.walletRefreshes, 1);
      expect(h.api.calls, isEmpty);
    },
  );

  test('can_regenerate=false does not prevent local dispatch', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([], canRegenerate: false);
    await h.controller.restoreLocationCards('l');
    h.api.calls.clear();
    h.session.regenerateHandler = () async => const ChatroomCardRegeneration(
      conversationRoundId: _round,
      originalCardId: 101,
      cardId: 102,
      generationState: ChatroomCardGenerationState.generating,
      billing: ChatroomCardBilling(status: ChatroomCardBillingStatus.reserved),
    );

    expect(h.state.canRegenerate, isTrue);
    await h.controller.regenerate('l');

    expect(h.state.showCandidates, isTrue);
    expect(h.session.requests, hasLength(1));
    expect(h.api.calls, isEmpty);
  });

  test('card can_edit and can_delete flags do not restrict editing', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([_card(101, canEdit: false, canDelete: false)]);
    await h.controller.restoreLocationCards('l');

    expect(h.state.canEdit, isTrue);
    final target = await h.controller.prepareEditor('l');
    await h.controller.submitEdit(target, const [
      ChatroomLlmMessageOperation.edit(
        globalMessageId: _messageId,
        content: 'Edited despite API flag',
      ),
      ChatroomLlmMessageOperation.delete(globalMessageId: _messageId + 1),
    ]);

    expect(h.api.calls, contains('batch-card:101'));
    expect(h.state.viewedCard!.messages, hasLength(1));
    expect(
      h.state.viewedCard!.messages.single.content,
      'Edited despite API flag',
    );
  });

  test(
    'candidate chunks dedupe seq, sort fixed indices, end replaces text, and browsing survives terminal',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      await h.prepareEditor();
      final ack = Completer<ChatroomCardRegeneration>();
      h.session.regenerateHandler = () => ack.future;
      final action = h.controller.regenerate('l');
      await _settle();
      h.controller.receiveEvent(_stream('chunk', seq: 2, content: 'B'));
      h.controller.receiveEvent(_stream('chunk', seq: 1, content: 'A'));
      h.controller.receiveEvent(_stream('chunk', seq: 2, content: 'duplicate'));
      final revision = h.state.presentationRevision;
      expect(h.state.displayedMessages.single.content, 'AB');
      h.controller.receiveEvent(_stream('end', content: 'Full'));
      h.controller.receiveEvent(_stream('chunk', seq: 3, content: 'late'));
      h.controller.receiveEvent(
        _stream('end', content: 'Second', id: _messageId + 1),
      );
      expect(h.state.displayedMessages.map((m) => m.content), [
        'Full',
        'Second',
      ]);
      expect(
        h.state.displayedMessages.every((m) => m.locationMessageId == 0),
        isTrue,
      );
      expect(h.state.presentationRevision, revision);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      ack.complete(
        const ChatroomCardRegeneration(
          conversationRoundId: _round,
          originalCardId: 101,
          cardId: 102,
          generationState: ChatroomCardGenerationState.generating,
          billing: ChatroomCardBilling(
            status: ChatroomCardBillingStatus.reserved,
          ),
        ),
      );
      await action;
      expect(h.state.canSwitchCards, isFalse);
      await h.controller.browse('l', -1);
      expect(h.state.viewedCardId, 102);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, content: 'Saved candidate'),
      ]);
      h.controller.receiveEvent(_terminal('succeeded'));
      await _settle();
      expect(h.state.canSwitchCards, isTrue);
      expect(h.state.viewedCardId, 102);
      expect(h.walletRefreshes, 1);
      await h.controller.browse('l', -1);
      await h.controller.browse('l', 1);
      expect(h.state.displayedMessages.first.content, 'Full');
      h.controller.receiveEvent(_stream('end', content: 'stale'));
      expect(h.state.displayedMessages.first.content, 'Full');
    },
  );

  test(
    'candidate save stays private and blank intermediate drafts persist but cannot submit',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      final target = await h.prepareEditor();
      const blank = [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: '',
        ),
      ];
      await h.controller.setDraft(target, blank);
      expect(
        (await storage.load(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
        )).single['drafts'],
        isNotEmpty,
      );
      await expectLater(h.controller.save(target, blank), throwsArgumentError);
      const edit = [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: '  saved\n@name  ',
        ),
      ];
      await h.controller.save(target, edit);
      expect(h.state.displayedMessages.first.content, '  saved\n@name  ');
      expect(h.api.calls.where((c) => c.startsWith('refresh:')), isEmpty);
      expect(h.state.confirmed, isFalse);
      expect(target.draftOperations, isEmpty);
      await expectLater(
        h.controller.submitEdit(await h.prepareEditor(), const [
          ChatroomLlmMessageOperation.delete(globalMessageId: _messageId),
          ChatroomLlmMessageOperation.delete(globalMessageId: _messageId + 1),
        ]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'At least one message must remain.',
          ),
        ),
      );
      expect(h.api.calls.where((call) => call == 'batch-card:101').length, 1);
    },
  );

  test(
    'formal saves omit card path and an unchanged editor does not send a batch',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final target = await h.prepareEditor();
      expect(target.cardId, isNull);
      await h.controller.save(target, []);
      expect(h.api.calls.contains('batch-formal'), isFalse);
      await h.controller.save(target, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'changed',
        ),
      ]);
      expect(h.api.calls.contains('batch-formal'), isTrue);
      expect(h.state.formalReplyMessages.single.content, 'Original');
    },
  );

  test(
    'isolated editor submissions can overlap and never refresh history',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final first = await h.prepareEditor();
      final second = await h.prepareEditor();
      final barrier = Completer<void>();
      h.api.saveBarrier = barrier;
      final firstSave = h.controller.submitEdit(first, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'First edit',
        ),
      ]);
      final secondSave = h.controller.submitEdit(second, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Second edit',
        ),
      ]);
      await _settle();
      expect(h.api.calls.where((call) => call == 'batch-formal').length, 2);
      expect(h.api.calls.where((call) => call.startsWith('refresh:')), isEmpty);
      barrier.complete();
      await Future.wait([firstSave, secondSave]);
      expect(h.api.calls.where((call) => call.startsWith('refresh:')), isEmpty);
    },
  );

  test(
    'isolated formal edit waits for conversation range history update',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final target = await h.prepareEditor();
      const operations = [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Optimistic edit',
        ),
      ];

      await h.controller.submitEdit(target, operations);

      expect(h.api.calls, contains('batch-formal'));
      expect(h.state.formalReplyMessages.single.content, 'Original');
    },
  );

  test(
    'unknown delete is reconciled with GET without resending an applied batch',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      final target = await h.prepareEditor();
      h.api.batchError = TimeoutException('lost response');
      h.api.applyBeforeError = true;
      const changes = [
        ChatroomLlmMessageOperation.delete(globalMessageId: _messageId),
      ];
      await expectLater(
        h.controller.save(target, changes),
        throwsA(isA<TimeoutException>()),
      );
      h.api.batchError = null;
      await h.controller.save(target, changes);
      expect(h.api.calls.where((c) => c == 'batch-card:101').length, 1);
      expect(target.draftOperations, isEmpty);
    },
  );

  test(
    'send preparation saves and selects without refreshing formal history',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101, messages: 1),
        _card(102, index: 2, content: 'New', messages: 1),
      ]);
      await h.prepareEditor();
      await h.controller.browse('l', 1);
      final target = await h.prepareEditor();
      await h.controller.setDraft(target, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Draft',
        ),
      ]);
      h.api.calls.clear();
      await h.controller.finalizeBeforeSend('l');
      expect(h.api.calls, ['cards:$_round', 'batch-card:102', 'select:102']);
      expect(h.state.confirmed, isTrue);
      expect(h.state.showCandidates, isFalse);
      expect(h.state.showCardPresentation, isTrue);
      expect(h.state.displayedMessages.single.content, 'Draft');

      final revision = h.state.presentationRevision;
      h.controller.observeMessages('l', [_formal(content: 'Draft')]);
      expect(h.state.showCardPresentation, isTrue);
      expect(h.state.displayedMessages.single.content, 'Draft');
      expect(h.state.presentationRevision, revision);

      h.controller.observeMessages('l', [_formal(content: 'Later edit')]);
      expect(h.state.showCardPresentation, isTrue);
      expect(h.state.displayedMessages.single.content, 'Later edit');
    },
  );

  test(
    'accepted Go On keeps the selected source card as presentation state',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101, messages: 1),
        _card(102, index: 2, content: 'New', messages: 1),
      ]);
      await h.controller.restoreLocationCards('l');
      await h.controller.browse('l', 1);
      final ack = Completer<ChatroomGoOnReceipt>();
      h.session.goOnHandler = (_) => ack.future;

      final goOn = h.controller.goOn('l');
      await _settle();
      expect(h.state.confirmed, isTrue);
      expect(h.controller.presentationStateFor('l'), same(h.state));
      expect(h.state.displayedMessages.single.content, 'New');

      ack.complete(
        const ChatroomGoOnReceipt(
          worldId: 'w',
          locationId: 'l',
          sourceConversationRoundId: _round,
          conversationRoundId: _round + 1,
          clientMsgId: 'go-on-test',
        ),
      );
      await goOn;
      expect(h.controller.stateFor('l')!.roundId, _round + 1);
      expect(h.controller.presentationStateFor('l'), same(h.state));
      expect(
        h.controller
            .presentationStateFor('l')!
            .displayedMessages
            .single
            .content,
        'New',
      );

      h.controller.observeMessages('l', [
        _formal(
          round: _round + 1,
          id: _messageId + 20,
          conversationType: 'go_on',
          content: 'Continued',
        ),
      ]);
      await _settle();
      expect(h.state.goOnPending, isFalse);
      expect(h.controller.presentationStateFor('l')!.roundId, _round + 1);
    },
  );

  test('preflight card refresh retains the fixed viewed card', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    final original = _card(101, messages: 1);
    final selected = _card(102, index: 2, content: 'New', messages: 1);
    h.api.cards = _cards([original, selected]);
    await h.controller.restoreLocationCards('l');
    await h.controller.browse('l', 1);
    h.api.cards = _cards([original]);

    await h.controller.finalizeBeforeSend('l');

    expect(h.state.selectedCardId, 102);
    expect(h.state.viewedCardId, 102);
    expect(h.state.displayedMessages.single.content, 'New');
  });

  test(
    'can_confirm=false does not prevent selecting a complete card',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)], canConfirm: false);
      await h.controller.restoreLocationCards('l');
      h.api.calls.clear();

      await h.controller.finalizeBeforeSend('l');

      expect(h.api.calls, ['cards:$_round', 'select:101']);
      expect(h.state.confirmed, isTrue);
    },
  );

  test(
    'an external next round freezes an open editor and saves its current draft',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      final target = await h.prepareEditor();
      await h.controller.setDraft(target, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Open draft',
        ),
      ]);
      await h.controller.browse('l', 1);
      final event = ChatroomUserMessage.fromV2Message(
        _v2('user', round: _round + 1, id: _messageId + 20, user: 'another'),
      );
      h.controller.receiveEvent(event);
      expect(target.frozen, isTrue);
      await _settle();
      expect(h.api.calls.contains('batch-card:101'), isTrue);
      expect(h.api.calls.contains('select:101'), isTrue);
      expect(h.state.confirmed, isTrue);
      final before = h.api.calls.length;
      h.controller.receiveEvent(event);
      await _settle();
      expect(h.api.calls.length, before);
    },
  );

  test(
    'Go On ACK loss stays locked across refresh and reconnect without resending',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      h.session.goOnHandler = (_) async => throw TimeoutException('lost ACK');
      await expectLater(
        h.controller.goOn('l'),
        throwsA(isA<TimeoutException>()),
      );
      expect(h.state.goOnUnknown, isTrue);
      expect(h.state.goOnPending, isTrue);
      expect(h.state.canGoOn, isFalse);
      await h.controller.reconnect();
      expect(h.session.requests.length, 1);
      expect(h.state.goOnUnknown, isTrue);
      expect(h.state.goOnPending, isTrue);
      final saved = await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      );
      expect(saved.single['go_on'], isNotNull);
      h.controller.dispose();
      await _settle();
      final restored = _Harness(storage: storage);
      addTearDown(restored.controller.dispose);
      await restored.controller.restoreLocationCards('l');
      expect(restored.state.goOnUnknown, isTrue);
      expect(restored.state.goOnPending, isTrue);
      expect(restored.session.requests, isEmpty);
      final other = _Harness(storage: storage, owner: 'another');
      addTearDown(other.controller.dispose);
      await other.controller.restore('l');
      expect(other.state.goOnUnknown, isFalse);
    },
  );

  test('Go On rejected ACK unlocks retry', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.session.goOnHandler = (_) async => throw const ChatroomFailureEvent(
      code: '2015',
      message: 'source expired',
      requestType: 'go_on',
    );
    await expectLater(
      h.controller.goOn('l'),
      throwsA(isA<ChatroomFailureEvent>()),
    );
    expect(h.state.goOnPending, isFalse);
  });

  test(
    'Go On end before ACK is restored by new round, with no user echo required',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.session.goOnHandler = (request) async {
        h.controller.receiveEvent(
          ChatroomWaitingConversationRound.fromV2Message(
            _v2('waiting_conversation_round', round: _round + 1),
          ),
        );
        h.controller.receiveEvent(
          ChatroomEndConversationRound.fromV2Message(
            _v2('end_conversation_round', round: _round + 1),
          ),
        );
        h.controller.observeMessages('l', [
          _formal(round: _round + 1).copyWith(content: 'Continued'),
        ]);
        return ChatroomGoOnReceipt(
          worldId: 'w',
          locationId: 'l',
          sourceConversationRoundId: _round,
          conversationRoundId: _round + 1,
          clientMsgId: request,
        );
      };
      await h.controller.goOn('l');
      expect(h.controller.stateFor('l')!.roundId, _round + 1);
      expect(
        h.controller.stateFor('l')!.displayedMessages.single.content,
        'Continued',
      );
      expect(h.state.goOnPending, isFalse);
      expect(h.session.requests.length, 1);
      expect(h.api.calls.where((call) => call.startsWith('refresh:')), isEmpty);
    },
  );

  test('save failures preserve draft and stop Go On before sending', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([_card(101)]);
    final target = await h.prepareEditor();
    await h.controller.setDraft(target, const [
      ChatroomLlmMessageOperation.edit(
        globalMessageId: _messageId,
        content: 'Draft',
      ),
    ]);
    h.api.batchError = ApiException(
      message: 'no',
      kind: ApiExceptionKind.business,
    );
    await expectLater(h.controller.goOn('l'), throwsA(isA<ApiException>()));
    expect(h.session.requests, isEmpty);
    expect(target.draftOperations, isNotEmpty);
    expect(h.state.error, isNotNull);
  });
  test(
    'accepted Go On recovers atomic persisted AI history even if round end was lost',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final ack = Completer<ChatroomGoOnReceipt>();
      h.session.goOnHandler = (request) => ack.future;
      final run = h.controller.goOn('l');
      await _settle();
      expect(h.state.goOnPending, isTrue);
      expect(h.state.goOnUnknown, isFalse);
      ack.complete(
        const ChatroomGoOnReceipt(
          worldId: 'w',
          locationId: 'l',
          sourceConversationRoundId: _round,
          conversationRoundId: _round + 1,
          clientMsgId: 'test',
        ),
      );
      await run;
      h.controller.observeMessages('l', [
        _formal(round: _round + 1, type: 'user'),
      ]);
      await _settle();
      expect(h.state.goOnPending, isTrue);
      expect(h.session.requests.length, 1);
      h.controller.observeMessages('l', [_formal(round: _round + 1)]);
      await _settle();
      expect(h.state.goOnPending, isFalse);
    },
  );

  test(
    'accepted Go On without a stream start times out without a history read',
    () async {
      final h = _Harness(
        goOnStreamStartTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.controller.dispose);
      h.session.goOnHandler = (request) async => ChatroomGoOnReceipt(
        worldId: 'w',
        locationId: 'l',
        sourceConversationRoundId: _round,
        conversationRoundId: _round + 1,
        clientMsgId: request,
      );

      await h.controller.goOn('l');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _settle();

      expect(h.api.calls, isNot(contains('history:${_round + 1}')));
      expect(h.session.requests, hasLength(1));
      expect(h.state.goOnPending, isFalse);
      expect(h.controller.stateFor('l')!.roundId, _round);
      expect(h.state.canGoOn, isTrue);
      expect(h.state.error.toString(), contains('did not start'));
    },
  );

  test(
    'accepted Go On stream without an end times out without a history read',
    () async {
      final h = _Harness(
        goOnStreamStartTimeout: const Duration(seconds: 1),
        goOnStreamEndTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.controller.dispose);
      h.session.goOnHandler = (request) async => ChatroomGoOnReceipt(
        worldId: 'w',
        locationId: 'l',
        sourceConversationRoundId: _round,
        conversationRoundId: _round + 1,
        clientMsgId: request,
      );
      await h.controller.goOn('l');
      h.controller.receiveEvent(
        ChatroomAiStreamStart.fromV2Message(
          ChatroomV2Message(
            type: 'character',
            streamType: 'llm_stream_start',
            worldId: 'w',
            locationId: 'l',
            userId: 'u',
            conversationRoundId: _round + 1,
            globalMessageId: _messageId + 100,
            senderType: 'character',
            senderId: 'character-id',
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _settle();

      expect(h.api.calls, isNot(contains('history:${_round + 1}')));
      expect(h.session.requests, hasLength(1));
      expect(h.state.goOnPending, isFalse);
      expect(h.controller.stateFor('l')!.roundId, _round);
      expect(h.state.canGoOn, isTrue);
      expect(h.state.error.toString(), contains('did not finish'));
    },
  );

  test(
    'completed Go On without range content waits then times out and unlocks',
    () async {
      final h = _Harness(
        goOnStreamStartTimeout: const Duration(seconds: 1),
        goOnStreamEndTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(h.controller.dispose);
      h.session.goOnHandler = (request) async => ChatroomGoOnReceipt(
        worldId: 'w',
        locationId: 'l',
        sourceConversationRoundId: _round,
        conversationRoundId: _round + 1,
        clientMsgId: request,
      );
      await h.controller.goOn('l');
      h.controller.observeMessages(
        'l',
        [_formal(), _formal(round: _round + 1).copyWith(streaming: true)],
        activeRoundIds: {_round + 1},
      );
      h.controller.receiveEvent(
        ChatroomEndConversationRound.fromV2Message(
          _v2('end_conversation_round', round: _round + 1),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _settle();
      expect(h.controller.stateFor('l')!.roundId, _round);
      expect(h.controller.stateFor('l')!.displayedMessages, isNotEmpty);
      expect(h.state.goOnPending, isFalse);
      expect(h.state.canGoOn, isTrue);
      expect(h.state.error, isNotNull);
    },
  );

  test(
    'Go On round errors immediately restore the source and unlock',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.session.goOnHandler = (request) async => ChatroomGoOnReceipt(
        worldId: 'w',
        locationId: 'l',
        sourceConversationRoundId: _round,
        conversationRoundId: _round + 1,
        clientMsgId: request,
      );
      await h.controller.goOn('l');

      h.controller.receiveEvent(
        ChatroomErrorEvent(
          code: '5000',
          message: 'Generation failed',
          worldId: 'w',
          locationId: 'l',
          conversationRoundId: '${_round + 1}',
        ),
      );
      await _settle();

      expect(h.state.goOnPending, isFalse);
      expect(h.controller.stateFor('l')!.roundId, _round);
      expect(h.state.canGoOn, isTrue);
      expect(h.state.error, isA<ChatroomErrorEvent>());
    },
  );

  test(
    'a zero-change formal editor remains independent of a new AI round',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final editor = await h.prepareEditor();
      h.controller.receiveEvent(
        ChatroomAiStreamStart.fromV2Message(
          ChatroomV2Message(
            type: 'character',
            streamType: 'llm_stream_start',
            worldId: 'w',
            locationId: 'l',
            conversationRoundId: _round + 1,
            globalMessageId: _messageId + 30,
            messageId: _messageId + 30,
            locationMessageId: _messageId + 30,
            senderType: 'character',
          ),
        ),
      );
      expect(editor.frozen, isFalse);
      await _settle();
      expect(editor.editorShouldClose, isFalse);
      expect(h.api.calls.any((call) => call.startsWith('batch-')), isFalse);
    },
  );

  test(
    'a confirmed formal editor saves on external next round and does not reselect',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)], confirmed: true, selected: 101);
      final editor = await h.prepareEditor();
      expect(editor.cardId, isNull);
      await h.controller.setDraft(editor, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Formal draft',
        ),
      ]);
      h.controller.receiveEvent(
        ChatroomUserMessage.fromV2Message(
          _v2('user', round: _round + 1, id: _messageId + 40, user: 'other'),
        ),
      );
      expect(editor.frozen, isTrue);
      await _settle();
      expect(h.api.calls.contains('batch-formal'), isTrue);
      expect(editor.editorShouldClose, isTrue);
      expect(h.api.calls.any((call) => call.startsWith('select:')), isFalse);
    },
  );

  test(
    'missing metadata stays disabled until history supplies both fields',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final controller = ChatroomReplyActionsController(
        worldId: 'w',
        ownerUid: 'u',
        httpApi: h.api,
        session: () => h.session,
        isReady: (_) => true,
        isTickLocked: () => false,
        storage: MemoryChatroomReplyActionStorage(),
      );
      addTearDown(controller.dispose);
      controller.observeMessages('l', [
        _formal(user: 'u', conversationType: '', triggerUid: 'u'),
      ]);
      await _settle();
      expect(controller.stateFor('l')!.isOwnRound, isTrue);
      expect(controller.stateFor('l')!.canGoOn, isFalse);
      expect(h.api.calls.where((call) => call.startsWith('history:')), isEmpty);
      controller.observeMessages('l', [
        _formal(user: '', conversationType: 'user_message', triggerUid: 'u'),
      ]);
      await _settle();
      expect(controller.stateFor('l')!.canGoOn, isTrue);
      expect(h.api.calls.where((call) => call.startsWith('history:')), isEmpty);
    },
  );

  test(
    'a timed out delete reconciles after app restart without deleting again',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      h.api.cards = _cards([_card(101)]);
      final target = await h.prepareEditor();
      h.api.batchError = TimeoutException('lost');
      h.api.applyBeforeError = true;
      const changes = [
        ChatroomLlmMessageOperation.delete(globalMessageId: _messageId),
      ];
      await expectLater(
        h.controller.save(target, changes),
        throwsA(isA<TimeoutException>()),
      );
      h.controller.dispose();
      await _settle();
      final second = _Harness(storage: storage);
      addTearDown(second.controller.dispose);
      second.api.cards = h.api.cards;
      await second.controller.restoreLocationCards('l');
      await second.controller.finalizeBeforeSend('l');
      expect(
        second.api.calls.where((call) => call.startsWith('batch-')),
        isEmpty,
      );
      expect(second.state.confirmed, isTrue);
    },
  );
  test(
    'a query started during save cannot replace its committed content',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      final target = await h.prepareEditor();
      final old = h.api.cards;
      final saving = Completer<void>();
      h.api.saveBarrier = saving;
      final save = h.controller.save(target, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Newest',
        ),
      ]);
      await _settle();
      final query = Completer<ChatroomLlmCardsResponse>();
      h.api.cardsBarrier = query;
      final restoring = h.controller.restoreLocationCards('l');
      await _settle();
      saving.complete();
      await save;
      query.complete(old);
      await restoring;
      expect(h.state.displayedMessages.first.content, 'Newest');
    },
  );

  test(
    'generation failure retains err_no and err_msg for the global presenter',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      await h.prepareEditor();
      final event = _terminal(
        'failed',
        errNo: 2023,
        errMsg: 'Server generation message',
        error: {'code': 'internal', 'message': 'Diagnostic details'},
      );
      h.controller.receiveEvent(event);
      expect(h.state.error, same(event));
    },
  );

  test(
    'failed candidate retains its page and never exposes uncommitted text',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'generating'),
      ]);
      await h.prepareEditor();
      await h.controller.browse('l', 1);
      expect(h.state.viewedCardId, 101);
      h.controller.receiveEvent(_stream('chunk', content: 'Must disappear'));
      expect(
        h.state.displayedMessages.first.content,
        'Original',
        reason: 'Generating cards cannot be opened by browsing.',
      );
      h.api.cards = _cards([
        _card(101),
        _card(102, index: 2, generation: 'failed'),
      ]);
      h.controller.receiveEvent(_terminal('failed'));
      await _settle();
      expect(h.state.canSwitchCards, isTrue);
      await h.controller.browse('l', 1);
      expect(h.state.displayedMessages, isEmpty);
      expect(h.state.cardCount, 2);
      expect(h.state.cardPosition, 2);
      expect(h.state.canEdit, isFalse);
      await h.controller.browse('l', -1);
      expect(h.state.canEdit, isTrue);
    },
  );

  test(
    'only a newer world Tick fixes the card; old Tick replay cannot freeze an editor',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.controller.observeMessages('l', [
        _formal(),
        _formal(
          type: 'tick',
          round: _round - 1,
          id: _messageId - 1,
          conversationType: '',
        ).copyWith(tickNo: 10, subTickNo: 1),
      ]);
      h.api.cards = _cards([_card(101)]);
      final target = await h.prepareEditor();
      ChatroomTickAdvanceMessage tick(int number) => ChatroomTickAdvanceMessage(
        sessionId: '',
        worldId: 'w',
        locationId: 'l',
        userId: '',
        code: 0,
        codeMsg: '',
        ts: null,
        messageId: number,
        globalMessageId: number,
        locationMessageId: number,
        conversationRoundId: '${_round + 1}',
        roundOrder: 0,
        senderType: 'tick',
        senderId: 'tick',
        senderName: '',
        content: '',
        broadcast: true,
        tickNo: number,
        subTickNo: 1,
        currentTime: '',
      );
      h.controller.receiveEvent(tick(9));
      await _settle();
      expect(target.frozen, isFalse);
      expect(target.editorShouldClose, isFalse);
      h.controller.receiveEvent(tick(11));
      expect(target.frozen, isTrue);
      await _settle();
      expect(target.editorShouldClose, isTrue);
      expect(h.api.calls.where((call) => call.startsWith('select:')).length, 1);
    },
  );

  test(
    'draft persistence includes only changed message baselines and empty save removes them',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101)]);
      final target = await h.prepareEditor();
      await h.controller.setDraft(target, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Draft',
        ),
      ]);
      var saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect((saved['draft_baselines'] as Map)['101'], {
        '$_messageId': 'Original',
      });
      await h.controller.save(target, []);
      saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect(saved['draft_baselines'], isEmpty);
      expect(saved['drafts'], isEmpty);
      expect(h.api.calls.any((call) => call.startsWith('batch-')), isFalse);
    },
  );

  test(
    'a save response after controller disposal cannot notify the old page',
    () async {
      final h = _Harness();
      h.api.cards = _cards([_card(101)]);
      final target = await h.prepareEditor();
      final barrier = Completer<void>();
      h.api.saveBarrier = barrier;
      var updates = 0;
      h.controller.addListener(() => updates++);
      final save = h.controller.save(target, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Draft',
        ),
      ]);
      final failure = expectLater(save, throwsStateError);
      await _settle();
      h.controller.dispose();
      final before = updates;
      barrier.complete();
      await failure;
      expect(updates, before);
    },
  );
  test(
    'documented infrastructure error ACKs unlock without resending',
    () async {
      for (final code in [2002, 2003, 2004, 5000, 5001, 5002]) {
        final h = _Harness();
        h.session.goOnHandler = (_) async => throw ChatroomFailureEvent(
          code: '$code',
          message: 'infrastructure error',
          requestType: 'go_on',
        );
        await expectLater(
          h.controller.goOn('l'),
          throwsA(isA<ChatroomFailureEvent>()),
        );
        expect(h.state.goOnUnknown, isFalse, reason: 'err_no=$code');
        expect(h.state.goOnPending, isFalse, reason: 'err_no=$code');
        await h.controller.reconnect();
        expect(h.session.requests.length, 1);
        h.controller.dispose();
      }
    },
  );

  test(
    'source expired ACK restores the previous source without refreshing',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      final controller = ChatroomReplyActionsController(
        worldId: 'w',
        ownerUid: 'u',
        httpApi: h.api,
        session: () => h.session,
        isReady: (_) => true,
        isTickLocked: () => false,
        storage: MemoryChatroomReplyActionStorage(),
      );
      addTearDown(controller.dispose);
      controller.observeMessages('l', [_formal()]);
      h.session.goOnHandler = (_) async => throw const ChatroomFailureEvent(
        code: '2015',
        message: 'source expired',
        requestType: 'go_on',
      );
      await expectLater(
        controller.goOn('l'),
        throwsA(isA<ChatroomFailureEvent>()),
      );
      expect(controller.stateFor('l')!.canGoOn, isTrue);
      expect(controller.stateFor('l')!.goOnPending, isFalse);
    },
  );
  test(
    'completed Go On receipt does not infer missing trigger metadata',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      h.session.goOnHandler = (request) async => ChatroomGoOnReceipt(
        worldId: 'w',
        locationId: 'l',
        sourceConversationRoundId: _round,
        conversationRoundId: _round + 1,
        clientMsgId: request,
      );
      await h.controller.goOn('l');
      h.controller.observeMessages('l', [
        _formal(
          round: _round + 1,
          user: '',
          conversationType: 'go_on',
          triggerUid: '',
        ),
      ]);
      await _settle();
      await h.controller.reconnect();
      expect(h.state.goOnPending, isFalse);
      h.controller.dispose();
      await _settle();
      final restored = _Harness(storage: storage);
      addTearDown(restored.controller.dispose);
      restored.controller.observeMessages('l', [
        _formal(
          round: _round + 1,
          user: '',
          conversationType: 'go_on',
          triggerUid: '',
        ),
      ]);
      await restored.controller.restoreLocationCards('l');
      expect(restored.controller.stateFor('l')!.roundId, _round + 1);
      expect(restored.controller.stateFor('l')!.isOwnRound, isFalse);
      expect(restored.controller.stateFor('l')!.canGoOn, isFalse);
      restored.controller.observeMessages('l', [
        _formal(
          round: _round + 1,
          user: '',
          conversationType: 'go_on',
          triggerUid: 'u',
        ),
      ]);
      expect(restored.controller.stateFor('l')!.canGoOn, isTrue);
    },
  );
  test(
    'confirming one of two drafted cards retires alternatives and future sends remain unblocked',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      final first = await h.prepareEditor();
      await h.controller.setDraft(first, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Unselected draft',
        ),
      ]);
      await h.controller.browse('l', 1);
      final selected = await h.prepareEditor();
      await h.controller.setDraft(selected, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Selected draft',
        ),
      ]);
      h.api.calls.clear();
      await h.controller.finalizeBeforeSend('l');
      expect(h.api.calls, ['cards:$_round', 'batch-card:102', 'select:102']);
      final saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect(saved['drafts'], isEmpty);
      expect(saved['draft_baselines'], isEmpty);
      expect(saved['uncertain_batches'], isEmpty);
      h.api.calls.clear();
      await h.controller.finalizeBeforeSend('l');
      expect(h.api.calls, isEmpty);
    },
  );

  test(
    'a read-only recovery completes a selection whose ACK was lost',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      final h = _Harness(storage: storage);
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      final first = await h.prepareEditor();
      await h.controller.setDraft(first, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Unselected draft',
        ),
      ]);
      await h.controller.browse('l', 1);
      final selected = await h.prepareEditor();
      await h.controller.setDraft(selected, const [
        ChatroomLlmMessageOperation.edit(
          globalMessageId: _messageId,
          content: 'Selected draft',
        ),
      ]);
      h.api.selectionError = TimeoutException('lost ACK');
      await h.controller.finalizeBeforeSend('l');
      expect(h.state.confirmed, isTrue);
      expect(h.state.frozen, isFalse);
      expect(h.state.error, isNull);
      h.api.selectionError = null;
      h.api.calls.clear();
      await h.controller.finalizeBeforeSend('l');
      expect(h.api.calls, isEmpty);
      final saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect(saved['drafts'], isEmpty);
      h.api.calls.clear();
      await h.controller.finalizeBeforeSend('l');
      expect(h.api.calls, isEmpty);
    },
  );

  test('definite selection rejection restores card switching', () async {
    final h = _Harness();
    addTearDown(h.controller.dispose);
    h.api.cards = _cards([_card(101), _card(102, index: 2)]);
    await h.controller.restoreLocationCards('l');
    await h.controller.browse('l', 1);
    h.api.selectionApplyBeforeError = false;
    h.api.selectionError = ApiException(
      message: 'Selection rejected',
      kind: ApiExceptionKind.business,
      code: 5002,
    );

    await expectLater(
      h.controller.finalizeBeforeSend('l'),
      throwsA(isA<ApiException>()),
    );

    expect(h.state.confirmed, isFalse);
    expect(h.state.frozen, isFalse);
    expect(h.state.canSwitchCards, isTrue);
  });

  test(
    'uncertain selection stays frozen when cards cannot prove its result',
    () async {
      final h = _Harness();
      addTearDown(h.controller.dispose);
      h.api.cards = _cards([_card(101), _card(102, index: 2)]);
      await h.controller.restoreLocationCards('l');
      await h.controller.browse('l', 1);
      h.api.selectionApplyBeforeError = false;
      h.api.selectionError = TimeoutException('lost selection ACK');
      h.api.calls.clear();

      await expectLater(
        h.controller.finalizeBeforeSend('l'),
        throwsA(isA<TimeoutException>()),
      );

      expect(h.state.confirmed, isFalse);
      expect(h.state.frozen, isTrue);
      expect(h.state.canSwitchCards, isFalse);
      expect(h.api.calls.where((call) => call == 'cards:$_round').length, 2);
    },
  );

  test(
    'a selected card draft is preserved when confirmed recovery cannot prove it was saved',
    () async {
      final storage = MemoryChatroomReplyActionStorage();
      await storage.save(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
        roundId: _round,
        value: {
          'round_id': _round,
          'owner': 'u',
          'viewed_card_id': 102,
          'last_complete_card_id': 102,
          'fixed_card_id': 102,
          'selection_request_id': 'pending-selection',
          'frozen': true,
          'drafts': {
            '101': [
              {
                'action': 'edit',
                'global_message_id': _messageId,
                'content': 'Unselected',
              },
            ],
            '102': [
              {
                'action': 'edit',
                'global_message_id': _messageId,
                'content': 'Still unsaved',
              },
            ],
          },
        },
      );
      final h = _Harness(storage: storage);
      addTearDown(h.controller.dispose);
      h.api.cards = _cards(
        [_card(101), _card(102, index: 2)],
        confirmed: true,
        selected: 102,
      );
      await h.controller.restoreLocationCards('l');
      expect(h.state.error, isA<StateError>());
      final saved = (await storage.load(
        ownerUid: 'u',
        worldId: 'w',
        locationId: 'l',
      )).single;
      expect((saved['drafts'] as Map).keys, ['102']);
      expect(
        ((saved['drafts'] as Map)['102'] as List).single['content'],
        'Still unsaved',
      );
      expect(h.api.calls.any((call) => call.startsWith('batch-')), isFalse);
    },
  );
}
