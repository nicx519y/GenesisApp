part of 'location_chat_page.dart';

final class _LocationChatAnalyticsAttempt {
  _LocationChatAnalyticsAttempt({
    required this.action,
    required this.worldId,
    required this.locationId,
  });

  final String action;
  final String worldId;
  final String locationId;
  bool _finished = false;

  bool get finished => _finished;

  void record(String object3) {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: action,
      object1: worldId,
      object2: locationId,
      object3: object3,
    );
  }

  void finish(String object3) {
    if (_finished) return;
    _finished = true;
    record(object3);
  }
}

final class _LocationChatRegenerateAnalyticsAttempt
    extends _LocationChatAnalyticsAttempt {
  _LocationChatRegenerateAnalyticsAttempt({
    required super.worldId,
    required super.locationId,
    required this.roundId,
    required this.baselineCardIds,
  }) : super(action: 'location_chat_regenerate');

  final int roundId;
  final Set<int> baselineCardIds;
}

final class _LocationChatGoOnAnalyticsAttempt
    extends _LocationChatAnalyticsAttempt {
  _LocationChatGoOnAnalyticsAttempt({
    required super.worldId,
    required super.locationId,
    required this.sourceRoundId,
  }) : super(action: 'location_chat_go_on');

  final int sourceRoundId;
}

final class _LocationChatEditAnalyticsAttempt
    extends _LocationChatAnalyticsAttempt {
  _LocationChatEditAnalyticsAttempt({
    required super.worldId,
    required super.locationId,
    required this.roundId,
  }) : super(action: 'location_chat_edit');

  final int roundId;
}

enum _LocationChatInspirationAnalyticsPhase { loading, displayed, sending }

final class _LocationChatInspirationAnalyticsAttempt
    extends _LocationChatAnalyticsAttempt {
  _LocationChatInspirationAnalyticsAttempt({
    required super.worldId,
    required super.locationId,
    required this.sourceRoundId,
  }) : super(action: 'location_chat_inspiration');

  final int sourceRoundId;
  _LocationChatInspirationAnalyticsPhase phase =
      _LocationChatInspirationAnalyticsPhase.loading;
}

int _locationChatConsumedCardCount(ChatroomReplyRoundState? state) =>
    state?.cards.where((card) => card.cardId > 0).length ?? 0;

bool _locationChatTelemetryBalanceInsufficient(Object error) {
  if (error is ChatroomLlmCardGenerationEnd) {
    return isChatroomBalanceFailureCode(error.errNo.toString()) ||
        isChatroomBalanceFailureCode(
          chatroomCardFailureCode(error.error, fallback: 0).toString(),
        );
  }
  if (error is ChatroomFailureEvent) {
    return isChatroomBalanceFailureCode(error.code);
  }
  if (error is ChatroomErrorEvent) {
    return isChatroomBalanceFailureCode(error.code) ||
        (error.errNo != null &&
            isChatroomBalanceFailureCode(error.errNo.toString()));
  }
  if (error is ApiException && error.code != null) {
    return isChatroomBalanceFailureCode(error.code.toString());
  }
  return false;
}

bool _locationChatTelemetryUnknown(Object error) {
  if (error is TimeoutException) return true;
  if (error is ApiException) {
    return const {
      ApiExceptionKind.unknown,
      ApiExceptionKind.transport,
      ApiExceptionKind.timeout,
      ApiExceptionKind.cancelled,
    }.contains(error.kind);
  }
  if (error is ChatroomFailureEvent) {
    if (_locationChatTelemetryUnknownCode(error.code) ||
        _locationChatTelemetryUnknownCode(error.sourceType) ||
        _locationChatTelemetryUnknownText(error.message)) {
      return true;
    }
    final cause = error.cause;
    return cause != null &&
        !identical(cause, error) &&
        _locationChatTelemetryUnknown(cause);
  }
  if (error is ChatroomErrorEvent) {
    final cause = error.cause;
    return _locationChatTelemetryUnknownCode(error.code) ||
        _locationChatTelemetryUnknownCode(error.sourceType) ||
        _locationChatTelemetryUnknownText(error.message) ||
        (cause != null &&
            !identical(cause, error) &&
            _locationChatTelemetryUnknown(cause));
  }
  return _locationChatTelemetryUnknownText(error.toString());
}

