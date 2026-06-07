import 'dart:async';

import '../genesis_api.dart';
import '../json_utils.dart';
import '../models/location_tree.dart';
import '../models/world.dart';
import 'chatroom_client.dart';
import 'chatroom_connection_controller.dart';
import 'chatroom_http_models.dart';
import 'chatroom_message_storage.dart';
import 'chatroom_models.dart';

const _maxMessagesPerLocation = 200;

class WorldChatroomOlderMessagesPage {
  const WorldChatroomOlderMessagesPage({
    required this.loadedCount,
    required this.hasMore,
  });

  final int loadedCount;
  final bool hasMore;
}

class WorldChatroomService {
  WorldChatroomService({
    required GenesisApi api,
    required ChatroomClient client,
    required ChatroomMessageStorage messageStorage,
    Duration heartbeatInterval = const Duration(seconds: 10),
    Duration reconnectInterval = const Duration(seconds: 5),
  }) : _api = api,
       _client = client,
       _messageStorage = messageStorage,
       _heartbeatInterval = heartbeatInterval,
       _reconnectInterval = reconnectInterval;

  final GenesisApi _api;
  final ChatroomClient _client;
  final ChatroomMessageStorage _messageStorage;
  final Duration _heartbeatInterval;
  final Duration _reconnectInterval;
  final _states = StreamController<WorldChatroomState>.broadcast();
  final _failures = StreamController<ChatroomFailureEvent>.broadcast();

  WorldChatroomState _state = const WorldChatroomState();
  ChatroomSession? _session;
  ChatroomConnectionIdentity? _identity;
  String _worldId = '';
  String _desiredLocationId = '';
  bool _userDisconnected = true;
  bool _disposed = false;
  Completer<void>? _connectCompleter;
  Completer<ChatroomJoined>? _joinCompleter;
  bool _heartbeatInFlight = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  StreamSubscription<ChatroomEvent>? _eventSubscription;
  StreamSubscription<ChatroomFailureEvent>? _failureSubscription;
  StreamSubscription<ChatroomErrorEvent>? _errorSubscription;
  Future<void> _eventQueue = Future<void>.value();

  Stream<WorldChatroomState> get states => _states.stream;

  Stream<ChatroomFailureEvent> get failures => _failures.stream;

  WorldChatroomState get state => _state;

  ChatroomConnectionIdentity? get identity => _identity;

  Future<void> connect({
    required String worldId,
    required ChatroomConnectionIdentity identity,
  }) async {
    _throwIfDisposed();
    _worldId = worldId.trim();
    if (_worldId.isEmpty) {
      throw const ChatroomProtocolException('worldId is required');
    }
    _identity = identity;
    _userDisconnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _connectOnce();
  }

