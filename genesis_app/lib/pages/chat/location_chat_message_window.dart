part of 'location_chat_page.dart';

extension _LocationChatMessageWindow on _LocationChatPanelState {
  void _handleMessageListScroll() {
    if (!_scrollController.hasClients) return;
    if (_initialBottomScrollPending &&
        _initialBottomScrollDidJump &&
        _messages.isNotEmpty &&
        !_isAtBottom()) {
      _initialBottomScrollPending = false;
      _initialBottomScrollShouldComplete = false;
    }
    if (_unseenIncomingCount > 0 && _isAtBottom()) {
      _clearUnseenIncomingCount();
    }
    if (!widget.active ||
        !widget.isLeafLocation ||
        _loadingOlderMessages ||
        !_hasMoreOlderMessages) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentBefore > 180) return;
    unawaited(_loadOlderMessages());
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlderMessages) return;
    final service = _service;
    if (service == null) return;
    final beforeLocationMessageId = _earliestLoadedLocationMessageId();
    if (beforeLocationMessageId <= 0) {
      _hasMoreOlderMessages = false;
      return;
    }
    _setLocationChatState(() {
      _loadingOlderMessages = true;
      _loadingOlderBeforeLocationMessageId = beforeLocationMessageId;
    });
    _recordPanelDebug(
      action: 'loadOlderStart',
      details: {'beforeLocationMessageId': beforeLocationMessageId},
    );
    try {
      final page = await service.loadOlderMessages(
        locationId: widget.locationId,
        beforeMessageId: beforeLocationMessageId,
        limit: 20,
      );
      _olderMessagesExhaustedByRemote = !page.hasMore;
      _hasMoreOlderMessages = page.hasMore;
      if (page.loadedCount > 0 && mounted) {
        _syncFromServiceState(service);
      }
      if (page.loadedCount > 0 &&
          mounted &&
          _loadingOlderMessages &&
          !_olderLoadHasRenderedNewMessages()) {
        _setLocationChatState(() {
          _finishOlderMessagesLoading();
        });
        _runDeferredVisibleMessageGapFillIfNeeded();
      }
      _recordPanelDebug(
        action: 'loadOlderDone',
        details: {
          'beforeLocationMessageId': beforeLocationMessageId,
          'loadedCount': page.loadedCount,
          'hasMore': page.hasMore,
        },
      );
      if (page.loadedCount <= 0 && mounted) {
        _setLocationChatState(() {
          _finishOlderMessagesLoading();
        });
        _runDeferredVisibleMessageGapFillIfNeeded();
      } else if (page.loadedCount <= 0) {
        _finishOlderMessagesLoading();
      }
    } catch (error) {
      _recordPanelDebug(
        action: 'loadOlderFailed',
        details: {
          'beforeLocationMessageId': beforeLocationMessageId,
          'error': '$error',
        },
      );
      // Up-scroll history loading is opportunistic; connection failures are
      // surfaced by the chatroom service failure stream when appropriate.
      if (mounted) {
        _setLocationChatState(() {
          _finishOlderMessagesLoading();
        });
        _runDeferredVisibleMessageGapFillIfNeeded();
      } else {
        _finishOlderMessagesLoading();
      }
    }
  }

  bool _olderLoadHasRenderedNewMessages() {
    if (!_loadingOlderMessages || _loadingOlderBeforeLocationMessageId <= 0) {
      return false;
    }
    final oldestRenderedLocationMessageId = _oldestRenderedLocationMessageId();
    return oldestRenderedLocationMessageId > 0 &&
        oldestRenderedLocationMessageId < _loadingOlderBeforeLocationMessageId;
  }

  int _oldestRenderedLocationMessageId() {
    var oldest = 0;
    for (final message in _messages) {
      if (message.isSystem || message.locationMessageId <= 0) continue;
      if (oldest == 0 || message.locationMessageId < oldest) {
        oldest = message.locationMessageId;
      }
    }
    return oldest;
  }

  void _finishOlderMessagesLoading() {
    _loadingOlderMessages = false;
    _loadingOlderBeforeLocationMessageId = 0;
  }

  int _earliestLoadedLocationMessageId() {
    var earliest = 0;
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    for (final message in source) {
      final messageId = message.locationMessageId > 0
          ? message.locationMessageId
          : message.messageId;
      if (messageId <= 0) continue;
      if (earliest == 0 || messageId < earliest) earliest = messageId;
    }
    return earliest;
  }

  int _newIncomingTailMessageCount(
    List<WorldChatroomMessage> previous,
    List<WorldChatroomMessage> next,
  ) {
    final previousKeys = previous.map(_messageDedupKey).toSet();
    var count = 0;
    for (final message in next) {
      if (previousKeys.contains(_messageDedupKey(message))) continue;
      if (_isMineMessage(message)) continue;
      count += 1;
    }
    return count;
  }

  String _messageDedupKey(WorldChatroomMessage message) {
    final clientMsgId = message.clientMsgId.trim();
    if (clientMsgId.isNotEmpty) return 'client:$clientMsgId';
    if (message.locationMessageId > 0) {
      return 'location:${message.locationId}:${message.locationMessageId}';
    }
    if (message.locationId.trim().isEmpty && message.messageId > 0) {
      return 'message:${message.messageId}';
    }
    return [
      'round',
      message.locationId,
      message.conversationRoundId,
      message.senderId,
      message.roundOrder,
    ].join(':');
  }
}

