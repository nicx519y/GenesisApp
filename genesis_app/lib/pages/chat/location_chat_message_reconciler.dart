part of 'location_chat_page.dart';

extension _LocationChatMessageReconciler on _LocationChatPanelState {
  bool _reconcileMessages(
    List<WorldChatroomMessage> source, {
    WorldChatroomState? identityState,
  }) {
    final resolvedIdentityState = identityState ?? _chatroomState;
    final renderWindow = _visibleLocationChatMessages(
      source,
      renderedLocationMessageIds: _renderedLocationMessageIds(),
      releasedGapKeys: _releasedMessageGapKeys,
      locationId: widget.locationId,
    );
    _requestVisibleMessageGapFillIfNeeded(renderWindow.gaps, source);
    final visibleSource = <_RenderableLocationChatMessage>[];
    for (final message in renderWindow.messages) {
      if (_isHiddenLocationChatTimelineMessage(message)) continue;
      final timelinePayload = _timelinePayloadVmForMessage(
        message,
        identityState: resolvedIdentityState,
      );
      if (isChatroomTimelinePayloadSenderType(message.senderType)) {
        if (timelinePayload == null) continue;
      } else if (resolveChatroomMessageRenderKind(
            messageType: message.messageType,
            senderId: message.senderId,
          ) ==
          ChatroomMessageRenderKind.hidden) {
        continue;
      }
      visibleSource.add(
        _RenderableLocationChatMessage(
          message: message,
          timelinePayload: timelinePayload,
        ),
      );
    }
    final previous = _messages.where((message) => !message.isSystem).toList();
    final existingByKey = {
      for (final message in previous) message.localId: message,
    };
    final existingByMessageId = <int, ChatMessageVm>{
      for (final message in previous)
        if ((message.messageId ?? 0) > 0) message.messageId!: message,
    };
    final existingByClientMsgId = <String, ChatMessageVm>{
      for (final message in previous)
        if (message.clientMsgId.trim().isNotEmpty)
          message.clientMsgId.trim(): message,
    };
    final next = <ChatMessageVm>[];
    final usedLocalIds = <String>{};
    var changed = previous.length != visibleSource.length;
    for (final visibleMessage in visibleSource) {
      final message = visibleMessage.message;
      final timelinePayload = visibleMessage.timelinePayload;
      final localId = _messageLocalId(message);
      final status = message.streaming ? 'streaming' : 'sent';
      final isMe = _isMineMessage(
        message,
        identityState: resolvedIdentityState,
      );
      final senderName = _messageSenderDisplayName(
        message,
        identityState: resolvedIdentityState,
      );
      final isPlayerControlledRole = _messageSenderIsPlayerControlledRole(
        message,
        identityState: resolvedIdentityState,
      );
      final clientMsgId = message.clientMsgId.trim();
      final existing =
          (clientMsgId.isEmpty ? null : existingByClientMsgId[clientMsgId]) ??
          existingByKey[localId] ??
          (message.messageId > 0
              ? existingByMessageId[message.messageId]
              : null) ??
          _matchingPendingSelfMessage(
            previous,
            message,
            usedLocalIds: usedLocalIds,
          );
      final avatarUrl = _messageAvatarUrl(
        message,
        identityState: resolvedIdentityState,
      );
      final text = timelinePayload == null
          ? _locationChatMessageDisplayText(message)
          : _timelinePayloadCopyText(timelinePayload);
      final renderKind = resolveChatroomMessageRenderKind(
        messageType: message.messageType,
        senderId: message.senderId,
      );
      final senderType = renderKind == ChatroomMessageRenderKind.image
          ? 'image'
          : _messageSenderType(message);
      final imageUrl = renderKind == ChatroomMessageRenderKind.image
          ? text.trim()
          : '';
      final currentTime = _messageCurrentTime(message);
      final createdAt = message.createdAt ?? DateTime.now();
      if (existing != null) {
        if (usedLocalIds.contains(existing.localId)) {
          changed = true;
          continue;
        }
        usedLocalIds.add(existing.localId);
        if (existing.globalMessageId != message.globalMessageId ||
            existing.messageId != message.messageId ||
            existing.locationMessageId != message.locationMessageId ||
            existing.roundId != message.conversationRoundId ||
            existing.tickNo != message.tickNo ||
            existing.subTickNo != message.subTickNo ||
            existing.senderName != senderName ||
            existing.isMe != isMe ||
            existing.isPlayerControlledRole != isPlayerControlledRole ||
            existing.avatarUrl != avatarUrl ||
            existing.imageUrl != imageUrl ||
            existing.timelinePayload != timelinePayload ||
            existing.text != text ||
            existing.currentTime != currentTime ||
            existing.status != status ||
            existing.localId != localId) {
          changed = true;
        }
        existing.globalMessageId = message.globalMessageId;
        existing.messageId = message.messageId;
        existing.locationMessageId = message.locationMessageId;
        existing.roundId = message.conversationRoundId;
        existing.tickNo = message.tickNo;
        existing.subTickNo = message.subTickNo;
        existing.senderName = senderName;
        existing.isMe = isMe;
        existing.isPlayerControlledRole = isPlayerControlledRole;
        existing.avatarUrl = avatarUrl;
        existing.imageUrl = imageUrl;
        existing.timelinePayload = timelinePayload;
        existing.text = text;
        existing.currentTime = currentTime;
        existing.status = status;
        existing.error = null;
        next.add(existing);
      } else {
        changed = true;
        final nextMessage = ChatMessageVm(
          localId: localId,
          clientMsgId: message.clientMsgId,
          globalMessageId: message.globalMessageId,
          messageId: message.messageId,
          locationMessageId: message.locationMessageId,
          roundId: message.conversationRoundId,
          tickNo: message.tickNo,
          subTickNo: message.subTickNo,
          senderId: message.senderId,
          senderName: senderName,
          isPlayerControlledRole: isPlayerControlledRole,
          avatarUrl: avatarUrl,
          imageUrl: imageUrl,
          timelinePayload: timelinePayload,
          text: text,
          currentTime: currentTime,
          isMe: isMe,
          status: status,
          senderType: senderType,
          createdAt: createdAt,
        );
        usedLocalIds.add(nextMessage.localId);
        next.add(nextMessage);
      }
    }
    preserveUnmatchedLocationChatLocalMessages(
      previous: previous,
      reconciled: next,
      usedLocalIds: usedLocalIds,
    );
    for (var i = 0; i < next.length && i < previous.length; i += 1) {
      if (next[i].localId != previous[i].localId) {
        changed = true;
        break;
      }
    }
    if (changed) {
      _messages
        ..clear()
        ..addAll(next);
    }
    _syncScrollCenterLocalId();
    return changed;
  }