bool _locationChatTelemetryUnknownText(String value) {
  final message = value.toLowerCase();
  return message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('did not start') ||
      message.contains('did not finish') ||
      message.contains('could not confirm') ||
      message.contains('socket closed') ||
      message.contains('socket error') ||
      message.contains('socketexception') ||
      message.contains('connection reset') ||
      message.contains('connection closed') ||
      message.contains('failed host lookup') ||
      message.contains('disconnected');
}

bool _locationChatTelemetryUnknownCode(String value) => const {
  'ack_timeout',
  'closed',
  'connect_failed',
  'disconnect',
  'socket_closed',
  'socket_error',
  'stream_missing',
}.contains(value.trim().toLowerCase());

extension _LocationChatReplyAnalytics on _LocationChatPanelState {
  void _recordLocationChatAnalytics(String action, String object3) {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: action,
      object1: widget.worldId,
      object2: widget.locationId,
      object3: object3,
    );
  }

  _LocationChatRegenerateAnalyticsAttempt _beginRegenerateAnalytics() {
    final state = _displayReplyState;
    final previous = _regenerateAnalyticsAttempt;
    if (previous != null && !previous.finished) {
      previous.finish('unknown|${_locationChatConsumedCardCount(state)}');
    }
    final attempt = _LocationChatRegenerateAnalyticsAttempt(
      worldId: widget.worldId,
      locationId: widget.locationId,
      roundId: state?.roundId ?? 0,
      baselineCardIds: {
        for (final card in state?.cards ?? const <ChatroomLlmCard>[])
          if (card.cardId > 0) card.cardId,
      },
    );
    _regenerateAnalyticsAttempt = attempt;
    attempt.record('click|${_locationChatConsumedCardCount(state)}');
    return attempt;
  }

  void _recordRegenerateLimit() {
    final count = _locationChatConsumedCardCount(_displayReplyState);
    _recordLocationChatAnalytics('location_chat_regenerate', 'click|$count');
    _recordLocationChatAnalytics('location_chat_regenerate', 'limit|$count');
  }

  void _finishRegenerateAnalyticsFromError(
    _LocationChatRegenerateAnalyticsAttempt attempt,
    Object error,
  ) {
    final state = _replyController?.stateForRound(
      attempt.locationId,
      attempt.roundId,
    );
    final count = _locationChatConsumedCardCount(state);
    final status = _locationChatTelemetryBalanceInsufficient(error)
        ? 'balance_insufficient'
        : _locationChatTelemetryUnknown(error)
        ? 'unknown'
        : 'failed';
    attempt.finish('$status|$count');
  }

  _LocationChatGoOnAnalyticsAttempt _beginGoOnAnalytics() {
    final sourceRoundId = _displayReplyState?.roundId ?? 0;
    final previous = _goOnAnalyticsAttempt;
    if (previous != null && !previous.finished) {
      previous.finish('unknown|${previous.sourceRoundId}');
    }
    final attempt = _LocationChatGoOnAnalyticsAttempt(
      worldId: widget.worldId,
      locationId: widget.locationId,
      sourceRoundId: sourceRoundId,
    );
    _goOnAnalyticsAttempt = attempt;
    attempt.record('click|$sourceRoundId');
    return attempt;
  }

  void _finishGoOnAnalyticsFromError(
    _LocationChatGoOnAnalyticsAttempt attempt,
    Object error,
  ) {
    final source = _replyController?.stateForRound(
      attempt.locationId,
      attempt.sourceRoundId,
    );
    final newRoundId = source?.goOnRoundId ?? 0;
    if (_locationChatTelemetryBalanceInsufficient(error)) {
      attempt.finish('balance_insufficient|${attempt.sourceRoundId}');
    } else if (_locationChatTelemetryUnknown(error)) {
      attempt.finish('unknown|$newRoundId');
    } else {
      attempt.finish('failed|$newRoundId');
    }
  }

  _LocationChatInspirationAnalyticsAttempt _beginInspirationAnalytics() {
    final sourceRoundId = _displayReplyState?.roundId ?? 0;
    final previous = _inspirationAnalyticsAttempt;
    if (previous != null && !previous.finished) {
      previous.finish('unknown');
    }
    final attempt = _LocationChatInspirationAnalyticsAttempt(
      worldId: widget.worldId,
      locationId: widget.locationId,
      sourceRoundId: sourceRoundId,
    );
    _inspirationAnalyticsAttempt = attempt;
    attempt.record('click|$sourceRoundId');
    return attempt;
  }

  _LocationChatEditAnalyticsAttempt _beginEditAnalytics() {
    final roundId = _displayReplyState?.roundId ?? 0;
    final attempt = _LocationChatEditAnalyticsAttempt(
      worldId: widget.worldId,
      locationId: widget.locationId,
      roundId: roundId,
    );
    attempt.record('edit_click|$roundId');
    return attempt;
  }

  void _finishEditAnalyticsFromError(
    _LocationChatEditAnalyticsAttempt attempt,
    Object _,
  ) {
    attempt.finish('edit_failed|${attempt.roundId}');
  }

  void _finishInspirationAnalytics(
    _LocationChatInspirationAnalyticsAttempt? attempt,
    String result,
  ) {
    if (attempt == null) return;
    attempt.finish(result);
    if (identical(_inspirationAnalyticsAttempt, attempt)) {
      _inspirationAnalyticsAttempt = null;
    }
  }

  void _finishInspirationAnalyticsFromError(
    _LocationChatInspirationAnalyticsAttempt? attempt,
    Object error,
  ) {
    _finishInspirationAnalytics(
      attempt,
      _locationChatTelemetryUnknown(error) ? 'unknown' : 'failed',
    );
  }

  void _syncReplyAnalyticsOutcomes() {
    final controller = _replyController;
    if (controller == null) return;

    final regenerate = _regenerateAnalyticsAttempt;
    if (regenerate != null && !regenerate.finished) {
      final state = controller.stateForRound(
        regenerate.locationId,
        regenerate.roundId,
      );
      if (state != null) {
        final generated = state.cards.any(
          (card) =>
              card.cardId > 0 &&
              !card.isOriginal &&
              !regenerate.baselineCardIds.contains(card.cardId) &&
              card.generationState == ChatroomCardGenerationState.succeeded &&
              card.messages.any((message) => message.content.trim().isNotEmpty),
        );
        if (generated) {
          regenerate.finish('success|${_locationChatConsumedCardCount(state)}');
        } else if (!state.generating && state.error != null) {
          _finishRegenerateAnalyticsFromError(regenerate, state.error!);
        }
      }
    }

    final goOn = _goOnAnalyticsAttempt;
    if (goOn != null && !goOn.finished) {
      final source = controller.stateForRound(
        goOn.locationId,
        goOn.sourceRoundId,
      );
      if (source != null && !source.goOnPending) {
        final newRoundId = source.goOnRoundId ?? 0;
        final next = newRoundId > 0
            ? controller.stateForRound(goOn.locationId, newRoundId)
            : null;
        final hasPersistedReply =
            next?.complete == true &&
            next!.formalReplyMessages.any(
              (message) => message.content.trim().isNotEmpty,
            );
        if (source.error case final error?) {
          _finishGoOnAnalyticsFromError(goOn, error);
        } else if (hasPersistedReply) {
          goOn.finish('success|$newRoundId');
        }
      }
    }
  }

  void _finishPendingReplyAnalyticsForDetach() {
    final regenerate = _regenerateAnalyticsAttempt;
    if (regenerate != null && !regenerate.finished) {
      final state = _replyController?.stateForRound(
        regenerate.locationId,
        regenerate.roundId,
      );
      regenerate.finish('unknown|${_locationChatConsumedCardCount(state)}');
    }
    final goOn = _goOnAnalyticsAttempt;
    if (goOn != null && !goOn.finished) {
      final source = _replyController?.stateForRound(
        goOn.locationId,
        goOn.sourceRoundId,
      );
      goOn.finish('unknown|${source?.goOnRoundId ?? 0}');
    }
  }
}