String _mapString(Map<String, dynamic>? map, String key) {
  if (map == null) return '';
  final value = map[key];
  if (value == null) return '';
  return '$value'.trim();
}

String _resolvedProfileAvatar(
  Map<dynamic, dynamic> userInfo,
  String profileAvatar,
) {
  final resolved = asResolvedImageUrl(
    _mapValue(userInfo, const ['avatar']),
    resolveAssetUrl,
    fallback: _mapValue(userInfo, const [
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]),
  );
  if (resolved.isNotEmpty) return resolved;
  return asResolvedImageUrl(profileAvatar, resolveAssetUrl);
}

@visibleForTesting
String locationChatMessageReportTargetIdForTesting(ChatMessageVm message) {
  final globalMessageId = message.globalMessageId;
  if (globalMessageId > 0) return '$globalMessageId';
  return '';
}

@visibleForTesting
String resolveLocationChatMessageSenderNameForTesting({
  required String senderId,
  required String senderName,
  required Iterable<Map<String, dynamic>> characters,
}) {
  final character = _locationChatCharacterForSenderId(characters, senderId);
  return firstNonEmpty([
    character == null ? '' : _mapString(character, 'name'),
    senderName,
  ]);
}

@visibleForTesting
String resolveLocationChatMessageAvatarForTesting({
  required String senderId,
  required Iterable<Map<String, dynamic>> characters,
}) {
  final character = _locationChatCharacterForSenderId(characters, senderId);
  if (character == null) return '';
  return _firstMapImageUrl(character, const ['avatar']);
}

Map<String, dynamic>? _locationChatCharacterForSenderId(
  Iterable<Map<String, dynamic>> characters,
  String senderId,
) {
  final resolvedSenderId = senderId.trim();
  if (resolvedSenderId.isEmpty) return null;
  for (final character in characters) {
    if (_mapString(character, 'char_id').trim() == resolvedSenderId) {
      return character;
    }
  }
  return null;
}