  void _syncScrollCenterLocalId() {
    final nextCenterLocalId = _firstNonSystemMessageLocalId();
    if (nextCenterLocalId.isEmpty) {
      if (_scrollCenterLocalId.isNotEmpty) {
        final previousCenterLocalId = _scrollCenterLocalId;
        _scrollCenterLocalId = '';
        _recordPanelDebug(
          action: 'scrollCenterCleared',
          details: {'previousCenterLocalId': previousCenterLocalId},
        );
      }
      return;
    }
    if (_scrollCenterLocalId.isNotEmpty &&
        _messages.any((message) => message.localId == _scrollCenterLocalId)) {
      return;
    }
    final previousCenterLocalId = _scrollCenterLocalId;
    _scrollCenterLocalId = nextCenterLocalId;
    _recordPanelDebug(
      action: previousCenterLocalId.isEmpty
          ? 'scrollCenterInitialized'
          : 'scrollCenterReset',
      details: {
        'previousCenterLocalId': previousCenterLocalId,
        'centerLocalId': _scrollCenterLocalId,
      },
    );
  }

  String _firstNonSystemMessageLocalId() {
    for (final message in _messages) {
      if (!message.isSystem) return message.localId;
    }
    return '';
  }

  Set<int> _renderedLocationMessageIds() {
    return _messages
        .where((message) => !message.isSystem && message.locationMessageId > 0)
        .map((message) => message.locationMessageId)
        .toSet();
  }

