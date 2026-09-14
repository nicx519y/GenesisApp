import 'dart:async';

import '../../features/location_chat_reply/inspiration/inspiration.dart';

import 'package:flutter/foundation.dart';

import '../api_exception.dart';
import 'chatroom_client.dart';
import 'chatroom_http_api.dart';
import 'chatroom_http_models.dart';
import 'chatroom_models.dart';
import 'chatroom_failure_identity.dart';
import 'chatroom_reply_action_storage.dart';
import 'chatroom_message_storage.dart';
import 'world_chatroom_service.dart' show WorldChatroomMessage;

part 'chatroom_reply_performance.dart';
part 'chatroom_reply_snapshots.dart';

part '../../features/location_chat_reply/regenerate/src/chatroom_regenerate_action.dart';
part '../../features/location_chat_reply/go_on/src/chatroom_go_on_action.dart';
part '../../features/location_chat_reply/edit/src/chatroom_edit_action.dart';

/// A stable editor identity; the messages are an authoritative, complete snapshot.
class ChatroomReplyEditorTarget {
  ChatroomReplyEditorTarget({
    required this.worldId,
    required this.locationId,
    required this.roundId,
    required this.cardId,
    required this.messages,
    required ChatroomReplyRoundState state,
  }) : _state = state,
       _openedRevision = state.completionRevision;

  final String worldId, locationId;
  final int roundId;
  final int? cardId;
  final List<WorldChatroomMessage> messages;
  final ChatroomReplyRoundState _state;
  final int _openedRevision;
  bool get frozen => _state.frozen;
  bool get editorShouldClose =>
      _state.completionRevision > _openedRevision &&
      !_state.busy &&
      _state.error == null;
  List<ChatroomLlmMessageOperation> get draft =>
      List.unmodifiable(_state._drafts[cardId ?? 0] ?? const []);
  List<ChatroomLlmMessageOperation> get draftOperations => draft;
}

/// Mutable internally, read-only to widgets. Candidate bodies never enter history.
class ChatroomReplyRoundState {
  ChatroomReplyRoundState._(this._controller, this.locationId, this.roundId);

  final ChatroomReplyActionsController _controller;
  final String locationId;
  final int roundId;
  String _conversationType = '';
  String _triggerUid = '';
  bool _metadataConflict = false;
  bool _invalidated = false;
  bool _active = false;
  bool _ended = false;
  bool _roundFailed = false;
  bool _generating = false;
  bool _regenerateDispatching = false;
  int _regenerationDispatchGeneration = 0;
  bool _regenerationRequestUncertain = false;
  bool _busy = false;
  bool _frozen = false;
  bool _confirmed = false;
  bool _retainSelectedCardPresentation = false;
  bool _selectedCardPromotedToFormal = false;
  int _viewedCardId = 0;
  int _lastCompleteCardId = 0;
  int _selectedCardId = 0;
  int _generation = 0;
  int _query = 0;
  int _presentationRevision = 0;
  final _performance = _ReplyRoundPerformance();
  final _streamContentRevisions = <int, int>{};
  final _streamStructureRevisions = <int, int>{};
  final _dirtyStreamMessages = <int, Set<int>>{};
  int _streamReceiptRevision = 0;
  int _completionRevision = 0;
  int? _fixedCardId;
  String? _selectionRequestId;
  String? _regenerationRequestId;
  Object? _error;
  bool _cardsNeedRefresh = false;
  Map<int, List<WorldChatroomMessage>>? _snapshotMessages;
  bool? _snapshotLatest;
  Set<int>? _snapshotChunkCardIds;
  ChatroomLlmCardsResponse? _cardsResponse;
  ChatroomLlmCardsResponse? _cachedCards;
  int? _cardsCachedAt;
  int _cardsCacheVersion = 0;
  Future<ChatroomLlmCardsResponse>? _cardsFetch;
  final _cards = <ChatroomLlmCard>[];
  List<WorldChatroomMessage> _formal = const [];
  final _drafts = <int, List<ChatroomLlmMessageOperation>>{};
  final _draftBaselines = <int, Map<int, String>>{};
  final _uncertainBatches = <int>{};
  final _streamMessages = <int, Map<int, _CandidateMessage>>{};
  final _authoritativeCards = <int>{};
  final _cardTerminals = <int, ChatroomLlmCardGenerationEnd>{};
  Timer? _regenerationStreamStartTimer;
  Timer? _regenerationStreamEndTimer;
  int? _watchedRegenerationCardId;
  bool _regenerationStreamStarted = false;
  Timer? _goOnStreamStartTimer;
  Timer? _goOnStreamEndTimer;
  bool _goOnStreamStarted = false;
  _PendingGoOn? _goOn;
  int _goOnDispatchGeneration = 0;

  List<ChatroomLlmCard> get cards => List.unmodifiable(_cards);
  int get viewedCardId => _viewedCardId;
  int get lastCompleteCardId => _lastCompleteCardId;
  int get selectedCardId => _selectedCardId;
  int get presentationRevision => _presentationRevision;
  int get structureRevision => _performance.structureRevision;
  int get contentRevision => _performance.contentRevision;
  int get controlsRevision => _performance.controlsRevision;
  int cardContentRevision(int cardId) =>
      _performance.cards[cardId]?.contentRevision ?? 0;
  int messageContentRevision(int cardId, int globalMessageId) =>
      _performance.cards[cardId]?.messageRevisions[globalMessageId] ?? 0;
  int get completionRevision => _completionRevision;
  String get conversationType => _conversationType;
  String get triggerUid => _triggerUid;
  bool get sourceOwnerKnown => _triggerUid.isNotEmpty;
  bool get isOwnRound =>
      !_metadataConflict &&
      _triggerUid.isNotEmpty &&
      _controller.ownerUid.isNotEmpty &&
      _triggerUid == _controller.ownerUid;
  bool get isOpeningRound =>
      !_metadataConflict && _conversationType == 'opening';
  bool get _isOwnSupportedRound =>
      isOwnRound && const {'user_message', 'go_on'}.contains(_conversationType);
  bool get _supportsReplyActions =>
      _isOwnSupportedRound ||
      (isOpeningRound && _controller._isWorldCreator) ||
      (isOwnRound && _conversationType == 'user_enter_location');
  bool get _supportsEditing => _supportsReplyActions;
  bool get confirmed => _confirmed;
  bool get hasCardGroup => _cards.isNotEmpty;
  bool get provisional => _cards.any((card) => card.cardId <= 0);
  bool get showCandidates => hasCardGroup && !confirmed;

  /// Confirmation locks card actions immediately, while presentation keeps the
  /// selected body in the same deck when conversation-range history arrives.
  bool get showCardPresentation =>
      showCandidates ||
      (confirmed &&
          _retainSelectedCardPresentation &&
          _selectedCardId > 0 &&
          _card(_selectedCardId) != null);

  /// Keep the chosen candidate over stale formal history until its range update.
  bool get selectedCardAwaitingFormalHistory =>
      confirmed && showCardPresentation && !_formalHistoryContainsSelectedCard;
  bool get generating =>
      _regenerateDispatching ||
      _generating ||
      _cards.any((card) => !_terminal(card.generationState));
  bool get busy => _busy;
  bool get frozen => _frozen;
  bool get invalidatedByTick => _invalidated;
  Object? get error => _error;
  bool get complete => !_active && (_ended || _formal.any(_isReply));
  bool get isLatest =>
      _snapshotLatest ?? (_controller._latest[locationId] == roundId);
  bool get goOnPending => _goOn != null && !_goOn!.finished;
  bool get goOnUnknown =>
      goOnPending && _goOn!.uncertain && _goOn!.roundId == null;
  int? get goOnRoundId => _goOn?.roundId;
  bool get canSwitchCards =>
      isLatest &&
      _isOwnSupportedRound &&
      showCandidates &&
      !busy &&
      !frozen &&
      !generating &&
      !_controller._hasPendingGoOn(locationId);
  bool get canRegenerate =>
      _eligible &&
      _isOwnSupportedRound &&
      !busy &&
      !frozen &&
      !generating &&
      !confirmed &&
      _cards.length < 10;

  /// Round-level capability, excluding transient operation locks.
  bool get supportsRegenerate =>
      _baseEligible && _isOwnSupportedRound && !confirmed && _cards.length < 10;
  bool get regenerateLimitReached =>
      _baseEligible &&
      _isOwnSupportedRound &&
      !confirmed &&
      _cards.length >= 10;
  bool get supportsGoOn => _baseEligible;
  bool get supportsEdit => _baseEligible && _supportsEditing;
  bool get supportsInspiration => _baseEligible && !_roundFailed;
  bool get canGoOn =>
      _eligible &&
      !busy &&
      !frozen &&
      !_controller._hasPendingGoOn(locationId) &&
      (!showCandidates || _completeCard(viewedCard));
  bool get canEdit =>
      _eligible &&
      _supportsEditing &&
      !busy &&
      !frozen &&
      (!showCandidates || _completeCard(viewedCard));
  bool get _baseEligible =>
      isLatest &&
      !_invalidated &&
      _supportsReplyActions &&
      complete &&
      _formal.any(_isReply);
  bool get _eligible =>
      _baseEligible &&
      _controller._isReady(locationId) &&
      !_controller._isTickLocked();
  ChatroomLlmCard? get viewedCard => _card(_viewedCardId);

  int get inspirationTailMessageId {
    _performance.formalMessages(this);
    return _performance.formalTailMessageId;
  }

  ChatroomInspirationSource? get inspirationSource {
    if (!isLatest ||
        _invalidated ||
        !_supportsReplyActions ||
        !complete ||
        _roundFailed ||
        !_controller._isReady(locationId) ||
        _controller._isTickLocked() ||
        !_formal.any(_isReply) ||
        busy ||
        frozen) {
      return null;
    }
    final card = _isOwnSupportedRound
        ? (confirmed ? _card(selectedCardId) : viewedCard)
        : null;
    if (_isOwnSupportedRound &&
        hasCardGroup &&
        (card == null || !_completeCard(card) || card.cardId <= 0)) {
      return null;
    }
    return ChatroomInspirationSource(
      ownerUid: _controller.ownerUid,
      worldId: _controller.worldId,
      locationId: locationId,
      roundId: roundId,
      cardId: card?.cardId,
      sourceCardId: card == null || card.isOriginal ? 0 : card.cardId,
      tailMessageId: inspirationTailMessageId,
    );
  }