@visibleForTesting
List<String> resolveLocationChatAiRoleNamesForTesting(
  WorldChatroomState state,
  Iterable<String> locationIds,
) {
  final names = <String>[];
  final seen = <String>{};
  for (final locationId in locationIds) {
    final trimmedLocationId = locationId.trim();
    if (trimmedLocationId.isEmpty) continue;
    final entities =
        state.entitiesByLocation[trimmedLocationId] ??
        const <WorldChatroomEntity>[];
    for (final entity in entities) {
      if (!entity.isAi) continue;
      final name = entity.name.trim();
      if (name.isEmpty) continue;
      final key = _locationChatEntityDedupKey(entity);
      if (key.isEmpty || !seen.add(key)) continue;
      names.add(name);
    }
  }
  return names;
}

String _locationChatEntityDedupKey(WorldChatroomEntity entity) {
  final idKey = _chatroomIdentityKey(entity.id);
  if (idKey.isNotEmpty) return 'id:$idKey';
  final nameKey = entity.name.trim().toLowerCase();
  return nameKey.isEmpty ? '' : 'name:$nameKey';
}

@visibleForTesting
String locationChatMessageLocalIdForTesting(WorldChatroomMessage message) {
  return _locationChatMessageLocalId(message);
}

String _locationChatMessageLocalId(WorldChatroomMessage message) {
  if (message.locationMessageId > 0) {
    return 'location-${message.locationId}-${message.locationMessageId}';
  }
  return 'stream-${message.locationId}-${message.conversationRoundId}-${message.senderId}';
}

String _locationChatMessageDisplayText(WorldChatroomMessage message) {
  if (message.isLlmStreamMessage) {
    return decodeLlmStreamTextForDisplay(
      message.content,
      isStreaming: message.streaming,
    );
  }
  final senderType = message.senderType.trim().toLowerCase();
  if (senderType.isEmpty || senderType == 'user') {
    return decodeGenesisUgcTextForDisplay(message.content);
  }
  return normalizeGenesisUgcTextForDisplay(message.content);
}

@visibleForTesting
String locationChatMessageDisplayTextForTesting(WorldChatroomMessage message) {
  return _locationChatMessageDisplayText(message);
}

Object? _mapValue(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return value;
  }
  return null;
}

bool _senderIdIsNarrator(String senderId) {
  return senderId.trim().toLowerCase() == 'nar';
}

bool _senderIdIsNarratorPicture(String senderId) {
  return senderId.trim().toLowerCase() == 'nar_pic';
}

@visibleForTesting
List<WorldChatroomMessage> visibleLocationChatMessagesForTesting(
  List<WorldChatroomMessage> source,
) {
  return _visibleLocationChatMessages(source).messages;
}

@visibleForTesting
List<WorldChatroomMessage> visibleLocationChatMessagesWithRenderedIdsForTesting(
  List<WorldChatroomMessage> source, {
  Set<int> renderedLocationMessageIds = const <int>{},
  Set<String> releasedGapKeys = const <String>{},
  String locationId = 'loc-1',
}) {
  return _visibleLocationChatMessages(
    source,
    renderedLocationMessageIds: renderedLocationMessageIds,
    releasedGapKeys: releasedGapKeys,
    locationId: locationId,
  ).messages;
}

@visibleForTesting
int locationChatMessageGapFillCursorForTesting(
  List<WorldChatroomMessage> source,
) {
  return _visibleLocationChatMessages(source).gapFillBeforeLocationMessageId;
}

@visibleForTesting
bool shouldShowLocationChatOldestEdgeNoticeForTesting(
  List<WorldChatroomMessage> source, {
  Set<int> renderedLocationMessageIds = const <int>{},
  Set<String> releasedGapKeys = const <String>{},
  String locationId = 'loc-1',
  bool hasMoreOlderMessages = false,
  bool loadingOlderMessages = false,
  bool hasPendingGapFill = false,
}) {
  if (hasMoreOlderMessages || loadingOlderMessages || hasPendingGapFill) {
    return false;
  }
  final renderWindow = _visibleLocationChatMessages(
    source,
    renderedLocationMessageIds: renderedLocationMessageIds,
    releasedGapKeys: releasedGapKeys,
    locationId: locationId,
  );
  if (renderWindow.gaps.isNotEmpty) return false;
  return _visibleWindowContainsOldestLocationMessage(
    source: source,
    visible: renderWindow.messages,
  );
}