  void _requestVisibleMessageGapFillIfNeeded(
    List<_LocationChatMessageGap> gaps,
    List<WorldChatroomMessage> source,
  ) {
    final service = _service;
    if (service == null || source.isEmpty || gaps.isEmpty) return;
    if (_loadingOlderMessages) {
      _deferredVisibleMessageGapFill = true;
      return;
    }
    for (final gap in gaps) {
      final key = _locationChatMessageGapKey(widget.locationId, gap);
      if (_releasedMessageGapKeys.contains(key)) continue;
      if (!_messageGapFillBeforeLocationMessageIds.add(
        gap.upperLocationMessageId,
      )) {
        continue;
      }
      if (!_messageGapFillKeys.add(key)) {
        _messageGapFillBeforeLocationMessageIds.remove(
          gap.upperLocationMessageId,
        );
        continue;
      }
      _logPanelMetric(
        'message gap fill requested location=${widget.locationId} '
        'lower=${gap.lowerLocationMessageId} '
        'upper=${gap.upperLocationMessageId}',
      );
      _recordPanelDebug(
        action: 'gapFillRequested',
        sourceMessages: source,
        details: {
          'lowerLocationMessageId': gap.lowerLocationMessageId,
          'upperLocationMessageId': gap.upperLocationMessageId,
          'missingCount': gap.missingCount,
        },
      );
      unawaited(_fillVisibleMessageGap(service: service, key: key, gap: gap));
    }
  }

  void _runDeferredVisibleMessageGapFillIfNeeded() {
    if (!_deferredVisibleMessageGapFill || _loadingOlderMessages) return;
    _deferredVisibleMessageGapFill = false;
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final renderWindow = _visibleLocationChatMessages(
      source,
      renderedLocationMessageIds: _renderedLocationMessageIds(),
      releasedGapKeys: _releasedMessageGapKeys,
      locationId: widget.locationId,
    );
    _requestVisibleMessageGapFillIfNeeded(renderWindow.gaps, source);
  }

  Future<void> _fillVisibleMessageGap({
    required WorldChatroomService service,
    required String key,
    required _LocationChatMessageGap gap,
  }) async {
    try {
      for (
        var attempt = 1;
        attempt <= _locationChatMessageGapMaxAttempts;
        attempt += 1
      ) {
        _messageGapFillAttempts[key] = attempt;
        try {
          if (_isLocationChatMessageGapFilled(
            service.state.messagesByLocation[widget.locationId] ??
                const <WorldChatroomMessage>[],
            gap,
          )) {
            _messageGapFillKeys.remove(key);
            _messageGapFillAttempts.remove(key);
            return;
          }
          await service.loadOlderMessages(
            locationId: widget.locationId,
            beforeMessageId: gap.upperLocationMessageId,
            limit: math.min(100, gap.missingCount + 1),
          );
          if (_isLocationChatMessageGapFilled(
            service.state.messagesByLocation[widget.locationId] ??
                const <WorldChatroomMessage>[],
            gap,
          )) {
            _messageGapFillKeys.remove(key);
            _messageGapFillAttempts.remove(key);
            return;
          }
        } catch (error) {
          _logPanelMetric(
            'message gap fill failed location=${widget.locationId} '
            'lower=${gap.lowerLocationMessageId} '
            'upper=${gap.upperLocationMessageId} '
            'attempt=$attempt error=$error',
          );
          _recordPanelDebug(
            action: 'gapFillFailed',
            details: {
              'lowerLocationMessageId': gap.lowerLocationMessageId,
              'upperLocationMessageId': gap.upperLocationMessageId,
              'attempt': attempt,
              'error': '$error',
            },
          );
        }
      }
    } finally {
      _messageGapFillBeforeLocationMessageIds.remove(
        gap.upperLocationMessageId,
      );
    }
    _releasedMessageGapKeys.add(key);
    _messageGapFillKeys.remove(key);
    _messageGapFillAttempts.remove(key);
    _recordPanelDebug(
      action: 'gapFillReleased',
      details: {
        'lowerLocationMessageId': gap.lowerLocationMessageId,
        'upperLocationMessageId': gap.upperLocationMessageId,
        'attempts': _locationChatMessageGapMaxAttempts,
      },
    );
    if (!mounted) return;
    final changed = _reconcileMessages(
      _chatroomState.messagesByLocation[widget.locationId] ??
          const <WorldChatroomMessage>[],
    );
    if (changed && mounted) {
      _setLocationChatState(() {});
    }
  }