  int get cardPosition =>
      _cards.indexWhere((card) => card.cardId == _viewedCardId) + 1;
  int get cardCount => _cards.length;

  List<WorldChatroomMessage> get formalReplyMessages =>
      _performance.formalMessages(this);

  List<WorldChatroomMessage> get displayedMessages {
    if (!showCardPresentation || _viewedCardId == 0) {
      return formalReplyMessages;
    }
    if (confirmed &&
        (_selectedCardPromotedToFormal || _formalHistoryContainsSelectedCard)) {
      return formalReplyMessages;
    }
    return messagesForCard(_viewedCardId);
  }

  bool get _formalHistoryContainsSelectedCard {
    final selected = _card(_selectedCardId);
    if (!_completeCard(selected)) return false;
    final formalById = <int, WorldChatroomMessage>{
      for (final message in formalReplyMessages)
        if (message.globalMessageId > 0) message.globalMessageId: message,
    };
    return selected!.messages.every((candidate) {
      final formal = formalById[candidate.globalMessageId];
      return formal != null && formal.content == candidate.content;
    });
  }

  /// Read-only preview; browsing and persistence are deliberately separate.
  List<WorldChatroomMessage> messagesForCard(int cardId) {
    if (_snapshotMessages != null) {
      return _snapshotMessages![cardId] ?? const [];
    }
    final card = _card(cardId);
    if (card == null ||
        card.generationState == ChatroomCardGenerationState.failed) {
      return const [];
    }
    return _performance.cardMessages(this, card);
  }

  bool hasNewCandidateChunk(Set<int> previousCardIds) =>
      (_snapshotChunkCardIds?.any((id) => !previousCardIds.contains(id)) ??
          false) ||
      _streamMessages.entries.any(
        (entry) =>
            !previousCardIds.contains(entry.key) &&
            entry.value.values.any((message) => message._receivedChunk),
      ) ||
      _cards.any(
        (card) =>
            card.cardId > 0 &&
            !card.isOriginal &&
            !previousCardIds.contains(card.cardId) &&
            card.messages.any((message) => message.content.trim().isNotEmpty),
      );

  bool hasCandidateChunk(int cardId) =>
      (_snapshotChunkCardIds?.contains(cardId) ?? false) ||
      (_streamMessages[cardId]?.values.any(
            (message) => message._receivedChunk,
          ) ??
          false) ||
      (_authoritativeCards.contains(cardId) &&
          (_card(cardId)?.messages.isNotEmpty ?? false));

  ChatroomLlmCard? _card(int id) {
    for (final card in _cards) {
      if (card.cardId == id) return card;
    }
    return null;
  }
}

/// Owns one account/world lifetime. Recreate on account or world switches.
class ChatroomReplyActionsController extends ChangeNotifier {
  ChatroomReplyActionsController({
    required this.worldId,
    required this.ownerUid,
    String Function()? worldCreatorUid,
    required ChatroomHttpApi httpApi,
    required ChatroomSession? Function() session,
    required bool Function(String locationId) isReady,
    required bool Function() isTickLocked,
    void Function(String locationId, int roundId)? onGoOnAccepted,
    void Function(String locationId, int roundId)? onGoOnFinished,
    void Function(
      String locationId,
      int roundId,
      List<ChatroomLlmMessageOperation> operations,
    )?
    onFormalEditCommitted,
    Future<void> Function()? refreshWallet,
    ChatroomReplyActionStorage? storage,
    ChatroomMessageStorage? snapshotStorage,
    DateTime Function()? now,
    Duration regenerationStreamStartTimeout = const Duration(seconds: 30),
    Duration regenerationStreamEndTimeout = const Duration(seconds: 120),
    Duration goOnStreamStartTimeout = const Duration(seconds: 30),
    Duration goOnStreamEndTimeout = const Duration(seconds: 120),
  }) : _worldCreatorUid = worldCreatorUid,
       _http = httpApi,
       _session = session,
       _isReady = isReady,
       _isTickLocked = isTickLocked,
       _onGoOnAccepted = onGoOnAccepted,
       _onGoOnFinished = onGoOnFinished,
       _onFormalEditCommitted = onFormalEditCommitted,
       _refreshWallet = refreshWallet,
       _storage = storage ?? SqfliteChatroomReplyActionStorage(),
       _snapshotStorage = snapshotStorage,
       _now = now ?? DateTime.now,
       _regenerationStreamStartTimeout = regenerationStreamStartTimeout,
       _regenerationStreamEndTimeout = regenerationStreamEndTimeout,
       _goOnStreamStartTimeout = goOnStreamStartTimeout,
       _goOnStreamEndTimeout = goOnStreamEndTimeout;

  final DateTime Function() _now;
  final Duration _regenerationStreamStartTimeout;
  final Duration _regenerationStreamEndTimeout;
  final Duration _goOnStreamStartTimeout;
  final Duration _goOnStreamEndTimeout;
  final ChatroomMessageStorage? _snapshotStorage;

  final String worldId, ownerUid;
  final String Function()? _worldCreatorUid;
  bool get _isWorldCreator =>
      ownerUid.isNotEmpty && _worldCreatorUid?.call() == ownerUid;
  final ChatroomHttpApi _http;
  final ChatroomSession? Function() _session;
  final bool Function(String) _isReady;
  final bool Function() _isTickLocked;
  final void Function(String, int)? _onGoOnAccepted;
  final void Function(String, int)? _onGoOnFinished;
  final void Function(String, int, List<ChatroomLlmMessageOperation>)?
  _onFormalEditCommitted;
  final Future<void> Function()? _refreshWallet;
  final ChatroomReplyActionStorage _storage;
  final _states = <String, Map<int, ChatroomReplyRoundState>>{};
  final _latest = <String, int>{};
  final _restored = <String, Future<void>>{};
  final _seenEvents = <String>{};
  final _finalizations = <String, Future<void>>{};
  final _active = <String, Set<int>>{};
  int _latestTick = -1;
  int _latestSubTick = -1;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  int _requestCounter = 0;
  final _locationChanges = <String, _ReplyLocationChanges>{};
  final _pendingLocations = <String>{};
  int _notificationDepth = 0;

  Listenable changesForLocation(String locationId) =>
      _locationChanges.putIfAbsent(locationId, _ReplyLocationChanges.new);

  ChatroomReplyLocationRevisions revisionsForLocation(String locationId) =>
      _locationChanges[locationId]?.revisions ??
      const ChatroomReplyLocationRevisions();

  /// Groups only the current synchronous transaction; ACK/error delivery is
  /// never deferred to a timer or the next microtask.
  void batchChanges(VoidCallback action) {
    _notificationDepth++;
    try {
      action();
    } finally {
      _notificationDepth--;
      if (_notificationDepth == 0) _flushNotifications();
    }
  }

  /// Connection/input availability has no message-content dependency.
  void refreshAvailability() => _notify();

  ChatroomReplyRoundState? stateFor(String locationId) =>
      _states[locationId]?[_latest[locationId]];

  /// Keeps the selected source card mounted while a subsequent round is
  /// active, whether it was started by Go On or by a new user message.
  ChatroomReplyRoundState? presentationStateFor(String locationId) {
    final latest = stateFor(locationId);
    if (latest == null) return null;
    ChatroomReplyRoundState? retained;
    for (final state in statesFor(locationId)) {
      if (!state.showCardPresentation) continue;
      final targetRoundId = state.goOnRoundId;
      final goOnContinuesIntoLatest =
          state.goOnPending &&
          (latest.roundId == state.roundId ||
              targetRoundId == latest.roundId ||
              (targetRoundId == null && latest.roundId > state.roundId));
      final userSendContinuesIntoLatest =
          state.selectedCardAwaitingFormalHistory &&
          latest.roundId > state.roundId &&
          !latest.complete;
      if (!goOnContinuesIntoLatest && !userSendContinuesIntoLatest) continue;
      if (retained == null || state.roundId > retained.roundId) {
        retained = state;
      }
    }
    return retained ?? latest;
  }

  Iterable<String> get locationIds => _states.keys;
  ChatroomReplyRoundState? stateForRound(String locationId, int roundId) =>
      _states[locationId]?[roundId];
  Iterable<ChatroomReplyRoundState> statesFor(String locationId) =>
      List.unmodifiable(
        _states[locationId]?.values ?? const <ChatroomReplyRoundState>[],
      );

  ChatroomReplyRoundState _state(String location, int round) =>
      (_states[location] ??= {})[round] ??= ChatroomReplyRoundState._(
        this,
        location,
        round,
      );

  void _mergeRoundMetadata(
    ChatroomReplyRoundState state, {
    required String conversationType,
    required String triggerUid,
  }) {
    if (conversationType.isNotEmpty) {
      if (state._conversationType.isEmpty) {
        state._conversationType = conversationType;
      } else if (state._conversationType != conversationType) {
        state._metadataConflict = true;
      }
    }
    if (triggerUid.isNotEmpty) {
      if (state._triggerUid.isEmpty) {
        state._triggerUid = triggerUid;
      } else if (state._triggerUid != triggerUid) {
        state._metadataConflict = true;
      }
    }
  }

  void _notify([String? locationId]) {
    if (_disposed) return;
    _pendingLocations.addAll(locationId == null ? _states.keys : [locationId]);
    if (_notificationDepth == 0) _flushNotifications();
  }

  void _flushNotifications() {
    if (_disposed || _pendingLocations.isEmpty) return;
    final locations = _pendingLocations.toList();
    _pendingLocations.clear();
    var changed = false;
    for (final location in locations) {
      final states = statesFor(location);
      for (final state in states) {
        state._performance.synchronize(state);
      }
      final channel = _locationChanges.putIfAbsent(
        location,
        _ReplyLocationChanges.new,
      );
      if (channel.synchronize(this, location, states)) {
        changed = true;
        channel.emit();
      }
    }
    if (changed) notifyListeners();
  }

