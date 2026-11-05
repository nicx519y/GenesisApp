part of 'world_chatroom_service.dart';

extension _WorldChatroomSync on WorldChatroomService {
  Iterable<(String, Object)> _liveMessageKeys(
    WorldChatroomMessage message,
  ) sync* {
    if (message.globalMessageId > 0) {
      yield (message.locationId, ('global', message.globalMessageId));
    }
    if (message.locationMessageId > 0) {
      yield (message.locationId, ('location', message.locationMessageId));
    }
    if (message.clientMsgId.isNotEmpty) {
      yield (message.locationId, ('client', message.clientMsgId));
    }
    if (message.globalMessageId <= 0 &&
        message.locationMessageId <= 0 &&
        message.clientMsgId.isEmpty) {
      yield (
        message.locationId,
        ('stream', message.conversationRoundId, message.senderId),
      );
    }
  }

  int _liveRevisionFor(WorldChatroomMessage message) =>
      _liveMessageKeys(message).fold(
        0,
        (revision, key) => math.max(revision, _liveMessageRevisions[key] ?? 0),
      );

  void _invalidateMessageSync() {
    _messageSyncGeneration++;
    _messageSyncCancellation.cancel();
    _messageSyncCancellation = NetworkCancellationToken();
    _entryNetworkVerified.clear();
    _latestMessageFetchFutures.clear();
    _connectionSyncAttempted.clear();
    _failedLocationSyncs.clear();
    _liveLocationSyncRetryCounts.clear();
    _releasedLocationGaps.clear();
    _entryReadDepth.clear();
    _entryReadErrors.clear();
    _liveMessageRevisions.clear();
    // Keep unfinished ranges so reconnect can retry the authoritative read.
    for (final refresh in _historyRefreshes.values) {
      refresh.cancel();
      refresh.complete();
    }
  }

  bool _messageConnectionIsCurrent(int generation) =>
      !_disposed &&
      !_userDisconnected &&
      _session != null &&
      generation == _messageSyncGeneration;

  void _scheduleConnectionLocationSync() {
    if (!_state.connected ||
        _state.world?.worldId != _worldId ||
        !_messageConnectionIsCurrent(_messageSyncGeneration)) {
      return;
    }
    final locations = _leafLocationIdsForCurrentWorld()
        .where(_connectionSyncAttempted.add)
        .toList();
    if (locations.isEmpty) return;
    final generation = _messageSyncGeneration;
    // State publication may happen inside range invalidation. Defer work until
    // that caller has installed its new range request, avoiding reentrancy.
    unawaited(
      Future<void>.microtask(() async {
        if (!_messageConnectionIsCurrent(generation)) return;
        for (final location in locations) {
          if (_historyRefreshes[location]?.token.isCancelled == true) {
            _restartPendingHistory(location);
          }
        }
        await initializeLeafLocationQueues(locationIds: locations);
      }).catchError((Object error) {
        if (!_messageConnectionIsCurrent(generation)) return;
        _recordServiceQueueDebug(
          action: 'connectionSyncFailed',
          locationId: '',
          details: {'error': '$error'},
        );
      }),
    );
  }

  /// All synchronization reads share this limit, including overlapping callers.
  Future<T> _withMessageReadSlot<T>(
    Future<T> Function() read,
    bool Function() current,
    NetworkCancellationToken cancellation,
  ) async {
    while (_messageReadsActive >= _defaultLocationQueueInitConcurrency) {
      final waiter = Completer<void>();
      _messageReadWaiters.add(waiter);
      try {
        await _untilMessageSyncCancelled(waiter.future, cancellation);
      } finally {
        _messageReadWaiters.remove(waiter);
      }
    }
    if (!current()) throw const NetworkRequestCancelledException();
    _messageReadsActive++;
    try {
      return await _untilMessageSyncCancelled(read(), cancellation);
    } finally {
      _messageReadsActive--;
      if (_messageReadWaiters.isNotEmpty) {
        final waiter = _messageReadWaiters.removeFirst();
        if (!waiter.isCompleted) waiter.complete();
      }
    }
  }

  Future<T> _untilMessageSyncCancelled<T>(
    Future<T> future,
    NetworkCancellationToken cancellation,
  ) async {
    final cancelled = Completer<T>();
    final removeListener = cancellation.addCancelListener(() {
      if (!cancelled.isCompleted) {
        cancelled.completeError(const NetworkRequestCancelledException());
      }
    });
    try {
      return await Future.any([future, cancelled.future]);
    } finally {
      removeListener();
    }
  }

