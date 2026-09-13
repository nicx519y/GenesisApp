part of 'world_chatroom_service.dart';

enum ChatroomEntryPhase { preparing, ready, failed }

class ChatroomEntrySnapshot {
  ChatroomEntrySnapshot({
    required Iterable<WorldChatroomMessage> messages,
    required this.reply,
    required this.actions,
    required this.retainedReplies,
    required this.historyGeneration,
  }) : messages = List.unmodifiable(messages);
  final List<WorldChatroomMessage> messages;
  final ChatroomReplyRoundState? reply;
  final ChatroomReplyRoundState? actions;
  final List<ChatroomReplyRoundState> retainedReplies;
  final int historyGeneration;
}

class ChatroomLocationEntry {
  const ChatroomLocationEntry({
    this.phase = ChatroomEntryPhase.preparing,
    this.snapshot,
    this.error,
    this.revision = 0,
  });
  final ChatroomEntryPhase phase;
  final ChatroomEntrySnapshot? snapshot;
  final Object? error;
  final int revision;
}

extension WorldChatroomEntry on WorldChatroomService {
  ValueListenable<ChatroomLocationEntry> entryForLocation(String locationId) =>
      _entryChannel(locationId);

  ValueNotifier<ChatroomLocationEntry> _entryChannel(String locationId) =>
      _entryChannels.putIfAbsent(
        locationId,
        () => ValueNotifier(const ChatroomLocationEntry()),
      );

  /// Read local content before the network phase. Does not join or send anything.
  Future<void> prepareLocalEntry(
    String locationId, {
    Iterable<String> aliases = const [],
  }) {
    if (_entryLocalReady.contains(locationId)) return Future.value();
    final ticket = _historyTicket(locationId);
    final key = (locationId, ticket);
    return _entryLocalReads.putIfAbsent(key, () async {
      _beginEntryRead(locationId);
      Object? failure;
      try {
        await hydrateLocalMessages(
          worldId: _worldId,
          locationId: locationId,
          locationAliases: aliases,
        );
        if (!_historyIsCurrent(locationId, ticket)) return;
        await replyActions?.restore(locationId);
        if (!_historyIsCurrent(locationId, ticket)) return;
        _entryLocalReady.add(locationId);
      } catch (error) {
        failure = error;
        rethrow;
      } finally {
        _endEntryRead(locationId, ticket, error: failure, localOnly: true);
        _entryLocalReads.remove(key);
      }
    });
  }

  void _beginEntryRead(String location) {
    final key = (location, _historyTicket(location));
    if (!_entryReadDepth.containsKey(key)) _entryReadErrors.remove(key);
    _entryReadDepth.update(key, (depth) => depth + 1, ifAbsent: () => 1);
    final channel = _entryChannel(location);
    channel.value = ChatroomLocationEntry(
      snapshot: channel.value.snapshot,
      revision: channel.value.revision + 1,
    );
  }

  void _endEntryRead(
    String location,
    _HistoryTicket ticket, {
    Object? error,
    bool localOnly = false,
  }) {
    final key = (location, ticket);
    if (error != null) _entryReadErrors[key] = error;
    final depth = (_entryReadDepth[key] ?? 1) - 1;
    if (depth <= 0) {
      _entryReadDepth.remove(key);
    } else {
      _entryReadDepth[key] = depth;
    }
    if (depth > 0) return;
    final batchError = _entryReadErrors.remove(key);
    if (!_historyIsCurrent(location, ticket)) return;
    error ??= batchError;
    if (error != null) {
      final channel = _entryChannel(location);
      channel.value = ChatroomLocationEntry(
        phase: ChatroomEntryPhase.failed,
        snapshot: (channel.value.snapshot?.messages.isNotEmpty ?? false)
            ? channel.value.snapshot
            : _captureEntry(location, includeReply: false),
        error: error,
        revision: channel.value.revision + 1,
      );
    } else if (!localOnly ||
        ((_state.messagesByLocation[location]?.isNotEmpty ?? false) &&
            (replyActions?.historyCardsResolved(location) ?? true))) {
      _entryLocalReady.add(location);
      _publishEntry(location);
    }
  }

  ChatroomEntrySnapshot _captureEntry(
    String location, {
    bool includeReply = true,
  }) => ChatroomEntrySnapshot(
    messages: _state.messagesByLocation[location] ?? const [],
    reply: includeReply
        ? _replyActionsController?.snapshotForPresentation(location)
        : null,
    actions: includeReply
        ? _replyActionsController?.snapshotForActions(location)
        : null,
    retainedReplies: includeReply
        ? _replyActionsController?.snapshotRetainedPresentations(location) ??
              const []
        : const [],
    historyGeneration: _state.historyGenerationByLocation[location] ?? 0,
  );

  void _publishEntry(String location) {
    if (_disposed ||
        (_entryReadDepth[(location, _historyTicket(location))] ?? 0) > 0) {
      return;
    }
    final channel = _entryChannel(location);
    channel.value = ChatroomLocationEntry(
      phase: ChatroomEntryPhase.ready,
      snapshot: _captureEntry(location),
      revision: channel.value.revision + 1,
    );
  }

  /// Called after history observation and reply changes; only changed locations publish.
  void _syncEntrySnapshots() {
    if (_disposed) return;
    for (final location in _entryLocalReady) {
      if ((_entryReadDepth[(location, _historyTicket(location))] ?? 0) > 0) {
        continue;
      }
      final entry = _entryChannel(location).value;
      if (entry.phase == ChatroomEntryPhase.failed) {
        final previousRound =
            entry.snapshot?.messages.fold<int>(
              0,
              (latest, m) => math.max(latest, m.conversationRoundNumber),
            ) ??
            0;
        final currentReply = _replyActionsController?.stateFor(location);
        if (currentReply == null ||
            !currentReply.complete ||
            currentReply.roundId <= previousRound) {
          continue;
        }
      }
      if (entry.snapshot == null &&
          ((_state.messagesByLocation[location]?.isEmpty ?? true) ||
              !(replyActions?.historyCardsResolved(location) ?? true))) {
        continue;
      }
      final messages = _state.messagesByLocation[location];
      final revisions = _replyActionsController?.revisionsForLocation(location);
      final key = (
        messages,
        revisions,
        _state.historyGenerationByLocation[location],
      );
      if (_entrySources[location] == key) continue;
      _entrySources[location] = key;
      _publishEntry(location);
    }
  }

  void _clearEntrySnapshots() {
    _entrySources.clear();
    _entryLocalReady.clear();
    _entryLocalReads.clear();
    for (final channel in _entryChannels.values) {
      channel.value = ChatroomLocationEntry(
        revision: channel.value.revision + 1,
      );
    }
  }
}
