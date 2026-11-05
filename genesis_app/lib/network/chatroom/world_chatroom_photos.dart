part of 'world_chatroom_service.dart';

extension WorldChatroomPhotos on WorldChatroomService {
  bool get photoSessionReady =>
      !_disposed && _worldId.isNotEmpty && _identity != null;
  void beginPhotoVisit(String location) {
    for (final message
        in _state.messagesByLocation[location] ??
            const <WorldChatroomMessage>[]) {
      if (message.photo != null) {
        _photoConfirmedReads.remove(message.photo!.taskId);
      }
    }
  }

  Future<({List<WorldChatroomMessage> messages, bool hasMore})?>
  loadPhotoNavigationWindow(
    ChatPhotoTarget target, {
    required Object owner,
    required bool Function() isCurrent,
  }) async {
    final world = _worldId;
    final generation = _messageSyncGeneration;
    bool current() =>
        !_disposed &&
        world == _worldId &&
        generation == _messageSyncGeneration &&
        isCurrent();
    // Identify the target in its original round without publishing a disconnected
    // fragment into the visible message queue.
    final cached = {
      for (final m
          in _state.messagesByLocation[target.locationId] ??
              const <WorldChatroomMessage>[])
        if (m.locationMessageId > 0) m.locationMessageId: m,
    };
    var roundCursor = 0;
    var found = cached.values.any(
      (m) => (target.cardId != null
          ? m.conversationRoundNumber == target.roundId
          : m.globalMessageId == target.globalMessageId &&
                m.photo?.status == ChatPhotoStatus.succeeded),
    );
    while (!found && current()) {
      final page = await _api.chatroomHttp.getMessages(
        worldId: world,
        locationId: target.locationId,
        since: roundCursor,
        limit: 100,
        startConversationRoundId: target.roundId,
        endConversationRoundId: target.roundId,
      );
      if (!current()) return null;
      found = page.messages.any(
        (m) => (target.cardId != null
            ? m.conversationRoundId == target.roundId
            : m.globalMessageId == target.globalMessageId &&
                  ChatPhoto.tryParse(m.payload['photo'])?.status ==
                      ChatPhotoStatus.succeeded),
      );
      if (found || !page.hasMore) break;
      final ids = page.messages
          .map((m) => m.locationMessageId)
          .where((id) => id > 0);
      if (ids.isEmpty) break;
      final next = ids.reduce(math.min);
      if (roundCursor > 0 && next >= roundCursor) break;
      roundCursor = next;
    }
    if (!found || !current()) return null;
    final collected = <int, WorldChatroomMessage>{};
    var cursor = 0;
    while (current()) {
      final page = await _api.chatroomHttp.getMessages(
        worldId: world,
        locationId: target.locationId,
        since: cursor,
        limit: 100,
      );
      if (!current()) return null;
      for (final row in page.messages) {
        collected[row.locationMessageId] = WorldChatroomMessage.fromHttpMessage(
          row,
        );
      }
      if (collected.isNotEmpty) {
        var before = collected.keys.reduce(math.min) - 1;
        while (cached.containsKey(before)) {
          collected[before] = cached[before]!;
          if (cached[before]!.globalMessageId == target.globalMessageId) break;
          before--;
        }
      }
      if (collected.values.any(
        (m) => (target.cardId != null
            ? m.conversationRoundNumber == target.roundId
            : m.globalMessageId == target.globalMessageId &&
                  m.photo?.status == ChatPhotoStatus.succeeded),
      )) {
        final messages = collected.values.toList()
          ..sort((a, b) => a.locationMessageId.compareTo(b.locationMessageId));
        retainMessageWindow(
          owner: owner,
          locationId: target.locationId,
          protectedKeys: messages.map(locationMessageRetentionKey).toSet(),
        );
        _upsertMessages(messages);
        return (messages: messages, hasMore: page.hasMore);
      }
      if (!page.hasMore || collected.isEmpty) return null;
      final next = collected.keys.where((id) => id > 0).reduce(math.min);
      if (cursor > 0 && next >= cursor) return null;
      cursor = next;
    }
    return null;
  }

