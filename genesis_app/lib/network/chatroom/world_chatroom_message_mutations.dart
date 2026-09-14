part of 'world_chatroom_service.dart';

class _LocationHistoryRefresh {
  _LocationHistoryRefresh(this.start, this.end);
  final int? start;
  final int? end;
  final token = NetworkCancellationToken();
  final liveMessages = <int, WorldChatroomMessage>{};
}

typedef _HistoryTicket = ({
  String world,
  String owner,
  int generation,
  int session,
});

extension _WorldChatroomMessageMutations on WorldChatroomService {
  String _messageMutationKey(String locationId, int round) =>
      '$_historySessionGeneration\u001F$_storageOwnerUid\u001F$_worldId\u001F$locationId\u001F$round';

  Future<ChatroomMessageMutationResult> _mutateLlmReplies({
    required String locationId,
    required int conversationRoundId,
    required List<ChatroomLlmMessageOperation> operations,
  }) async {
    locationId = locationId.trim();
    final key = _messageMutationKey(locationId, conversationRoundId);
    if (!_pendingMessageMutationKeys.add(key)) {
      throw StateError('A batch for this round is already being submitted');
    }
    try {
      return await _api.chatroomHttp.batchMutateLlmMessages(
        worldId: _worldId,
        locationId: locationId,
        conversationRoundId: conversationRoundId,
        operations: operations,
      );
    } finally {
      _pendingMessageMutationKeys.remove(key);
    }
  }

  /// A successful Edit batch is already committed on the server. Apply its
  /// exact changes locally before the independent range event arrives.
  void _applyCommittedFormalEdit(
    String locationId,
    int roundId,
    List<ChatroomLlmMessageOperation> operations,
  ) {
    if (_disposed || roundId <= 0 || operations.isEmpty) return;
    final location = locationId.trim();
    final current = _state.messagesByLocation[location];
    if (location.isEmpty || current == null) return;
    final changes = {
      for (final operation in operations) operation.globalMessageId: operation,
    };
    bool target(WorldChatroomMessage message) =>
        message.locationId == location &&
        message.conversationRoundNumber == roundId &&
        !message.streaming &&
        changes.containsKey(message.globalMessageId);
    if (!current.any(target)) return;

    WorldChatroomMessage edit(
      WorldChatroomMessage message,
      ChatroomLlmMessageOperation operation,
    ) => message.copyWith(
      content: operation.content,
      rawPayload: {...message.rawPayload, 'content': operation.content},
    );

    List<WorldChatroomMessage> apply(List<WorldChatroomMessage> messages) =>
        List.unmodifiable([
          for (final message in messages)
            if (!target(message))
              message
            else if (changes[message.globalMessageId]!.action ==
                ChatroomLlmMessageAction.edit)
              edit(message, changes[message.globalMessageId]!),
        ]);

    final deleted = _deletedMessageIds.putIfAbsent(location, () => <int>{});
    for (final operation in operations) {
      if (operation.action == ChatroomLlmMessageAction.delete) {
        deleted.add(operation.globalMessageId);
      } else {
        deleted.remove(operation.globalMessageId);
      }
    }
    _invalidateHistory(location);
    final streams = <String, WorldChatroomMessage>{};
    for (final entry in _state.streamMessagesByKey.entries) {
      final message = entry.value;
      if (!target(message)) {
        streams[entry.key] = message;
      } else if (changes[message.globalMessageId]!.action ==
          ChatroomLlmMessageAction.edit) {
        streams[entry.key] = edit(message, changes[message.globalMessageId]!);
      }
    }
    final updated = apply(current);
    _setState(
      _state.copyWith(
        messagesByLocation: {..._state.messagesByLocation, location: updated},
        worldMessages: apply(_state.worldMessages),
        streamMessagesByKey: streams,
      ),
    );

    final ticket = _historyTicket(location);
    unawaited(
      _withLocationWrite(location, () async {
            if (!_historyIsCurrent(location, ticket) || ticket.owner.isEmpty) {
              return;
            }
            await _messageStorage.replaceMessages(
              ownerUid: ticket.owner,
              worldId: ticket.world,
              locationId: location,
              messages: updated
                  .where(
                    (message) =>
                        message.conversationRoundNumber == roundId &&
                        !message.streaming,
                  )
                  .map(_storageJsonFromWorldMessage)
                  .toList(),
              startConversationRoundId: roundId,
              endConversationRoundId: roundId,
              maxMessagesPerLocation: _maxMessagesPerLocation,
              isCurrent: () => _historyIsCurrent(location, ticket),
            );
          })
          .then((_) async {
            if (_historyIsCurrent(location, ticket)) {
              await _replyActionsController?.persistHistorySupport(location);
            }
          })
          .catchError((Object _) {}),
    );
    _restartPendingHistory(location);
  }