  void _checkCurrent() {
    if (_disposed) throw StateError('Reply actions disposed');
  }

  String _request(String kind) =>
      '$kind-${DateTime.now().microsecondsSinceEpoch}-${++_requestCounter}';

  /// Hydration/refresh does not finalize candidates. Only deduplicated live
  /// events can do that, so paging or replaying old history is harmless.
  void observeMessages(
    String locationId,
    List<WorldChatroomMessage> messages, {
    Set<int> activeRoundIds = const {},
  }) {
    if (_disposed) return;
    _active[locationId] = {...activeRoundIds};
    final groups = <int, List<WorldChatroomMessage>>{};
    for (final message in messages) {
      final round = message.conversationRoundNumber;
      if (message.locationId != locationId || round <= 0) continue;
      groups.putIfAbsent(round, () => []).add(message);
      final id = message.globalMessageId > 0
          ? message.globalMessageId
          : message.locationMessageId;
      if (id > 0) _remember('message:$locationId:$id');
      if (message.businessType == 'tick') {
        _rememberTick(message.tickNo, message.subTickNo);
      }
    }
    for (final entry in groups.entries) {
      final state = _state(locationId, entry.key);
      if (!listEquals(state._formal, entry.value)) {
        final previousContent = {
          for (final m in state._formal) m.globalMessageId: m.content,
        };
        if (entry.value.any(
          (m) =>
              previousContent.containsKey(m.globalMessageId) &&
              previousContent[m.globalMessageId] != m.content,
        )) {
          _invalidateCardsCache(state);
        }
        state._formal = List.unmodifiable(entry.value);
      }
      state._active =
          activeRoundIds.contains(entry.key) ||
          entry.value.any((m) => m.streaming);
      for (final message in entry.value) {
        _mergeRoundMetadata(
          state,
          conversationType: message.conversationType,
          triggerUid: message.triggerUid,
        );
      }
    }
    for (final state in statesFor(locationId)) {
      if (!groups.containsKey(state.roundId)) {
        state._active = activeRoundIds.contains(state.roundId);
      }
      if (state._retainSelectedCardPresentation &&
          state._formalHistoryContainsSelectedCard) {
        state._selectedCardPromotedToFormal = true;
      }
    }
    for (final source in statesFor(locationId).toList()) {
      final pending = source._goOn;
      if (pending == null || pending.finished || pending.roundId == null) {
        continue;
      }
      final next = _states[locationId]?[pending.roundId!];
      if (next == null) continue;
      if (next._formal.any((message) => message.streaming)) {
        _noteGoOnStreamStarted(source);
      }
      if (next._formal.any(
        (message) => !message.streaming && _isReply(message),
      )) {
        _background(source, () => _recoverGoOn(source));
      }
    }
    // Round IDs are positive monotonic server IDs. Include empty waiting rounds.
    final rounds = <int>[
      ...groups.keys,
      ...activeRoundIds,
      if (_latest[locationId] != null) _latest[locationId]!,
    ];
    if (rounds.isNotEmpty) {
      rounds.sort();
      _latest[locationId] = rounds.last;
    }
    _notify(locationId);
  }

  Future<void> restore(
    String locationId,
  ) => _restored.putIfAbsent(locationId, () async {
    var saved = await _storage.load(
      ownerUid: ownerUid,
      worldId: worldId,
      locationId: locationId,
    );
    _checkCurrent();
    final snapshots = _snapshotStorage;
    if (snapshots != null) {
      await snapshots.importLegacyReplySnapshots(
        ownerUid: ownerUid,
        worldId: worldId,
        locationId: locationId,
        values: saved,
      );
      final stored = await snapshots.loadReplySnapshots(
        ownerUid: ownerUid,
        worldId: worldId,
        locationId: locationId,
      );
      _checkCurrent();
      final merged = <int, Map<String, dynamic>>{
        for (final value in saved)
          if (value['round_id'] is int)
            value['round_id'] as int: Map<String, dynamic>.of(value)
              ..remove('cards_cache')
              ..remove('cards_cached_at')
              ..remove('viewed_card_id')
              ..remove('last_complete_card_id'),
      };
      for (final value in stored) {
        final round = value['round_id'];
        if (round is! int) continue;
        merged[round] = {...?merged[round], ...value};
      }
      saved = merged.values.toList();
    }
    for (final json in saved) {
      final round = json['round_id'];
      if (round is! int || round <= 0) continue;
      final state = _state(locationId, round);
      // A user action started during disk IO has newer state than this snapshot.
      if (state._generation != 0 ||
          state.busy ||
          state._cardsResponse != null) {
        continue;
      }
      _mergeRoundMetadata(
        state,
        conversationType: json['conversation_type'] is String
            ? json['conversation_type'] as String
            : '',
        triggerUid: json['trigger_uid'] is String
            ? json['trigger_uid'] as String
            : '',
      );
      state._metadataConflict =
          state._metadataConflict || json['metadata_conflict'] == true;
      state._invalidated = json['invalidated'] == true;
      final baselines = json['draft_baselines'];
      if (baselines is Map) {
        for (final entry in baselines.entries) {
          final cardId = int.tryParse('${entry.key}');
          final messages = entry.value;
          if (cardId == null || messages is! Map) continue;
          final baseline = <int, String>{};
          for (final message in messages.entries) {
            final messageId = int.tryParse('${message.key}');
            if (messageId != null && message.value is String) {
              baseline[messageId] = message.value as String;
            }
          }
          state._draftBaselines[cardId] = baseline;
        }
      }
      state._viewedCardId = json['viewed_card_id'] is int
          ? json['viewed_card_id'] as int
          : 0;
      state._lastCompleteCardId = json['last_complete_card_id'] is int
          ? json['last_complete_card_id'] as int
          : 0;
      state._fixedCardId = json['fixed_card_id'] is int
          ? json['fixed_card_id'] as int
          : null;
      state._selectionRequestId = json['selection_request_id'] is String
          ? json['selection_request_id'] as String
          : null;
      state._regenerationRequestId = json['regeneration_request_id'] is String
          ? json['regeneration_request_id'] as String
          : null;
      state._frozen = json['frozen'] == true;
      state._confirmed = json['confirmed'] == true;
      final drafts = json['drafts'];
      if (drafts is Map) {
        for (final entry in drafts.entries) {
          final card = int.tryParse('${entry.key}');
          if (card == null || entry.value is! List) continue;
          try {
            state._drafts[card] = (entry.value as List)
                .map(_operationFromJson)
                .toList();
          } catch (error) {
            debugPrint(
              '[ReplyActions] skipping invalid saved draft: '
              '${error.runtimeType}',
            );
          }
        }
      }
      final uncertainBatches = json['uncertain_batches'];
      if (uncertainBatches is List) {
        state._uncertainBatches.addAll(uncertainBatches.whereType<int>());
      }
      if (json['go_on'] is Map) {
        try {
          state._goOn = _PendingGoOn.fromJson(
            Map<String, dynamic>.from(json['go_on'] as Map),
          );
        } catch (error) {
          debugPrint(
            '[ReplyActions] skipping invalid saved Go On: ${error.runtimeType}',
          );
        }
      }
      if (state._formal.isNotEmpty) {
        _latest[locationId] = (_latest[locationId] ?? 0) > round
            ? _latest[locationId]!
            : round;
      }
      final cachedAt = json['cards_cached_at'];
      if (json['cards_cache'] != null) {
        if (state._cardsCacheVersion == 0 &&
            state._formal.isNotEmpty &&
            _matchesSnapshotSource(state, json)) {
          try {
            final cached = _decodeStoredCards(json);
            if (cached.conversationRoundId == round &&
                cached.list.every((card) => _terminal(card.generationState))) {
              state._cachedCards = cached;
              state._cardsCachedAt = cachedAt is int ? cachedAt : null;
              await _applyCards(state, cached, persist: false);
              state._roundFailed = json['round_failed'] == true;
              state._retainSelectedCardPresentation =
                  json['retain_selected_presentation'] == true;
              state._selectedCardPromotedToFormal =
                  json['selected_promoted_to_formal'] == true;
              state._cardsNeedRefresh = json['needs_refresh'] == true;
              if (state._cardsNeedRefresh) state._cachedCards = null;
            }
          } catch (error) {
            // A malformed cache must not prevent recovery of operation metadata.
            debugPrint(
              '[ReplyActions] skipping invalid saved cards: '
              '${error.runtimeType}',
            );
          }
        }
        // Recompute capabilities from current code and authoritative round ownership.
        if (state._cachedCards == null ||
            (_snapshotStorage != null &&
                json['capability_version'] != _replyCapabilityVersion)) {
          await _persist(state);
        }
      }
      final accepted = state._goOn;
      if (accepted?.roundId != null) {
        final next = _state(locationId, accepted!.roundId!);
        next._ended = accepted.finished || accepted.ended;
        if (accepted.roundId! > (_latest[locationId] ?? 0)) {
          _latest[locationId] = accepted.roundId!;
        }
      }
      if (_isReady(locationId)) {
        final pending = state._goOn;
        if (pending != null &&
            !pending.finished &&
            pending.roundId != null &&
            !pending.ended) {
          final next = _state(locationId, pending.roundId!);
          next._active = true;
          if (pending.roundId! > (_latest[locationId] ?? 0)) {
            _latest[locationId] = pending.roundId!;
          }
          _onGoOnAccepted?.call(locationId, pending.roundId!);
          _watchGoOn(state);
        }
      }
    }
    _notify(locationId);
  });