  Future<void> _waitForMessageSyncRetry(
    Duration delay,
    NetworkCancellationToken cancellation,
  ) async {
    final elapsed = Completer<void>();
    final timer = Timer(delay, elapsed.complete);
    try {
      await _untilMessageSyncCancelled(elapsed.future, cancellation);
    } finally {
      timer.cancel();
    }
  }

  void _retryFailedLocationSyncOnMessage(String location) {
    final generation = _messageSyncGeneration;
    final ticket = _historyTicket(location);
    if (!_messageConnectionIsCurrent(generation) ||
        _failedLocationSyncs[location] != ticket ||
        _entryNetworkVerified[location] == ticket ||
        (_liveLocationSyncRetryCounts[location] ?? 0) >=
            _maxLiveLocationSyncRetries) {
      return;
    }
    final key = (location, generation);
    if (_liveLocationSyncRetries.containsKey(key)) return;
    final attempt = (_liveLocationSyncRetryCounts[location] ?? 0) + 1;
    _liveLocationSyncRetryCounts[location] = attempt;
    final cancellation = _messageSyncCancellation;
    final done = Completer<void>();
    _liveLocationSyncRetries[key] = done.future;
    unawaited(() async {
      try {
        await _waitForMessageSyncRetry(
          Duration(seconds: attempt),
          cancellation,
        );
        if (!_messageConnectionIsCurrent(generation) ||
            !_historyIsCurrent(location, ticket) ||
            _failedLocationSyncs[location] != ticket ||
            _entryNetworkVerified[location] == ticket) {
          return;
        }
        await initializeLeafLocationQueues(locationIds: [location]);
      } catch (error) {
        if (_messageConnectionIsCurrent(generation)) {
          _recordServiceQueueDebug(
            action: 'liveLocationSyncRetryFailed',
            locationId: location,
            details: {'attempt': attempt, 'error': '$error'},
          );
        }
      } finally {
        _liveLocationSyncRetries.remove(key);
        done.complete();
      }
    }());
  }

  Future<ChatroomMessageListResponse> _readLocationMessages({
    required String locationId,
    required _HistoryTicket ticket,
    required int since,
    required int limit,
  }) {
    final cancellation = _messageSyncCancellation;
    return _withMessageReadSlot(
      () => _api.chatroomHttp.getMessages(
        worldId: ticket.world,
        locationId: locationId,
        since: since,
        limit: limit,
        cancellationToken: cancellation,
      ),
      () => _historyIsCurrent(locationId, ticket),
      cancellation,
    );
  }

  Set<String> _releasedGapKeysFor(String locationId) => Set.unmodifiable(
    _releasedLocationGaps.where(
      (key) => key.startsWith('${locationId.trim()}\u001F'),
    ),
  );

  /// Shared by live ingestion, connection synchronization and the chat viewport.
  Future<void> _requestLocationGapRepair(String locationId) {
    final location = locationId.trim();
    final generation = _messageSyncGeneration;
    if (location.isEmpty || !_messageConnectionIsCurrent(generation)) {
      return Future.value();
    }
    final key = (location, generation);
    _gapRepairPending.add(key);
    final active = _gapRepairs[key];
    if (active != null) return active;
    final done = Completer<void>();
    _gapRepairs[key] = done.future;
    unawaited(() async {
      try {
        while (_messageConnectionIsCurrent(generation) &&
            _gapRepairPending.remove(key)) {
          final preload = _entryPreloads[(location, _historyTicket(location))];
          if (preload != null) await preload;
          if (!_messageConnectionIsCurrent(generation)) break;
          // A failed latest-page read cannot establish a safe discard boundary.
          if (_connectionSyncAttempted.contains(location) &&
              _entryNetworkVerified[location] != _historyTicket(location)) {
            break;
          }
          await _repairLocationMessageGaps(location);
        }
      } catch (error) {
        if (_messageConnectionIsCurrent(generation)) {
          _recordServiceQueueDebug(
            action: 'gapRepairFailed',
            locationId: location,
            details: {'error': '$error'},
          );
        }
      } finally {
        _gapRepairs.remove(key);
        _gapRepairPending.remove(key);
        done.complete();
      }
    }());
    return done.future;
  }

  void _releaseLocationGap(String locationId, _LocationMessageGap gap) {
    if (!_releasedLocationGaps.add(_locationMessageGapKey(locationId, gap))) {
      return;
    }
    // Publish a new source identity so a mounted viewport releases its gate.
    _setState(
      _state.copyWith(
        messagesByLocation: {
          ..._state.messagesByLocation,
          locationId: List<WorldChatroomMessage>.unmodifiable(
            _state.messagesByLocation[locationId] ?? const [],
          ),
        },
      ),
    );
  }
}