  _HistoryTicket _historyTicket(String locationId) => (
    world: _worldId,
    owner: _storageOwnerUid,
    generation: _state.historyGenerationByLocation[locationId] ?? 0,
    session: _historySessionGeneration,
  );

  bool _historyIsCurrent(String locationId, _HistoryTicket ticket) =>
      !_disposed &&
      ticket.world == _worldId &&
      ticket.owner == _storageOwnerUid &&
      ticket.session == _historySessionGeneration &&
      ticket.generation ==
          (_state.historyGenerationByLocation[locationId] ?? 0);

  void _requireHistoryAvailable(String locationId) {
    if (_historyRefreshes.containsKey(locationId)) {
      throw const ChatroomProtocolException(
        'Location history requires refresh',
      );
    }
  }

  void _invalidateHistory(String locationId, {bool resetPagination = true}) {
    _historyRefreshes[locationId]?.token.cancel();
    _localMessageCacheGeneration += 1;
    _latestMessageFetchFutures.clear();
    if (!resetPagination) return;
    _setState(
      _state.copyWith(
        historyGenerationByLocation: {
          ..._state.historyGenerationByLocation,
          locationId: (_state.historyGenerationByLocation[locationId] ?? 0) + 1,
        },
      ),
    );
  }

  void _cancelHistoryRefreshes() {
    _historySessionGeneration += 1;
    _entryNetworkVerified.clear();
    for (final request in _historyRefreshes.values) {
      request.token.cancel();
    }
    _historyRefreshes.clear();
  }