_VisibleLocationChatMessages _visibleLocationChatMessages(
  List<WorldChatroomMessage> source, {
  Set<int> renderedLocationMessageIds = const <int>{},
  Set<String> releasedGapKeys = const <String>{},
  String locationId = '',
}) {
  final renderableSource = source
      .where((message) => !_isTickAdvanceMessage(message) || message.tickNo > 0)
      .toList(growable: false);
  if (renderableSource.length < 2) {
    return _VisibleLocationChatMessages(
      messages: renderableSource,
      gapFillBeforeLocationMessageId: 0,
      gaps: const <_LocationChatMessageGap>[],
    );
  }
  final sorted = renderableSource..sort(_compareLocationChatRenderMessages);
  final locationMessages = sorted
      .where(
        (message) =>
            !_isTickAdvanceMessage(message) && message.locationMessageId > 0,
      )
      .toList(growable: false);
  if (locationMessages.isEmpty) {
    return _VisibleLocationChatMessages(
      messages: _collapseConsecutiveTickMessages(sorted),
      gapFillBeforeLocationMessageId: 0,
      gaps: const <_LocationChatMessageGap>[],
    );
  }

  final locationIds =
      locationMessages
          .map((message) => message.locationMessageId)
          .toSet()
          .toList(growable: false)
        ..sort();
  final visibleLocationMessageIds = renderedLocationMessageIds
      .where(locationIds.contains)
      .toSet();
  final gaps = <_LocationChatMessageGap>[];

  if (visibleLocationMessageIds.isEmpty) {
    var expectedLocationMessageId = locationMessages.last.locationMessageId;
    for (final message in locationMessages.reversed) {
      final locationMessageId = message.locationMessageId;
      if (locationMessageId == expectedLocationMessageId) {
        visibleLocationMessageIds.add(locationMessageId);
        expectedLocationMessageId -= 1;
        continue;
      }
      if (locationMessageId < expectedLocationMessageId) {
        final gap = _LocationChatMessageGap(
          lowerLocationMessageId: locationMessageId,
          upperLocationMessageId: expectedLocationMessageId + 1,
        );
        if (_locationChatGapIsReleased(locationId, gap, releasedGapKeys)) {
          visibleLocationMessageIds.add(locationMessageId);
          expectedLocationMessageId = locationMessageId - 1;
          continue;
        }
        gaps.add(gap);
        break;
      }
    }
  } else {
    _includeVisibleLocationIdsInsideRenderedSpan(
      locationIds: locationIds,
      visibleLocationMessageIds: visibleLocationMessageIds,
    );
    _expandVisibleLocationIdsAcrossGaps(
      locationIds: locationIds,
      visibleLocationMessageIds: visibleLocationMessageIds,
      gaps: gaps,
      releasedGapKeys: releasedGapKeys,
      locationId: locationId,
      forward: true,
    );
    _expandVisibleLocationIdsAcrossGaps(
      locationIds: locationIds,
      visibleLocationMessageIds: visibleLocationMessageIds,
      gaps: gaps,
      releasedGapKeys: releasedGapKeys,
      locationId: locationId,
      forward: false,
    );
  }

  final visibleLocationMessages = locationMessages
      .where(
        (message) =>
            visibleLocationMessageIds.contains(message.locationMessageId),
      )
      .toList(growable: false);
  if (visibleLocationMessages.isEmpty) {
    return const _VisibleLocationChatMessages(
      messages: <WorldChatroomMessage>[],
      gapFillBeforeLocationMessageId: 0,
      gaps: <_LocationChatMessageGap>[],
    );
  }
  final visible = _visibleLocationChatMessagesWithTicks(
    sorted: sorted,
    visibleLocationMessageIds: visibleLocationMessageIds,
  );
  return _VisibleLocationChatMessages(
    messages: visible,
    gapFillBeforeLocationMessageId: gaps.isEmpty
        ? 0
        : gaps.first.upperLocationMessageId,
    gaps: gaps,
  );
}

