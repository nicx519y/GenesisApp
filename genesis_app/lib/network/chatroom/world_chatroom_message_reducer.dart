part of 'world_chatroom_service.dart';

extension _WorldChatroomMessageReducer on WorldChatroomService {
  Future<void> _handleIncomingMessage(WorldChatroomMessage message) async {
    _upsertMessage(message, socketCurrentTime: message.currentTime);
  }

  Future<void> _handleTickAdvanceMessage(WorldChatroomMessage message) async {
    final messages = _tickAdvanceLocationIds(message.locationId)
        .map((locationId) => message.copyWith(locationId: locationId))
        .toList(growable: false);
    _upsertMessages(
      messages.isEmpty ? [message] : messages,
      socketCurrentTime: message.currentTime,
      socketTickNo: message.tickNo,
    );
  }

  Future<List<WorldChatroomMessage>> _fetchLatestLocationMessages({
    required String locationId,
    required int limit,
    bool emitLatestFetched = true,
  }) async {
    if (_worldId.isEmpty) return const <WorldChatroomMessage>[];
    final response = await _api.chatroomHttp.getMessages(
      worldId: _worldId,
      locationId: locationId,
      since: 0,
      limit: limit,
    );
    final messages = await _mergeFetchedMessages(locationId, response.messages);
    if (emitLatestFetched &&
        messages.isNotEmpty &&
        !_latestFetchedMessages.isClosed) {
      _latestFetchedMessages.add(messages);
    }
    _recordServiceQueueDebug(
      action: 'refreshLocationLatestDone',
      locationId: locationId,
      details: {
        'limit': limit,
        'loaded': messages.length,
        'hasMore': response.hasMore,
        'emitLatestFetched': emitLatestFetched,
      },
    );
    return messages;
  }

  Future<List<WorldChatroomMessage>> _fetchLatestLocationMessagesWithFailure({
    required String locationId,
    required int limit,
    bool emitLatestFetched = true,
  }) async {
    try {
      return await _fetchLatestLocationMessages(
        locationId: locationId,
        limit: limit,
        emitLatestFetched: emitLatestFetched,
      );
    } catch (e) {
      _logChatroomSocketEvent(
        'latest location messages fetch failed world=$_worldId '
        'location=$locationId limit=$limit error=$e',
      );
      _recordFailure(
        ChatroomFailureEvent(
          code: 'message_history_load_failed',
          message: 'Something went wrong',
          sourceType: 'message_history',
          requestType: 'get_messages',
          cause: e,
        ),
      );
      return const <WorldChatroomMessage>[];
    }
  }