  Future<T> _withLocationWrite<T>(
    String locationId,
    Future<T> Function() action,
  ) {
    final key = '$_storageOwnerUid\u001F$_worldId\u001F$locationId';
    final previous = _locationWrites[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _locationWrites[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_locationWrites[key], tail)) _locationWrites.remove(key);
      }),
    );
    return result;
  }

  void _backgroundHistoryRefresh(Future<void> future) {
    unawaited(
      future.catchError((Object _) {}),
    ); // The task reports to failures itself.
  }

  Future<void> _requestHistoryReplacement({
    required String locationId,
    int? start,
    int? end,
    bool preserveLive = false,
  }) {
    _throwIfDisposed();
    final location = locationId.trim();
    if (location.isEmpty || _worldId.isEmpty) {
      throw ArgumentError('History replacement requires world and location');
    }
    if ((start != null || end != null) &&
        (start == null || end == null || start <= 0 || end < start)) {
      throw ArgumentError('Invalid conversation range');
    }
    final previous = _historyRefreshes[location];
    final incomingStart = start;
    final incomingEnd = end;
    if (previous != null) {
      if (previous.start == null || start == null) {
        start = null;
        end = null;
      } else {
        start = math.min(start, previous.start!);
        end = math.max(end!, previous.end!);
      }
    }
    _invalidateHistory(location, resetPagination: !preserveLive);
    final request = _LocationHistoryRefresh(start, end);
    if (previous != null) {
      request.liveMessages.addEntries(
        previous.liveMessages.entries.where(
          (entry) =>
              preserveLive ||
              (incomingStart != null &&
                  (entry.value.conversationRoundNumber < incomingStart ||
                      entry.value.conversationRoundNumber > incomingEnd!)),
        ),
      );
    }
    _historyRefreshes[location] = request;
    final ticket = _historyTicket(location);
    return _runHistoryReplacement(location, request, ticket);
  }

  Future<void> _runHistoryReplacement(
    String location,
    _LocationHistoryRefresh request,
    _HistoryTicket ticket,
  ) async {
    bool current() =>
        _historyIsCurrent(location, ticket) &&
        identical(_historyRefreshes[location], request) &&
        !request.token.isCancelled;

    // A range replacement already keeps the old round until its atomic commit
    // below. Once an entry is ready, keep publishing live user echoes and streams
    // while that request runs; freezing the whole entry would drop canonical
    // echoes from the page after their optimistic rows acquire server ids.
    final prepareEntry =
        request.start == null ||
        _entryChannel(location).value.phase != ChatroomEntryPhase.ready;
    if (prepareEntry) _beginEntryRead(location);
    Object? entryError;
    try {
      if (request.start != null) {
        await _replyActionsController?.clearCardsCache(
          location,
          start: request.start,
          end: request.end,
        );
        if (!current()) return;
      }
      var since = 0;
      var newest = 0;
      var snapshotTruncated = false;
      final fetched = <int, WorldChatroomMessage>{};
      final other = <WorldChatroomMessage>[];
      while (current()) {
        final page = await _api.chatroomHttp.getMessages(
          worldId: ticket.world,
          locationId: location,
          since: since,
          limit: 100,
          startConversationRoundId: request.start,
          endConversationRoundId: request.end,
          cancellationToken: request.token,
        );
        if (!current()) return;
        newest = page.newestMessageId;
        for (final item in page.messages) {
          final message = _worldMessageFromHttpMessage(
            item,
            fallbackLocationId: location,
          );
          if (message.locationId != location) {
            throw const ChatroomProtocolException('History location mismatch');
          }
          if (request.start != null &&
              (message.conversationRoundNumber < request.start! ||
                  message.conversationRoundNumber > request.end!)) {
            throw const ChatroomProtocolException(
              'History outside requested round range',
            );
          }
          if (message.globalMessageId > 0) {
            fetched[message.globalMessageId] = message;
          } else {
            other.add(message);
          }
        }
        snapshotTruncated =
            request.start == null &&
            page.hasMore &&
            fetched.length + other.length >= _maxMessagesPerLocation;
        if (!page.hasMore || snapshotTruncated) break;
        final cursors = page.messages
            .map((m) => m.locationMessageId)
            .where((id) => id > 0);
        if (cursors.isEmpty) {
          throw const ChatroomProtocolException(
            'History cursor did not advance',
          );
        }
        final next = cursors.reduce(math.min);
        if (since > 0 && next >= since) {
          throw const ChatroomProtocolException(
            'History cursor did not advance',
          );
        }
        since = next;
      }
      if (!current()) return;
      fetched.addEntries(
        request.liveMessages.entries.where(
          (entry) =>
              request.start == null ||
              (entry.value.conversationRoundNumber >= request.start! &&
                  entry.value.conversationRoundNumber <= request.end!),
        ),
      );
      for (final message in request.liveMessages.values) {
        newest = math.max(newest, message.locationMessageId);
      }
      final incoming = [...fetched.values, ...other]..sort(_compareMessages);
      await _withLocationWrite(location, () async {
        if (!current()) return;
        if (ticket.owner.isNotEmpty) {
          await _messageStorage.replaceMessages(
            ownerUid: ticket.owner,
            worldId: ticket.world,
            locationId: location,
            messages: incoming.map(_storageJsonFromWorldMessage).toList(),
            startConversationRoundId: request.start,
            endConversationRoundId: request.end,
            maxMessagesPerLocation: _maxMessagesPerLocation,
            isCurrent: current,
          );
        }
        if (!current()) return;
        final previous =
            _state.messagesByLocation[location] ??
            const <WorldChatroomMessage>[];
        bool affected(WorldChatroomMessage m) =>
            m.locationId == location &&
            !m.streaming &&
            (request.start == null ||
                (m.conversationRoundNumber >= request.start! &&
                    m.conversationRoundNumber <= request.end!));
        final next = <WorldChatroomMessage>[
          ...previous.where((m) => !affected(m)),
          ...incoming,
        ];
        // Live streams are separate from canonical history. A refresh never ends one.
        for (final m in _state.streamMessagesByKey.values.where(
          (m) => m.locationId == location && m.streaming,
        )) {
          next.removeWhere(
            (old) =>
                old.globalMessageId > 0 &&
                old.globalMessageId == m.globalMessageId,
          );
          if (!next.any((old) => identical(old, m))) next.add(m);
        }
        next.sort(_compareMessages);
        final trimmed = _trimMessageList(next, _maxMessagesPerLocation);
        final incomingIds = incoming
            .map((m) => m.globalMessageId)
            .where((id) => id > 0)
            .toSet();
        final oldestFetchedWorldId = incoming
            .where((m) => m.messageId > 0)
            .map((m) => m.messageId)
            .fold<int?>(
              null,
              (oldest, id) => oldest == null ? id : math.min(oldest, id),
            );
        final deleted = _deletedMessageIds.putIfAbsent(location, () => <int>{});
        deleted.addAll(
          previous
              .where(affected)
              .where(
                (m) =>
                    !snapshotTruncated ||
                    (oldestFetchedWorldId != null &&
                        m.messageId >= oldestFetchedWorldId),
              )
              .map((m) => m.globalMessageId)
              .where((id) => id > 0 && !incomingIds.contains(id)),
        );
        deleted.removeAll(incomingIds);
        final activeIds = _state.streamMessagesByKey.values
            .where((m) => m.locationId == location && m.streaming)
            .map((m) => m.globalMessageId)
            .where((id) => id > 0)
            .toSet();
        final world = [
          ..._state.worldMessages.where((m) => !affected(m)),
          ...incoming.where((m) => !activeIds.contains(m.globalMessageId)),
        ];
        world.sort(_compareMessages);
        _historyRefreshes.remove(location);
        _setState(
          _state.copyWith(
            messagesByLocation: {
              ..._state.messagesByLocation,
              location: trimmed,
            },
            worldMessages: List.unmodifiable(world),
            newestLocationMessageIds: {
              ..._state.newestLocationMessageIds,
              location: newest,
            },
            historyHasMoreByLocation: {
              ..._state.historyHasMoreByLocation,
              if (request.start == null || newest == 0)
                location: snapshotTruncated,
            },
            latestHistoryLoads: {
              ..._state.latestHistoryLoads,
              if (request.start == null)
                location: (limit: 100, hasMore: snapshotTruncated),
            },
          ),
          inspirationReplacementLocation: request.start == null
              ? null
              : location,
        );
      });
      if (_historyIsCurrent(location, ticket)) {
        if (!await _loadReplyCardsForHistory(location, incoming, ticket)) {
          entryError = StateError('Reply cards could not be loaded');
        }
      }
    } catch (error) {
      entryError = error;
      if (!current()) return;
      _recordFailure(
        ChatroomFailureEvent(
          code: 'history_replacement_failed',
          message: 'Failed to refresh messages',
          sourceType: 'conversation_range_updated',
          cause: error,
        ),
      );
      // Retain the invalid range. A retry unions it with the next notification.
      rethrow;
    } finally {
      if (prepareEntry) _endEntryRead(location, ticket, error: entryError);
    }
  }

  void _restartPendingHistory(String locationId) {
    final pending = _historyRefreshes[locationId];
    if (pending != null) {
      _backgroundHistoryRefresh(
        _requestHistoryReplacement(
          locationId: locationId,
          start: pending.start,
          end: pending.end,
          preserveLive: true,
        ),
      );
    }
  }

  Future<void> _handleLlmMessageUpdated(ChatroomLlmMessageUpdated event) async {
    if (event.errNo != 0 ||
        event.worldId != _worldId ||
        event.locationId.isEmpty) {
      return;
    }
    final location = event.locationId;
    if (_deletedMessageIds[location]?.contains(event.globalMessageId) == true) {
      return;
    }
    final previous =
        (_state.messagesByLocation[location] ?? const <WorldChatroomMessage>[])
            .where((m) => m.globalMessageId == event.globalMessageId)
            .firstOrNull ??
        _state.worldMessages
            .where(
              (m) =>
                  m.locationId == location &&
                  m.globalMessageId == event.globalMessageId,
            )
            .firstOrNull;
    if (previous == null) {
      _backgroundHistoryRefresh(
        _requestHistoryReplacement(
          locationId: location,
          start: event.conversationRoundId,
          end: event.conversationRoundId,
        ),
      );
      return;
    }
    _invalidateHistory(location);
    final ticket = _historyTicket(location);
    final updated = previous.copyWith(
      content: event.content,
      messageId: event.messageId,
      locationMessageId: event.locationMessageId,
      conversationRoundId: '${event.conversationRoundId}',
      streaming: false,
      isLlmStreamMessage: false,
      streamType: '',
      rawPayload: {
        ...previous.rawPayload,
        'content': event.content,
        'status': event.status,
      },
    );
    List<WorldChatroomMessage> replace(List<WorldChatroomMessage> messages) {
      final next = messages
          .map(
            (m) =>
                m.locationId == location &&
                    m.globalMessageId == event.globalMessageId
                ? updated
                : m,
          )
          .toList();
      next.sort(_compareMessages);
      return List.unmodifiable(next);
    }

    // A range notification can precede a delayed edit for the deleted row.
    // Re-fetch after this edit, but never overlay it onto an empty authoritative result.
    _historyRefreshes[location]?.liveMessages.remove(event.globalMessageId);
    final streamKey = _streamKey(
      location,
      previous.conversationRoundId,
      previous.senderId,
    );
    _streamAccumulators.remove(streamKey);
    final streams = {..._state.streamMessagesByKey}..remove(streamKey);
    _setState(
      _state.copyWith(
        worldMessages: replace(_state.worldMessages),
        streamMessagesByKey: streams,
        messagesByLocation: {
          ..._state.messagesByLocation,
          location: replace(_state.messagesByLocation[location] ?? []),
        },
      ),
    );
    try {
      await _withLocationWrite(location, () async {
        if (!_historyIsCurrent(location, ticket) || ticket.owner.isEmpty) {
          return;
        }
        await _messageStorage.upsertMessage(
          ownerUid: ticket.owner,
          worldId: ticket.world,
          locationId: location,
          message: _storageJsonFromWorldMessage(updated),
        );
      });
    } catch (error) {
      if (_historyIsCurrent(location, ticket)) {
        _recordFailure(
          ChatroomFailureEvent(
            code: 'message_cache_failed',
            message: 'Failed to cache edited message',
            sourceType: 'llm_message_updated',
            cause: error,
          ),
        );
      }
    }
    if (_historyIsCurrent(location, ticket)) _restartPendingHistory(location);
  }
}
