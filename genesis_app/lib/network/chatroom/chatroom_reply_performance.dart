part of 'chatroom_reply_actions_controller.dart';

/// Independent invalidation tokens for one location's presentation and actions.
@immutable
class ChatroomReplyLocationRevisions {
  const ChatroomReplyLocationRevisions({
    this.structureRevision = 0,
    this.contentRevision = 0,
    this.controlsRevision = 0,
  });

  final int structureRevision;
  final int contentRevision;
  final int controlsRevision;
}

class _ReplyLocationChanges extends ChangeNotifier {
  ChatroomReplyLocationRevisions revisions =
      const ChatroomReplyLocationRevisions();
  List<Object?> _structure = const [];
  List<Object?> _content = const [];
  List<Object?> _controls = const [];

  bool synchronize(
    ChatroomReplyActionsController controller,
    String location,
    Iterable<ChatroomReplyRoundState> states,
  ) {
    final structure = <Object?>[
      controller._latest[location],
      for (final state in states) (state.roundId, state.structureRevision),
    ];
    final content = <Object?>[
      for (final state in states) (state.roundId, state.contentRevision),
    ];
    final controls = <Object?>[
      controller._isReady(location),
      controller._isTickLocked(),
      for (final state in states) (state.roundId, state.controlsRevision),
    ];
    final structureChanged = !listEquals(structure, _structure);
    final contentChanged = !listEquals(content, _content);
    final controlsChanged = !listEquals(controls, _controls);
    if (!structureChanged && !contentChanged && !controlsChanged) return false;
    _structure = structure;
    _content = content;
    _controls = controls;
    revisions = ChatroomReplyLocationRevisions(
      structureRevision:
          revisions.structureRevision + (structureChanged ? 1 : 0),
      contentRevision: revisions.contentRevision + (contentChanged ? 1 : 0),
      controlsRevision: revisions.controlsRevision + (controlsChanged ? 1 : 0),
    );
    return true;
  }

  void emit() => notifyListeners();
}

class _ReplyRoundPerformance {
  int structureRevision = 0;
  int contentRevision = 0;
  int controlsRevision = 0;
  final cards = <int, _ReplyCardPerformance>{};
  int formalTailMessageId = 0;
  List<WorldChatroomMessage>? _formalSource;
  List<WorldChatroomMessage> _formalMessages = const [];
  List<Object?> _formalStructure = const [];
  List<Object?> _structure = const [];
  List<Object?> _content = const [];
  List<Object?> _controls = const [];

  List<WorldChatroomMessage> formalMessages(ChatroomReplyRoundState state) {
    if (!identical(_formalSource, state._formal)) {
      _formalSource = state._formal;
      formalTailMessageId = state._formal.fold<int>(
        0,
        (tail, message) =>
            message.locationMessageId > tail ? message.locationMessageId : tail,
      );
      final messages = state._formal
          .where(_isRenderableReply)
          .toList(growable: false);
      if (!listEquals(messages, _formalMessages)) {
        _formalMessages = List.unmodifiable(messages);
        _formalStructure = [
          for (final message in _formalMessages)
            (
              message.globalMessageId,
              message.locationMessageId,
              message.roundOrder,
            ),
        ];
      }
    }
    return _formalMessages;
  }

  List<WorldChatroomMessage> cardMessages(
    ChatroomReplyRoundState state,
    ChatroomLlmCard card,
  ) {
    final cache = cards.putIfAbsent(card.cardId, _ReplyCardPerformance.new);
    cache.synchronize(state, card);
    return cache.messages(state, card);
  }

  void synchronize(ChatroomReplyRoundState state) {
    formalMessages(state);
    final ids = state._cards.map((card) => card.cardId).toSet();
    cards.removeWhere((id, _) => !ids.contains(id));
    for (final card in state._cards) {
      cards
          .putIfAbsent(card.cardId, _ReplyCardPerformance.new)
          .synchronize(state, card);
    }
    final structure = <Object?>[
      state._viewedCardId,
      state.showCardPresentation,
      state._selectedCardPromotedToFormal,
      ..._formalStructure,
      for (final card in state._cards)
        (card.cardId, card.cardIndex, cards[card.cardId]!.structureRevision),
    ];
    final content = <Object?>[
      _formalMessages,
      for (final card in state._cards)
        (card.cardId, cards[card.cardId]!.contentRevision),
    ];
    final controls = <Object?>[
      state._conversationType,
      state._triggerUid,
      state.isOpeningRound && state._controller._isWorldCreator,
      formalTailMessageId,
      state._metadataConflict,
      state._invalidated,
      state._active,
      state._ended,
      state._roundFailed,
      state._regenerateDispatching,
      state._generating,
      state._busy,
      state._frozen,
      state._confirmed,
      state._selectedCardId,
      state._lastCompleteCardId,
      state._fixedCardId,
      state._error,
      state._completionRevision,
      state._regenerationRequestUncertain,
      state._streamReceiptRevision,
      state._goOn?.roundId,
      state._goOn?.finished,
      state._goOn?.uncertain,
      state._goOn?.ended,
      state._goOn?.clientMsgId,
      state._controller._isReady(state.locationId),
      state._controller._isTickLocked(),
      state.isLatest,
      for (final card in state._cards)
        (card.cardId, card.generationState, card.billing, card.error),
      ...state._uncertainBatches,
      for (final draft in state._drafts.entries) (draft.key, draft.value),
    ];
    if (!listEquals(_structure, structure)) structureRevision++;
    if (!listEquals(_content, content)) contentRevision++;
    if (!listEquals(_controls, controls)) controlsRevision++;
    _structure = structure;
    _content = content;
    _controls = controls;
  }
}