  ChatMessageVm? _matchingPendingSelfMessage(
    List<ChatMessageVm> previous,
    WorldChatroomMessage message, {
    required Set<String> usedLocalIds,
  }) {
    final content = _locationChatMessageDisplayText(message).trim();
    if (content.isEmpty) return null;
    final now = DateTime.now();
    for (final candidate in previous.reversed) {
      if (usedLocalIds.contains(candidate.localId)) continue;
      if (!candidate.isMe) continue;
      if (candidate.status != 'sending' && candidate.status != 'sent') {
        continue;
      }
      final candidateMessageId = candidate.messageId ?? 0;
      if (candidateMessageId > 0 &&
          message.messageId > 0 &&
          candidateMessageId != message.messageId) {
        continue;
      }
      final age = now.difference(candidate.createdAt).abs();
      if (candidateMessageId <= 0 &&
          candidate.status != 'sending' &&
          age > const Duration(minutes: 1)) {
        continue;
      }
      if (candidate.text.trim() != content) continue;
      return candidate;
    }
    return null;
  }

  String _messageLocalId(WorldChatroomMessage message) {
    return _locationChatMessageLocalId(message);
  }

  String _messageSenderType(WorldChatroomMessage message) {
    final senderType = message.senderType.trim().toLowerCase();
    if (senderType == 'narrator') {
      return _senderIdIsNarrator(message.senderId) ? 'narrator' : 'character';
    }
    if (senderType == 'tick') return 'tick';
    if (senderType == 'ai') return 'character';
    return senderType.isEmpty ? 'user' : senderType;
  }

  ChatTimelinePayloadVm? _timelinePayloadVmForMessage(
    WorldChatroomMessage message, {
    required WorldChatroomState identityState,
  }) {
    final payload = message.timelinePayload;
    return switch (payload) {
      ChatroomUserEnterLocationPayload event => ChatUserEnterLocationPayloadVm(
        characterId: event.charId.trim(),
        toLocationId: event.toLocationId.trim(),
        text: normalizeGenesisUgcTextForDisplay(event.text),
      ),
      ChatroomStoryEventsPayload event => _storyEventsPayloadVm(
        event,
        identityState: identityState,
      ),
      ChatroomCharactersMovedPayload event => _charactersMovedPayloadVm(
        event,
        identityState: identityState,
      ),
      null => null,
    };
  }

  ChatStoryEventsPayloadVm? _storyEventsPayloadVm(
    ChatroomStoryEventsPayload payload, {
    required WorldChatroomState identityState,
  }) {
    final roleNamesById = _locationChatRoleNamesById(
      currentUserIds: _myUserIdKeys,
      currentSenderIds: _mySenderIdKeys,
      characters:
          identityState.world?.characters ?? const <Map<String, dynamic>>[],
      characterPositions:
          identityState.world?.characterPositions ??
          const <Map<String, dynamic>>[],
    );
    final paragraphs = <ChatStoryEventParagraphVm>[];
    for (final paragraph in payload.paragraphs) {
      final paragraphVm = _storyEventParagraphVm(
        paragraph,
        roleNamesById: roleNamesById,
      );
      paragraphs.add(paragraphVm);
    }
    if (paragraphs.isEmpty) return null;
    final payloadLocationName = normalizeGenesisUgcTextForDisplay(
      payload.locationName,
    ).trim();
    return ChatStoryEventsPayloadVm(
      locationId: payload.locationId.trim(),
      locationName: payloadLocationName.isNotEmpty
          ? payloadLocationName
          : _timelineLocationName(payload.locationId, identityState),
      paragraphs: List<ChatStoryEventParagraphVm>.unmodifiable(paragraphs),
    );
  }

  ChatCharactersMovedPayloadVm? _charactersMovedPayloadVm(
    ChatroomCharactersMovedPayload payload, {
    required WorldChatroomState identityState,
  }) {
    if (payload.movements.isEmpty) return null;
    final movements = payload.movements
        .map(
          (movement) => ChatCharacterMovementVm(
            characterId: movement.charId.trim(),
            characterName: _timelineCharacterName(
              movement.charId,
              identityState,
            ),
            toLocationId: movement.toLocationId.trim(),
            toLocationName: _timelineLocationName(
              movement.toLocationId,
              identityState,
            ),
          ),
        )
        .toList(growable: false);
    return ChatCharactersMovedPayloadVm(movements: movements);
  }

  String _timelineCharacterName(
    String characterId,
    WorldChatroomState identityState,
  ) {
    return _resolveTimelineCharacterName(
      characterId,
      characters:
          identityState.world?.characters ?? const <Map<String, dynamic>>[],
      characterPositions:
          identityState.world?.characterPositions ??
          const <Map<String, dynamic>>[],
      entitiesById: identityState.entitiesById,
    );
  }