  Future<List<WorldChatroomMessage>> _fetchLatestWorldMessages({
    required int limit,
    bool emitLatestFetched = true,
  }) async {
    final stopwatch = _chatroomHydrateMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    if (_worldId.isEmpty) return const <WorldChatroomMessage>[];
    _logChatroomHydrateMetric(
      'world history fetch start world=$_worldId limit=$limit '
      'locationCount=${_state.messagesByLocation.length}',
    );
    final response = await _api.chatroomHttp.getWorldMessages(
      worldId: _worldId,
    );
    final messages = <WorldChatroomMessage>[];
    for (final location in response.locations) {
      final locationId = location.locationId.trim();
      if (locationId.isEmpty) continue;
      messages.addAll(
        await _mergeFetchedMessages(locationId, location.messages),
      );
    }
    if (emitLatestFetched &&
        messages.isNotEmpty &&
        !_latestFetchedMessages.isClosed) {
      _latestFetchedMessages.add(messages);
    }
    _logChatroomHydrateMetric(
      'world history fetch done world=$_worldId '
      'locations=${response.locations.length} loaded=${messages.length} '
      'elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
    _recordServiceQueueDebug(
      action: 'refreshWorldLatestDone',
      locationId: '',
      details: {
        'limit': limit,
        'locations': response.locations.length,
        'loaded': messages.length,
        'emitLatestFetched': emitLatestFetched,
        'elapsedMs': stopwatch?.elapsedMilliseconds,
      },
    );
    return messages;
  }

  Future<List<WorldChatroomMessage>> _fetchLatestWorldMessagesWithFailure({
    required int limit,
    bool emitLatestFetched = true,
  }) async {
    try {
      return await _fetchLatestWorldMessages(
        limit: limit,
        emitLatestFetched: emitLatestFetched,
      );
    } catch (e) {
      _logChatroomSocketEvent(
        'latest world messages fetch failed world=$_worldId limit=$limit error=$e',
      );
      _recordFailure(
        ChatroomFailureEvent(
          code: 'message_history_load_failed',
          message: 'Something went wrong',
          sourceType: 'message_history',
          requestType: 'get_messages',
          cause: e,
        ),
      );
      return const <WorldChatroomMessage>[];
    }
  }

  Future<void> _fetchLatestMessagesForNotification() async {
    await _fetchLatestWorldMessagesWithFailure(limit: 20);
  }

  List<String> _leafLocationIdsForCurrentWorld() {
    return _leafLocationIdsForWorld(_state.world);
  }

  List<String> _leafLocationIdsForWorld(WorldDetail? world) {
    final ids = <String>{};
    if (world != null) {
      for (final node in world.processedLocationTree.flattened) {
        if (node.children.isNotEmpty) continue;
        final id = node.id.trim();
        if (id.isNotEmpty) ids.add(id);
      }
      if (ids.isEmpty) {
        final parentIds = world.locations
            .map((location) => asString(location['location_pid']).trim())
            .where((id) => id.isNotEmpty)
            .toSet();
        for (final location in world.locations) {
          final id = asString(
            location['location_id'],
            fallback: asString(location['id']),
          ).trim();
          if (id.isEmpty || parentIds.contains(id)) continue;
          ids.add(id);
        }
      }
    }
    return ids.toList(growable: false);
  }

  List<String> _tickAdvanceLocationIds(String fallbackLocationId) {
    final ids = <String>{..._leafLocationIdsForCurrentWorld()};
    if (ids.isEmpty) {
      ids.addAll(
        _state.messagesByLocation.keys
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty),
      );
      final joinedLocationId = _state.joinedLocationId.trim();
      if (joinedLocationId.isNotEmpty) ids.add(joinedLocationId);
      final fallback = fallbackLocationId.trim();
      if (fallback.isNotEmpty) ids.add(fallback);
    }
    return ids.toList(growable: false);
  }

  Future<List<WorldChatroomMessage>> _mergeFetchedMessages(
    String locationId,
    List<ChatroomHttpMessage> messages,
  ) async {
    final worldMessages = messages
        .map(
          (message) => _worldMessageFromHttpMessage(
            message,
            fallbackLocationId: locationId,
          ),
        )
        .toList(growable: false);
    final ownerUid = _storageOwnerUid;
    if (ownerUid.isNotEmpty && _worldId.isNotEmpty) {
      await _messageStorage.mergeMessages(
        ownerUid: ownerUid,
        worldId: _worldId,
        locationId: locationId,
        messages: messages
            .map(
              (message) => _storageJsonFromHttpMessage(
                message,
                fallbackLocationId: locationId,
              ),
            )
            .toList(growable: false),
        maxMessagesPerLocation: _maxMessagesPerLocation,
      );
    }
    _upsertMessages(worldMessages, persist: false);
    if (LocationChatDebugSlice.enabled) {
      LocationChatDebugSlice.recordEvent(
        source: 'service',
        action: 'mergeFetched',
        worldId: _worldId,
        locationId: locationId,
        details: {
          'incoming': messages.length,
          'messages': LocationChatDebugSlice.debugWorldMessageQueue(
            worldMessages,
          ),
        },
      );
    }
    return worldMessages;
  }

