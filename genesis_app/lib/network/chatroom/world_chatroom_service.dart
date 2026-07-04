import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../app/debug/location_chat_debug_slice.dart';
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
const _maxRecoverableLocationMessageGap = 50;
const _maxLocationMessageGapFillAttempts = 3;
const _defaultLocationQueueInitConcurrency = 4;

bool get _chatroomHydrateMetricsEnabled => kDebugMode || kProfileMode;

void _logChatroomHydrateMetric(String message) {
  if (!_chatroomHydrateMetricsEnabled) return;
  debugPrint('[WorldChatroomHydrate] $message');
}

void _logChatroomSocketEvent(String message) {
  if (!_chatroomHydrateMetricsEnabled) return;
  debugPrint('[WorldChatroomSocket] $message');
}

class WorldChatroomOlderMessagesPage {
  const WorldChatroomOlderMessagesPage({
    required this.loadedCount,
    required this.hasMore,
  });

  final int loadedCount;
  final bool hasMore;
}

class _LocationMessageGap {
  const _LocationMessageGap({required this.lower, required this.upper});

  final int lower;
  final int upper;

  int get missingCount => upper - lower - 1;
}

class WorldChatroomService {
  WorldChatroomService({
    required GenesisApi api,
    required ChatroomClient client,
    required ChatroomMessageStorage messageStorage,
    Duration heartbeatInterval = const Duration(seconds: 2),
    Duration reconnectInterval = const Duration(seconds: 5),
    bool refreshInitialSnapshotOnConnect = true,
  }) : _api = api,
       _client = client,
       _messageStorage = messageStorage,
       _heartbeatInterval = heartbeatInterval,
       _reconnectInterval = reconnectInterval,
       _refreshInitialSnapshotOnConnect = refreshInitialSnapshotOnConnect;

  final GenesisApi _api;
  final ChatroomClient _client;
  final ChatroomMessageStorage _messageStorage;
  final Duration _heartbeatInterval;
  final Duration _reconnectInterval;
  final bool _refreshInitialSnapshotOnConnect;
  final _states = StreamController<WorldChatroomState>.broadcast();
  final _failures = StreamController<ChatroomFailureEvent>.broadcast();
  final _latestFetchedMessages =
      StreamController<List<WorldChatroomMessage>>.broadcast();

  WorldChatroomState _state = const WorldChatroomState();
  ChatroomSession? _session;
  ChatroomConnectionIdentity? _identity;
  String _worldId = '';
  String _desiredLocationId = '';
  bool _userDisconnected = true;
  bool _disposed = false;
  Completer<void>? _connectCompleter;
  Completer<ChatroomJoined>? _joinCompleter;
  final Map<String, Future<void>> _localHydratingMessageFutures =
      <String, Future<void>>{};
  final Set<String> _localHydratedMessageKeys = <String>{};
  int _localMessageCacheGeneration = 0;
  final Map<String, Future<List<WorldChatroomMessage>>>
  _latestMessageFetchFutures = <String, Future<List<WorldChatroomMessage>>>{};
  bool _heartbeatInFlight = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  StreamSubscription<ChatroomEvent>? _eventSubscription;
  StreamSubscription<ChatroomFailureEvent>? _failureSubscription;
  StreamSubscription<ChatroomErrorEvent>? _errorSubscription;
  Future<void> _eventQueue = Future<void>.value();

  Stream<WorldChatroomState> get states => _states.stream;

  Stream<ChatroomFailureEvent> get failures => _failures.stream;

  Stream<List<WorldChatroomMessage>> get latestFetchedMessages =>
      _latestFetchedMessages.stream;

  WorldChatroomState get state => _state;

  ChatroomConnectionIdentity? get identity => _identity;

  void setInputBlocked(bool blocked) {
    _throwIfDisposed();
    if (_state.inputBlocked == blocked) return;
    _setState(_state.copyWith(inputBlocked: blocked));
  }

  void applyWorldSnapshot(WorldDetail world) {
    _throwIfDisposed();
    final entities = _entitiesFromWorld(world);
    _setState(
      _state.copyWith(
        world: world,
        locationTree: world.locationTree,
        processedLocationTree: world.processedLocationTree,
        entitiesById: entities,
        entitiesByLocation: _entitiesByLocation(entities),
        messagesByLocation: _leafLocationMessageQueues(
          world,
          _state.messagesByLocation,
        ),
      ),
    );
  }