class _ReplyCardPerformance {
  int structureRevision = 0;
  int contentRevision = 0;
  final messageRevisions = <int, int>{};
  List<ChatroomLlmCardMessage>? _source;
  Map<int, _CandidateMessage>? _streams;
  int _streamRevision = -1;
  int _streamOrderRevision = -1;
  List<_CandidateMessage> _sortedStreams = const [];
  List<Object?> _structure = const [];
  Map<int, Object?> _messageSignatures = {};
  List<WorldChatroomMessage> _messages = const [];
  int _materializedRevision = -1;
  Map<int, (Object?, WorldChatroomMessage)> _converted = {};
  bool _failed = false;

  void synchronize(ChatroomReplyRoundState state, ChatroomLlmCard card) {
    final streams = state._authoritativeCards.contains(card.cardId)
        ? null
        : state._streamMessages[card.cardId];
    final streamRevision = state._streamContentRevisions[card.cardId] ?? 0;
    final orderRevision = state._streamStructureRevisions[card.cardId] ?? 0;
    final failed = card.generationState == ChatroomCardGenerationState.failed;
    if (identical(_source, card.messages) &&
        identical(_streams, streams) &&
        _streamRevision == streamRevision &&
        _failed == failed) {
      return;
    }
    // A normal chunk changes one body without changing card membership. Avoid
    // rebuilding/sorting even the lightweight signature list in that hot path.
    if (!failed &&
        !_failed &&
        streams != null &&
        identical(_streams, streams) &&
        _streamOrderRevision == orderRevision) {
      var changed = false;
      for (final id
          in state._dirtyStreamMessages.remove(card.cardId) ?? const <int>{}) {
        final revision = streams[id]!._revision;
        if (_messageSignatures[id] == revision) continue;
        _messageSignatures[id] = revision;
        messageRevisions.update(id, (value) => value + 1, ifAbsent: () => 1);
        changed = true;
      }
      if (changed) contentRevision++;
      _source = card.messages;
      _streamRevision = streamRevision;
      return;
    }
    state._dirtyStreamMessages.remove(card.cardId);
    final oldStreams = _streams;
    final signatures = <int, Object?>{};
    List<Object?> structure;
    if (failed) {
      _sortedStreams = const [];
      _converted.clear();
      structure = const [];
    } else if (streams != null) {
      if (!identical(oldStreams, streams) ||
          _streamOrderRevision != orderRevision) {
        _sortedStreams = streams.values.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
      }
      structure = [
        for (final message in _sortedStreams) (message.id, message.index),
      ];
      for (final message in _sortedStreams) {
        // Message snapshots are lazy; unchanged messages retain their instance.
        signatures[message.id] = message._revision;
      }
    } else {
      _sortedStreams = const [];
      structure = [
        for (final message in card.messages)
          (message.globalMessageId, message.cardMessageIndex),
      ];
      for (final message in card.messages) {
        signatures[message.globalMessageId] = (
          message.isLlmStreamMessage,
          message.message.toJson(),
        );
      }
    }
    var contentChanged =
        failed != _failed ||
        signatures.length != _messageSignatures.length ||
        !identical(oldStreams, streams);
    for (final entry in signatures.entries) {
      final before = _messageSignatures[entry.key];
      if (!_sameSignature(before, entry.value)) {
        messageRevisions.update(
          entry.key,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        contentChanged = true;
      }
    }
    messageRevisions.removeWhere((id, _) => !signatures.containsKey(id));
    if (!listEquals(_structure, structure)) {
      structureRevision++;
      contentChanged = true;
    }
    if (contentChanged) contentRevision++;
    _structure = structure;
    _messageSignatures = signatures;
    _source = card.messages;
    _streams = streams;
    _streamRevision = streamRevision;
    _streamOrderRevision = orderRevision;
    _failed = failed;
  }

  static bool _sameSignature(Object? left, Object? right) {
    if (left is (bool, Map<String, Object?>) &&
        right is (bool, Map<String, Object?>)) {
      return left.$1 == right.$1 && _sameJson(left.$2, right.$2);
    }
    return left == right;
  }

  static bool _sameJson(Object? left, Object? right) {
    if (identical(left, right) || left == right) return true;
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) => right.containsKey(key) && _sameJson(left[key], right[key]),
          );
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameJson(left[index], right[index])) return false;
      }
      return true;
    }
    return false;
  }

  List<WorldChatroomMessage> messages(
    ChatroomReplyRoundState state,
    ChatroomLlmCard card,
  ) {
    if (_materializedRevision == contentRevision) return _messages;
    _materializedRevision = contentRevision;
    if (_failed) {
      _converted.clear();
      return _messages = const [];
    }
    if (_streams != null) {
      _converted.clear();
      return _messages = List.unmodifiable([
        for (final message in _sortedStreams)
          if (message.toMessage(state.locationId, state.roundId)
              case final rendered when _messageHasRenderableOutput(rendered))
            rendered,
      ]);
    }
    final converted = <int, (Object?, WorldChatroomMessage)>{};
    final result = <WorldChatroomMessage>[];
    for (final message in card.messages) {
      final signature = _messageSignatures[message.globalMessageId];
      final previous = _converted[message.globalMessageId];
      final value = previous != null && _sameSignature(previous.$1, signature)
          ? previous.$2
          : _candidateToWorld(message);
      converted[message.globalMessageId] = (signature, value);
      result.add(value);
    }
    _converted = converted;
    return _messages = List.unmodifiable(result);
  }
}
