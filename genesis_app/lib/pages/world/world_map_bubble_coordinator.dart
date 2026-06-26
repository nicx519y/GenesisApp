import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/world_map.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/world.dart';
import 'world_location_chat_host.dart';
import 'world_models.dart';
import 'world_value_helpers.dart';

class WorldMapBubbleCoordinator {
  WorldMapBubbleCoordinator({
    required this.worldId,
    required bool Function() isMounted,
    required WorldDetail? Function() world,
    required WorldChatroomService? Function() chatroom,
    required Iterable<WorldLocationChatPanelDescriptor> Function() descriptors,
    required VoidCallback requestUiUpdate,
  }) : _isMounted = isMounted,
       _world = world,
       _chatroom = chatroom,
       _descriptors = descriptors,
       _requestUiUpdate = requestUiUpdate;

  static const Duration _mapMessageBubbleInterval = Duration(seconds: 4);
  static const Duration _mapMessageBubbleHiddenInterval = Duration(
    milliseconds: 500,
  );
  static const int _mapMessageBubbleQueueLimit = 60;
  static const int _mapMessageBubbleHistoryLimit = 20;
  static const int _mapMessageBubbleCacheLimit = 60;

  final String worldId;
  final bool Function() _isMounted;
  final WorldDetail? Function() _world;
  final WorldChatroomService? Function() _chatroom;
  final Iterable<WorldLocationChatPanelDescriptor> Function() _descriptors;
  final VoidCallback _requestUiUpdate;

  final Map<String, WorldMapMessageBubble> _mapMessageBubbles =
      <String, WorldMapMessageBubble>{};
  final Map<String, Queue<WorldChatroomMessage>>
  _mapMessageBubbleQueuesByLocation = <String, Queue<WorldChatroomMessage>>{};
  final Map<String, Queue<WorldChatroomMessage>>
  _priorityMapMessageBubbleQueuesByLocation =
      <String, Queue<WorldChatroomMessage>>{};
  final List<String> _mapMessageBubbleLocationOrder = <String>[];
  int _mapMessageBubbleLocationCursor = 0;
  Timer? _mapMessageBubbleTimer;
  final Map<String, List<String>> _mapMessageBubbleKeysByLocation =
      <String, List<String>>{};
  final Map<String, WorldMapMessageBubble> _activeMapMessageBubblesByLocation =
      <String, WorldMapMessageBubble>{};
  final Map<String, String> _mapMessageBubbleRoundByLocation =
      <String, String>{};
  final Set<String> _shownMapMessageBubbleKeys = <String>{};
  String _mapMessageBubblePrimeKey = '';
  Future<void>? _mapMessageBubblePrimeFuture;
  Set<String> _visibleMapLocationIds = <String>{};
  String _visibleMapLocationIdsSignature = '';
  bool _isInSecondaryMap = false;

  Map<String, WorldMapMessageBubble> get messageBubbles => _mapMessageBubbles;

  @visibleForTesting
  String displayContentForTesting(String raw) {
    return _mapBubbleDisplayContent(raw);
  }

  @visibleForTesting
  List<WorldChatroomMessage> interleaveBySenderForTesting(
    List<WorldChatroomMessage> messages,
  ) {
    return _interleaveMapBubbleMessagesBySender(messages);
  }

  void dispose() {
    clear(updateUi: false);
  }

  void _updateUi(VoidCallback update) {
    update();
    if (_isMounted()) _requestUiUpdate();
  }