  String _timelineLocationName(
    String locationId,
    WorldChatroomState identityState,
  ) {
    final world = identityState.world;
    return _resolveTimelineLocationName(
      locationId,
      locations: world?.locations ?? const <Map<String, dynamic>>[],
      processedLocationTree: world?.processedLocationTree,
    );
  }

  String _messageCurrentTime(WorldChatroomMessage message) {
    if (message.senderType.trim().toLowerCase() ==
        chatroomStoryEventsSenderType) {
      return message.currentTime.trim();
    }
    if (isChatroomTimelinePayloadSenderType(message.senderType)) return '';
    final senderType = _messageSenderType(message);
    if (senderType == 'user' ||
        senderType == 'tick' ||
        senderType == 'system') {
      return '';
    }
    return message.currentTime.trim();
  }

  void _syncSenderIdentity(WorldChatroomService service) {
    final identity = service.identity;
    if (identity == null) return;
    final userId = identity.userId.trim();
    final senderId = identity.senderId.trim();
    final senderName = identity.senderName.trim();
    _rememberMyUserId(userId);
    _rememberMySenderId(senderId);
    if (senderName.isNotEmpty) _mySenderName = senderName;
  }

  Future<void> _syncLocalIdentity(AppServices services) async {
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final userInfo = await services.sessionStore.readUserInfo();
    final cachedUid = _mapString(userInfo, 'uid');
    final avatarUrl = _resolvedProfileAvatar(
      userInfo ?? const <String, dynamic>{},
      '',
    );
    final avatarChanged = avatarUrl != _myAvatarUrl;
    _myAvatarUrl = avatarUrl;
    final changed =
        _rememberMyUserId(uid) | _rememberMyUserId(cachedUid) | avatarChanged;
    if (!changed || !mounted) return;
    final changedMessages = _reconcileMessages(
      _chatroomState.messagesByLocation[widget.locationId] ??
          const <WorldChatroomMessage>[],
    );
    if (changedMessages && mounted) _setLocationChatState(() {});
  }

  bool _rememberMyUserId(String? userId) {
    final trimmed = userId?.trim() ?? '';
    final key = _chatroomIdentityKey(trimmed);
    if (key.isEmpty) return false;
    if (_myUserId.isEmpty) _myUserId = trimmed;
    return _myUserIdKeys.add(key);
  }

  bool _rememberMySenderId(String? senderId) {
    final trimmed = senderId?.trim() ?? '';
    final key = _chatroomIdentityKey(trimmed);
    if (key.isEmpty) return false;
    if (_mySenderId.isEmpty) _mySenderId = trimmed;
    return _mySenderIdKeys.add(key);
  }

  bool _isMineMessage(
    WorldChatroomMessage message, {
    WorldChatroomState? identityState,
  }) {
    final world = (identityState ?? _chatroomState).world;
    return _locationChatMessageBelongsToCurrentRole(
      messageUserId: message.userId,
      messageSenderId: message.senderId,
      currentUserIds: _myUserIdKeys,
      currentSenderIds: _mySenderIdKeys,
      characters: world?.characters ?? const <Map<String, dynamic>>[],
      characterPositions:
          world?.characterPositions ?? const <Map<String, dynamic>>[],
    );
  }

  void _handleFailure(ChatroomFailureEvent failure) {
    if (!isChatroomUnauthorizedFailure(failure)) return;
    unawaited(_handleUnauthorizedFailure());
  }

  Future<void> _handleUnauthorizedFailure() async {
    if (_handlingUnauthorizedFailure || !mounted) return;
    _handlingUnauthorizedFailure = true;
    try {
      final services = AppServicesScope.read(context);
      final previousService = _service;
      final ownedPreviousService = _ownsService;
      await _closeChatroom();
      if (!ownedPreviousService && previousService != null) {
        try {
          await previousService.disconnect();
        } catch (_) {}
      }
      await services.sessionStore.clearUid();
      services.notifySessionChanged();
      try {
        await services.identityAuth.signOutIdentity();
      } catch (error) {
        debugPrint(
          '[Auth][ChatroomUnauthorized] identity sign out failed: $error',
        );
      }
      if (!mounted) return;
      final loggedIn = await ensureGenesisLogin(context);
      if (!mounted) return;
      if (!loggedIn) {
        final onBack = widget.onBack;
        if (onBack != null) {
          onBack();
        } else {
          await Navigator.of(context).maybePop();
        }
        return;
      }
      if (!ownedPreviousService && previousService != null) {
        _service = previousService;
        _ownsService = false;
        _attachService(previousService);
        await _connectFallbackAndJoin(previousService, services);
      } else {
        _prepareConnection();
      }
    } finally {
      _handlingUnauthorizedFailure = false;
    }
  }