  Future<void> refreshUserLocations() async {
    _throwIfDisposed();
    if (_worldId.trim().isEmpty) return;
    await _refreshUserLocations();
  }

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
    if (_desiredLocationId.isNotEmpty) {
      unawaited(_hydrateLocalMessagesForLocation(_desiredLocationId));
    }
    await _connectOnce();
  }

  Future<ChatroomJoined> join({required String locationId}) async {
    _throwIfDisposed();
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) {
      throw const ChatroomProtocolException('locationId is required');
    }
    _desiredLocationId = resolvedLocationId;
    unawaited(_hydrateLocalMessagesForLocation(resolvedLocationId));
    final existing = _joinCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<ChatroomJoined>();
    _joinCompleter = completer;
    unawaited(_joinDesiredLocation(completer));
    return completer.future;
  }

  Future<void> hydrateLocalMessages({
    required String worldId,
    required String locationId,
    String? ownerUid,
    Iterable<String> locationAliases = const <String>[],
  }) async {
    final stopwatch = _chatroomHydrateMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    _throwIfDisposed();
    final resolvedWorldId = worldId.trim();
    final resolvedLocationId = locationId.trim();
    if (resolvedWorldId.isEmpty || resolvedLocationId.isEmpty) return;
    if (_worldId.isEmpty) _worldId = resolvedWorldId;
    final storageLocationIds = _orderedNonEmpty([
      ...locationAliases,
      resolvedLocationId,
    ]);
    _logChatroomHydrateMetric(
      'request start world=$resolvedWorldId state=$resolvedLocationId '
      'storageAliases=${storageLocationIds.join(',')} '
      'owner=${ownerUid?.trim().isNotEmpty == true ? 'provided' : 'service'}',
    );
    LocationChatDebugSlice.recordEvent(
      source: 'service',
      action: 'hydrateStart',
      worldId: resolvedWorldId,
      locationId: resolvedLocationId,
      details: {
        'storageAliases': storageLocationIds,
        'ownerSource': ownerUid?.trim().isNotEmpty == true
            ? 'provided'
            : 'service',
      },
    );
    final hydrations = storageLocationIds.map(
      (storageLocationId) => _hydrateLocalMessagesForLocation(
        storageLocationId,
        worldId: resolvedWorldId,
        ownerUid: ownerUid,
        stateLocationId: resolvedLocationId,
      ),
    );
    await Future.wait(hydrations);
    _logChatroomHydrateMetric(
      'request done world=$resolvedWorldId state=$resolvedLocationId '
      'stateCount=${_state.messagesByLocation[resolvedLocationId]?.length ?? 0} '
      'elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
    _recordServiceQueueDebug(
      action: 'hydrateDone',
      locationId: resolvedLocationId,
      details: {
        'storageAliases': storageLocationIds,
        'elapsedMs': stopwatch?.elapsedMilliseconds,
      },
    );
  }

  Future<List<WorldChatroomMessage>> loadCachedMessages({
    required String worldId,
    required String locationId,
    String? ownerUid,
    Iterable<String> locationAliases = const <String>[],
    int limit = 20,
    bool updateState = true,
  }) async {
    _throwIfDisposed();
    final resolvedWorldId = worldId.trim();
    final resolvedLocationId = locationId.trim();
    if (resolvedWorldId.isEmpty || resolvedLocationId.isEmpty || limit <= 0) {
      return const <WorldChatroomMessage>[];
    }
    if (_worldId.isEmpty) _worldId = resolvedWorldId;
    final resolvedOwnerUid = ownerUid?.trim().isNotEmpty == true
        ? ownerUid!.trim()
        : _storageOwnerUid;
    if (resolvedOwnerUid.isEmpty) return const <WorldChatroomMessage>[];

    final storageLocationIds = _orderedNonEmpty([
      ...locationAliases,
      resolvedLocationId,
    ]);
    var messages = const <WorldChatroomMessage>[];
    for (final storageLocationId in storageLocationIds) {
      final localMessages = await _messageStorage.loadLatestMessages(
        ownerUid: resolvedOwnerUid,
        worldId: resolvedWorldId,
        locationId: storageLocationId,
        limit: limit,
      );
      for (final json in localMessages) {
        final message = WorldChatroomMessage.fromStorageJson(json);
        messages = _trimMessageList(
          _upsertIntoList(
            messages,
            message.locationId == resolvedLocationId
                ? message
                : message.copyWith(locationId: resolvedLocationId),
          ),
          limit,
        );
      }
    }
    if (updateState && messages.isNotEmpty) {
      _upsertMessages(messages, persist: false);
    }
    if (LocationChatDebugSlice.enabled) {
      LocationChatDebugSlice.recordEvent(
        source: 'service',
        action: 'loadCached',
        worldId: resolvedWorldId,
        locationId: resolvedLocationId,
        details: {
          'ownerUid': resolvedOwnerUid,
          'storageAliases': storageLocationIds,
          'limit': limit,
          'updateState': updateState,
          'loaded': messages.length,
          'messages': LocationChatDebugSlice.debugWorldMessageQueue(messages),
        },
      );
    }
    return messages;
  }

  Future<List<WorldChatroomMessage>> refreshLatestMessages({
    required String locationId,
    int limit = 20,
    bool emitLatestFetched = true,
  }) async {
    _throwIfDisposed();
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty || limit <= 0) {
      return const <WorldChatroomMessage>[];
    }
    if (_worldId.isEmpty) return const <WorldChatroomMessage>[];
    final fetchKey =
        'location\u001F$_worldId\u001F$resolvedLocationId\u001F$limit\u001F$emitLatestFetched';
    final existingFetch = _latestMessageFetchFutures[fetchKey];
    if (existingFetch != null) {
      return existingFetch;
    }
    final fetch = _fetchLatestLocationMessagesWithFailure(
      locationId: resolvedLocationId,
      limit: limit,
      emitLatestFetched: emitLatestFetched,
    );
    LocationChatDebugSlice.recordEvent(
      source: 'service',
      action: 'refreshLatestStart',
      worldId: _worldId,
      locationId: resolvedLocationId,
      details: {'limit': limit, 'emitLatestFetched': emitLatestFetched},
    );
    _latestMessageFetchFutures[fetchKey] = fetch;
    try {
      return await fetch;
    } finally {
      _latestMessageFetchFutures.remove(fetchKey);
    }
  }

  Future<void> initializeLeafLocationQueues({
    Iterable<String>? locationIds,
    int latestLimit = 20,
    int concurrency = _defaultLocationQueueInitConcurrency,
  }) async {
    _throwIfDisposed();
    if (_worldId.isEmpty || latestLimit <= 0) return;
    final ids = _orderedNonEmpty(
      locationIds ?? _leafLocationIdsForCurrentWorld(),
    );
    if (ids.isEmpty) return;
    final stopwatch = _chatroomHydrateMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    _logChatroomHydrateMetric(
      'leaf queue init start world=$_worldId locations=${ids.length} '
      'limit=$latestLimit concurrency=$concurrency',
    );
    _recordServiceQueueDebug(
      action: 'leafQueueInitStart',
      locationId: '',
      details: {
        'locations': ids,
        'limit': latestLimit,
        'concurrency': concurrency,
      },
    );
    await _runLimited<String>(
      ids,
      math.max(1, concurrency),
      (locationId) => _initializeLeafLocationQueue(
        locationId: locationId,
        latestLimit: latestLimit,
      ),
    );
    _logChatroomHydrateMetric(
      'leaf queue init done world=$_worldId locations=${ids.length} '
      'elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
    _recordServiceQueueDebug(
      action: 'leafQueueInitDone',
      locationId: '',
      details: {'locations': ids, 'elapsedMs': stopwatch?.elapsedMilliseconds},
    );
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
          message: 'Something went wrong',
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
              message: 'Something went wrong',
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
    LocationChatDebugSlice.recordEvent(
      source: 'service',
      action: 'loadOlderStart',
      worldId: _worldId,
      locationId: resolvedLocationId,
      details: {'beforeMessageId': beforeMessageId, 'limit': limit},
    );
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
        final queueMessageId = message.locationQueueMessageId;
        if (queueMessageId > 0) loadedMessageIds.add(queueMessageId);
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
      final queueMessageId = message.locationMessageId;
      if (queueMessageId > 0) loadedMessageIds.add(queueMessageId);
    }
    final page = WorldChatroomOlderMessagesPage(
      loadedCount: loadedMessageIds.length,
      hasMore: response.hasMore || loadedMessageIds.length >= limit,
    );
    _recordServiceQueueDebug(
      action: 'loadOlderDone',
      locationId: resolvedLocationId,
      details: {
        'beforeMessageId': beforeMessageId,
        'limit': limit,
        'loadedCount': page.loadedCount,
        'hasMore': page.hasMore,
      },
    );
    return page;
  }

  Future<void> clearCachedMessages() async {
    _throwIfDisposed();
    final ownerUid = _storageOwnerUid;
    if (ownerUid.isEmpty) return;
    await _messageStorage.clearCache(ownerUid);
    _localMessageCacheGeneration += 1;
    _localHydratedMessageKeys.clear();
    _localHydratingMessageFutures.clear();
    _setState(
      _state.copyWith(
        worldMessages: const <WorldChatroomMessage>[],
        messagesByLocation: _leafLocationMessageQueues(
          _state.world,
          const <String, List<WorldChatroomMessage>>{},
        ),
        streamMessagesByKey: const <String, WorldChatroomMessage>{},
        lastMessageId: 0,
      ),
    );
    LocationChatDebugSlice.recordEvent(
      source: 'service',
      action: 'clearCachedMessages',
      worldId: _worldId,
      details: {'ownerUid': ownerUid},
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _states.close();
    await _failures.close();
    await _latestFetchedMessages.close();
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
      if (_refreshInitialSnapshotOnConnect) {
        await _refreshInitialSnapshot();
      }
      final desiredLocationId = _desiredLocationId;
      if (desiredLocationId.isNotEmpty && _joinCompleter == null) {
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
              message: 'Failed to connect to chatroom',
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
      await _refreshUserLocations();
    } catch (e) {
      _recordFailure(
        ChatroomFailureEvent(
          code: 'snapshot_failed',
          message: 'Something went wrong',
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
              message: 'Something went wrong',
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
        final joinedLocationId = joined.locationId.isEmpty
            ? locationId
            : joined.locationId;
        _setState(
          _state.copyWith(
            connected: true,
            joining: false,
            joinedLocationId: joinedLocationId,
          ),
        );
        unawaited(
          refreshLatestMessages(locationId: joinedLocationId, limit: 20),
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
    _logChatroomSocketEvent(
      'event received type=${chatroomEventType(event)} '
      'world=$_worldId joined=${_state.joinedLocationId}',
    );
    _eventQueue = _eventQueue.then((_) => _handleEvent(event)).catchError((
      Object error,
    ) {
      _recordFailure(
        ChatroomFailureEvent(
          code: 'event_handle_failed',
          message: 'Something went wrong',
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

  Future<void> _initializeLeafLocationQueue({
    required String locationId,
    required int latestLimit,
  }) async {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty || _worldId.isEmpty) return;
    try {
      _recordServiceQueueDebug(
        action: 'leafQueueInitLocationStart',
        locationId: resolvedLocationId,
        details: {'limit': latestLimit},
      );
      final response = await _api.chatroomHttp.getMessages(
        worldId: _worldId,
        locationId: resolvedLocationId,
        since: 0,
        limit: latestLimit,
      );
      await _mergeFetchedMessages(resolvedLocationId, response.messages);
      await _repairLocationMessageGaps(resolvedLocationId);
      _recordServiceQueueDebug(
        action: 'leafQueueInitLocationDone',
        locationId: resolvedLocationId,
        details: {
          'loaded': response.messages.length,
          'hasMore': response.hasMore,
        },
      );
    } catch (error) {
      _recordServiceQueueDebug(
        action: 'leafQueueInitLocationFailed',
        locationId: resolvedLocationId,
        details: {'error': '$error'},
      );
    }
  }

  Future<void> _repairLocationMessageGaps(String locationId) async {
    final unresolvedGapKeys = <String>{};
    for (var pass = 0; pass < _maxMessagesPerLocation; pass += 1) {
      final gap = _firstLocationMessageGap(
        _state.messagesByLocation[locationId] ?? const <WorldChatroomMessage>[],
        ignoredKeys: unresolvedGapKeys,
      );
      if (gap == null) return;
      final gapKey = _locationMessageGapKey('', gap);
      if (gap.missingCount > _maxRecoverableLocationMessageGap) {
        await _discardLocationMessagesAtOrBefore(
          locationId: locationId,
          maxLocationMessageId: gap.lower,
          reason: 'largeGap',
        );
        continue;
      }
      final filled = await _fillLocationMessageGap(
        locationId: locationId,
        gap: gap,
      );
      if (!filled) {
        unresolvedGapKeys.add(gapKey);
        return;
      }
    }
  }

  Future<bool> _fillLocationMessageGap({
    required String locationId,
    required _LocationMessageGap gap,
  }) async {
    final limit = math.min(100, gap.missingCount + 1);
    for (
      var attempt = 1;
      attempt <= _maxLocationMessageGapFillAttempts;
      attempt += 1
    ) {
      try {
        _recordServiceQueueDebug(
          action: 'gapFillStart',
          locationId: locationId,
          details: {
            'lower': gap.lower,
            'upper': gap.upper,
            'missingCount': gap.missingCount,
            'attempt': attempt,
            'limit': limit,
          },
        );
        final response = await _api.chatroomHttp.getMessages(
          worldId: _worldId,
          locationId: locationId,
          since: gap.upper,
          limit: limit,
        );
        await _mergeFetchedMessages(locationId, response.messages);
        if (_isLocationMessageGapFilled(
          _state.messagesByLocation[locationId] ??
              const <WorldChatroomMessage>[],
          gap,
        )) {
          _recordServiceQueueDebug(
            action: 'gapFillDone',
            locationId: locationId,
            details: {
              'lower': gap.lower,
              'upper': gap.upper,
              'attempt': attempt,
              'loaded': response.messages.length,
            },
          );
          return true;
        }
      } catch (error) {
        _recordServiceQueueDebug(
          action: 'gapFillFailed',
          locationId: locationId,
          details: {
            'lower': gap.lower,
            'upper': gap.upper,
            'attempt': attempt,
            'error': '$error',
          },
        );
      }
    }
    _recordServiceQueueDebug(
      action: 'gapFillReleased',
      locationId: locationId,
      details: {
        'lower': gap.lower,
        'upper': gap.upper,
        'attempts': _maxLocationMessageGapFillAttempts,
      },
    );
    return false;
  }

  Future<void> _discardLocationMessagesAtOrBefore({
    required String locationId,
    required int maxLocationMessageId,
    required String reason,
  }) async {
    if (maxLocationMessageId <= 0) return;
    final ownerUid = _storageOwnerUid;
    if (ownerUid.isNotEmpty && _worldId.isNotEmpty) {
      await _messageStorage.deleteMessagesAtOrBefore(
        ownerUid: ownerUid,
        worldId: _worldId,
        locationId: locationId,
        maxLocationMessageId: maxLocationMessageId,
      );
    }
    final byLocation = Map<String, List<WorldChatroomMessage>>.from(
      _state.messagesByLocation,
    );
    byLocation[locationId] = List<WorldChatroomMessage>.unmodifiable(
      (byLocation[locationId] ?? const <WorldChatroomMessage>[]).where(
        (message) => message.locationQueueMessageId > maxLocationMessageId,
      ),
    );
    final streamMessagesByKey = <String, WorldChatroomMessage>{
      ..._state.streamMessagesByKey,
    };
    streamMessagesByKey.removeWhere((_, message) {
      return message.locationId == locationId &&
          message.locationQueueMessageId <= maxLocationMessageId;
    });
    _setState(
      _state.copyWith(
        worldMessages: _state.worldMessages
            .where(
              (message) =>
                  message.locationId != locationId ||
                  message.locationQueueMessageId > maxLocationMessageId,
            )
            .toList(growable: false),
        messagesByLocation: byLocation,
        streamMessagesByKey: streamMessagesByKey,
      ),
    );
    _recordServiceQueueDebug(
      action: 'discardLocationMessages',
      locationId: locationId,
      details: {'maxLocationMessageId': maxLocationMessageId, 'reason': reason},
    );
  }

  _LocationMessageGap? _firstLocationMessageGap(
    List<WorldChatroomMessage> messages, {
    Set<String> ignoredKeys = const <String>{},
  }) {
    final ids =
        messages
            .where(
              (message) =>
                  !_isTickAdvanceWorldMessage(message) &&
                  message.locationMessageId > 0,
            )
            .map((message) => message.locationMessageId)
            .toSet()
            .toList(growable: false)
          ..sort();
    for (var index = 1; index < ids.length; index += 1) {
      final lower = ids[index - 1];
      final upper = ids[index];
      if (upper <= lower + 1) continue;
      final gap = _LocationMessageGap(lower: lower, upper: upper);
      if (ignoredKeys.contains(_locationMessageGapKey('', gap))) continue;
      return gap;
    }
    return null;
  }

  bool _isTickAdvanceWorldMessage(WorldChatroomMessage message) {
    return message.senderType.trim().toLowerCase() == 'tick';
  }

  bool _isLocationMessageGapFilled(
    List<WorldChatroomMessage> messages,
    _LocationMessageGap gap,
  ) {
    final ids = messages
        .where(
          (message) =>
              !_isTickAdvanceWorldMessage(message) &&
              message.locationMessageId > 0,
        )
        .map((message) => message.locationMessageId)
        .toSet();
    for (var id = gap.lower + 1; id < gap.upper; id += 1) {
      if (!ids.contains(id)) return false;
    }
    return true;
  }

  String _locationMessageGapKey(String locationId, _LocationMessageGap gap) {
    return '${locationId.trim()}\u001F${gap.lower}\u001F${gap.upper}';
  }

  Future<void> _runLimited<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) run,
  ) async {
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < items.length) {
        final index = nextIndex;
        nextIndex += 1;
        await run(items[index]);
      }
    }

    final workerCount = math.min(concurrency, items.length);
    await Future.wait<void>([
      for (var i = 0; i < workerCount; i += 1) worker(),
    ]);
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
      case ChatroomTickAdvanceMessage e:
        await _handleTickAdvanceMessage(
          WorldChatroomMessage.fromTickAdvanceMessage(e),
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
    _logChatroomSocketEvent(
      'world notification event=${event.eventType} '
      'location=${event.locationId} world=$_worldId',
    );
    switch (event.eventType) {
      case 'world_change':
        await _refreshWorld();
      case 'user_location_change':
        await _refreshUserLocations();
      case 'world_new_message':
        _logChatroomSocketEvent(
          'world_new_message fetch start location=${event.locationId} '
          'world=$_worldId',
        );
        await _fetchLatestMessagesForNotification();
        _logChatroomSocketEvent(
          'world_new_message fetch done location=${event.locationId} '
          'world=$_worldId',
        );
      case 'tick_start':
        _setState(_state.copyWith(inputBlocked: true));
        break;
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
        messagesByLocation: _leafLocationMessageQueues(
          world,
          _state.messagesByLocation,
        ),
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
        entry.key: entry.value.type == WorldChatroomEntityType.player
            ? _entityWithoutLocation(entry.value)
            : entry.value,
    };
    for (final group in response.locations) {
      for (final user in group.users) {
        final id = user.userId.trim();
        if (id.isEmpty) continue;
        final existing = _state.entitiesById[id];
        final locationId = group.locationId.trim();
        entities[id] = WorldChatroomEntity(
          id: id,
          name: _firstNonEmpty([existing?.name, user.userName, id]),
          avatarUrl: _firstNonEmpty([existing?.avatarUrl, user.avatar]),
          type: WorldChatroomEntityType.player,
          locationId: locationId,
          isAi: false,
        );
      }
    }
    final locatedEntities = entities.values
        .where((entity) => entity.locationId.trim().isNotEmpty)
        .length;
    final realUsers = entities.values
        .where((entity) => entity.locationId.trim().isNotEmpty && !entity.isAi)
        .length;
    _logChatroomSocketEvent(
      'user locations refreshed groups=${response.locations.length} '
      'located=$locatedEntities realUsers=$realUsers world=$_worldId',
    );
    final world = _state.world;
    final updatedWorld = world == null
        ? null
        : _worldWithEntityLocations(world, entities);
    _setState(
      _state.copyWith(
        world: updatedWorld,
        entitiesById: entities,
        entitiesByLocation: _entitiesByLocation(entities),
      ),
    );
  }

  WorldDetail _worldWithEntityLocations(
    WorldDetail world,
    Map<String, WorldChatroomEntity> entities,
  ) {
    final characters = world.characters
        .map((character) {
          final copy = Map<String, dynamic>.from(character);
          final playerUid = _firstString(copy, const ['player_uid', 'user_id']);
          final charId = _firstString(copy, const [
            'char_id',
            'character_id',
            'id',
          ]);
          final entity = _firstEntity(entities, [
            if (playerUid.isNotEmpty) playerUid,
            if (charId.isNotEmpty) charId,
          ]);
          if (entity == null || entity.locationId.trim().isEmpty) {
            copy.remove('location_id');
            copy.remove('current_location_id');
            return copy;
          }
          copy['location_id'] = entity.locationId;
          return copy;
        })
        .toList(growable: false);
    return world.copyWith(
      characters: characters,
      locations: _locationsWithCharacters(world.locations, characters),
      characterPositions: characters
          .map(_characterPositionFromWorldCharacter)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      userPositions: characters
          .map(_userPositionFromWorldCharacter)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    );
  }

  WorldChatroomEntity? _firstEntity(
    Map<String, WorldChatroomEntity> entities,
    Iterable<String> ids,
  ) {
    for (final id in ids) {
      final entity = entities[id.trim()];
      if (entity != null) return entity;
    }
    return null;
  }

  WorldChatroomEntity _entityWithoutLocation(WorldChatroomEntity entity) {
    if (entity.locationId.trim().isEmpty) return entity;
    return WorldChatroomEntity(
      id: entity.id,
      name: entity.name,
      avatarUrl: entity.avatarUrl,
      type: entity.type,
      locationId: '',
      isAi: entity.isAi,
    );
  }

  List<Map<String, dynamic>> _locationsWithCharacters(
    List<Map<String, dynamic>> locations,
    List<Map<String, dynamic>> characters,
  ) {
    return locations
        .map((location) {
          final copy = Map<String, dynamic>.from(location);
          final locationId = _locationIdFromMap(copy);
          copy['characters'] = characters
              .where((character) => _locationIdFromMap(character) == locationId)
              .map((character) => Map<String, dynamic>.from(character))
              .toList(growable: false);
          return copy;
        })
        .toList(growable: false);
  }

  Map<String, dynamic>? _characterPositionFromWorldCharacter(
    Map<String, dynamic> character,
  ) {
    final locationId = _locationIdFromMap(character);
    if (locationId.isEmpty) return null;
    return {
      'location_id': locationId,
      'character': {
        'id': _firstString(character, const ['char_id', 'character_id', 'id']),
        'name': _firstString(character, const ['name']),
        'type': _firstString(character, const ['type']),
        'player_uid': _firstString(character, const ['player_uid', 'user_id']),
        'player_username': _firstString(character, const [
          'player_username',
          'user_name',
          'username',
        ]),
        'player_deleted': character['player_deleted'],
        'identity': _firstString(character, const ['identity']),
        'tagline': _firstString(character, const ['brief', 'tagline']),
        'description': _firstString(character, const ['description']),
        'avatar': _firstImageUrl(character, const ['avatar', 'avatar_url']),
      },
    };
  }

  Map<String, dynamic>? _userPositionFromWorldCharacter(
    Map<String, dynamic> character,
  ) {
    final playerUid = _firstString(character, const ['player_uid', 'user_id']);
    final locationId = _locationIdFromMap(character);
    if (playerUid.isEmpty || locationId.isEmpty) return null;
    return {'uid': playerUid, 'location_id': locationId};
  }

  Future<void> _hydrateLocalMessagesForLocation(
    String locationId, {
    String? worldId,
    String? ownerUid,
    String? stateLocationId,
  }) async {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) return;
    final resolvedStateLocationId = stateLocationId?.trim().isNotEmpty == true
        ? stateLocationId!.trim()
        : resolvedLocationId;
    final resolvedOwnerUid = ownerUid?.trim().isNotEmpty == true
        ? ownerUid!.trim()
        : _storageOwnerUid;
    final resolvedWorldId = worldId?.trim().isNotEmpty == true
        ? worldId!.trim()
        : _worldId;
    if (resolvedOwnerUid.isEmpty || resolvedWorldId.isEmpty) return;
    final hydrationKey = _messageHydrationKey(
      ownerUid: resolvedOwnerUid,
      worldId: resolvedWorldId,
      locationId: resolvedLocationId,
      stateLocationId: resolvedStateLocationId,
    );
    if (_localHydratedMessageKeys.contains(hydrationKey)) {
      _logChatroomHydrateMetric(
        'alias skip hydrated storage=$resolvedLocationId '
        'state=$resolvedStateLocationId',
      );
      return;
    }
    final existingHydration = _localHydratingMessageFutures[hydrationKey];
    if (existingHydration != null) {
      final stopwatch = _chatroomHydrateMetricsEnabled
          ? (Stopwatch()..start())
          : null;
      _logChatroomHydrateMetric(
        'alias wait inFlight storage=$resolvedLocationId '
        'state=$resolvedStateLocationId',
      );
      await existingHydration;
      _logChatroomHydrateMetric(
        'alias waited inFlight storage=$resolvedLocationId '
        'state=$resolvedStateLocationId '
        'elapsed=${stopwatch?.elapsedMilliseconds}ms',
      );
      return;
    }
    final hydration = _loadLocalMessagesForLocation(
      ownerUid: resolvedOwnerUid,
      worldId: resolvedWorldId,
      storageLocationId: resolvedLocationId,
      stateLocationId: resolvedStateLocationId,
      hydrationKey: hydrationKey,
      cacheGeneration: _localMessageCacheGeneration,
    );
    _localHydratingMessageFutures[hydrationKey] = hydration;
    try {
      await hydration;
    } finally {
      if (identical(_localHydratingMessageFutures[hydrationKey], hydration)) {
        _localHydratingMessageFutures.remove(hydrationKey);
      }
    }
  }

  Future<void> _loadLocalMessagesForLocation({
    required String ownerUid,
    required String worldId,
    required String storageLocationId,
    required String stateLocationId,
    required String hydrationKey,
    required int cacheGeneration,
  }) async {
    final stopwatch = _chatroomHydrateMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final beforeStateCount =
        _state.messagesByLocation[stateLocationId]?.length ?? 0;
    _logChatroomHydrateMetric(
      'db load start storage=$storageLocationId state=$stateLocationId '
      'world=$worldId beforeStateCount=$beforeStateCount',
    );
    try {
      final localMessages = await _messageStorage.loadLatestMessages(
        ownerUid: ownerUid,
        worldId: worldId,
        locationId: storageLocationId,
        limit: 20,
      );
      if (cacheGeneration != _localMessageCacheGeneration) {
        _logChatroomHydrateMetric(
          'db load skipped stale generation storage=$storageLocationId '
          'state=$stateLocationId',
        );
        return;
      }
      final hydratedMessages = localMessages
          .map((json) {
            final message = WorldChatroomMessage.fromStorageJson(json);
            return message.locationId == stateLocationId
                ? message
                : message.copyWith(locationId: stateLocationId);
          })
          .toList(growable: false);
      _upsertMessages(hydratedMessages, persist: false);
      _localHydratedMessageKeys.add(hydrationKey);
      final afterStateCount =
          _state.messagesByLocation[stateLocationId]?.length ?? 0;
      final firstMessageId = localMessages.isEmpty
          ? 0
          : WorldChatroomMessage.fromStorageJson(localMessages.first).messageId;
      _logChatroomHydrateMetric(
        'db load done storage=$storageLocationId state=$stateLocationId '
        'loaded=${localMessages.length} firstMsg=$firstMessageId '
        'beforeStateCount=$beforeStateCount afterStateCount=$afterStateCount '
        'elapsed=${stopwatch?.elapsedMilliseconds}ms',
      );
      _recordServiceQueueDebug(
        action: 'dbHydrateDone',
        locationId: stateLocationId,
        details: {
          'storageLocationId': storageLocationId,
          'loaded': localMessages.length,
          'firstMsg': firstMessageId,
          'beforeStateCount': beforeStateCount,
          'afterStateCount': afterStateCount,
          'elapsedMs': stopwatch?.elapsedMilliseconds,
        },
      );
    } catch (e) {
      _logChatroomHydrateMetric(
        'db load failed storage=$storageLocationId state=$stateLocationId '
        'elapsed=${stopwatch?.elapsedMilliseconds}ms error=$e',
      );
      LocationChatDebugSlice.recordEvent(
        source: 'service',
        action: 'dbHydrateFailed',
        worldId: worldId,
        locationId: stateLocationId,
        details: {
          'storageLocationId': storageLocationId,
          'elapsedMs': stopwatch?.elapsedMilliseconds,
          'error': '$e',
        },
      );
      _recordFailure(
        ChatroomFailureEvent(
          code: 'message_cache_load_failed',
          message: 'Something went wrong',
          sourceType: 'message_cache',
          cause: e,
        ),
      );
    }
  }

  String _messageHydrationKey({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required String stateLocationId,
  }) => '$ownerUid\u001F$worldId\u001F$locationId\u001F$stateLocationId';

  List<String> _orderedNonEmpty(Iterable<String?> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) continue;
      result.add(trimmed);
    }
    return result;
  }

  Future<void> _handleIncomingMessage(WorldChatroomMessage message) async {
    _upsertMessage(message);
  }

  Future<void> _handleTickAdvanceMessage(WorldChatroomMessage message) async {
    final messages = _tickAdvanceLocationIds(message.locationId)
        .map((locationId) => message.copyWith(locationId: locationId))
        .toList(growable: false);
    _upsertMessages(messages.isEmpty ? [message] : messages);
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
    );
  }

  void _upsertMessage(WorldChatroomMessage message, {bool persist = true}) {
    _upsertMessages([message], persist: persist);
  }

  void _upsertMessages(
    List<WorldChatroomMessage> messages, {
    bool persist = true,
  }) {
    if (messages.isEmpty) return;
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
      _state.copyWith(
        worldMessages: worldMessages,
        messagesByLocation: byLocation,
        streamMessagesByKey: streamKeys,
        lastMessageId: lastMessageId,
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
    if (a.locationId == b.locationId &&
        a.locationMessageId > 0 &&
        b.locationMessageId > 0) {
      return a.locationMessageId.compareTo(b.locationMessageId);
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
    return _isTickAdvanceWorldMessage(message) || message.locationMessageId > 0;
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
    final name = isPlayer
        ? _firstNonEmpty([
            _firstString(character, const [
              'name',
              'role_nickname',
              'role_name',
              'character_name',
            ]),
            _firstString(character, const [
              'player_username',
              'user_name',
              'username',
              'sender_name',
            ]),
            id,
          ])
        : _firstString(character, const [
            'name',
            'role_nickname',
            'role_name',
            'character_name',
            'sender_name',
          ]);
    return WorldChatroomEntity(
      id: id,
      name: name,
      avatarUrl: _firstImageUrl(character, const ['avatar', 'avatar_url']),
      type: isPlayer
          ? WorldChatroomEntityType.player
          : WorldChatroomEntityType.character,
      locationId: locationId,
      isAi: !isPlayer,
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
      avatarUrl: _firstImageUrl(user, const ['avatar', 'avatar_url']),
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

  String _firstImageUrl(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final value = map[key];
      final resolved = asResolvedImageUrl(value, resolveAssetUrl);
      if (resolved.isNotEmpty) return resolved;
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
    if (LocationChatDebugSlice.enabled) {
      LocationChatDebugSlice.recordEvent(
        source: 'service',
        action: 'persistMessage',
        worldId: _worldId,
        locationId: locationId,
        details: {
          'ownerUid': ownerUid,
          'message': LocationChatDebugSlice.debugWorldMessage(message),
        },
      );
    }
  }

  void _recordServiceQueueDebug({
    required String action,
    required String locationId,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    LocationChatDebugSlice.recordServiceQueue(
      action: action,
      worldId: _worldId,
      locationId: locationId,
      state: _state,
      details: details,
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
      'global_msg_id': message.globalMessageId,
      'msg_id': message.messageId,
      'location_msg_id': message.locationMessageId,
      'location_id': message.locationId,
      'conversation_round_id': message.conversationRoundNumber,
      'round_order': message.roundOrder,
      'tick_no': message.tickNo,
      'sender_type': message.senderType,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'user_id': message.userId,
      'client_msg_id': message.clientMsgId,
      'content': message.content,
      'current_time': message.currentTime,
      'ts': message.createdAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _storageJsonFromHttpMessage(
    ChatroomHttpMessage message, {
    String fallbackLocationId = '',
  }) {
    return {
      'global_msg_id': message.globalMessageId,
      'msg_id': message.messageId,
      'location_msg_id': message.locationMessageId,
      'location_id': message.locationId.trim().isEmpty
          ? fallbackLocationId
          : message.locationId,
      'conversation_round_id': message.conversationRoundId,
      'round_order': 0,
      'tick_no': message.tickNo,
      'sender_type': message.senderType,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'user_id': message.userId,
      'client_msg_id': '',
      'content': message.content,
      'current_time': message.currentTime,
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
    this.globalMessageId = 0,
    required this.messageId,
    this.locationMessageId = 0,
    required this.conversationRoundId,
    required this.roundOrder,
    this.tickNo = 0,
    required this.locationId,
    required this.senderType,
    this.userId = '',
    required this.senderId,
    required this.senderName,
    this.clientMsgId = '',
    required this.content,
    this.currentTime = '',
    required this.createdAt,
    this.streaming = false,
  });

  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final int roundOrder;
  final int tickNo;
  final String locationId;
  final String senderType;
  final String userId;
  final String senderId;
  final String senderName;
  final String clientMsgId;
  final String content;
  final String currentTime;
  final DateTime? createdAt;
  final bool streaming;

  int get locationQueueMessageId => locationMessageId;

  int get conversationRoundNumber => int.tryParse(conversationRoundId) ?? 0;

  factory WorldChatroomMessage.fromHttpMessage(ChatroomHttpMessage message) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: message.locationMessageId,
      conversationRoundId: '${message.conversationRoundId}',
      roundOrder: 0,
      tickNo: message.tickNo,
      locationId: message.locationId,
      senderType: message.senderType,
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      clientMsgId: '',
      content: message.content,
      currentTime: message.currentTime,
      createdAt: message.createdAt,
    );
  }

  factory WorldChatroomMessage.fromStorageJson(Map<String, dynamic> json) {
    return WorldChatroomMessage(
      globalMessageId: asInt(json['global_msg_id']),
      messageId: asInt(json['msg_id']),
      locationMessageId: asInt(json['location_msg_id']),
      conversationRoundId: asString(
        json['conversation_round_id'],
        fallback: '${asInt(json['conversation_round_id'])}',
      ),
      roundOrder: asInt(json['round_order']),
      tickNo: asInt(json['tick_no']),
      locationId: asString(json['location_id']),
      senderType: asString(json['sender_type']),
      userId: asString(json['user_id']),
      senderId: asString(json['sender_id']),
      senderName: asString(json['sender_name']),
      clientMsgId: asString(json['client_msg_id']),
      content: asString(json['content']),
      currentTime: asString(json['current_time']),
      createdAt: asDateTime(json['ts']),
    );
  }

  factory WorldChatroomMessage.fromUserMessage(ChatroomUserMessage message) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: message.locationMessageId,
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      locationId: message.locationId,
      senderType: message.senderType.isEmpty ? 'user' : message.senderType,
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      clientMsgId: message.clientMsgId,
      content: message.content,
      currentTime: message.currentTime,
      createdAt: message.createdAt ?? message.ts,
    );
  }

  factory WorldChatroomMessage.fromNarratorMessage(
    ChatroomNarratorMessage message,
  ) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: message.locationMessageId,
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
      currentTime: message.currentTime,
      createdAt: message.createdAt ?? message.ts,
    );
  }

  factory WorldChatroomMessage.fromTickAdvanceMessage(
    ChatroomTickAdvanceMessage message,
  ) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: message.locationMessageId,
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      tickNo: message.tickNo,
      locationId: message.locationId,
      senderType: 'tick',
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content.isEmpty ? message.currentTime : message.content,
      currentTime: message.currentTime,
      createdAt: message.ts,
    );
  }

  factory WorldChatroomMessage.fromAiStreamStart(ChatroomAiStreamStart event) {
    return WorldChatroomMessage(
      globalMessageId: event.globalMessageId,
      messageId: event.messageId,
      locationMessageId: event.locationMessageId,
      conversationRoundId: event.conversationRoundId,
      roundOrder: event.roundOrder,
      tickNo: 0,
      locationId: event.locationId,
      senderType: event.senderType,
      userId: '',
      senderId: event.senderId,
      senderName: event.senderName,
      content: '',
      currentTime: event.currentTime,
      createdAt: null,
      streaming: true,
    );
  }

  WorldChatroomMessage copyWith({
    int? globalMessageId,
    int? messageId,
    int? locationMessageId,
    String? conversationRoundId,
    int? roundOrder,
    int? tickNo,
    String? locationId,
    String? senderType,
    String? userId,
    String? senderId,
    String? senderName,
    String? clientMsgId,
    String? content,
    String? currentTime,
    DateTime? createdAt,
    bool? streaming,
  }) {
    return WorldChatroomMessage(
      globalMessageId: globalMessageId ?? this.globalMessageId,
      messageId: messageId ?? this.messageId,
      locationMessageId: locationMessageId ?? this.locationMessageId,
      conversationRoundId: conversationRoundId ?? this.conversationRoundId,
      roundOrder: roundOrder ?? this.roundOrder,
      tickNo: tickNo ?? this.tickNo,
      locationId: locationId ?? this.locationId,
      senderType: senderType ?? this.senderType,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      content: content ?? this.content,
      currentTime: currentTime ?? this.currentTime,
      createdAt: createdAt ?? this.createdAt,
      streaming: streaming ?? this.streaming,
    );
  }
}

bool _senderIdIsNarrator(String senderId) {
  return senderId.trim().toLowerCase() == 'nar';
}