  bool enqueue(
    Iterable<WorldChatroomMessage> messages, {
    required bool priority,
    bool startCarousel = true,
  }) {
    final byLocation = <String, List<WorldChatroomMessage>>{};
    for (final message in messages) {
      final candidate = _mapBubbleCandidate(message);
      if (candidate == null) continue;
      final queueLocationId = _mapBubbleQueueLocationId(candidate.locationId);
      byLocation
          .putIfAbsent(queueLocationId, () => <WorldChatroomMessage>[])
          .add(candidate);
    }
    if (byLocation.isEmpty) return false;
    var queuedAny = false;
    for (final entry in byLocation.entries) {
      final locationId = entry.key;
      final latestRoundMessages = _latestMapBubbleConversationMessages(
        entry.value,
      );
      if (latestRoundMessages.isEmpty) continue;
      final roundId = latestRoundMessages.first.conversationRoundId.trim();
      _resetMapBubbleLocationQueueForNewRound(locationId, roundId);
      final dedupedMessages = <WorldChatroomMessage>[];
      for (final message in latestRoundMessages) {
        final key = _mapMessageKey(message);
        if (key.isEmpty || !_shownMapMessageBubbleKeys.add(key)) continue;
        dedupedMessages.add(message);
      }
      if (dedupedMessages.isEmpty) continue;
      final locationMessages = _interleaveMapBubbleMessagesBySender(
        dedupedMessages,
      );
      _registerMapMessageBubbleLocation(locationId);
      final queueMap = priority
          ? _priorityMapMessageBubbleQueuesByLocation
          : _mapMessageBubbleQueuesByLocation;
      final queue = queueMap.putIfAbsent(
        locationId,
        () => Queue<WorldChatroomMessage>(),
      );
      queue.addAll(locationMessages);
      _trimMapMessageBubbleQueues(locationId);
      queuedAny = true;
    }
    if (queuedAny && startCarousel) {
      _ensureMapMessageBubbleCarousel();
    }
    return queuedAny;
  }

  List<WorldChatroomMessage> _latestMapBubbleConversationMessages(
    List<WorldChatroomMessage> messages,
  ) {
    if (messages.isEmpty) {
      return const <WorldChatroomMessage>[];
    }

    var latestTickNo = -1;
    for (final message in messages) {
      if (message.tickNo > latestTickNo) latestTickNo = message.tickNo;
    }
    if (latestTickNo < 0) return const <WorldChatroomMessage>[];

    final latestTickMessages = messages
        .where((message) => message.tickNo == latestTickNo)
        .toList(growable: false);
    if (latestTickMessages.isEmpty) return const <WorldChatroomMessage>[];

    var latestRound = -1;
    for (final message in latestTickMessages) {
      final round = message.conversationRoundNumber;
      if (round > latestRound) latestRound = round;
    }
    if (latestRound < 0) return const <WorldChatroomMessage>[];

    return latestTickMessages
        .where((message) => message.conversationRoundNumber == latestRound)
        .toList(growable: false)
      ..sort(_compareMapBubbleMessages);
  }

  void _resetMapBubbleLocationQueueForNewRound(
    String locationId,
    String roundId,
  ) {
    if (roundId.isEmpty) return;
    final previousRoundId = _mapMessageBubbleRoundByLocation[locationId];
    if (previousRoundId == roundId) return;
    _mapMessageBubbleRoundByLocation[locationId] = roundId;
    _mapMessageBubbleQueuesByLocation.remove(locationId);
    _priorityMapMessageBubbleQueuesByLocation.remove(locationId);
    if (_activeMapMessageBubblesByLocation.containsKey(locationId)) {
      _removeActiveMapMessageBubble();
    }
  }