  Future<ChatroomJoined> join({required String locationId}) async {
    _throwIfDisposed();
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) {
      throw const ChatroomProtocolException('locationId is required');
    }
    _desiredLocationId = resolvedLocationId;
    final existing = _joinCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<ChatroomJoined>();
    _joinCompleter = completer;
    unawaited(_joinDesiredLocation(completer));
    return completer.future;
  }

  Future<void> leave() async {
    _throwIfDisposed();
    _desiredLocationId = '';
    final joinCompleter = _joinCompleter;
    _joinCompleter = null;
    if (joinCompleter != null && !joinCompleter.isCompleted) {
      joinCompleter.completeError(
        const ChatroomFailureEvent(
          code: 'join_cancelled',
          message: 'Join was cancelled',
          sourceType: 'leave',
          requestType: 'join',
        ),
      );
    }
    final session = _session;
    _setState(_state.copyWith(joining: false, joinedLocationId: ''));
    if (session == null) return;
    try {
      await session.leave();
    } catch (e) {
      final failure = e is ChatroomFailureEvent
          ? e
          : ChatroomFailureEvent(
              code: 'leave_failed',
              message: 'Failed to leave chatroom',
              sourceType: 'leave',
              requestType: 'leave',
              cause: e,
            );
      _recordFailure(failure);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _desiredLocationId = '';
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _detachSession(disconnect: true);
    _setState(
      _state.copyWith(
        connected: false,
        joining: false,
        joinedLocationId: '',
        reconnecting: false,
      ),
    );
  }

  Future<ChatroomAck> sendMessage(String text, {String? clientMsgId}) {
    final session = _session;
    if (session == null) {
      throw const ChatroomProtocolException('chatroom is not connected');
    }
    return session.sendMessage(text, clientMsgId: clientMsgId);
  }

  Future<WorldChatroomOlderMessagesPage> loadOlderMessages({
    required String locationId,
    required int beforeMessageId,
    int limit = 20,
  }) async {
    _throwIfDisposed();
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty ||
        _worldId.isEmpty ||
        beforeMessageId <= 0 ||
        limit <= 0) {
      return const WorldChatroomOlderMessagesPage(
        loadedCount: 0,
        hasMore: false,
      );
    }
    final loadedMessageIds = <int>{};
    final ownerUid = _storageOwnerUid;
    if (ownerUid.isNotEmpty && _worldId.isNotEmpty) {
      final localMessages = await _messageStorage.loadMessagesBefore(
        ownerUid: ownerUid,
        worldId: _worldId,
        locationId: resolvedLocationId,
        beforeMessageId: beforeMessageId,
        limit: limit,
      );
      for (final json in localMessages) {
        final message = WorldChatroomMessage.fromStorageJson(json);
        if (message.messageId > 0) loadedMessageIds.add(message.messageId);
        _upsertMessage(message, persist: false);
      }
    }

    final response = await _api.chatroomHttp.getMessages(
      worldId: _worldId,
      locationId: resolvedLocationId,
      since: beforeMessageId,
      limit: limit,
    );
    await _mergeFetchedMessages(resolvedLocationId, response.messages);
    for (final message in response.messages) {
      if (message.messageId > 0) loadedMessageIds.add(message.messageId);
    }
    return WorldChatroomOlderMessagesPage(
      loadedCount: loadedMessageIds.length,
      hasMore: response.hasMore || loadedMessageIds.length >= limit,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _states.close();
    await _failures.close();
  }

  Future<void> _connectOnce() async {
    if (_userDisconnected || _disposed) return;
    if (_session != null && _state.connected) return;
    final current = _connectCompleter;
    if (current != null) {
      await current.future;
      return;
    }
    final identity = _identity;
    if (identity == null) {
      throw const ChatroomProtocolException('chatroom identity is required');
    }
    final completer = Completer<void>();
    _connectCompleter = completer;
    unawaited(completer.future.catchError((Object _) {}));
    _setState(
      _state.copyWith(connected: false, reconnecting: _state.world != null),
    );
    try {
      await _detachSession(disconnect: true);
      final session = await _client.connect(
        worldId: _worldId,
        userId: identity.userId,
        senderId: identity.senderId,
        senderName: identity.senderName,
        autoHeartbeat: false,
      );
      if (_userDisconnected || _disposed) {
        await session.disconnect();
        return;
      }
      _session = session;
      _attachSession(session);
      _setState(_state.copyWith(connected: true));
      await _refreshInitialSnapshot();
      final desiredLocationId = _desiredLocationId;
      if (desiredLocationId.isNotEmpty) {
        await _joinSession(session, desiredLocationId);
      }
      _startHeartbeat();
      _setState(_state.copyWith(connected: true, reconnecting: false));
      completer.complete();
    } catch (e) {
      final failure = e is ChatroomFailureEvent
          ? e
          : ChatroomFailureEvent(
              code: 'connect_failed',
              message: 'Failed to connect chatroom',
              sourceType: 'connect',
              requestType: 'connect',
              cause: e,
            );
      _recordFailure(failure);
      _scheduleReconnect();
      completer.completeError(failure);
      rethrow;
    } finally {
      if (identical(_connectCompleter, completer)) {
        _connectCompleter = null;
      }
    }
  }

  Future<void> _refreshInitialSnapshot() async {
    try {
      await _refreshWorld();
      await _hydrateLocationMessageQueues();
      await _refreshUserLocations();
    } catch (e) {
      _recordFailure(
        ChatroomFailureEvent(
          code: 'snapshot_failed',
          message: 'Failed to refresh chatroom snapshot',
          sourceType: 'snapshot',
          cause: e,
        ),
      );
    }
  }

  Future<void> _joinDesiredLocation(Completer<ChatroomJoined> completer) async {
    try {
      await _connectOnce();
      final session = _session;
      final locationId = _desiredLocationId;
      if (session == null || locationId.isEmpty) {
        throw const ChatroomProtocolException('chatroom is not connected');
      }
      final joined = await _joinSession(session, locationId);
      if (!completer.isCompleted) completer.complete(joined);
    } catch (e) {
      final failure = e is ChatroomFailureEvent
          ? e
          : ChatroomFailureEvent(
              code: 'join_failed',
              message: 'Failed to join location',
              sourceType: 'join',
              requestType: 'join',
              cause: e,
            );
      _recordFailure(failure);
      if (!completer.isCompleted) completer.completeError(failure);
    } finally {
      if (identical(_joinCompleter, completer)) {
        _joinCompleter = null;
      }
    }
  }

  Future<ChatroomJoined> _joinSession(
    ChatroomSession session,
    String locationId,
  ) async {
    _setState(_state.copyWith(joining: true));
    try {
      final joined = await session.join(locationId: locationId);
      if (_desiredLocationId == locationId) {
        _setState(
          _state.copyWith(
            connected: true,
            joining: false,
            joinedLocationId: joined.locationId.isEmpty
                ? locationId
                : joined.locationId,
          ),
        );
      }
      return joined;
    } catch (_) {
      _setState(_state.copyWith(joining: false, joinedLocationId: ''));
      rethrow;
    }
  }

  void _attachSession(ChatroomSession session) {
    _eventSubscription = session.events.listen(
      _enqueueEvent,
      onDone: () => _handleConnectionLost(),
    );
    _failureSubscription = session.failures.listen(_recordFailure);
    _errorSubscription = session.errors.listen((error) {
      _recordFailure(ChatroomFailureEvent.fromError(error));
    });
  }

  void _enqueueEvent(ChatroomEvent event) {
    _eventQueue = _eventQueue.then((_) => _handleEvent(event)).catchError((
      Object error,
    ) {
      _recordFailure(
        ChatroomFailureEvent(
          code: 'event_handle_failed',
          message: 'Failed to handle chatroom event',
          sourceType: chatroomEventType(event),
          cause: error,
        ),
      );
    });
    unawaited(_eventQueue);
  }

  Future<void> _detachSession({required bool disconnect}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final session = _session;
    _session = null;
    if (disconnect && session != null) {
      try {
        await session.disconnect();
      } catch (_) {}
    }
    await _eventSubscription?.cancel();
    await _failureSubscription?.cancel();
    await _errorSubscription?.cancel();
    _eventSubscription = null;
    _failureSubscription = null;
    _errorSubscription = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(_sendHeartbeat());
    });
  }

  Future<void> _sendHeartbeat() async {
    final session = _session;
    if (session == null ||
        _userDisconnected ||
        _disposed ||
        _heartbeatInFlight) {
      return;
    }
    _heartbeatInFlight = true;
    try {
      await session.heartbeat();
    } catch (_) {
      await _handleConnectionLost();
    } finally {
      _heartbeatInFlight = false;
    }
  }

  Future<void> _handleConnectionLost() async {
    if (_userDisconnected || _disposed) return;
    await _detachSession(disconnect: true);
    _setState(_state.copyWith(connected: false, joinedLocationId: ''));
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_userDisconnected || _disposed) return;
    _setState(_state.copyWith(reconnecting: true));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectInterval, () {
      _reconnectTimer = null;
      unawaited(_connectOnce().catchError((Object _) {}));
    });
  }

  Future<void> _handleEvent(ChatroomEvent event) async {
    switch (event) {
      case ChatroomWorldNotification e:
        await _handleWorldNotification(e);
      case ChatroomUserMessage e:
        await _handleIncomingMessage(WorldChatroomMessage.fromUserMessage(e));
      case ChatroomNarratorMessage e:
        await _handleIncomingMessage(
          WorldChatroomMessage.fromNarratorMessage(e),
        );
      case ChatroomAiStreamStart e:
        _upsertMessage(WorldChatroomMessage.fromAiStreamStart(e));
      case ChatroomAiStreamChunk e:
        _appendStreamChunk(e);
      case ChatroomAiStreamEnd e:
        _finishStream(e);
      case ChatroomErrorEvent e:
        _recordFailure(ChatroomFailureEvent.fromError(e));
      case ChatroomFailureEvent e:
        _recordFailure(e);
      case ChatroomJoined():
      case ChatroomDisconnected():
      case ChatroomAck():
        break;
    }
  }

  Future<void> _handleWorldNotification(ChatroomWorldNotification event) async {
    switch (event.eventType) {
      case 'world_change':
        await _refreshWorld();
      case 'user_location_change':
        await _refreshUserLocations();
      case 'world_new_message':
        await _fetchLatestMessagesForNotification(event.locationId);
      case 'tick_start':
        _setState(_state.copyWith(inputBlocked: true));
        break;
      case 'tick_end':
      case 'tick_done':
        _setState(_state.copyWith(inputBlocked: false));
        break;
      default:
        break;
    }
  }

  Future<WorldDetail> _refreshWorld() async {
    final world = await _api.getWorld(_worldId);
    final entities = _entitiesFromWorld(world);
    _setState(
      _state.copyWith(
        world: world,
        locationTree: world.locationTree,
        processedLocationTree: world.processedLocationTree,
        entitiesById: entities,
        entitiesByLocation: _entitiesByLocation(entities),
      ),
    );
    return world;
  }

  Future<void> _refreshUserLocations() async {
    final response = await _api.chatroomHttp.getUserLocations(
      worldId: _worldId,
    );
    final entities = <String, WorldChatroomEntity>{
      for (final entry in _state.entitiesById.entries)
        if (entry.value.type != WorldChatroomEntityType.player)
          entry.key: entry.value,
    };
    for (final group in response.locations) {
      for (final user in group.users) {
        final id = user.userId.trim();
        if (id.isEmpty) continue;
        final existing = _state.entitiesById[id];
        entities[id] = WorldChatroomEntity(
          id: id,
          name: _firstNonEmpty([existing?.name, user.userName]),
          avatarUrl: _firstNonEmpty([user.avatar, existing?.avatarUrl]),
          type: WorldChatroomEntityType.player,
          locationId: group.locationId,
        );
      }
    }
    _setState(
      _state.copyWith(
        entitiesById: entities,
        entitiesByLocation: _entitiesByLocation(entities),
      ),
    );
  }

  Future<void> _hydrateLocationMessageQueues() async {
    final ownerUid = _storageOwnerUid;
    if (ownerUid.isEmpty || _worldId.isEmpty) return;
    final locationIds = _locationIdsForMessageHydration();
    for (final locationId in locationIds) {
      final localMessages = await _messageStorage.loadLatestMessages(
        ownerUid: ownerUid,
        worldId: _worldId,
        locationId: locationId,
        limit: 20,
      );
      for (final json in localMessages) {
        _upsertMessage(
          WorldChatroomMessage.fromStorageJson(json),
          persist: false,
        );
      }
    }
    for (final locationId in locationIds) {
      try {
        await _fetchLatestMessages(locationId, limit: 20);
      } catch (_) {
        // Initial history hydration is a background cache warmup. A single
        // location failing should not block the world chatroom snapshot.
      }
    }
  }

  List<String> _locationIdsForMessageHydration() {
    final ids = <String>{};
    final world = _state.world;
    if (world != null) {
      for (final node in world.processedLocationTree.flattened) {
        if (node.children.isNotEmpty) continue;
        final id = node.id.trim();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids.toList(growable: false);
  }

  Future<void> _handleIncomingMessage(WorldChatroomMessage message) async {
    if (_shouldFetchGap(message)) {
      await _fetchLatestMessages(message.locationId, limit: 100);
    }
    _upsertMessage(message);
  }

  bool _shouldFetchGap(WorldChatroomMessage message) {
    return message.messageId > 0 &&
        _state.lastMessageId > 0 &&
        message.messageId > _state.lastMessageId + 1 &&
        message.locationId.isNotEmpty;
  }

  Future<void> _fetchLatestMessages(
    String locationId, {
    required int limit,
  }) async {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) return;
    final response = await _api.chatroomHttp.getMessages(
      worldId: _worldId,
      locationId: resolvedLocationId,
      limit: limit,
    );
    await _mergeFetchedMessages(resolvedLocationId, response.messages);
  }

  Future<void> _fetchLatestMessagesForNotification(String locationId) async {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isNotEmpty) {
      await _fetchLatestMessages(resolvedLocationId, limit: 20);
      return;
    }
    for (final id in _locationIdsForMessageHydration()) {
      await _fetchLatestMessages(id, limit: 20);
    }
  }

  Future<void> _mergeFetchedMessages(
    String locationId,
    List<ChatroomHttpMessage> messages,
  ) async {
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
    for (final message in messages) {
      _upsertMessage(
        _worldMessageFromHttpMessage(message, fallbackLocationId: locationId),
        persist: false,
      );
    }
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
      );
      return;
    }
    _upsertMessage(existing.copyWith(content: existing.content + event.chunk));
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
      );
      return;
    }
    _upsertMessage(
      existing.copyWith(
        content: event.content.trim().isEmpty
            ? existing.content
            : event.content,
        streaming: false,
      ),
    );
  }

  void _upsertMessage(WorldChatroomMessage message, {bool persist = true}) {
    final worldMessages = _upsertIntoList(_state.worldMessages, message);
    final byLocation = <String, List<WorldChatroomMessage>>{
      ..._state.messagesByLocation,
    };
    if (message.locationId.isNotEmpty) {
      byLocation[message.locationId] = _trimMessageList(
        _upsertIntoList(
          byLocation[message.locationId] ?? const <WorldChatroomMessage>[],
          message,
        ),
        _maxMessagesPerLocation,
      );
    }
    final streamKeys = <String, WorldChatroomMessage>{
      ..._state.streamMessagesByKey,
    };
    final key = _streamKey(message.locationId, message.conversationRoundId);
    if (message.streaming && key.isNotEmpty) {
      streamKeys[key] = message;
    } else {
      streamKeys.remove(key);
    }
    final lastMessageId = message.messageId > _state.lastMessageId
        ? message.messageId
        : _state.lastMessageId;
    _setState(
      _state.copyWith(
        worldMessages: worldMessages,
        messagesByLocation: byLocation,
        streamMessagesByKey: streamKeys,
        lastMessageId: lastMessageId,
      ),
    );
    if (persist) {
      unawaited(
        _persistMessage(message).catchError((Object error) {
          _recordFailure(
            ChatroomFailureEvent(
              code: 'message_cache_failed',
              message: 'Failed to cache chatroom message',
              sourceType: 'message_cache',
              cause: error,
            ),
          );
        }),
      );
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

  Map<String, WorldChatroomEntity> _entitiesFromWorld(WorldDetail world) {
    final entities = <String, WorldChatroomEntity>{};
    for (final character in world.characters) {
      final entity = _entityFromCharacter(character, '');
      if (entity != null) entities[entity.id] = entity;
    }
    for (final position in world.characterPositions) {
      final locationId = _locationIdFromMap(position);
      final raw = position['character'];
      final character = raw is Map ? asJsonMap(raw) : position;
      final entity = _entityFromCharacter(character, locationId);
      if (entity != null) entities[entity.id] = entity;
    }
    for (final position in world.userPositions) {
      final entity = _entityFromUserPosition(position);
      if (entity == null) continue;
      final existing = entities[entity.id];
      entities[entity.id] = WorldChatroomEntity(
        id: entity.id,
        name: _firstNonEmpty([existing?.name, entity.name]),
        avatarUrl: _firstNonEmpty([entity.avatarUrl, existing?.avatarUrl]),
        type: WorldChatroomEntityType.player,
        locationId: entity.locationId,
        isAi: false,
      );
    }
    return entities;
  }

  WorldChatroomEntity? _entityFromCharacter(
    Map<String, dynamic> character,
    String locationId,
  ) {
    final type = _firstString(character, const ['type', 'sender_type']);
    final normalizedType = type.trim().toLowerCase();
    final playerUid = _firstString(character, const [
      'player_uid',
      'user_id',
      'uid',
    ]);
    final characterId = _firstString(character, const [
      'character_id',
      'char_id',
      'id',
    ]);
    final isPlayer = normalizedType == 'player' || playerUid.isNotEmpty;
    final id = isPlayer
        ? _firstNonEmpty([playerUid, characterId])
        : characterId;
    if (id.isEmpty) return null;
    return WorldChatroomEntity(
      id: id,
      name: _firstString(character, const [
        'name',
        'role_nickname',
        'role_name',
        'character_name',
        'sender_name',
      ]),
      avatarUrl: _firstString(character, const ['avatar', 'avatar_url']),
      type: WorldChatroomEntityType.character,
      locationId: locationId,
      isAi: normalizedType == 'ai',
    );
  }

  WorldChatroomEntity? _entityFromUserPosition(Map<String, dynamic> position) {
    final rawUser = position['user'];
    final user = rawUser is Map ? asJsonMap(rawUser) : position;
    final id = _firstString(user, const ['user_id', 'uid', 'id']);
    if (id.isEmpty) return null;
    return WorldChatroomEntity(
      id: id,
      name: _firstString(user, const [
        'role_nickname',
        'role_name',
        'character_name',
        'name',
        'user_name',
        'sender_name',
      ]),
      avatarUrl: _firstString(user, const ['avatar', 'avatar_url']),
      type: WorldChatroomEntityType.player,
      locationId: _locationIdFromMap(position),
    );
  }

  Map<String, List<WorldChatroomEntity>> _entitiesByLocation(
    Map<String, WorldChatroomEntity> entities,
  ) {
    final byLocation = <String, List<WorldChatroomEntity>>{};
    for (final entity in entities.values) {
      final locationId = entity.locationId.trim();
      if (locationId.isEmpty) continue;
      byLocation
          .putIfAbsent(locationId, () => <WorldChatroomEntity>[])
          .add(entity);
    }
    return {
      for (final entry in byLocation.entries)
        entry.key: List<WorldChatroomEntity>.unmodifiable(entry.value),
    };
  }

  String _locationIdFromMap(Map<String, dynamic> map) {
    return _firstString(map, const ['location_id', 'current_location_id']);
  }

  String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = asString(map[key]).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String _streamKey(String locationId, String conversationRoundId) {
    final location = locationId.trim();
    final round = conversationRoundId.trim();
    if (location.isEmpty || round.isEmpty) return '';
    return '$location|$round';
  }

  void _recordFailure(ChatroomFailureEvent failure) {
    if (!_failures.isClosed) _failures.add(failure);
    _setState(_state.copyWith(lastFailure: failure));
  }

  Future<void> _persistMessage(WorldChatroomMessage message) async {
    final ownerUid = _storageOwnerUid;
    final locationId = message.locationId.trim();
    if (ownerUid.isEmpty ||
        _worldId.isEmpty ||
        locationId.isEmpty ||
        message.streaming ||
        message.messageId <= 0) {
      return;
    }
    await _messageStorage.upsertMessage(
      ownerUid: ownerUid,
      worldId: _worldId,
      locationId: locationId,
      message: _storageJsonFromWorldMessage(message),
      maxMessagesPerLocation: _maxMessagesPerLocation,
    );
  }

  String get _storageOwnerUid {
    final identity = _identity;
    if (identity == null) return '';
    final userId = identity.userId.trim();
    if (userId.isNotEmpty) return userId;
    return identity.senderId.trim();
  }

  Map<String, dynamic> _storageJsonFromWorldMessage(
    WorldChatroomMessage message,
  ) {
    return {
      'msg_id': message.messageId,
      'location_id': message.locationId,
      'conversation_round_id': message.conversationRoundNumber,
      'round_order': message.roundOrder,
      'sender_type': message.senderType,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'user_id': message.userId,
      'client_msg_id': message.clientMsgId,
      'content': message.content,
      'ts': message.createdAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _storageJsonFromHttpMessage(
    ChatroomHttpMessage message, {
    String fallbackLocationId = '',
  }) {
    return {
      'msg_id': message.messageId,
      'location_id': message.locationId.trim().isEmpty
          ? fallbackLocationId
          : message.locationId,
      'conversation_round_id': message.conversationRoundId,
      'round_order': message.roundOrder,
      'sender_type': message.senderType,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'user_id': message.userId,
      'client_msg_id': message.clientMsgId,
      'content': message.content,
      'ts': message.createdAt?.millisecondsSinceEpoch,
    };
  }

  WorldChatroomMessage _worldMessageFromHttpMessage(
    ChatroomHttpMessage message, {
    required String fallbackLocationId,
  }) {
    final worldMessage = WorldChatroomMessage.fromHttpMessage(message);
    if (worldMessage.locationId.trim().isNotEmpty) return worldMessage;
    return worldMessage.copyWith(locationId: fallbackLocationId);
  }

  void _setState(WorldChatroomState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw const ChatroomProtocolException('WorldChatroomService is disposed');
    }
  }
}

class WorldChatroomState {
  const WorldChatroomState({
    this.world,
    this.locationTree = const <LocationTreeNode<Map<String, dynamic>>>[],
    this.processedLocationTree,
    this.entitiesById = const <String, WorldChatroomEntity>{},
    this.entitiesByLocation = const <String, List<WorldChatroomEntity>>{},
    this.worldMessages = const <WorldChatroomMessage>[],
    this.messagesByLocation = const <String, List<WorldChatroomMessage>>{},
    this.streamMessagesByKey = const <String, WorldChatroomMessage>{},
    this.lastMessageId = 0,
    this.connected = false,
    this.joining = false,
    this.joinedLocationId = '',
    this.inputBlocked = false,
    this.reconnecting = false,
    this.lastFailure,
  });

  final WorldDetail? world;
  final List<LocationTreeNode<Map<String, dynamic>>> locationTree;
  final ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree;
  final Map<String, WorldChatroomEntity> entitiesById;
  final Map<String, List<WorldChatroomEntity>> entitiesByLocation;
  final List<WorldChatroomMessage> worldMessages;
  final Map<String, List<WorldChatroomMessage>> messagesByLocation;
  final Map<String, WorldChatroomMessage> streamMessagesByKey;
  final int lastMessageId;
  final bool connected;
  final bool joining;
  final String joinedLocationId;
  final bool inputBlocked;
  final bool reconnecting;
  final ChatroomFailureEvent? lastFailure;

  WorldChatroomState copyWith({
    WorldDetail? world,
    List<LocationTreeNode<Map<String, dynamic>>>? locationTree,
    ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree,
    Map<String, WorldChatroomEntity>? entitiesById,
    Map<String, List<WorldChatroomEntity>>? entitiesByLocation,
    List<WorldChatroomMessage>? worldMessages,
    Map<String, List<WorldChatroomMessage>>? messagesByLocation,
    Map<String, WorldChatroomMessage>? streamMessagesByKey,
    int? lastMessageId,
    bool? connected,
    bool? joining,
    String? joinedLocationId,
    bool? inputBlocked,
    bool? reconnecting,
    ChatroomFailureEvent? lastFailure,
  }) {
    return WorldChatroomState(
      world: world ?? this.world,
      locationTree: locationTree ?? this.locationTree,
      processedLocationTree:
          processedLocationTree ?? this.processedLocationTree,
      entitiesById: entitiesById ?? this.entitiesById,
      entitiesByLocation: entitiesByLocation ?? this.entitiesByLocation,
      worldMessages: worldMessages ?? this.worldMessages,
      messagesByLocation: messagesByLocation ?? this.messagesByLocation,
      streamMessagesByKey: streamMessagesByKey ?? this.streamMessagesByKey,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      connected: connected ?? this.connected,
      joining: joining ?? this.joining,
      joinedLocationId: joinedLocationId ?? this.joinedLocationId,
      inputBlocked: inputBlocked ?? this.inputBlocked,
      reconnecting: reconnecting ?? this.reconnecting,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}

enum WorldChatroomEntityType { character, player }

class WorldChatroomEntity {
  const WorldChatroomEntity({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.type,
    required this.locationId,
    this.isAi = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final WorldChatroomEntityType type;
  final String locationId;
  final bool isAi;
}

class WorldChatroomMessage {
  const WorldChatroomMessage({
    required this.messageId,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.locationId,
    required this.senderType,
    this.userId = '',
    required this.senderId,
    required this.senderName,
    this.clientMsgId = '',
    required this.content,
    required this.createdAt,
    this.streaming = false,
  });

  final int messageId;
  final String conversationRoundId;
  final int roundOrder;
  final String locationId;
  final String senderType;
  final String userId;
  final String senderId;
  final String senderName;
  final String clientMsgId;
  final String content;
  final DateTime? createdAt;
  final bool streaming;

  int get conversationRoundNumber => int.tryParse(conversationRoundId) ?? 0;

  factory WorldChatroomMessage.fromHttpMessage(ChatroomHttpMessage message) {
    return WorldChatroomMessage(
      messageId: message.messageId,
      conversationRoundId: '${message.conversationRoundId}',
      roundOrder: message.roundOrder,
      locationId: message.locationId,
      senderType: message.senderType,
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      clientMsgId: message.clientMsgId,
      content: message.content,
      createdAt: message.createdAt,
    );
  }

  factory WorldChatroomMessage.fromStorageJson(Map<String, dynamic> json) {
    return WorldChatroomMessage.fromHttpMessage(
      ChatroomHttpMessage.fromJson(json),
    );
  }

  factory WorldChatroomMessage.fromUserMessage(ChatroomUserMessage message) {
    return WorldChatroomMessage(
      messageId: message.messageId,
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      locationId: message.locationId,
      senderType: message.senderType.isEmpty ? 'user' : message.senderType,
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      clientMsgId: message.clientMsgId,
      content: message.content,
      createdAt: message.createdAt ?? message.ts,
    );
  }

  factory WorldChatroomMessage.fromNarratorMessage(
    ChatroomNarratorMessage message,
  ) {
    return WorldChatroomMessage(
      messageId: message.messageId,
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      locationId: message.locationId,
      senderType: _senderIdIsNarrator(message.senderId)
          ? 'narrator'
          : 'character',
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      createdAt: message.createdAt ?? message.ts,
    );
  }

  factory WorldChatroomMessage.fromAiStreamStart(ChatroomAiStreamStart event) {
    return WorldChatroomMessage(
      messageId: event.messageId,
      conversationRoundId: event.conversationRoundId,
      roundOrder: event.roundOrder,
      locationId: event.locationId,
      senderType: event.senderType,
      userId: '',
      senderId: event.senderId,
      senderName: event.senderName,
      content: '',
      createdAt: null,
      streaming: true,
    );
  }

  WorldChatroomMessage copyWith({
    int? messageId,
    String? conversationRoundId,
    int? roundOrder,
    String? locationId,
    String? senderType,
    String? userId,
    String? senderId,
    String? senderName,
    String? clientMsgId,
    String? content,
    DateTime? createdAt,
    bool? streaming,
  }) {
    return WorldChatroomMessage(
      messageId: messageId ?? this.messageId,
      conversationRoundId: conversationRoundId ?? this.conversationRoundId,
      roundOrder: roundOrder ?? this.roundOrder,
      locationId: locationId ?? this.locationId,
      senderType: senderType ?? this.senderType,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      streaming: streaming ?? this.streaming,
    );
  }
}

bool _senderIdIsNarrator(String senderId) {
  return senderId.trim().toLowerCase() == 'nar';
}