  /// Card bodies are part of remote history, including preloaded locations.
  /// This read path never finalizes drafts or starts recovery writes.
  Future<void> loadHistoryCards(
    String locationId, {
    required Set<int> roundIds,
    required bool Function() isCurrent,
  }) async {
    await restore(locationId);
    if (_disposed || !isCurrent()) return;
    final state = stateFor(locationId);
    if (state == null ||
        !roundIds.contains(state.roundId) ||
        !state._isOwnSupportedRound ||
        !state.complete ||
        state.busy ||
        state._regenerateDispatching) {
      return;
    }
    try {
      await _loadCards(state, isCurrent: isCurrent);
    } catch (error) {
      if (!_disposed && isCurrent()) {
        state._error = error;
        _notify(state.locationId);
        rethrow;
      }
    }
  }

  /// Called after entry history is loaded, even on a fresh installation with
  /// no saved reply-action metadata. Actions themselves use the local cards.
  Future<void> restoreLocationCards(
    String locationId, {
    bool reloadCards = true,
  }) async {
    await restore(locationId);
    _checkCurrent();
    if (!_isReady(locationId)) return;
    final latest = stateFor(locationId);
    for (final state in statesFor(locationId)) {
      if (!_isReady(locationId)) return;
      if (!state._isOwnSupportedRound) continue;
      try {
        if (reloadCards &&
            ((identical(state, latest) &&
                    state.complete &&
                    state._isOwnSupportedRound) ||
                state.frozen ||
                state._regenerationRequestId != null)) {
          await _loadCards(
            state,
            force: state.frozen || state._regenerationRequestId != null,
          );
        }
        if (!_isReady(locationId)) return;
        if (state.frozen) await finalizeBeforeSend(locationId);
        await _recoverGoOn(state);
      } catch (error) {
        if (!_disposed) state._error = error;
      }
    }
    _notify(locationId);
  }