  void _registerMapMessageBubbleLocation(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty || _mapMessageBubbleLocationOrder.contains(id)) return;
    _mapMessageBubbleLocationOrder.add(id);
  }

  String _mapBubbleQueueLocationId(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty) return '';
    final locationKeys = _mapBubbleLocationKeys(id);
    for (final key in locationKeys) {
      if (_visibleMapLocationIds.contains(key)) return key;
    }
    return id;
  }

  WorldChatroomMessage? _mapBubbleCandidate(WorldChatroomMessage message) {
    final locationId = message.locationId.trim();
    final content = message.content.trim();
    if (locationId.isEmpty || content.isEmpty || message.streaming) return null;
    final senderType = message.senderType.trim().toLowerCase();
    if (senderType != 'character') return null;
    if (content == message.content && locationId == message.locationId) {
      return message;
    }
    return message.copyWith(locationId: locationId, content: content);
  }

  void _trimMapMessageBubbleQueues(String locationId) {
    final normal = _mapMessageBubbleQueuesByLocation[locationId];
    final priority = _priorityMapMessageBubbleQueuesByLocation[locationId];
    var total = (normal?.length ?? 0) + (priority?.length ?? 0);
    while (total > _mapMessageBubbleQueueLimit) {
      if (normal?.isNotEmpty == true) {
        final removed = _removeLeastFairMapBubbleMessage(normal!);
        if (!removed) break;
      } else if (priority?.isNotEmpty == true) {
        final removed = _removeLeastFairMapBubbleMessage(priority!);
        if (!removed) break;
      } else {
        break;
      }
      total -= 1;
    }
    if (normal?.isEmpty == true) {
      _mapMessageBubbleQueuesByLocation.remove(locationId);
    }
    if (priority?.isEmpty == true) {
      _priorityMapMessageBubbleQueuesByLocation.remove(locationId);
    }
  }

  void _ensureMapMessageBubbleCarousel() {
    if (_mapMessageBubbleTimer != null) return;
    _advanceMapMessageBubbleCarousel();
  }

  void _advanceMapMessageBubbleCarousel() {
    if (!_isMounted()) return;
    if (!_showNextMapMessageBubble()) {
      _mapMessageBubbleTimer?.cancel();
      _mapMessageBubbleTimer = null;
      _clearActiveMapMessageBubble();
      return;
    }

    _mapMessageBubbleTimer?.cancel();
    _mapMessageBubbleTimer = Timer(
      _mapMessageBubbleInterval,
      _hideMapMessageBubbleBeforeNext,
    );
  }

  void _hideMapMessageBubbleBeforeNext() {
    if (!_isMounted()) return;
    _clearActiveMapMessageBubble();
    _mapMessageBubbleTimer?.cancel();
    _mapMessageBubbleTimer = Timer(
      _mapMessageBubbleHiddenInterval,
      _advanceMapMessageBubbleCarousel,
    );
  }

  bool _showNextMapMessageBubble() {
    final triedLocationIds = <String>{};
    while (true) {
      final locationId = _nextPlayableMapBubbleLocationId(triedLocationIds);
      if (locationId == null) return false;
      triedLocationIds.add(locationId);
      final nextMessage = _nextMapMessageBubble(locationId);
      if (nextMessage == null) continue;
      if (_showMapMessageBubble(locationId, nextMessage)) {
        return true;
      }
    }
  }

  String? _nextPlayableMapBubbleLocationId(Set<String> excludedLocationIds) {
    for (final locationId in _priorityMapMessageBubbleQueuesByLocation.keys) {
      _registerMapMessageBubbleLocation(locationId);
    }
    for (final locationId in _mapMessageBubbleQueuesByLocation.keys) {
      _registerMapMessageBubbleLocation(locationId);
    }
    final total = _mapMessageBubbleLocationOrder.length;
    if (total == 0) return null;
    var cursor = _mapMessageBubbleLocationCursor % total;
    for (var offset = 0; offset < total; offset += 1) {
      final index = (cursor + offset) % total;
      final locationId = _mapMessageBubbleLocationOrder[index];
      if (excludedLocationIds.contains(locationId)) continue;
      if (!_hasPlayableMapBubbleQueue(locationId)) continue;
      _mapMessageBubbleLocationCursor = (index + 1) % total;
      return locationId;
    }
    _mapMessageBubbleLocationCursor = cursor;
    return null;
  }

  bool _hasPlayableMapBubbleQueue(String locationId) {
    return (_priorityMapMessageBubbleQueuesByLocation[locationId]?.isNotEmpty ??
            false) ||
        (_mapMessageBubbleQueuesByLocation[locationId]?.isNotEmpty ?? false);
  }

  WorldChatroomMessage? _nextMapMessageBubble(String locationId) {
    final priority = _priorityMapMessageBubbleQueuesByLocation[locationId];
    while (priority != null && priority.isNotEmpty) {
      final message = priority.removeFirst();
      if (priority.isEmpty) {
        _priorityMapMessageBubbleQueuesByLocation.remove(locationId);
      }
      if (!_hasMapBubbleDisplayContent(message)) {
        _trimMapMessageBubbleQueues(locationId);
        continue;
      }
      _mapMessageBubbleQueuesByLocation
          .putIfAbsent(locationId, () => Queue<WorldChatroomMessage>())
          .addLast(message);
      _trimMapMessageBubbleQueues(locationId);
      return message;
    }
    final normal = _mapMessageBubbleQueuesByLocation[locationId];
    if (normal != null && normal.isNotEmpty) {
      final attempts = normal.length;
      for (var index = 0; index < attempts; index += 1) {
        final message = normal.removeFirst();
        if (!_hasMapBubbleDisplayContent(message)) continue;
        normal.addLast(message);
        return message;
      }
      if (normal.isEmpty) {
        _mapMessageBubbleQueuesByLocation.remove(locationId);
      }
    }
    return null;
  }

  bool _removeLeastFairMapBubbleMessage(Queue<WorldChatroomMessage> queue) {
    if (queue.isEmpty) return false;
    if (queue.length == 1) {
      queue.removeFirst();
      return true;
    }
    final countsBySender = <String, int>{};
    for (final message in queue) {
      final sender = _mapBubbleSenderStableId(message);
      countsBySender[sender] = (countsBySender[sender] ?? 0) + 1;
    }
    var maxCount = 0;
    for (final count in countsBySender.values) {
      if (count > maxCount) maxCount = count;
    }
    final next = Queue<WorldChatroomMessage>();
    var removed = false;
    for (final message in queue) {
      final sender = _mapBubbleSenderStableId(message);
      if (!removed && (countsBySender[sender] ?? 0) == maxCount) {
        removed = true;
        continue;
      }
      next.addLast(message);
    }
    if (!removed) {
      queue.removeFirst();
      return true;
    }
    queue
      ..clear()
      ..addAll(next);
    return true;
  }

  bool _hasMapBubbleDisplayContent(WorldChatroomMessage message) {
    return _mapBubbleDisplayContent(message.content).isNotEmpty;
  }

  bool _showMapMessageBubble(
    String queueLocationId,
    WorldChatroomMessage message,
  ) {
    final content = _mapBubbleDisplayContent(message.content);
    if (content.isEmpty) {
      return false;
    }
    final locationId = message.locationId.trim().isNotEmpty
        ? message.locationId.trim()
        : queueLocationId;
    final bubble = WorldMapMessageBubble(
      locationId: locationId,
      senderId: worldFirstNonEmpty([message.senderId, message.userId]),
      senderName: message.senderName,
      senderAvatarUrl: _mapBubbleSenderAvatarUrl(message),
      content: content,
      createdAt: DateTime.now(),
    );
    final locationKeys = _mapBubbleLocationKeys(locationId);
    if (locationKeys.isEmpty) {
      return false;
    }
    _updateUi(() {
      _removeActiveMapMessageBubble();
      _activeMapMessageBubblesByLocation[queueLocationId] = bubble;
      _mapMessageBubbleKeysByLocation[queueLocationId] = locationKeys;
      for (final locationId in locationKeys) {
        _mapMessageBubbles[locationId] = bubble;
      }
    });
    return true;
  }

  String _mapBubbleDisplayContent(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(
      RegExp(r'(^|\n)[ \t]*(`{3,}|~{3,})[\s\S]*?(\n[ \t]*\2[ \t]*(?=\n|$)|$)'),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
    text = text
        .split('\n')
        .where((line) => !_isMapBubbleMarkdownLine(line))
        .join('\n');
    text = _removeMapBubbleInlineMarkdown(text);
    text = text.replaceAllMapped(
      RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>])'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'[「」]'), '');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n+ *'), ' ');
    text = text.replaceAllMapped(
      RegExp(r'\s+([,.!?;:])'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'([([{])\s+'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'\\r\\n|\\n|\\r'), ' ');
    return text.trim();
  }

  bool _isMapBubbleMarkdownLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^#{1,6}\s+').hasMatch(trimmed) ||
        RegExp(r'^>\s*').hasMatch(trimmed) ||
        RegExp(r'^[-*+]\s+').hasMatch(trimmed) ||
        RegExp(r'^\d+[.)]\s+').hasMatch(trimmed) ||
        RegExp(r'^[-*_]{3,}$').hasMatch(trimmed) ||
        RegExp(r'^\[[^\]]+\]:\s*\S+').hasMatch(trimmed) ||
        RegExp(r'^\|.*\|$').hasMatch(trimmed) ||
        RegExp(
          r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$',
        ).hasMatch(trimmed);
  }

  String _removeMapBubbleInlineMarkdown(String input) {
    var text = input;
    final patterns = <RegExp>[
      RegExp(r'!\[[^\]\n]*\]\([^)\n]*\)'),
      RegExp(r'!\[[^\]\n]*\]\[[^\]\n]*\]'),
      RegExp(r'\[[^\]\n]+\]\([^)\n]*\)'),
      RegExp(r'\[[^\]\n]+\]\[[^\]\n]*\]'),
      RegExp(r'`+[^`\n]+`+'),
      RegExp(r'\*\*[^*\n]+\*\*'),
      RegExp(r'__[^_\n]+__'),
      RegExp(r'~~[^~\n]+~~'),
      RegExp(r'\*[^*\n]+\*'),
      RegExp(r'_[^_\n]+_'),
      RegExp(r'<https?://[^>\s]+>'),
      RegExp(r'\[[^\]\n]+\]'),
    ];
    var changed = true;
    while (changed) {
      changed = false;
      for (final pattern in patterns) {
        final next = text.replaceAll(pattern, ' ');
        if (next != text) {
          changed = true;
          text = next;
        }
      }
    }
    return text;
  }

  void _clearActiveMapMessageBubble() {
    if (!_isMounted()) {
      _removeActiveMapMessageBubble();
      return;
    }
    _updateUi(() {
      _removeActiveMapMessageBubble();
    });
  }

  void _removeActiveMapMessageBubble() {
    _activeMapMessageBubblesByLocation.clear();
    _mapMessageBubbleKeysByLocation.clear();
    _mapMessageBubbles.clear();
  }

  void clear({bool updateUi = true}) {
    _mapMessageBubbleTimer?.cancel();
    _mapMessageBubbleTimer = null;
    void clearState() {
      _mapMessageBubbleQueuesByLocation.clear();
      _priorityMapMessageBubbleQueuesByLocation.clear();
      _mapMessageBubbleLocationOrder.clear();
      _mapMessageBubbleLocationCursor = 0;
      _mapMessageBubbleKeysByLocation.clear();
      _activeMapMessageBubblesByLocation.clear();
      _mapMessageBubbleRoundByLocation.clear();
      _shownMapMessageBubbleKeys.clear();
      _mapMessageBubblePrimeKey = '';
      _mapMessageBubblePrimeFuture = null;
      _mapMessageBubbles.clear();
    }

    if (updateUi && _isMounted()) {
      _updateUi(clearState);
    } else {
      clearState();
    }
  }

  void maybePrime() {
    if (!_isInSecondaryMap) return;
    final service = _chatroom();
    final world = _world();
    final identity = service?.identity;
    if (service == null || world == null || identity == null) return;
    if (!shouldConnectWorldChatroom(world.relationStatus)) return;
    final ownerUid = worldFirstNonEmpty([identity.userId, identity.senderId]);
    if (ownerUid.isEmpty) return;
    final descriptors = _leafLocationChatDescriptors();
    if (descriptors.isEmpty) return;
    if (_visibleMapLocationIds.isEmpty) return;
    final primeKey = [
      worldId,
      ownerUid,
      for (final locationId in (_visibleMapLocationIds.toList()..sort()))
        locationId,
      for (final descriptor in descriptors) descriptor.locationId,
    ].join('\u001F');
    if (_mapMessageBubblePrimeKey == primeKey) return;
    _mapMessageBubblePrimeKey = primeKey;
    final future = _primeMapMessageBubbles(
      service: service,
      descriptors: descriptors,
      primeKey: primeKey,
    );
    _mapMessageBubblePrimeFuture = future;
    unawaited(
      future
          .catchError((Object error) {
            debugPrint('[WorldPage] map bubble prime failed: $error');
            if (_mapMessageBubblePrimeKey == primeKey) {
              _mapMessageBubblePrimeKey = '';
            }
          })
          .whenComplete(() {
            if (identical(_mapMessageBubblePrimeFuture, future)) {
              _mapMessageBubblePrimeFuture = null;
            }
          }),
    );
  }

  Future<void> _primeMapMessageBubbles({
    required WorldChatroomService service,
    required List<WorldLocationChatPanelDescriptor> descriptors,
    required String primeKey,
  }) async {
    try {
      await service.refreshUserLocations();
    } catch (error) {
      debugPrint('[WorldPage] map bubble location refresh failed: $error');
    }
    if (!_isCurrentMapBubblePrime(service, primeKey)) return;
    var queuedAny = false;
    for (final descriptor in descriptors) {
      if (!_isCurrentMapBubblePrime(service, primeKey)) return;
      var cachedMessages = await service.loadCachedMessages(
        worldId: worldId,
        locationId: descriptor.locationId,
        locationAliases: descriptor.localMessageLocationIds,
        limit: _mapMessageBubbleCacheLimit,
      );
      if (!_isCurrentMapBubblePrime(service, primeKey)) return;
      if (cachedMessages.isEmpty) {
        await service.refreshLatestMessages(
          locationId: descriptor.locationId,
          limit: _mapMessageBubbleHistoryLimit,
          emitLatestFetched: false,
        );
        if (!_isCurrentMapBubblePrime(service, primeKey)) return;
        cachedMessages = await service.loadCachedMessages(
          worldId: worldId,
          locationId: descriptor.locationId,
          locationAliases: descriptor.localMessageLocationIds,
          limit: _mapMessageBubbleCacheLimit,
        );
      }
      if (!_isCurrentMapBubblePrime(service, primeKey)) return;
      queuedAny =
          enqueue(cachedMessages, priority: false, startCarousel: false) ||
          queuedAny;
    }
    if (_isCurrentMapBubblePrime(service, primeKey) && queuedAny) {
      _ensureMapMessageBubbleCarousel();
    }
  }

  bool _isCurrentMapBubblePrime(WorldChatroomService service, String primeKey) {
    return _isMounted() &&
        identical(_chatroom(), service) &&
        _mapMessageBubblePrimeKey == primeKey;
  }

  List<WorldLocationChatPanelDescriptor> _leafLocationChatDescriptors() {
    final descriptors =
        _descriptors()
            .where(
              (descriptor) =>
                  descriptor.isLeafLocation &&
                  descriptor.locationId.trim().isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.locationId.compareTo(b.locationId));
    return descriptors;
  }

  void handleSecondaryMapChanged(bool isInSecondaryMap) {
    if (_isInSecondaryMap == isInSecondaryMap) return;
    _isInSecondaryMap = isInSecondaryMap;
    if (isInSecondaryMap) {
      _visibleMapLocationIds = <String>{};
      _visibleMapLocationIdsSignature = '';
      clear();
      return;
    }
    clear();
  }

  void handleVisibleLocationIdsChanged(List<String> locationIds) {
    final ids = locationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final signature = (ids.toList()..sort()).join('\u001F');
    if (signature == _visibleMapLocationIdsSignature) return;
    _visibleMapLocationIds = ids;
    _visibleMapLocationIdsSignature = signature;
    if (!_isInSecondaryMap) return;
    clear();
    maybePrime();
  }

  List<String> _mapBubbleLocationKeys(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty) return const <String>[];
    final world = _world();
    final result = <String>[id];
    final tree = world?.processedLocationTree;
    if (tree == null) return result;
    var node = tree.nodeById(id);
    while (node != null && node.parentId.trim().isNotEmpty) {
      final parentId = node.parentId.trim();
      if (!result.contains(parentId)) result.add(parentId);
      node = tree.nodeById(parentId);
    }
    return result;
  }

  String _mapMessageKey(WorldChatroomMessage message) {
    if (message.messageId > 0) return 'm:${message.messageId}';
    final clientMsgId = message.clientMsgId.trim();
    if (clientMsgId.isNotEmpty) return 'c:$clientMsgId';
    return [
      message.locationId,
      message.conversationRoundId,
      message.roundOrder,
      message.senderId,
      message.content,
    ].join('|');
  }

  String _mapBubbleSenderStableId(WorldChatroomMessage message) {
    final senderId = worldFirstNonEmpty([
      message.senderId,
      message.userId,
    ]).trim();
    if (senderId.isNotEmpty) return senderId;
    final senderName = message.senderName.trim().toLowerCase();
    if (senderName.isNotEmpty) return 'bubble-sender-name:$senderName';
    return 'bubble-sender-location:${message.locationId.trim()}';
  }

  List<WorldChatroomMessage> _interleaveMapBubbleMessagesBySender(
    List<WorldChatroomMessage> messages,
  ) {
    if (messages.length < 3) {
      return messages..sort(_compareMapBubbleMessages);
    }
    final sorted = [...messages]..sort(_compareMapBubbleMessages);
    final bySender = <String, Queue<WorldChatroomMessage>>{};
    final senderOrder = <String>[];
    for (final message in sorted) {
      final sender = _mapBubbleSenderStableId(message);
      if (!bySender.containsKey(sender)) {
        senderOrder.add(sender);
        bySender[sender] = Queue<WorldChatroomMessage>();
      }
      bySender[sender]!.addLast(message);
    }
    if (senderOrder.length < 2) return sorted;
    final out = <WorldChatroomMessage>[];
    var senderIndex = 0;
    while (out.length < sorted.length) {
      var advanced = false;
      for (var offset = 0; offset < senderOrder.length; offset += 1) {
        final index = (senderIndex + offset) % senderOrder.length;
        final queue = bySender[senderOrder[index]];
        if (queue == null || queue.isEmpty) continue;
        out.add(queue.removeFirst());
        senderIndex = (index + 1) % senderOrder.length;
        advanced = true;
        break;
      }
      if (!advanced) break;
    }
    return out;
  }

  int _compareMapBubbleMessages(
    WorldChatroomMessage a,
    WorldChatroomMessage b,
  ) {
    if (a.messageId > 0 && b.messageId > 0) {
      return a.messageId.compareTo(b.messageId);
    }
    final createdAtA = a.createdAt;
    final createdAtB = b.createdAt;
    if (createdAtA != null && createdAtB != null) {
      return createdAtA.compareTo(createdAtB);
    }
    final round = a.conversationRoundNumber.compareTo(
      b.conversationRoundNumber,
    );
    if (round != 0) return round;
    return a.roundOrder.compareTo(b.roundOrder);
  }

  String _mapBubbleSenderAvatarUrl(WorldChatroomMessage message) {
    final senderId = worldFirstNonEmpty([
      message.senderId,
      message.userId,
    ]).trim();
    final senderKey = senderId.toLowerCase();
    final senderNameKey = message.senderName.trim().toLowerCase();
    final world = _world();
    if (world == null) return '';
    for (final character in world.characters) {
      final characterId = worldMapString(character, const [
        'character_id',
        'char_id',
        'id',
        'uid',
        'player_uid',
      ]).trim();
      final characterName = worldMapString(character, const ['name']).trim();
      final matchesId =
          senderKey.isNotEmpty && characterId.toLowerCase() == senderKey;
      final matchesName =
          senderNameKey.isNotEmpty &&
          characterName.toLowerCase() == senderNameKey;
      if (!matchesId && !matchesName) continue;
      return worldResolveAssetUrl(
        worldMapString(character, const ['avatar', 'avatar_url']),
      );
    }
    return '';
  }
}