  void _appendStreamChunk(ChatroomAiStreamChunk event) {
    final key = _streamKey(event.locationId, event.conversationRoundId);
    final existing = _state.streamMessagesByKey[key];
    if (existing == null) {
      _recordFailure(
        ChatroomFailureEvent(
          code: 'stream_missing',
          message: 'Missing LLM stream start for ${event.conversationRoundId}',
          sourceType: 'llm_chunk',
        ),
        socketCurrentTime: event.currentTime,
      );
      return;
    }
    _upsertMessage(
      existing.copyWith(
        content: existing.content + event.chunk,
        currentTime: event.currentTime.trim().isEmpty
            ? existing.currentTime
            : event.currentTime,
      ),
      socketCurrentTime: event.currentTime,
    );
  }

  void _finishStream(ChatroomAiStreamEnd event) {
    final key = _streamKey(event.locationId, event.conversationRoundId);
    final existing = _state.streamMessagesByKey[key];
    if (existing == null) {
      _recordFailure(
        ChatroomFailureEvent(
          code: 'stream_missing',
          message: 'Missing LLM stream start for ${event.conversationRoundId}',
          sourceType: 'llm_stream_end',
        ),
        socketCurrentTime: event.currentTime,
      );
      return;
    }
    _upsertMessage(
      existing.copyWith(
        content: event.content.trim().isEmpty
            ? existing.content
            : event.content,
        currentTime: event.currentTime.trim().isEmpty
            ? existing.currentTime
            : event.currentTime,
        streaming: false,
      ),
      socketCurrentTime: event.currentTime,
    );
  }

  WorldChatroomState _stateWithSocketWorldProgress(
    WorldChatroomState state, {
    String socketCurrentTime = '',
    int socketTickNo = 0,
  }) {
    final resolvedSocketCurrentTime = socketCurrentTime.trim();
    final resolvedSocketTickNo = socketTickNo > 0 ? socketTickNo : 0;
    final hasSocketWorldProgress =
        resolvedSocketCurrentTime.isNotEmpty || resolvedSocketTickNo > 0;
    if (!hasSocketWorldProgress) return state;
    return state.copyWith(
      world: _worldWithSocketProgress(
        state.world,
        currentTime: resolvedSocketCurrentTime,
        tickNo: resolvedSocketTickNo,
      ),
      latestSocketCurrentTime: resolvedSocketCurrentTime,
      latestSocketTickNo: resolvedSocketTickNo,
      latestSocketCurrentTimeRevision:
          state.latestSocketCurrentTimeRevision + 1,
    );
  }

  WorldDetail? _worldWithSocketProgress(
    WorldDetail? world, {
    required String currentTime,
    required int tickNo,
  }) {
    if (world == null) return null;
    final resolvedCurrentTime = currentTime.trim();
    final resolvedTickNo = tickNo > 0 ? tickNo : 0;
    if (resolvedCurrentTime.isEmpty && resolvedTickNo <= 0) return world;
    return world.copyWith(
      currentTime: resolvedCurrentTime.isEmpty ? null : resolvedCurrentTime,
      tickCount: resolvedTickNo > 0 ? resolvedTickNo : null,
    );
  }

  void _upsertMessage(
    WorldChatroomMessage message, {
    bool persist = true,
    String socketCurrentTime = '',
    int socketTickNo = 0,
  }) {
    _upsertMessages(
      [message],
      persist: persist,
      socketCurrentTime: socketCurrentTime,
      socketTickNo: socketTickNo,
    );
  }