  bool _hasCompletedAwaitedAiResponse(List<WorldChatroomMessage> source) {
    final awaitedRoundId = _awaitingAiResponseRoundId.trim();
    if (!_awaitingAiResponse) return false;
    if (awaitedRoundId.isEmpty) return false;
    for (final message in source.reversed) {
      if (!_currentLocationIds().contains(message.locationId)) continue;
      if (message.conversationRoundId != awaitedRoundId) continue;
      if (_isMineMessage(message)) continue;
      if (_messageSenderType(message) == 'user') continue;
      return !message.streaming;
    }
    return false;
  }
}

class _RenderableLocationChatMessage {
  const _RenderableLocationChatMessage({
    required this.message,
    required this.timelinePayload,
  });

  final WorldChatroomMessage message;
  final ChatTimelinePayloadVm? timelinePayload;
}

String _resolveTimelineCharacterName(
  String characterId, {
  required Iterable<Map<String, dynamic>> characters,
  required Iterable<Map<String, dynamic>> characterPositions,
  required Map<String, WorldChatroomEntity> entitiesById,
}) {
  final resolvedId = characterId.trim();
  final identityKey = _chatroomIdentityKey(resolvedId);
  for (final candidate in <Map<String, dynamic>>[
    ...characters,
    ...characterPositions,
  ]) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    final candidateId = _firstMapString(character, const [
      'char_id',
      'character_id',
      'id',
    ]);
    if (_chatroomIdentityKey(candidateId) != identityKey) continue;
    final name = _firstMapString(character, const [
      'name',
      'role_nickname',
      'role_name',
      'character_name',
    ]).trim();
    if (name.isNotEmpty) return normalizeGenesisUgcTextForDisplay(name);
  }
  for (final entry in entitiesById.entries) {
    if (_chatroomIdentityKey(entry.key) != identityKey &&
        _chatroomIdentityKey(entry.value.id) != identityKey) {
      continue;
    }
    final name = entry.value.name.trim();
    if (name.isNotEmpty) return normalizeGenesisUgcTextForDisplay(name);
  }
  return resolvedId;
}

String _resolveTimelineLocationName(
  String locationId, {
  required Iterable<Map<String, dynamic>> locations,
  ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree,
}) {
  final resolvedId = locationId.trim();
  final identityKey = _chatroomIdentityKey(resolvedId);
  for (final location in locations) {
    final candidateId = _firstMapString(location, const ['location_id', 'id']);
    if (_chatroomIdentityKey(candidateId) != identityKey) continue;
    final name = _firstMapString(location, const [
      'location_name',
      'name',
    ]).trim();
    if (name.isNotEmpty) return normalizeGenesisUgcTextForDisplay(name);
  }
  final node = processedLocationTree?.nodeById(resolvedId);
  if (node != null) {
    final name = _firstMapString(node.value, const [
      'location_name',
      'name',
    ]).trim();
    if (name.isNotEmpty) return normalizeGenesisUgcTextForDisplay(name);
  }
  return resolvedId;
}

ChatStoryEventParagraphVm _storyEventParagraphVm(
  ChatroomStoryEventParagraph paragraph, {
  required Map<String, String> roleNamesById,
}) {
  final visibility = paragraph.visibility.trim().toLowerCase();
  String visibilityLabel;
  if (visibility == 'public') {
    visibilityLabel = 'public';
  } else if (visibility == 'char_only') {
    final matchingNames = <String>[];
    final seenNames = <String>{};
    for (final visibleId in paragraph.visibleTo) {
      final name = roleNamesById[_chatroomIdentityKey(visibleId)]?.trim() ?? '';
      if (name.isEmpty || !seenNames.add(name)) continue;
      matchingNames.add(name);
    }
    visibilityLabel = matchingNames.join(', ');
  } else {
    visibilityLabel = '';
  }
  return ChatStoryEventParagraphVm(
    timestamp: normalizeGenesisUgcTextForDisplay(paragraph.timestamp),
    text: normalizeGenesisUgcTextForDisplay(paragraph.text),
    clue: normalizeGenesisUgcTextForDisplay(paragraph.clue),
    visibilityLabel: normalizeGenesisUgcTextForDisplay(visibilityLabel),
  );
}

