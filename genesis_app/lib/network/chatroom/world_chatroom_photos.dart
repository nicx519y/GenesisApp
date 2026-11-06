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
      final refreshed = await replyActions?.refreshPhotoCards(
        receipt.locationId,
        receipt.roundId,
        {receipt.cardId!},
      );
      if (refreshed != null) {
        _observeRefreshedCardPhotos(
          receipt.locationId,
          receipt.roundId,
          refreshed,
        );
      }
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

  void _observeRefreshedCardPhotos(String location, int round, Set<int> cards) {
    final monitor = _photoGenerationMonitor;
    if (monitor == null) return;
    final state = replyActions?.stateForRound(location, round);
    if (state == null) return;
    for (final id in cards) {
      for (final message in state.messagesForCard(id)) {
        if (message.photo case final photo? when photo.terminal) {
          monitor.observe('chat', photo);
        }
      }
    }
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
      final store = ChatPhotoJobStore(
        _api.chatroomHttp.cacheNamespace,
        _storageOwnerUid,
        world,
        locationId,
      );
      final targets = <int, Set<int>>{};
      var jobs = <Map<String, dynamic>>[];
      try {
        jobs = await store.read();
        if (_disposed ||
            generation != _messageSyncGeneration ||
            world != _worldId) {
          return;
        }
        for (final job in jobs) {
          final round = chatPhotoId(job['conversation_round_id']);
          if (job['card_id'] != null) {
            targets
                .putIfAbsent(round, () => <int>{})
                .add(chatPhotoId(job['card_id']));
          } else {
            final message = WorldChatroomMessage.fromStorageJson(job);
            if (message.photo?.status == ChatPhotoStatus.generating &&
                round > 0) {
              rounds.add(round);
            }
          }
        }
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
            targets.putIfAbsent(state.roundId, () => <int>{}).add(card.cardId);
          }
        }
      }
      for (final entry in targets.entries) {
        if (_disposed ||
            generation != _messageSyncGeneration ||
            world != _worldId) {
          return;
        }
        try {
          final refreshed =
              await replyActions?.refreshPhotoCards(
                locationId,
                entry.key,
                entry.value,
              ) ??
              <int>{};
          if (_disposed ||
              generation != _messageSyncGeneration ||
              world != _worldId) {
            return;
          }
          _observeRefreshedCardPhotos(locationId, entry.key, refreshed);
          for (final job in jobs.where(
            (j) =>
                chatPhotoId(j['conversation_round_id']) == entry.key &&
                j['card_id'] != null &&
                refreshed.contains(chatPhotoId(j['card_id'])),
          )) {
            final oldPhoto = ChatPhoto.fromJson(
              ((job['raw_payload'] ?? job['payload']) as Map)['photo'],
            );
            final messages = replyActions
                ?.stateForRound(locationId, entry.key)
                ?.messagesForCard(chatPhotoId(job['card_id']));
            if (messages != null &&
                !messages.any(
                  (m) =>
                      m.photo?.taskId == oldPhoto.taskId &&
                      m.photo?.terminal == false,
                )) {
              await store.remove(oldPhoto.taskId);
            }
          }
        } catch (error) {
          _logChatroomSocketEvent('photo card recovery failed: $error');
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
              if (message.photo case final photo? when photo.terminal) {
                _photoGenerationMonitor?.observe('chat', photo);
              }
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