  void _upsertMessages(
    List<WorldChatroomMessage> messages, {
    bool persist = true,
    String socketCurrentTime = '',
    int socketTickNo = 0,
  }) {
    if (messages.isEmpty) return;
    final resolvedSocketCurrentTime = socketCurrentTime.trim();
    final resolvedSocketTickNo = socketTickNo > 0 ? socketTickNo : 0;
    var worldMessages = _state.worldMessages;
    final byLocation = _leafLocationMessageQueues(
      _state.world,
      _state.messagesByLocation,
    );
    final streamKeys = <String, WorldChatroomMessage>{
      ..._state.streamMessagesByKey,
    };
    var lastMessageId = _state.lastMessageId;
    for (final message in messages) {
      worldMessages = _upsertIntoList(worldMessages, message);
      if (_shouldStoreMessageInLocationQueue(message)) {
        byLocation[message.locationId] = _trimMessageList(
          _upsertIntoList(
            byLocation[message.locationId] ?? const <WorldChatroomMessage>[],
            message,
          ),
          _maxMessagesPerLocation,
        );
      }
      final key = _streamKey(message.locationId, message.conversationRoundId);
      if (message.streaming && key.isNotEmpty) {
        streamKeys[key] = message;
      } else {
        streamKeys.remove(key);
      }
      if (message.messageId > lastMessageId) lastMessageId = message.messageId;
    }
    _setState(
      _stateWithSocketWorldProgress(
        _state.copyWith(
          worldMessages: worldMessages,
          messagesByLocation: byLocation,
          streamMessagesByKey: streamKeys,
          lastMessageId: lastMessageId,
        ),
        socketCurrentTime: resolvedSocketCurrentTime,
        socketTickNo: resolvedSocketTickNo,
      ),
    );
    final changedLocationIds = messages
        .map((message) => message.locationId.trim())
        .where((locationId) => locationId.isNotEmpty)
        .toSet();
    for (final locationId in changedLocationIds) {
      _recordServiceQueueDebug(
        action: persist ? 'upsertPersist' : 'upsertState',
        locationId: locationId,
        details: {'incoming': messages.length, 'persist': persist},
      );
    }
    if (persist) {
      for (final message in messages) {
        unawaited(
          _persistMessage(message).catchError((Object error) {
            _recordFailure(
              ChatroomFailureEvent(
                code: 'message_cache_failed',
                message: 'Something went wrong',
                sourceType: 'message_cache',
                cause: error,
              ),
            );
          }),
        );
      }
    }
  }

  List<WorldChatroomMessage> _upsertIntoList(
    List<WorldChatroomMessage> messages,
    WorldChatroomMessage message,
  ) {
    final next = <WorldChatroomMessage>[];
    var replaced = false;
    for (final item in messages) {
      if (_sameMessage(item, message)) {
        if (!replaced) {
          next.add(message);
          replaced = true;
        }
      } else {
        next.add(item);
      }
    }
    if (!replaced) next.add(message);
    next.sort(_compareMessages);
    return List<WorldChatroomMessage>.unmodifiable(next);
  }

  List<WorldChatroomMessage> _trimMessageList(
    List<WorldChatroomMessage> messages,
    int maxMessages,
  ) {
    if (maxMessages <= 0 || messages.length <= maxMessages) return messages;
    return List<WorldChatroomMessage>.unmodifiable(
      messages.skip(messages.length - maxMessages),
    );
  }

  bool _sameMessage(WorldChatroomMessage a, WorldChatroomMessage b) {
    final aClientMsgId = a.clientMsgId.trim();
    final bClientMsgId = b.clientMsgId.trim();
    if (aClientMsgId.isNotEmpty && bClientMsgId.isNotEmpty) {
      return aClientMsgId == bClientMsgId;
    }
    if (a.locationId == b.locationId &&
        a.locationMessageId > 0 &&
        b.locationMessageId > 0) {
      return a.locationMessageId == b.locationMessageId;
    }
    if (a.locationId == b.locationId &&
        a.messageId > 0 &&
        b.messageId > 0 &&
        (_isTickAdvanceWorldMessage(a) ||
            _isTickAdvanceWorldMessage(b) ||
            a.locationMessageId <= 0 ||
            b.locationMessageId <= 0)) {
      return a.messageId == b.messageId;
    }
    if (a.locationId == b.locationId) {
      return a.conversationRoundId == b.conversationRoundId &&
          a.userId == b.userId &&
          a.senderId == b.senderId &&
          a.streaming == b.streaming;
    }
    if (a.messageId > 0 && b.messageId > 0) {
      return a.messageId == b.messageId;
    }
    return a.locationId == b.locationId &&
        a.conversationRoundId == b.conversationRoundId &&
        a.userId == b.userId &&
        a.senderId == b.senderId &&
        a.streaming == b.streaming;
  }

