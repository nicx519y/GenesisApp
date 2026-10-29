import 'package:flutter/foundation.dart';

import '../../components/chat/shared/chat_ui.dart' show ChatMessageVm;
import '../../utils/llm_generation.dart';
import 'location_chat_reply_card.dart';

class _OutgoingAttempt {
  _OutgoingAttempt(
    this.attempt,
    this.messages,
    this.index,
    this.release,
    this.cardId,
    this.cardBindingIdentity,
  );

  final LlmAttempt attempt;
  final List<ChatMessageVm> messages;
  final int index;
  final VoidCallback release;
  final int? cardId;
  final Object? cardBindingIdentity;
}

/// Owns reply presentation lifetime, independently of viewport and animations.
/// The view supplies frozen, actually visible rows and reports their exit.
/// Network state is never delayed or changed by this controller.
class LocationChatReplyRetractionController {
  LocationChatReplyRetractionController({required this.onRetract});

  final ValueChanged<LlmAttempt> onRetract;
  final _listeners = <LlmAttempt, VoidCallback>{};
  final _outgoing = <LlmAttempt, _OutgoingAttempt>{};
  final _retrySources = <LlmGenerationId, LlmAttempt>{};
  List<ChatMessageVm> _messages = const [];
  List<LocationChatReplyCard> _cards = const [];
  Object? _session, _operation, _binding;
  int _regenerationRevision = 0, _cardId = 0, _revision = 0;
  bool _regenerateOperation = false, _readOnly = false, _initialized = false;
  List<ChatMessageVm>? _currentMessages, _projectedMessages;
  List<LocationChatReplyCard>? _projectedCards;
  LocationChatReplyCard? _currentCard;
  bool _currentCardResolved = false;
  Set<String>? _currentCardMessageIds;
  _RetractionProjection? _cachedProjection;
  _RetractionProjection get _projection =>
      _cachedProjection ??= _RetractionProjection(_outgoing.values, _binding);
  bool _observationsDirty = true;

  /// Called once per input update, even when the source reuses mutable VMs.
  /// Animation/layout rebuilds reuse the resulting projection. Inactive cards
  /// stay lazy and are resolved at most once per projection if requested.
  void update({
    required List<ChatMessageVm> messages,
    required List<LocationChatReplyCard> cards,
    required int currentCardId,
    required Object? cardBindingIdentity,
    required Object sessionIdentity,
    required Object? operationIdentity,
    required int regenerationRevision,
    required bool regenerationInProgress,
    required bool readOnly,
  }) {
    final sessionChanged = _initialized && _session != sessionIdentity;
    final regenerationDispatched =
        _initialized && _regenerationRevision != regenerationRevision;
    final operationChanged =
        sessionChanged ||
        regenerationDispatched ||
        (operationIdentity != null && _operation != operationIdentity);
    if (operationChanged) {
      _regenerateOperation = false;
      _retrySources.clear();
    }
    if (sessionChanged || readOnly) {
      release();
    } else if (_initialized &&
        (_cardId != currentCardId || _binding != cardBindingIdentity)) {
      // Ordinary Go On output belongs to its generation, not the source deck.
      release(candidatesOnly: true);
    }
    if (regenerationInProgress || regenerationDispatched) {
      _regenerateOperation = true;
    }
    _initialized = true;
    _messages = messages;
    _cards = cards;
    _cardId = currentCardId;
    _binding = cardBindingIdentity;
    _session = sessionIdentity;
    _operation = operationIdentity;
    _regenerationRevision = regenerationRevision;
    _readOnly = readOnly;
    _currentMessages = null;
    _invalidateProjection();
  }

  List<ChatMessageVm> get _rawCurrentMessages => _currentMessages ??=
      _cards.where((c) => c.id == _cardId).firstOrNull?.messages ?? const [];

  Iterable<ChatMessageVm> get incomingMessages sync* {
    yield* _messages;
    yield* _rawCurrentMessages;
  }

  void observeAttempts() {
    if (_readOnly || !_observationsDirty) return;
    _observationsDirty = false;
    final wanted =
        incomingMessages
            .map((m) => m.llmAttempt)
            .whereType<LlmAttempt>()
            .toSet()
          ..addAll(_outgoing.keys);
    for (final attempt in _listeners.keys.toList()) {
      if (!wanted.contains(attempt)) {
        attempt.removeListener(_listeners.remove(attempt)!);
      }
    }
    for (final attempt in wanted) {
      if (_listeners.containsKey(attempt) || attempt.invalidated) continue;
      void listener() => onRetract(attempt);
      _listeners[attempt] = listener;
      attempt.addListener(listener);
    }
  }

  bool canRetract(LlmAttempt attempt) =>
      !_readOnly &&
      attempt.animateRetraction &&
      !_outgoing.containsKey(attempt);

  void beginRetraction(
    LlmAttempt attempt, {
    required List<ChatMessageVm> snapshots,
    required int index,
    required int? cardId,
  }) {
    if (!canRetract(attempt)) return;
    _retrySources[attempt.generation] = attempt;
    if (attempt.generation.card != null) _regenerateOperation = true;
    if (snapshots.isEmpty) return;
    _outgoing[attempt] = _OutgoingAttempt(
      attempt,
      List.of(snapshots),
      index,
      attempt.retainPresentation(),
      cardId,
      _binding,
    );
    _invalidateProjection();
  }