  Future<void> acceptPhotoReceipt(
    ChatPhotoReceipt receipt, {
    ChatPhotoRequest? request,
  }) async {
    if (_disposed || receipt.worldId != _worldId) return;
    if (receipt.cardId != null) {
      if (_storageOwnerUid.isNotEmpty) {
        await ChatPhotoJobStore(
          _api.chatroomHttp.cacheNamespace,
          _storageOwnerUid,
          _worldId,
          receipt.locationId,
        ).update({
          ...receipt.toMessageJson(),
          'card_id': receipt.cardId,
        }, request: request);
      }
      _photoLiveRevisions[receipt.photo.taskId] = ++_photoRevision;
      await replyActions?.refreshPhotoCard(
        receipt.locationId,
        receipt.roundId,
        receipt.cardId!,
      );
      return;
    }
    final message = WorldChatroomMessage.fromHttpMessage(
      ChatroomHttpMessage.fromV2Json(receipt.toMessageJson()),
    );
    acceptLivePhoto(message, authoritative: true);
    await _rememberPhotoJob(message, request: request, failOnError: true);
  }

  void acceptLivePhoto(
    WorldChatroomMessage message, {
    bool authoritative = false,
  }) {
    if (_disposed || message.photo == null) return;
    final photo = message.photo!;
    final resident =
        (_state.messagesByLocation[message.locationId] ??
                const <WorldChatroomMessage>[])
            .where(
              (m) =>
                  m.globalMessageId == message.globalMessageId &&
                  m.photo != null,
            )
            .firstOrNull;
    if (!authoritative &&
        resident != null &&
        resident.photo!.taskId != photo.taskId) {
      unawaited(
        refreshLocationHistory(locationId: message.locationId).catchError((
          Object error,
        ) {
          _logChatroomSocketEvent('photo task reconciliation failed: $error');
        }),
      );
      return;
    }
    final existing =
        (_state.messagesByLocation[message.locationId] ??
                const <WorldChatroomMessage>[])
            .where((m) => m.photo?.taskId == photo.taskId)
            .firstOrNull;
    // A duplicate terminal broadcast must not resurrect a hidden historical
    // failure on a later visit. A fresh generating echo confirms a live task.
    if (!_photoKnownTasks.contains(photo.taskId) && existing == null ||
        (!photo.terminal &&
            existing?.photo?.terminal != true &&
            !_photoTerminals.containsKey(photo.taskId))) {
      _photoLiveRevisions[photo.taskId] = ++_photoRevision;
    }
    _upsertMessage(message);
  }

  void _applyPhotoResult(ChatroomPhotoResult event) {
    final photo = event.photo!;
    _photoTerminals[photo.taskId] = photo;
    final matches = event.message.payload['card_id'] != null
        ? const <WorldChatroomMessage>[]
        : _state.messagesByLocation.values
              .expand((messages) => messages)
              .where((message) => message.photo?.taskId == photo.taskId)
              .toList();
    for (final message in matches) {
      acceptLivePhoto(
        message.copyWith(
          content: photo.imageUrl,
          rawPayload: {
            ...message.rawPayload,
            'content': photo.imageUrl,
            'photo': photo.toJson(),
          },
        ),
      );
    }
    if (event.eventId.isNotEmpty && _seenPhotoResults.add(event.eventId)) {
      _photoResults.add(event);
    }
  }

  Future<void> _rememberPhotoJob(
    WorldChatroomMessage message, {
    ChatPhotoRequest? request,
    bool failOnError = false,
  }) {
    if (message.photo == null || _storageOwnerUid.isEmpty || _worldId.isEmpty) {
      return Future.value();
    }
    _photoKnownTasks.add(message.photo!.taskId);
    final store = ChatPhotoJobStore(
      _api.chatroomHttp.cacheNamespace,
      _storageOwnerUid,
      _worldId,
      message.locationId,
    );
    final terminal = _photoTerminals[message.photo!.taskId];
    if (terminal != null && !message.photo!.terminal) {
      message = message.copyWith(
        content: terminal.imageUrl,
        rawPayload: {...message.rawPayload, 'photo': terminal.toJson()},
      );
    }
    final json = _storageJsonFromWorldMessage(message);
    final write = _photoJournalWrites.then(
      (_) => store.update(json, request: request),
    );
    _photoJournalWrites = write.catchError((Object error) {
      _logChatroomSocketEvent('photo task storage failed: $error');
    });
    return failOnError ? write : _photoJournalWrites;
  }