  int _compareMessages(WorldChatroomMessage a, WorldChatroomMessage b) {
    if (a.locationId == b.locationId) {
      final aIsTick = _isTickAdvanceWorldMessage(a);
      final bIsTick = _isTickAdvanceWorldMessage(b);
      if (aIsTick || bIsTick) {
        final byMessageId = a.messageId.compareTo(b.messageId);
        if (byMessageId != 0) return byMessageId;
        final byLocationMessage = a.locationMessageId.compareTo(
          b.locationMessageId,
        );
        if (byLocationMessage != 0) return byLocationMessage;
      } else {
        final aHasLocationMessageId = a.locationMessageId > 0;
        final bHasLocationMessageId = b.locationMessageId > 0;
        if (aHasLocationMessageId && bHasLocationMessageId) {
          return a.locationMessageId.compareTo(b.locationMessageId);
        }
        if (aHasLocationMessageId != bHasLocationMessageId) {
          return aHasLocationMessageId ? 1 : -1;
        }
      }
    }
    if (a.locationId == b.locationId) {
      final round = a.conversationRoundNumber.compareTo(
        b.conversationRoundNumber,
      );
      if (round != 0) return round;
      final order = a.roundOrder.compareTo(b.roundOrder);
      if (order != 0) return order;
      return a.messageId.compareTo(b.messageId);
    }
    if (a.messageId > 0 && b.messageId > 0) {
      return a.messageId.compareTo(b.messageId);
    }
    final round = a.conversationRoundNumber.compareTo(
      b.conversationRoundNumber,
    );
    if (round != 0) return round;
    final order = a.roundOrder.compareTo(b.roundOrder);
    if (order != 0) return order;
    return a.messageId.compareTo(b.messageId);
  }

  Map<String, List<WorldChatroomMessage>> _leafLocationMessageQueues(
    WorldDetail? world,
    Map<String, List<WorldChatroomMessage>> current,
  ) {
    if (world == null) {
      return Map<String, List<WorldChatroomMessage>>.from(current);
    }
    final leafIds = _leafLocationIdsForWorld(world);
    if (leafIds.isEmpty) {
      return Map<String, List<WorldChatroomMessage>>.from(current);
    }
    return <String, List<WorldChatroomMessage>>{
      for (final locationId in leafIds)
        locationId: List<WorldChatroomMessage>.unmodifiable(
          (current[locationId] ?? const <WorldChatroomMessage>[]).where(
            _isLocationQueueMessage,
          ),
        ),
    };
  }

  bool _shouldStoreMessageInLocationQueue(WorldChatroomMessage message) {
    return _shouldStoreMessageForLocation(message.locationId) &&
        _isLocationQueueMessage(message);
  }

  bool _shouldStoreMessageForLocation(String locationId) {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) return false;
    final world = _state.world;
    if (world == null) return true;
    final leafIds = _leafLocationIdsForWorld(world);
    return leafIds.isEmpty || leafIds.contains(resolvedLocationId);
  }

  bool _isLocationQueueMessage(WorldChatroomMessage message) {
    return _isTickAdvanceWorldMessage(message) ||
        message.locationMessageId > 0 ||
        message.messageId > 0;
  }

  bool _messageIsAtOrBeforeLocationCursor(
    WorldChatroomMessage message,
    int maxLocationMessageId,
  ) {
    if (maxLocationMessageId <= 0) return false;
    if (_isTickAdvanceWorldMessage(message)) {
      return message.messageId > 0 && message.messageId <= maxLocationMessageId;
    }
    if (message.locationMessageId <= 0) return true;
    return message.locationMessageId <= maxLocationMessageId;
  }
}