  /// A replacement is ready only after the entire generation has exited.
  /// Late callbacks from released cards/pages are harmless.
  ({bool changed, bool generationFinished}) finishMessage(
    LlmAttempt attempt,
    ChatMessageVm message,
  ) {
    final outgoing = _outgoing[attempt];
    if (outgoing == null || !outgoing.messages.remove(message)) {
      return (changed: false, generationFinished: false);
    }
    final finished = outgoing.messages.isEmpty;
    if (finished) _outgoing.remove(attempt);
    _invalidateProjection();
    if (finished) outgoing.release();
    return (
      changed: true,
      generationFinished:
          finished &&
          !_outgoing.keys.any((a) => a.generation == attempt.generation),
    );
  }

  // Regenerate suppression survives network completion and reveal drain until
  // a new user operation. Layout-transition suppression is supplied by the view.
  bool suppressWaiting({required bool layoutPending}) =>
      _outgoing.isNotEmpty || _regenerateOperation || layoutPending;

  LlmGenerationId? get waitingGeneration {
    if (_retrySources.isEmpty || _outgoing.isNotEmpty || _regenerateOperation) {
      return null;
    }
    final withContent = incomingMessages
        .where(
          (m) =>
              m.llmAttempt?.invalidated == false &&
              (m.text.isNotEmpty || m.isImage),
        )
        .map((m) => m.llmAttempt!.generation)
        .toSet();
    for (final attempt in _retrySources.values.toList().reversed) {
      if (attempt.generation.card == null &&
          !attempt.terminal &&
          !attempt.waitingExpired &&
          !withContent.contains(attempt.generation)) {
        return attempt.generation;
      }
    }
    return null;
  }

  List<ChatMessageVm> get messages =>
      _projectedMessages ??= _projection.project(_messages);

  List<LocationChatReplyCard> get cards => _projectedCards ??= _outgoing.isEmpty
      ? _cards
      : [for (final card in _cards) _projectCard(card)];

  LocationChatReplyCard? get currentCard {
    if (!_currentCardResolved) {
      _currentCard = cards.where((c) => c.id == _cardId).firstOrNull;
      _currentCardResolved = true;
    }
    return _currentCard;
  }

  Set<String> get currentCardMessageIds => _currentCardMessageIds ??=
      currentCard?.messages.map((m) => m.localId).toSet() ?? <String>{};

  LocationChatReplyCard _projectCard(LocationChatReplyCard card) {
    // Capture this projection's state. An old lazy card may still be read by
    // the card switcher after a later input update or animation callback.
    final projection = _projection;
    final currentMessages = card.id == _cardId ? _rawCurrentMessages : null;
    List<ChatMessageVm>? projected;
    return LocationChatReplyCard.lazy(
      id: card.id,
      resolveMessages: () => projected ??= projection.project(
        currentMessages ?? card.messages,
        cardId: card.id,
      ),
      status: projection.ownsCard(card.id) ? null : card.status,
      contentIdentity: (card.contentIdentity, _revision),
    );
  }

  void _invalidateProjection() {
    _revision++;
    _cachedProjection = null;
    _observationsDirty = true;
    _projectedMessages = null;
    _projectedCards = null;
    _currentCard = null;
    _currentCardResolved = false;
    _currentCardMessageIds = null;
  }

  void release({bool candidatesOnly = false}) {
    bool matches(LlmAttempt a) => !candidatesOnly || a.generation.card != null;
    for (final attempt in _listeners.keys.where(matches).toList()) {
      attempt.removeListener(_listeners.remove(attempt)!);
    }
    _retrySources.removeWhere((_, attempt) => matches(attempt));
    final removed = _outgoing.keys.where(matches).toList();
    final leases = [for (final attempt in removed) _outgoing.remove(attempt)!];
    _invalidateProjection();
    for (final outgoing in leases) {
      outgoing.release();
    }
  }

  void dispose() => release();
}

// One stable structural snapshot per input/exit revision. It deliberately keeps
// mutable incoming VMs live; the adapter freezes only the outgoing content.
class _RetractionProjection {
  _RetractionProjection(Iterable<_OutgoingAttempt> attempts, this.binding)
    : outgoing = [
        for (final a in attempts)
          (
            generation: a.attempt.generation,
            messages: List<ChatMessageVm>.unmodifiable(a.messages),
            index: a.index,
            cardId: a.cardId,
            binding: a.cardBindingIdentity,
          ),
      ];

  final Object? binding;
  final List<
    ({
      LlmGenerationId generation,
      List<ChatMessageVm> messages,
      int index,
      int? cardId,
      Object? binding,
    })
  >
  outgoing;
  late final generations = outgoing.map((o) => o.generation).toSet();

  bool ownsCard(int id) =>
      outgoing.any((o) => o.cardId == id && o.binding == binding);

  List<ChatMessageVm> project(List<ChatMessageVm> incoming, {int? cardId}) {
    if (outgoing.isEmpty) return incoming;
    // Buffer across ALL containers; ownership only controls snapshot placement.
    final result = incoming
        .where((m) => !generations.contains(m.llmAttempt?.generation))
        .toList();
    for (final row in outgoing) {
      if (cardId != null && (row.cardId != cardId || row.binding != binding)) {
        continue;
      }
      final first = incoming.indexWhere(
        (m) => m.llmAttempt?.generation == row.generation,
      );
      final index = cardId != null
          ? 0
          : (first < 0 ? row.index : first).clamp(0, result.length);
      result.insertAll(index, row.messages);
    }
    return result;
  }
}
