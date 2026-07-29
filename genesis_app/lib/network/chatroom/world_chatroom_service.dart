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
import 'chatroom_message_type.dart';
import 'chatroom_message_storage.dart';
import 'chatroom_models.dart';

part 'world_chatroom_connection.dart';
part 'world_chatroom_history_repository.dart';
part 'world_chatroom_event_projection.dart';
part 'world_chatroom_message_reducer.dart';
part 'world_chatroom_world_projection.dart';
part 'world_chatroom_models.dart';

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

enum GemBalanceAlertKind { insufficient, low }

class GemBalanceAlert {
  const GemBalanceAlert({
    required this.kind,
    this.balance = 0,
    this.message = '',
  });

  final GemBalanceAlertKind kind;
  final int balance;
  final String message;
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
  final _balanceAlerts = StreamController<GemBalanceAlert>.broadcast();
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

  Stream<GemBalanceAlert> get balanceAlerts => _balanceAlerts.stream;

  Stream<List<WorldChatroomMessage>> get latestFetchedMessages =>
      _latestFetchedMessages.stream;

  WorldChatroomState get state => _state;

  ChatroomConnectionIdentity? get identity => _identity;

  bool get isDisposed => _disposed;

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
      hasMore: response.hasMore,
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
    await _balanceAlerts.close();
    await _latestFetchedMessages.close();
  }
}