  Future<void> _persist(ChatroomReplyRoundState state) {
    _checkCurrent();
    final snapshot = _storedSnapshot(state);
    final generation = state._generation;
    final cacheVersion = state._cardsCacheVersion;
    final value = <String, dynamic>{
      'round_id': state.roundId,
      if (_snapshotStorage == null && snapshot != null) ...snapshot,
      if (state._conversationType.isNotEmpty)
        'conversation_type': state._conversationType,
      'trigger_uid': state._triggerUid,
      'metadata_conflict': state._metadataConflict,
      'invalidated': state._invalidated,
      'draft_baselines': state._draftBaselines.map(
        (card, messages) => MapEntry(
          '$card',
          messages.map((id, content) => MapEntry('$id', content)),
        ),
      ),
      'viewed_card_id': state._viewedCardId,
      'last_complete_card_id': state._lastCompleteCardId,
      'fixed_card_id': state._fixedCardId,
      'selection_request_id': state._selectionRequestId,
      'regeneration_request_id': state._regenerationRequestId,
      'frozen': state._frozen,
      'confirmed': state._confirmed,
      'drafts': state._drafts.map(
        (card, operations) =>
            MapEntry('$card', operations.map(_operationToDraftJson).toList()),
      ),
      'uncertain_batches': state._uncertainBatches.toList(),
      'go_on': state._goOn?.toJson(),
    };
    final write = _writes.then((_) async {
      await _storage.save(
        ownerUid: ownerUid,
        worldId: worldId,
        locationId: state.locationId,
        roundId: state.roundId,
        value: value,
      );
      if (snapshot != null) {
        await _snapshotStorage?.saveReplySnapshot(
          ownerUid: ownerUid,
          worldId: worldId,
          locationId: state.locationId,
          roundId: state.roundId,
          value: snapshot,
          isCurrent: () =>
              !_disposed &&
              state._generation == generation &&
              state._cardsCacheVersion == cacheVersion,
        );
      }
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  void _invalidateCardsCache(ChatroomReplyRoundState state) {
    state._cardsCacheVersion++;
    state._cardsNeedRefresh = true;
    state._query++;
    state._cardsFetch = null;
    final hadCache = state._cachedCards != null;
    state._cachedCards = null;
    state._cardsCachedAt = null;
    if (hadCache) _background(state, () => _persist(state));
  }

  void invalidateCardsOnDisconnect() {
    for (final location in locationIds.toList()) {
      for (final state in statesFor(location)) {
        _cancelRegenerationWatchdog(state);
        _invalidateCardsCache(state);
      }
    }
  }

  /// Invalidates network reuse while retaining complete display content and receipts.
  Future<void> clearCardsCache(
    String locationId, {
    int? start,
    int? end,
  }) async {
    // Mark current states immediately so pending disk/network reads cannot revive them.
    for (final state in statesFor(locationId)) {
      if ((start == null || state.roundId >= start) &&
          (end == null || state.roundId <= end)) {
        _invalidateCardsCache(state);
      }
    }
    await restore(locationId);
    _checkCurrent();
    for (final state in statesFor(locationId)) {
      if ((start == null || state.roundId >= start) &&
          (end == null || state.roundId <= end)) {
        _invalidateCardsCache(state);
        await _persist(state);
      }
    }
  }

  Future<void> _loadCards(
    ChatroomReplyRoundState state, {
    bool Function()? isCurrent,
    bool force = false,
  }) async {
    if (force) {
      // An authoritative recovery read must never fall back to stale data on error.
      if (state._cachedCards != null) _invalidateCardsCache(state);
    }
    final generation = state._generation;
    final cacheVersion = state._cardsCacheVersion;
    final query = ++state._query;
    var fetched = force ? null : state._cachedCards;
    if (fetched == null) {
      final fetch = state._cardsFetch ??= _http.getLlmCards(
        worldId: worldId,
        locationId: state.locationId,
        conversationRoundId: state.roundId,
      );
      try {
        fetched = await fetch;
      } finally {
        if (identical(state._cardsFetch, fetch)) state._cardsFetch = null;
      }
    }
    final result = fetched;
    _checkCurrent();
    if (generation != state._generation ||
        cacheVersion != state._cardsCacheVersion ||
        query != state._query ||
        (isCurrent != null && !isCurrent())) {
      return;
    }
    if (result.list.every((card) => _terminal(card.generationState))) {
      state._cardsCachedAt ??= _now().millisecondsSinceEpoch;
      state._cachedCards = result;
    }
    await _applyCards(state, result);
  }

  Future<void> _applyCards(
    ChatroomReplyRoundState state,
    ChatroomLlmCardsResponse result, {
    bool persist = true,
  }) async {
    state._cardsNeedRefresh = false;
    state._cardsResponse = result;
    state._selectedCardId = result.selectedCardId;
    state._confirmed = result.confirmed;
    final unresolved = state._card(-1);
    if (unresolved != null &&
        result.activeCardId > 0 &&
        result.list.any(
          (card) =>
              card.cardId == result.activeCardId &&
              card.cardIndex >= unresolved.cardIndex,
        )) {
      if (state._viewedCardId == -1) state._viewedCardId = result.activeCardId;
      state._cards.removeWhere((card) => card.cardId == -1);
    }
    final pending = state._cards
        .where(
          (card) =>
              !result.list.any((item) => item.cardId == card.cardId) &&
              (card.cardId == state._fixedCardId ||
                  card.cardId < 0 ||
                  (card.cardId == 0 && result.list.isEmpty) ||
                  !_terminal(card.generationState)),
        )
        .toList();
    state._cards
      ..clear()
      ..addAll(result.list)
      ..addAll(pending);
    state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
    for (final card in result.list) {
      if (_terminal(card.generationState)) {
        state._streamMessages.remove(card.cardId);
        state._cardTerminals.remove(card.cardId);
        state._authoritativeCards.add(card.cardId);
      }
    }
    if (state._card(state._viewedCardId) == null) {
      final nextView = result.selectedCardId > 0
          ? result.selectedCardId
          : result.originalCardId;
      if (nextView != state._viewedCardId) {
        state._viewedCardId = nextView;
        state._presentationRevision++;
      }
    }
    if (_completeCard(state.viewedCard)) {
      state._lastCompleteCardId = state._viewedCardId;
    }
    state._generating = state._cards.any(
      (card) => !_terminal(card.generationState),
    );
    if (!state._generating) {
      state._cardsNeedRefresh = false;
      state._regenerationRequestId = null;
      _cancelRegenerationWatchdog(state);
    } else if (state._regenerationRequestId != null) {
      final activeCardId = result.activeCardId > 0
          ? result.activeCardId
          : state._watchedRegenerationCardId;
      if (activeCardId != null && activeCardId > 0) {
        _watchRegeneration(state, activeCardId);
      }
    }
    if (persist) await _persist(state);
    _notify(state.locationId);
  }

  Future<void> browse(String locationId, int delta) async {
    final state = stateFor(locationId);
    if (state == null || !state.canSwitchCards || delta == 0) {
      return;
    }
    final index = state._cards.indexWhere(
      (card) => card.cardId == state.viewedCardId,
    );
    final next = index + delta;
    if (next < 0 || next >= state._cards.length) return;
    state._viewedCardId = state._cards[next].cardId;
    if (_completeCard(state.viewedCard)) {
      state._lastCompleteCardId = state.viewedCardId;
    }
    state._presentationRevision++;
    _notify(state.locationId);
    await _persist(state);
  }

  Future<ChatroomReplyRoundState> _target(String locationId) async {
    _checkCurrent();
    final state = stateFor(locationId);
    if (state == null) throw StateError('No identified conversation round');
    return state;
  }

  Future<void> finalizeBeforeSend(
    String locationId, {
    ChatroomInspirationSource? expectedSource,
  }) async {
    void verify() {
      if (expectedSource != null &&
          !expectedSource.sameOrigin(stateFor(locationId)?.inspirationSource)) {
        throw StateError('The reply changed. Please select inspiration again.');
      }
    }

    verify();
    final existing = _finalizations[locationId];
    if (existing != null) {
      await existing;
      verify();
      return;
    }
    if (expectedSource != null) {
      final sourceState = stateFor(locationId)!;
      if (sourceState.hasCardGroup && !sourceState.confirmed) {
        sourceState._fixedCardId = sourceState.viewedCardId;
        sourceState._frozen = true;
      }
    }
    final task = _finalizeLocation(locationId);
    _finalizations[locationId] = task;
    await task.whenComplete(() {
      if (identical(_finalizations[locationId], task)) {
        _finalizations.remove(locationId);
      }
    });
    verify();
  }

  Future<void> _finalizeLocation(String locationId) async {
    _checkCurrent();
    final targets =
        statesFor(locationId)
            .where(
              (state) =>
                  state.showCandidates ||
                  (state.frozen) ||
                  state._drafts.isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.roundId.compareTo(b.roundId));
    for (final state in targets) {
      if (!state._supportsReplyActions) continue;
      if (state.busy) throw StateError('A reply is currently being saved');
      state._fixedCardId ??= _completeCard(state.viewedCard)
          ? state.viewedCardId
          : state.lastCompleteCardId;
      state._frozen = true;
      state._busy = true;
      state._error = null;
      _notify(state.locationId);
      try {
        await _persist(state);
        await _loadCards(state, force: true);
        if (state.confirmed &&
            state._selectionRequestId != null &&
            state.selectedCardId == state._fixedCardId) {
          // GET can recover our successful selection after its ACK was lost.
          // Only retire alternatives; a remaining selected-card draft still
          // needs the conflict path below and must never be silently dropped.
          _retireAlternativeDrafts(state, state.selectedCardId);
          state._retainSelectedCardPresentation = true;
          state._selectedCardPromotedToFormal =
              state._formalHistoryContainsSelectedCard;
        }
        if (!state.confirmed && state.hasCardGroup) {
          final id = state._fixedCardId!;
          final card = state._card(id);
          if (!_completeCard(card)) {
            throw StateError('No complete candidate is available to confirm');
          }
          await _saveDraft(state, _editor(state, cardId: id));
          _invalidateCardsCache(state);
          final createdSelectionRequest = state._selectionRequestId == null;
          state._selectionRequestId ??= _request('select');
          try {
            await _persist(state);
          } catch (_) {
            if (createdSelectionRequest) state._selectionRequestId = null;
            rethrow;
          }
          final result = await _http.selectLlmCard(
            worldId: worldId,
            locationId: locationId,
            conversationRoundId: state.roundId,
            cardId: id,
            clientMsgId: state._selectionRequestId!,
          );
          _checkCurrent();
          state._selectedCardId = result.selectedCardId;
          state._confirmed = true;
          state._viewedCardId = result.selectedCardId;
          state._retainSelectedCardPresentation = true;
          state._selectedCardPromotedToFormal =
              state._formalHistoryContainsSelectedCard;
          _retireAlternativeDrafts(state, result.selectedCardId);
        } else if (!state.hasCardGroup &&
            state._drafts[0]?.isNotEmpty == true) {
          await _saveDraft(state, _editor(state));
        } else if (state.confirmed) {
          if (state._drafts.entries.any(
            (entry) => entry.key > 0 && entry.value.isNotEmpty,
          )) {
            throw StateError(
              'This card was confirmed before its draft could be saved',
            );
          }
          if (state._drafts[0]?.isNotEmpty == true) {
            await _saveDraft(state, _editor(state));
          }
          // A select ACK may have been lost; GET confirmed proves selection.
          // Formal history is reconciled only by conversation_range_updated.
        }
        state._fixedCardId = null;
        state._selectionRequestId = null;
        state._frozen = false;
        state._completionRevision++;
        state._presentationRevision++;
        await _persist(state);
      } catch (error) {
        if (_disposed) rethrow;
        if (_definiteRejection(error)) {
          state._error = error;
          _releaseFailedFinalization(state);
          await _persist(state);
          rethrow;
        }
        final recovered = await _recoverUncertainFinalization(state);
        if (recovered) {
          state._error = null;
        } else {
          state._error = error;
          if (!_finalizationIsUncertain(state)) {
            _releaseFailedFinalization(state);
          }
          await _persist(state);
          rethrow;
        }
      } finally {
        state._busy = false;
        _notify(state.locationId);
      }
    }
  }

  bool _finalizationIsUncertain(ChatroomReplyRoundState state) =>
      state._selectionRequestId != null || state._uncertainBatches.isNotEmpty;

  void _releaseFailedFinalization(ChatroomReplyRoundState state) {
    state._selectionRequestId = null;
    state._fixedCardId = null;
    state._frozen = false;
  }

  /// Reconciles a dispatched batch/select through read-only authoritative data.
  /// Returns true only when the whole confirmation is proven complete.
  Future<bool> _recoverUncertainFinalization(
    ChatroomReplyRoundState state,
  ) async {
    if (!_finalizationIsUncertain(state)) return false;
    try {
      await _loadCards(state, force: true);
      _checkCurrent();
      for (final key in state._uncertainBatches.toList()) {
        final operations = state._drafts[key] ?? const [];
        final current = key == 0
            ? List<WorldChatroomMessage>.of(state._formal)
            : state._card(key)?.messages.map(_candidateToWorld).toList();
        if (current != null && _operationsApplied(operations, current)) {
          state._drafts.remove(key);
          state._draftBaselines.remove(key);
          state._uncertainBatches.remove(key);
        }
      }
      final fixedCardId = state._fixedCardId;
      if (state._selectionRequestId == null ||
          fixedCardId == null ||
          !state.confirmed ||
          state.selectedCardId != fixedCardId ||
          state._drafts[fixedCardId]?.isNotEmpty == true ||
          state._uncertainBatches.contains(fixedCardId)) {
        await _persist(state);
        return false;
      }
      _retireAlternativeDrafts(state, fixedCardId);
      state._retainSelectedCardPresentation = true;
      state._selectedCardPromotedToFormal =
          state._formalHistoryContainsSelectedCard;
      state._fixedCardId = null;
      state._selectionRequestId = null;
      state._frozen = false;
      state._completionRevision++;
      state._presentationRevision++;
      await _persist(state);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _retireAlternativeDrafts(
    ChatroomReplyRoundState state,
    int selectedCardId,
  ) {
    bool isAlternative(int cardId) => cardId > 0 && cardId != selectedCardId;
    state._drafts.removeWhere((cardId, _) => isAlternative(cardId));
    state._draftBaselines.removeWhere((cardId, _) => isAlternative(cardId));
    state._uncertainBatches.removeWhere(isAlternative);
  }

  bool _hasPendingGoOn(String location) =>
      statesFor(location).any((state) => state.goOnPending);
  ChatroomSession _requireSession() =>
      _session() ?? (throw StateError('Chatroom is disconnected'));

  void receiveEvent(ChatroomEvent event) =>
      batchChanges(() => _receiveEvent(event));

  void _receiveEvent(ChatroomEvent event) {
    if (_disposed) return;
    if (event is ChatroomAck) {
      if (event.ok) {
        _receiveLateRegenerationAck(event);
      } else {
        _receiveRejectedReplyAck(event);
      }
      return;
    }
    if (event is ChatroomLlmMessageUpdated) {
      if (event.worldId == worldId && event.errNo == 0) {
        unawaited(clearCardsCache(event.locationId).catchError((Object _) {}));
      }
      return;
    }
    if (event is ChatroomLlmCardStream) {
      if (event.worldId != worldId || event.triggerUid != ownerUid) return;
      final state = _state(event.locationId, event.conversationRoundId);
      _mergeRoundMetadata(
        state,
        conversationType: '',
        triggerUid: event.triggerUid,
      );
      if (state.confirmed || state._authoritativeCards.contains(event.cardId)) {
        return;
      }
      if (state._viewedCardId == -1) state._viewedCardId = event.cardId;
      state._cards.removeWhere((card) => card.cardId == -1);
      if (state._card(event.cardId) == null) {
        final index =
            state._cards.fold<int>(
              0,
              (v, c) => c.cardIndex > v ? c.cardIndex : v,
            ) +
            1;
        state._cards.add(_placeholder(event.cardId, index));
      }
      final streams = state._streamMessages.putIfAbsent(event.cardId, () => {});
      final isNewMessage = !streams.containsKey(event.globalMessageId);
      final message = streams.putIfAbsent(
        event.globalMessageId,
        () => _CandidateMessage(event),
      );
      final receivedChunk = message._receivedChunk;
      final contentChanged = message.apply(event);
      _noteRegenerationStream(state, event.cardId);
      if (isNewMessage) {
        state._streamStructureRevisions.update(
          event.cardId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (isNewMessage || contentChanged) {
        state._dirtyStreamMessages
            .putIfAbsent(event.cardId, () => {})
            .add(event.globalMessageId);
        state._streamContentRevisions.update(
          event.cardId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (receivedChunk != message._receivedChunk) {
        state._streamReceiptRevision++;
      } else if (!isNewMessage && !contentChanged) {
        return;
      }
      _invalidateCardsCache(state);
      ++state._generation;
      final terminal = state._cardTerminals[event.cardId];
      if (terminal != null) {
        _completeLocalCard(state, terminal);
        _background(state, () => _persist(state));
      }
      _notify(state.locationId);
    } else if (event is ChatroomLlmCardGenerationEnd) {
      if (event.worldId != worldId || event.triggerUid != ownerUid) return;
      final state = _state(event.locationId, event.conversationRoundId);
      if (state.confirmed ||
          state._authoritativeCards.contains(event.cardId) ||
          state._cardTerminals.containsKey(event.cardId)) {
        return;
      }
      _invalidateCardsCache(state);
      ++state._generation;
      state._cardTerminals[event.cardId] = event;
      _completeLocalCard(state, event);
      if (state._generating && state._regenerationRequestId != null) {
        _watchRegeneration(state, event.cardId, streamStarted: true);
      }
      _notify(state.locationId);
      _background(state, () async {
        await _persist(state);
        await _refreshRegenerationOutcome(
          state,
          event.cardId,
          reloadCards:
              event.generationState == ChatroomCardGenerationState.failed,
        );
      });
    } else if (event is ChatroomWaitingConversationRound) {
      if (event.worldId != worldId) return;
      final round = int.tryParse(event.conversationRoundId);
      if (round == null || round <= 0) return;
      final state = _state(event.locationId, round);
      _mergeRoundMetadata(
        state,
        conversationType: event.conversationType,
        triggerUid: event.triggerUid,
      );
      if (!state._ended) state._active = true;
      if (round > (_latest[event.locationId] ?? 0)) {
        _latest[event.locationId] = round;
      }
      _notify(state.locationId);
    } else if (event is ChatroomEndConversationRound) {
      if (event.worldId != worldId) return;
      final round = int.tryParse(event.conversationRoundId);
      if (round == null || round <= 0) return;
      final state = _state(event.locationId, round);
      state._active = false;
      state._ended = true;
      state._roundFailed = !event.ok;
      _mergeRoundMetadata(
        state,
        conversationType: event.conversationType,
        triggerUid: event.triggerUid,
      );
      for (final source in statesFor(event.locationId)) {
        if (source.goOnPending && source.goOnRoundId == round) {
          source._goOn!.ended = true;
          _background(source, () async {
            await _persist(source);
            await _recoverGoOn(source);
          });
        }
      }
      _notify(state.locationId);
    } else if (event is ChatroomErrorEvent) {
      if (event.worldId != worldId) return;
      for (final state in statesFor(event.locationId)) {
        final pending = state._goOn;
        final eventRound = int.tryParse(event.conversationRoundId);
        if (pending != null &&
            ((event.clientMsgId.isNotEmpty &&
                    event.clientMsgId == pending.clientMsgId) ||
                (eventRound != null && eventRound == pending.roundId))) {
          state._error = event;
          if (!pending.finished) {
            pending.finished = true;
            _cancelGoOnWatchdog(state);
            _rollbackGoOnRound(state);
            final round = pending.roundId;
            if (round != null) _onGoOnFinished?.call(state.locationId, round);
            _background(state, () => _persist(state));
          }
          _notify(state.locationId);
        }
      }
    } else if (event is ChatroomTickAdvanceMessage) {
      if (event.worldId != worldId ||
          !_rememberTick(event.tickNo, event.subTickNo)) {
        return;
      }
      final tickRound = int.tryParse(event.conversationRoundId);
      for (final location in _states.keys.toList()) {
        for (final state in statesFor(location)) {
          // The canonical Tick may arrive after its own AI reply. It closes
          // earlier sources, but must not invalidate the Tick source itself.
          if (tickRound == null ||
              tickRound <= 0 ||
              state.roundId != tickRound) {
            state._invalidated = true;
          }
        }
        _freezeFromExternal(location, null);
      }
    } else if (event is ChatroomAiStreamStart) {
      if (event.worldId != worldId) return;
      final round = int.tryParse(event.conversationRoundId);
      if (round == null ||
          round <= 0 ||
          event.globalMessageId <= 0 ||
          !_remember('message:${event.locationId}:${event.globalMessageId}')) {
        return;
      }
      _mergeRoundMetadata(
        _state(event.locationId, round),
        conversationType: event.conversationType,
        triggerUid: event.triggerUid,
      );
      for (final source in statesFor(event.locationId)) {
        if (source.goOnPending && source.goOnRoundId == round) {
          _noteGoOnStreamStarted(source);
        }
      }
      _freezeFromExternal(event.locationId, round);
    } else if (event is ChatroomUserEnterLocationMessage) {
      if (event.worldId != worldId) return;
      final round = int.tryParse(event.conversationRoundId);
      if (round == null ||
          round <= 0 ||
          event.globalMessageId <= 0 ||
          !_remember('message:${event.locationId}:${event.globalMessageId}')) {
        return;
      }
      final state = _state(event.locationId, round);
      _mergeRoundMetadata(
        state,
        conversationType: event.conversationType,
        triggerUid: event.triggerUid,
      );
      _freezeFromExternal(event.locationId, round);
    } else if (event is ChatroomUserMessage) {
      if (event.worldId != worldId) return;
      final round = int.tryParse(event.conversationRoundId);
      if (round == null || round <= 0) return;
      final state = _state(event.locationId, round);
      _mergeRoundMetadata(
        state,
        conversationType: event.conversationType,
        triggerUid: event.triggerUid,
      );
      final id = event.globalMessageId > 0
          ? event.globalMessageId
          : event.locationMessageId;
      if (id <= 0 || !_remember('message:${event.locationId}:$id')) return;
      _freezeFromExternal(event.locationId, round);
    } else if (event is ChatroomNarratorMessage) {
      if (event.worldId != worldId) return;
      final round = int.tryParse(event.conversationRoundId);
      if (round == null || round <= 0) return;
      _mergeRoundMetadata(
        _state(event.locationId, round),
        conversationType: event.conversationType,
        triggerUid: event.triggerUid,
      );
      final id = event.globalMessageId > 0
          ? event.globalMessageId
          : event.locationMessageId;
      if (id > 0 && _remember('message:${event.locationId}:$id')) {
        _freezeFromExternal(event.locationId, round);
      }
    }
  }

  void _completeLocalCard(
    ChatroomReplyRoundState state,
    ChatroomLlmCardGenerationEnd event,
  ) {
    final old = state._card(event.cardId);
    final streams = state._streamMessages[event.cardId]?.values.toList()
      ?..sort((a, b) => a.index.compareTo(b.index));
    final failed = event.generationState == ChatroomCardGenerationState.failed;
    final complete =
        !failed &&
        streams != null &&
        streams.isNotEmpty &&
        streams.every((m) => m._ended);
    state._cards.removeWhere(
      (card) => card.cardId == event.cardId || card.cardId == -1,
    );
    state._cards.add(
      _assembledCard(
        state,
        event.cardId,
        old?.cardIndex ?? state._cards.length + 1,
        failed
            ? const []
            : (streams ?? [])
                  .map((m) => m.toMessage(state.locationId, state.roundId))
                  .toList(),
        billing: event.billing,
        generation: !failed && !complete
            ? ChatroomCardGenerationState.generating
            : event.generationState,
        editable: complete,
        error: event.error,
      ),
    );
    state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
    if (failed &&
        (state._viewedCardId == -1 || state._viewedCardId == event.cardId)) {
      state._viewedCardId = state._lastCompleteCardId;
      state._presentationRevision++;
    } else if (state._viewedCardId == -1) {
      state._viewedCardId = event.cardId;
    }
    if (failed || complete) {
      state._authoritativeCards.add(event.cardId);
      state._streamMessages.remove(event.cardId);
    }
    if (failed) state._regenerateDispatching = false;
    state._generating = state._cards.any(
      (card) => !_terminal(card.generationState),
    );
    if (!state._generating) {
      state._cardsNeedRefresh = false;
      state._regenerationRequestId = null;
      _cancelRegenerationWatchdog(state);
    }
    state._error = failed
        ? event.errNo != 0
              ? event
              : ChatroomFailureEvent(
                  code: chatroomCardFailureCode(event.error).toString(),
                  message: event.errMsg.isNotEmpty
                      ? event.errMsg
                      : chatroomCardFailureMessage(event.error),
                  requestType: 'regenerate_llm_card',
                  sourceType: 'llm_card_generation_end',
                  cause: event,
                )
        : complete
        ? null
        : StateError('Candidate content is incomplete; reload to recover');
    if (complete && state._viewedCardId == event.cardId) {
      state._lastCompleteCardId = event.cardId;
    }
  }

  Future<void> _refreshRegenerationOutcome(
    ChatroomReplyRoundState state,
    int cardId, {
    required bool reloadCards,
  }) async {
    if (!_remember(
      'candidate-refresh:${state.locationId}:${state.roundId}:$cardId',
    )) {
      return;
    }
    if (reloadCards && !_disposed) {
      try {
        await _loadCards(state, force: true);
      } catch (_) {
        // Keep the confirmed failed candidate and original reply if recovery
        // is unavailable. Never replace the useful business error with GET's.
      }
    }
    await _refreshWalletAfterOutcome();
  }

  Future<void> _refreshWalletAfterOutcome() async {
    if (_disposed || _refreshWallet == null) return;
    try {
      await _refreshWallet();
    } catch (_) {
      // A wallet refresh cannot change an already confirmed request outcome.
    }
  }

  Future<void> _refreshRejectedReplyBalance(
    ChatroomReplyRoundState state,
    String requestId,
  ) async {
    if (!_remember('request-balance:${state.locationId}:$requestId')) return;
    await _refreshWalletAfterOutcome();
  }

  void _receiveRejectedReplyAck(ChatroomAck ack) {
    if ((ack.worldId.isNotEmpty && ack.worldId != worldId) ||
        ack.clientMsgId.isEmpty ||
        ack.regeneration != null) {
      return;
    }
    for (final states in _states.values) {
      for (final state in states.values) {
        if (ack.locationId.isNotEmpty && ack.locationId != state.locationId) {
          continue;
        }
        String? operation;
        if (state._regenerationRequestId == ack.clientMsgId) {
          operation = 'regenerate_llm_card';
          // Invalidate a timeout recovery GET/future before releasing the
          // source, so neither can clobber a subsequent explicit operation.
          ++state._regenerationDispatchGeneration;
          ++state._generation;
          state._regenerationRequestId = null;
          state._regenerateDispatching = false;
          state._cards.removeWhere((card) => card.cardId <= 0);
          state._viewedCardId = state._lastCompleteCardId;
          state._presentationRevision++;
          state._generating = state._cards.any(
            (card) => !_terminal(card.generationState),
          );
          if (!state._generating) _cancelRegenerationWatchdog(state);
        } else if (state._goOn case final pending?
            when pending.clientMsgId == ack.clientMsgId &&
                pending.roundId == null &&
                !pending.finished) {
          operation = 'go_on';
          ++state._goOnDispatchGeneration;
          state._goOn = null;
          state._busy = false;
          _cancelGoOnWatchdog(state);
        }
        if (operation == null) continue;
        state._error = ChatroomFailureEvent.fromPayloadEvent(
          ack,
          requestType: operation,
        );
        _notify(state.locationId);
        _background(state, () async {
          await _persist(state);
          if (isChatroomBalanceFailureCode(ack.code.toString())) {
            await _refreshRejectedReplyBalance(state, ack.clientMsgId);
          }
        });
        return;
      }
    }
  }

  ChatroomLlmCard _assembledCard(
    ChatroomReplyRoundState state,
    int id,
    int index,
    List<WorldChatroomMessage> messages, {
    required ChatroomCardBilling billing,
    bool isOriginal = false,
    bool editable = true,
    ChatroomCardGenerationState generation =
        ChatroomCardGenerationState.succeeded,
    Object? error,
  }) => ChatroomLlmCard(
    cardId: id,
    cardIndex: index,
    isOriginal: isOriginal,
    generationState: generation,
    canEdit: editable,
    canDelete: editable,
    messages: [
      for (final (position, message) in messages.indexed)
        ChatroomLlmCardMessage(
          cardId: id,
          cardMessageIndex: isOriginal ? position + 1 : message.roundOrder,
          isLlmStreamMessage: message.isLlmStreamMessage,
          message: ChatroomV2Message(
            type: message.businessType,
            worldId: worldId,
            locationId: state.locationId,
            conversationRoundId: state.roundId,
            conversationType: message.conversationType,
            triggerUid: message.triggerUid,
            globalMessageId: message.globalMessageId,
            userId: message.userId,
            senderId: message.senderId,
            senderName: message.senderName,
            senderType: message.senderType,
            messageType: message.messageType,
            currentTime: message.currentTime,
            ts: message.createdAt?.millisecondsSinceEpoch,
            payload: {
              ...message.rawPayload,
              'content': message.content,
              'current_time': message.currentTime,
            },
          ),
          rawJson: const {},
        ),
    ],
    billing: billing,
    createdAt: '',
    rawJson: const {},
    error: error,
  );

  bool _rememberTick(int tick, int subTick) {
    if (tick < _latestTick ||
        (tick == _latestTick && subTick <= _latestSubTick)) {
      return false;
    }
    _latestTick = tick;
    _latestSubTick = subTick;
    return true;
  }

  bool _remember(String key) {
    if (!_seenEvents.add(key)) return false;
    if (_seenEvents.length > 1000) _seenEvents.remove(_seenEvents.first);
    return true;
  }

  void _freezeFromExternal(String location, int? incomingRound) {
    final targets = statesFor(location)
        .where(
          (state) =>
              state._supportsReplyActions &&
              (state.showCandidates || state._drafts.isNotEmpty) &&
              (incomingRound == null || incomingRound > state.roundId),
        )
        .toList();
    if (targets.isEmpty) return;
    for (final state in targets) {
      state._fixedCardId ??= _completeCard(state.viewedCard)
          ? state.viewedCardId
          : state.lastCompleteCardId;
      state._frozen = true;
    }
    _notify(location);
    if (targets.any((state) => state.busy || state._regenerateDispatching)) {
      for (final state in targets) {
        _background(state, () => _persist(state));
      }
      return;
    }
    _background(targets.first, () => finalizeBeforeSend(location));
  }

  void _background(
    ChatroomReplyRoundState state,
    Future<void> Function() work,
  ) {
    unawaited(
      Future.sync(work).catchError((Object error) {
        if (!_disposed) {
          state._error = error;
          _notify(state.locationId);
        }
      }),
    );
  }

  void _watchRegeneration(
    ChatroomReplyRoundState state,
    int cardId, {
    bool streamStarted = false,
  }) {
    _cancelRegenerationWatchdog(state);
    final card = state._card(cardId);
    if (_disposed || card == null || _terminal(card.generationState)) return;
    state._watchedRegenerationCardId = cardId;
    state._regenerationStreamStarted =
        streamStarted || (state._streamMessages[cardId]?.isNotEmpty ?? false);
    if (state._regenerationStreamStarted) {
      state._regenerationStreamEndTimer = Timer(
        _regenerationStreamEndTimeout,
        () => _recoverTimedOutRegeneration(state, cardId),
      );
    } else {
      state._regenerationStreamStartTimer = Timer(
        _regenerationStreamStartTimeout,
        () => _recoverTimedOutRegeneration(state, cardId),
      );
    }
  }

  void _noteRegenerationStream(ChatroomReplyRoundState state, int cardId) {
    if (state._regenerationRequestId == null ||
        (state._watchedRegenerationCardId != null &&
            state._watchedRegenerationCardId != cardId)) {
      return;
    }
    if (state._regenerationStreamStarted &&
        state._watchedRegenerationCardId == cardId) {
      return;
    }
    state._regenerationStreamStartTimer?.cancel();
    state._regenerationStreamStartTimer = null;
    state._watchedRegenerationCardId = cardId;
    state._regenerationStreamStarted = true;
    state._regenerationStreamEndTimer?.cancel();
    state._regenerationStreamEndTimer = Timer(
      _regenerationStreamEndTimeout,
      () => _recoverTimedOutRegeneration(state, cardId),
    );
  }

  void _recoverTimedOutRegeneration(ChatroomReplyRoundState state, int cardId) {
    final card = state._card(cardId);
    if (_disposed ||
        state._regenerationRequestId == null ||
        state._watchedRegenerationCardId != cardId ||
        card == null ||
        _terminal(card.generationState)) {
      _cancelRegenerationWatchdog(state);
      return;
    }
    state._regenerationStreamStartTimer = null;
    state._regenerationStreamEndTimer = null;
    // A stream event racing the recovery GET must be able to arm a fresh
    // end watchdog even if the stale HTTP response is discarded.
    state._regenerationStreamStarted = false;
    final requestId = state._regenerationRequestId!;
    unawaited(_recoverTimedOutRegenerationFromCards(state, cardId, requestId));
  }

  Future<void> _recoverTimedOutRegenerationFromCards(
    ChatroomReplyRoundState state,
    int cardId,
    String requestId,
  ) async {
    try {
      await _loadCards(state, force: true);
    } catch (error) {
      if (_disposed || state._regenerationRequestId != requestId) return;
      await _failRegenerationLocally(state, cardId, error);
    }
  }

  Future<void> _failRegenerationLocally(
    ChatroomReplyRoundState state,
    int cardId,
    Object error,
  ) async {
    _cancelRegenerationWatchdog(state);
    final card = state._card(cardId);
    if (cardId <= 0) {
      state._cards.removeWhere((item) => item.cardId <= 0);
      state._viewedCardId = state._lastCompleteCardId;
    } else if (card != null && !_terminal(card.generationState)) {
      state._cards.remove(card);
      state._cards.add(
        _assembledCard(
          state,
          card.cardId,
          card.cardIndex,
          const [],
          billing: card.billing,
          editable: false,
          generation: ChatroomCardGenerationState.failed,
          error: error,
        ),
      );
      state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
    }
    state._regenerationRequestId = null;
    state._regenerateDispatching = false;
    state._generating = state._cards.any(
      (item) => !_terminal(item.generationState),
    );
    state._error = error;
    try {
      await _persist(state);
    } catch (_) {
      // A local terminal state must still release the action controls.
    }
    _notify(state.locationId);
  }

  void _cancelRegenerationWatchdog(ChatroomReplyRoundState state) {
    state._regenerationStreamStartTimer?.cancel();
    state._regenerationStreamEndTimer?.cancel();
    state._regenerationStreamStartTimer = null;
    state._regenerationStreamEndTimer = null;
    state._watchedRegenerationCardId = null;
    state._regenerationStreamStarted = false;
  }

  void _watchGoOn(
    ChatroomReplyRoundState source, {
    bool streamStarted = false,
  }) {
    _cancelGoOnWatchdog(source);
    final pending = source._goOn;
    if (_disposed ||
        pending == null ||
        pending.finished ||
        pending.roundId == null) {
      return;
    }
    source._goOnStreamStarted = streamStarted;
    if (streamStarted) {
      source._goOnStreamEndTimer = Timer(
        _goOnStreamEndTimeout,
        () => _recoverTimedOutGoOn(source, pending),
      );
    } else {
      source._goOnStreamStartTimer = Timer(
        _goOnStreamStartTimeout,
        () => _recoverTimedOutGoOn(source, pending),
      );
    }
  }

  void _noteGoOnStreamStarted(ChatroomReplyRoundState source) {
    final pending = source._goOn;
    if (pending == null || pending.finished || pending.roundId == null) return;
    if (source._goOnStreamStarted && source._goOnStreamEndTimer != null) {
      return;
    }
    _watchGoOn(source, streamStarted: true);
  }

  void _recoverTimedOutGoOn(
    ChatroomReplyRoundState source,
    _PendingGoOn pending,
  ) {
    if (_disposed || !identical(source._goOn, pending) || pending.finished) {
      _cancelGoOnWatchdog(source);
      return;
    }
    final message = source._goOnStreamStarted
        ? 'Go on did not finish. Please try again.'
        : 'Go on did not start. Please try again.';
    _cancelGoOnWatchdog(source);
    unawaited(_recoverOrFinishTimedOutGoOn(source, pending, message));
  }

  Future<void> _recoverOrFinishTimedOutGoOn(
    ChatroomReplyRoundState source,
    _PendingGoOn pending,
    String message,
  ) async {
    try {
      await _recoverGoOn(
        source,
        finishIfIncomplete: true,
        incompleteError: StateError(message),
      );
    } catch (_) {
      if (_disposed || !identical(source._goOn, pending) || pending.finished) {
        return;
      }
      pending.finished = true;
      source._error = StateError(message);
      _rollbackGoOnRound(source);
      final round = pending.roundId;
      if (round != null) _onGoOnFinished?.call(source.locationId, round);
      try {
        await _persist(source);
      } catch (_) {
        // The in-memory terminal state must still unlock the UI.
      }
      _notify(source.locationId);
    }
  }

  void _cancelGoOnWatchdog(ChatroomReplyRoundState source) {
    source._goOnStreamStartTimer?.cancel();
    source._goOnStreamEndTimer?.cancel();
    source._goOnStreamStartTimer = null;
    source._goOnStreamEndTimer = null;
    source._goOnStreamStarted = false;
  }

  void _rollbackGoOnRound(ChatroomReplyRoundState source) {
    final round = source._goOn?.roundId;
    if (round == null) return;
    final states = _states[source.locationId];
    final next = states?[round];
    if (next != null) next._active = false;
    if (round != source.roundId) states?.remove(round);
    final remaining = states?.keys.toList() ?? const <int>[];
    _latest[source.locationId] = remaining.isEmpty
        ? source.roundId
        : remaining.reduce((a, b) => a > b ? a : b);
  }

  Future<void> _recoverGoOn(
    ChatroomReplyRoundState source, {
    bool finishIfIncomplete = false,
    Object? incompleteError,
  }) async {
    final pending = source._goOn;
    if (pending == null || pending.finished) return;
    if (pending.roundId == null) {
      // There is no query-by-client-id API. Keep the lock until a correlated
      // terminal event can prove success or failure, without refreshing or
      // automatically resending this non-idempotent request.
      source._error ??= StateError(
        'Could not confirm Go on. Waiting to recover its result.',
      );
      await _persist(source);
      _notify(source.locationId);
      return;
    }
    final round = pending.roundId!;
    final next = _state(source.locationId, round);
    final messages = next._formal
        .where((message) => !message.streaming)
        .toList(growable: false);
    if (!messages.any(_isReply)) {
      // The contract commits a successful round atomically. Persisted AI
      // replies prove success even when end was lost; an empty/non-AI result
      // does not prove that an accepted request failed.
      if (!finishIfIncomplete) return;
      pending.finished = true;
      source._error =
          incompleteError ??
          StateError('Go on did not finish. Please try again.');
      _rollbackGoOnRound(source);
      _onGoOnFinished?.call(source.locationId, round);
      await _persist(source);
      _notify(source.locationId);
      return;
    }
    next._formal = messages;
    next._active = false;
    next._ended = true;
    pending.finished = true;
    _cancelGoOnWatchdog(source);
    source._error = messages.any(_isReply)
        ? null
        : StateError('No usable reply was persisted');
    next._error = source._error;
    if (!messages.any(_isReply)) _rollbackGoOnRound(source);
    _onGoOnFinished?.call(source.locationId, round);
    await _persist(source);
    _notify(source.locationId);
    if (_refreshWallet != null) {
      try {
        await _refreshWallet();
      } catch (_) {
        // Wallet availability must not undo a recovered, persisted round.
      }
    }
  }

  Future<void> reconnect() async {
    for (final location in _states.keys.toList()) {
      if (!_isReady(location)) continue;
      for (final state in statesFor(location)) {
        try {
          if (state.hasCardGroup ||
              state._regenerationRequestId != null ||
              state.frozen) {
            await _loadCards(state, force: true);
          }
          if (state.frozen) {
            await finalizeBeforeSend(location);
          }
          await _recoverGoOn(state);
        } catch (error) {
          if (!_disposed) state._error = error;
        }
      }
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final location in _states.keys.toList()) {
      for (final state in statesFor(location)) {
        _cancelRegenerationWatchdog(state);
        _cancelGoOnWatchdog(state);
      }
    }
    for (final channel in _locationChanges.values) {
      channel.dispose();
    }
    _locationChanges.clear();
    _pendingLocations.clear();
    unawaited(_writes.then((_) => _storage.close()).catchError((Object _) {}));
    super.dispose();
  }
}

class _PendingGoOn {
  _PendingGoOn(
    this.clientMsgId, {
    this.roundId,
    this.finished = false,
    this.uncertain = false,
    this.ended = false,
  });
  final String clientMsgId;
  int? roundId;
  bool finished;
  bool uncertain;
  bool ended;
  Map<String, dynamic> toJson() => {
    'client_msg_id': clientMsgId,
    'round_id': roundId,
    'finished': finished,
    'uncertain': uncertain,
    'ended': ended,
  };
  factory _PendingGoOn.fromJson(Map<String, dynamic> json) => _PendingGoOn(
    json['client_msg_id'] as String,
    roundId: json['round_id'] as int?,
    finished: json['finished'] == true,
    uncertain: json['round_id'] == null && json['finished'] != true,
    ended: json['ended'] == true,
  );
}

class _CandidateMessage {
  _CandidateMessage(ChatroomLlmCardStream event)
    : id = event.globalMessageId,
      index = event.cardMessageIndex,
      senderType = event.senderType,
      senderId = event.senderId,
      senderName = event.senderName,
      userId = event.userId,
      triggerUid = event.triggerUid,
      currentTime = event.currentTime,
      ts = event.ts;
  final int id, index;
  final String senderType,
      senderId,
      senderName,
      userId,
      triggerUid,
      currentTime;
  final int? ts;
  final _chunks = <int, String>{};
  String _content = '';
  int _revision = 0;
  int? _lastSequence;
  bool _needsMerge = false;
  bool _ended = false;
  bool _receivedChunk = false;
  WorldChatroomMessage? _snapshot;

  bool apply(ChatroomLlmCardStream event) {
    if (_ended || event.cardMessageIndex != index) return false;
    if (event.streamType == 'chunk') {
      _receivedChunk = true;
      final sequence = event.seq!;
      if (_chunks.containsKey(sequence)) return false;
      _chunks[sequence] = event.content;
      if (!_needsMerge &&
          (_lastSequence == null || sequence > _lastSequence!)) {
        _content += event.content;
      } else {
        _needsMerge = true;
      }
      if (_lastSequence == null || sequence > _lastSequence!) {
        _lastSequence = sequence;
      }
      if (event.content.isEmpty) return false;
    } else if (event.streamType == 'end') {
      _content = event.content;
      _needsMerge = false;
      _ended = true;
      _chunks.clear();
    } else {
      return false;
    }
    _snapshot = null;
    _revision++;
    return true;
  }

  WorldChatroomMessage toMessage(String location, int round) {
    if (_snapshot != null) return _snapshot!;
    if (_needsMerge) {
      final sequence = _chunks.keys.toList()..sort();
      _content = sequence.map((key) => _chunks[key]).join();
      _needsMerge = false;
    }
    return _snapshot = WorldChatroomMessage(
      globalMessageId: id,
      messageId: 0,
      locationMessageId: 0,
      conversationRoundId: '$round',
      triggerUid: triggerUid,
      roundOrder: index,
      locationId: location,
      senderType: senderType,
      businessType: senderType,
      senderId: senderId,
      senderName: senderName,
      userId: userId,
      content: _content,
      currentTime: currentTime,
      messageType: senderId == 'nar_pic' ? 'image' : 'text',
      createdAt: ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts!),
      streaming: !_ended,
      isLlmStreamMessage: true,
    );
  }
}

bool _isReply(WorldChatroomMessage message) =>
    !const {
      'user',
      'tick',
      'user_enter_location',
      'characters_moved',
      'story_events',
      'world_notification',
    }.contains(message.businessType) &&
    (const {'character', 'narrator', 'llm'}.contains(message.businessType) ||
        const {'character', 'narrator', 'ai'}.contains(message.senderType));
bool _terminal(ChatroomCardGenerationState state) =>
    state == ChatroomCardGenerationState.succeeded ||
    state == ChatroomCardGenerationState.failed;
bool _completeCard(ChatroomLlmCard? card) =>
    card != null &&
    card.generationState == ChatroomCardGenerationState.succeeded &&
    card.messages.isNotEmpty;
WorldChatroomMessage _candidateToWorld(ChatroomLlmCardMessage message) =>
    WorldChatroomMessage.fromHttpMessage(
      ChatroomHttpMessage.fromV2Message(message.message),
    ).copyWith(isLlmStreamMessage: message.isLlmStreamMessage);
ChatroomLlmCard _placeholder(
  int id,
  int index, {
  ChatroomCardGenerationState generationState =
      ChatroomCardGenerationState.generating,
}) => ChatroomLlmCard(
  cardId: id,
  cardIndex: index,
  isOriginal: false,
  generationState: generationState,
  canEdit: false,
  canDelete: false,
  messages: const [],
  billing: const ChatroomCardBilling(
    status: ChatroomCardBillingStatus.notStarted,
  ),
  createdAt: '',
  rawJson: const {},
);
ChatroomLlmMessageOperation _operationFromJson(Object? value) {
  final json = Map<String, dynamic>.from(value as Map);
  final id = json['global_message_id'] as int;
  return json['action'] == 'delete'
      ? ChatroomLlmMessageOperation.delete(globalMessageId: id)
      : ChatroomLlmMessageOperation.edit(
          globalMessageId: id,
          content: json['content'] as String,
        );
}

bool _operationsApplied(
  List<ChatroomLlmMessageOperation> operations,
  List<WorldChatroomMessage> current,
) {
  final messages = {
    for (final message in current) message.globalMessageId: message,
  };
  return operations.every(
    (operation) => operation.action == ChatroomLlmMessageAction.delete
        ? !messages.containsKey(operation.globalMessageId)
        : messages[operation.globalMessageId]?.content == operation.content,
  );
}

bool _unchangedTargets(
  List<ChatroomLlmMessageOperation> operations,
  Map<int, String> before,
  List<WorldChatroomMessage> current,
) {
  final after = {
    for (final message in current) message.globalMessageId: message.content,
  };
  return operations.every(
    (operation) =>
        before.containsKey(operation.globalMessageId) &&
        after.containsKey(operation.globalMessageId) &&
        before[operation.globalMessageId] == after[operation.globalMessageId],
  );
}

bool _definiteRejection(Object error) =>
    error is ArgumentError ||
    error is ChatroomErrorEvent && error.errNo != null ||
    error is ChatroomFailureEvent && int.tryParse(error.code) != null ||
    error is ApiException && error.kind == ApiExceptionKind.business;

Map<String, Object?> _operationToDraftJson(ChatroomLlmMessageOperation op) => {
  'action': op.action.name,
  'global_message_id': op.globalMessageId,
  if (op.action == ChatroomLlmMessageAction.edit) 'content': op.content,
};

bool _sameOperations(
  List<ChatroomLlmMessageOperation> a,
  List<ChatroomLlmMessageOperation> b,
) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every(
      (i) =>
          a[i].action == b[i].action &&
          a[i].globalMessageId == b[i].globalMessageId &&
          a[i].content == b[i].content,
    );