List<WorldChatroomMessage> _visibleLocationChatMessagesWithTicks({
  required List<WorldChatroomMessage> sorted,
  required Set<int> visibleLocationMessageIds,
}) {
  final visible = <WorldChatroomMessage>[];
  final leadingCursorlessMessages = <WorldChatroomMessage>[];
  var seenLocationMessage = false;
  var seenVisibleLocationMessage = false;
  var blockedByHiddenLocationAfterVisible = false;

  for (final message in sorted) {
    if (_isTickAdvanceMessage(message)) {
      if (seenVisibleLocationMessage && !blockedByHiddenLocationAfterVisible) {
        visible.add(message);
      } else if (!seenLocationMessage) {
        leadingCursorlessMessages.add(message);
      }
      continue;
    }

    if (message.locationMessageId <= 0) {
      if (!seenLocationMessage) {
        leadingCursorlessMessages.add(message);
      }
      continue;
    }

    final messageIsVisible = visibleLocationMessageIds.contains(
      message.locationMessageId,
    );
    if (messageIsVisible) {
      if (!seenVisibleLocationMessage && !seenLocationMessage) {
        visible.addAll(leadingCursorlessMessages);
      }
      visible.add(message);
      seenVisibleLocationMessage = true;
      blockedByHiddenLocationAfterVisible = false;
    } else {
      if (seenVisibleLocationMessage) {
        blockedByHiddenLocationAfterVisible = true;
      }
      leadingCursorlessMessages.clear();
    }
    seenLocationMessage = true;
  }

  return _collapseConsecutiveTickMessages(visible);
}

List<WorldChatroomMessage> _collapseConsecutiveTickMessages(
  List<WorldChatroomMessage> messages,
) {
  if (messages.length < 2) return messages;
  final collapsed = <WorldChatroomMessage>[];
  for (final message in messages) {
    if (_isTickAdvanceMessage(message) &&
        collapsed.isNotEmpty &&
        _isTickAdvanceMessage(collapsed.last)) {
      collapsed[collapsed.length - 1] = message;
      continue;
    }
    collapsed.add(message);
  }
  return collapsed;
}

bool _visibleWindowContainsOldestLocationMessage({
  required List<WorldChatroomMessage> source,
  required List<WorldChatroomMessage> visible,
}) {
  final oldestLocationMessageId = _oldestLocationMessageId(source);
  if (oldestLocationMessageId <= 0) return true;
  for (final message in visible) {
    if (message.locationMessageId == oldestLocationMessageId) return true;
  }
  return false;
}

int _oldestLocationMessageId(List<WorldChatroomMessage> messages) {
  var oldest = 0;
  for (final message in messages) {
    if (_isTickAdvanceMessage(message) || message.locationMessageId <= 0) {
      continue;
    }
    if (oldest == 0 || message.locationMessageId < oldest) {
      oldest = message.locationMessageId;
    }
  }
  return oldest;
}

void _includeVisibleLocationIdsInsideRenderedSpan({
  required List<int> locationIds,
  required Set<int> visibleLocationMessageIds,
}) {
  if (visibleLocationMessageIds.isEmpty) return;
  final minRendered = visibleLocationMessageIds.reduce(math.min);
  final maxRendered = visibleLocationMessageIds.reduce(math.max);
  for (final id in locationIds) {
    if (id < minRendered) continue;
    if (id > maxRendered) break;
    visibleLocationMessageIds.add(id);
  }
}