Map<String, String> _locationChatRoleNamesById({
  required Iterable<String> currentUserIds,
  required Iterable<String> currentSenderIds,
  required Iterable<Map<String, dynamic>> characters,
  required Iterable<Map<String, dynamic>> characterPositions,
}) {
  final candidates = <Map<String, dynamic>>[];
  for (final candidate in <Map<String, dynamic>>[
    ...characters,
    ...characterPositions,
  ]) {
    final rawCharacter = candidate['character'];
    candidates.add(
      rawCharacter is Map ? _stringKeyMap(rawCharacter) : candidate,
    );
  }
  final result = <String, String>{};
  for (final character in candidates) {
    final characterId = _firstMapString(character, const [
      'character_id',
      'char_id',
      'id',
    ]).trim();
    final characterKey = _chatroomIdentityKey(characterId);
    if (characterKey.isEmpty) continue;
    final name = _firstMapString(character, const [
      'name',
      'role_nickname',
      'role_name',
      'character_name',
    ]).trim();
    final resolvedName = normalizeGenesisUgcTextForDisplay(
      name.isEmpty ? characterId : name,
    );
    final existingName = result[characterKey];
    if (existingName == null ||
        existingName == characterId ||
        name.isNotEmpty) {
      result[characterKey] = resolvedName;
    }
  }
  return result;
}

bool _isHiddenLocationChatTimelineMessage(WorldChatroomMessage message) {
  return message.senderType.trim().toLowerCase() ==
      chatroomUserEnterLocationSenderType;
}

String _timelinePayloadCopyText(ChatTimelinePayloadVm payload) {
  return switch (payload) {
    ChatUserEnterLocationPayloadVm event => event.text,
    ChatStoryEventsPayloadVm event => [
      if (event.locationName.trim().isNotEmpty) event.locationName,
      for (final paragraph in event.paragraphs) ...[
        [
          if (paragraph.timestamp.trim().isNotEmpty) paragraph.timestamp,
          if (paragraph.visibilityLabel.trim().isNotEmpty)
            paragraph.visibilityLabel,
        ].join(' · '),
        paragraph.text,
        if (paragraph.clue.trim().isNotEmpty) paragraph.clue,
      ],
    ].join('\n'),
    ChatCharactersMovedPayloadVm event =>
      event.movements
          .map(
            (movement) =>
                '${movement.characterName} → ${movement.toLocationName}',
          )
          .join('\n'),
  };
}

@visibleForTesting
Map<String, String> locationChatCurrentRoleNamesByIdForTesting({
  required Iterable<String> currentUserIds,
  required Iterable<String> currentSenderIds,
  required Iterable<Map<String, dynamic>> characters,
  required Iterable<Map<String, dynamic>> characterPositions,
}) {
  return _locationChatRoleNamesById(
    currentUserIds: currentUserIds,
    currentSenderIds: currentSenderIds,
    characters: characters,
    characterPositions: characterPositions,
  );
}

@visibleForTesting
ChatStoryEventParagraphVm? locationChatStoryEventParagraphVmForTesting(
  ChatroomStoryEventParagraph paragraph, {
  required Map<String, String> roleNamesById,
}) {
  return _storyEventParagraphVm(paragraph, roleNamesById: roleNamesById);
}

@visibleForTesting
String resolveLocationChatTimelineCharacterNameForTesting({
  required String characterId,
  Iterable<Map<String, dynamic>> characters = const <Map<String, dynamic>>[],
  Iterable<Map<String, dynamic>> characterPositions =
      const <Map<String, dynamic>>[],
  Map<String, WorldChatroomEntity> entitiesById =
      const <String, WorldChatroomEntity>{},
}) {
  return _resolveTimelineCharacterName(
    characterId,
    characters: characters,
    characterPositions: characterPositions,
    entitiesById: entitiesById,
  );
}

@visibleForTesting
String resolveLocationChatTimelineLocationNameForTesting({
  required String locationId,
  Iterable<Map<String, dynamic>> locations = const <Map<String, dynamic>>[],
}) {
  return _resolveTimelineLocationName(locationId, locations: locations);
}