  /// Re-read known unfinished rounds; a latest-page cursor cannot find updates
  /// to an older message. This is lifecycle driven, never task polling.
  Future<void> recoverPhotos(
    String locationId,
  ) => _photoRecoveries.putIfAbsent(locationId, () async {
    final world = _worldId;
    final generation = _messageSyncGeneration;
    final rounds =
        (_state.messagesByLocation[locationId] ??
                const <WorldChatroomMessage>[])
            .where((m) => m.photo?.status == ChatPhotoStatus.generating)
            .map((m) => m.conversationRoundNumber)
            .where((r) => r > 0)
            .toSet();
    try {
      await _photoJournalWrites;
      if (_disposed ||
          generation != _messageSyncGeneration ||
          world != _worldId) {
        return;
      }
      try {
        final jobs = await ChatPhotoJobStore(
          _api.chatroomHttp.cacheNamespace,
          _storageOwnerUid,
          world,
          locationId,
        ).read();
        for (final job in jobs.where((j) => j['card_id'] != null)) {
          await replyActions?.refreshPhotoCard(
            locationId,
            chatPhotoId(job['conversation_round_id']),
            chatPhotoId(job['card_id']),
          );
          if (_disposed ||
              world != _worldId ||
              generation != _messageSyncGeneration) {
            return;
          }
          final oldPhoto = ChatPhoto.fromJson(
            (job['raw_payload'] ?? job['payload'] as Map)['photo'],
          );
          final current = replyActions
              ?.stateForRound(
                locationId,
                chatPhotoId(job['conversation_round_id']),
              )
              ?.messagesForCard(chatPhotoId(job['card_id']));
          if (current != null &&
              !current.any(
                (m) =>
                    m.photo?.taskId == oldPhoto.taskId &&
                    m.photo?.terminal == false,
              )) {
            await ChatPhotoJobStore(
              _api.chatroomHttp.cacheNamespace,
              _storageOwnerUid,
              world,
              locationId,
            ).remove(oldPhoto.taskId);
          }
        }
        rounds.addAll(
          jobs
              .where((j) => j['card_id'] == null)
              .map(WorldChatroomMessage.fromStorageJson)
              .where((m) => m.photo?.status == ChatPhotoStatus.generating)
              .map((m) => m.conversationRoundNumber)
              .where((r) => r > 0),
        );
      } catch (error) {
        _logChatroomSocketEvent('photo task restore failed: $error');
      }
      for (final state
          in replyActions?.statesFor(locationId) ??
              <ChatroomReplyRoundState>[]) {
        for (final card in state.cards) {
          if (card.messages.any(
            (m) =>
                ChatPhoto.tryParse(m.message.payload['photo'])?.status ==
                ChatPhotoStatus.generating,
          )) {
            await replyActions?.refreshPhotoCard(
              locationId,
              state.roundId,
              card.cardId,
            );
          }
        }
      }
      for (final round in rounds) {
        var since = 0;
        while (!_disposed &&
            world == _worldId &&
            generation == _messageSyncGeneration) {
          final page = await _api.chatroomHttp.getMessages(
            worldId: world,
            locationId: locationId,
            since: since,
            limit: 100,
            startConversationRoundId: round,
            endConversationRoundId: round,
          );
          if (_disposed ||
              world != _worldId ||
              generation != _messageSyncGeneration) {
            return;
          }
          for (final row in page.messages.where(
            (m) => m.businessType == 'live_photo',
          )) {
            final message = WorldChatroomMessage.fromHttpMessage(row);
            if (message.photo?.status == ChatPhotoStatus.generating) {
              _photoConfirmedReads.add(message.photo!.taskId);
            }
            final resident =
                (_state.messagesByLocation[locationId] ??
                        const <WorldChatroomMessage>[])
                    .any(
                      (m) => m.locationMessageId == message.locationMessageId,
                    );
            if (resident) {
              _upsertMessage(message);
            } else {
              // Recovery is not a pagination operation: don't splice an isolated
              // old round into the visible latest window.
              _rememberPhotoJob(message);
              await _persistMessage(message);
            }
          }
          if (!page.hasMore) break;
          final ids = page.messages
              .map((m) => m.locationMessageId)
              .where((id) => id > 0);
          if (ids.isEmpty) break;
          final next = ids.reduce(math.min);
          if (since != 0 && next >= since) break;
          since = next;
        }
      }
    } catch (error) {
      // Preserve pending state on read failure. Next lifecycle entry can retry.
      _logChatroomSocketEvent('photo recovery failed: $error');
    } finally {
      _photoRecoveries.remove(locationId);
    }
  });
}