void _expandVisibleLocationIdsAcrossGaps({
  required List<int> locationIds,
  required Set<int> visibleLocationMessageIds,
  required List<_LocationChatMessageGap> gaps,
  required Set<String> releasedGapKeys,
  required String locationId,
  required bool forward,
}) {
  if (visibleLocationMessageIds.isEmpty) return;
  if (forward) {
    var expected = visibleLocationMessageIds.reduce(math.max) + 1;
    for (final id in locationIds.where((id) => id >= expected)) {
      if (id == expected) {
        visibleLocationMessageIds.add(id);
        expected += 1;
        continue;
      }
      final gap = _LocationChatMessageGap(
        lowerLocationMessageId: expected - 1,
        upperLocationMessageId: id,
      );
      if (_locationChatGapIsReleased(locationId, gap, releasedGapKeys)) {
        visibleLocationMessageIds.add(id);
        expected = id + 1;
        continue;
      }
      gaps.add(gap);
      return;
    }
    return;
  }

  var expected = visibleLocationMessageIds.reduce(math.min) - 1;
  for (final id in locationIds.reversed.where((id) => id <= expected)) {
    if (id == expected) {
      visibleLocationMessageIds.add(id);
      expected -= 1;
      continue;
    }
    final gap = _LocationChatMessageGap(
      lowerLocationMessageId: id,
      upperLocationMessageId: expected + 1,
    );
    if (_locationChatGapIsReleased(locationId, gap, releasedGapKeys)) {
      visibleLocationMessageIds.add(id);
      expected = id - 1;
      continue;
    }
    gaps.add(gap);
    return;
  }
}

bool _locationChatGapIsReleased(
  String locationId,
  _LocationChatMessageGap gap,
  Set<String> releasedGapKeys,
) {
  return releasedGapKeys.contains(_locationChatMessageGapKey(locationId, gap));
}

bool _isLocationChatMessageGapFilled(
  List<WorldChatroomMessage> messages,
  _LocationChatMessageGap gap,
) {
  final ids = messages
      .where(
        (message) =>
            !_isTickAdvanceMessage(message) && message.locationMessageId > 0,
      )
      .map((message) => message.locationMessageId)
      .toSet();
  for (
    var id = gap.lowerLocationMessageId + 1;
    id < gap.upperLocationMessageId;
    id += 1
  ) {
    if (!ids.contains(id)) return false;
  }
  return true;
}

String _locationChatMessageGapKey(
  String locationId,
  _LocationChatMessageGap gap,
) {
  return '${locationId.trim()}\u001F${gap.lowerLocationMessageId}\u001F${gap.upperLocationMessageId}';
}

bool _isTickAdvanceMessage(WorldChatroomMessage message) {
  return message.senderType.trim().toLowerCase() == 'tick';
}

int _compareLocationChatRenderMessages(
  WorldChatroomMessage a,
  WorldChatroomMessage b,
) {
  final byMessageId = a.messageId.compareTo(b.messageId);
  if (byMessageId != 0) return byMessageId;
  final byLocationMessageId = a.locationMessageId.compareTo(
    b.locationMessageId,
  );
  if (byLocationMessageId != 0) return byLocationMessageId;
  final byRound = a.conversationRoundNumber.compareTo(
    b.conversationRoundNumber,
  );
  if (byRound != 0) return byRound;
  return a.roundOrder.compareTo(b.roundOrder);
}

class _VisibleLocationChatMessages {
  const _VisibleLocationChatMessages({
    required this.messages,
    required this.gapFillBeforeLocationMessageId,
    required this.gaps,
  });

  final List<WorldChatroomMessage> messages;
  final int gapFillBeforeLocationMessageId;
  final List<_LocationChatMessageGap> gaps;
}

class _LocationChatMessageGap {
  const _LocationChatMessageGap({
    required this.lowerLocationMessageId,
    required this.upperLocationMessageId,
  });

  final int lowerLocationMessageId;
  final int upperLocationMessageId;

  int get missingCount => upperLocationMessageId - lowerLocationMessageId - 1;
}
