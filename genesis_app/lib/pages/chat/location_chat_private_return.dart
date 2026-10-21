part of 'location_chat_page.dart';

/// A return-to-room view, never a synthetic server message or History record.
class _PrivateChatReturn {
  _PrivateChatReturn({
    required this.locationId,
    required this.anchor,
    required this.publicMessageId,
    required this.baselineMessageKeys,
    required this.tick,
    required this.identityIsCurrent,
  });

  final String locationId;
  final movements = <String, ChatroomV2CharacterMovement>{};
  final String? anchor;
  final int publicMessageId;
  final Set<(int, String)> baselineMessageKeys;
  final Set<(String, String)> authoritativeDestinations = {};
  final Object tick;
  final bool Function() identityIsCurrent;
  final DateTime createdAt = DateTime.now();
  final String id = 'phone-return-${DateTime.now().microsecondsSinceEpoch}';
  bool observing = true;
  DateTime? closedAt;
  bool revealed = false;
  ChatMessageVm? row;
}

Object _privateReturnTick(WorldChatroomState state) =>
    (state.world?.tickCount, state.world?.subTickNo);

extension _LocationChatPrivateReturn on _LocationChatPanelState {
  Future<void> _openPhoneFromRoom({
    MiniPhoneSession? session,
    PhonePerson? contact,
    required String source,
  }) async {
    final service = _service;
    final location = widget.locationId;
    final world = widget.worldId;
    final services = AppServicesScope.read(context);
    _PrivateChatReturn? visit;
    await PagePresentationScope.runCovered(context, () async {
      await showMiniPhone(
        context,
        session: session,
        worldId: _modelWorldId,
        modelCache: _modelRequestCache,
        initialContact: contact,
        entrySource: source,
        onPrivateChatOpened: (phone) {
          final data = phone.data;
          if (visit != null ||
              service == null ||
              data == null ||
              !mounted ||
              !widget.active ||
              widget.locationId != location ||
              widget.worldId != world ||
              !identical(service, _service)) {
            return;
          }
          final uid = data.uid;
          if (uid == null || uid.isEmpty) return;
          final generation = services.sessionRevision.value;
          final serviceUser = service.identity?.userId;
          final state = service.state;
          final sourceMessages =
              state.messagesByLocation[location] ??
              const <WorldChatroomMessage>[];
          final anchor = _replyProjection
              .presentation(_renderedReplyState)
              .messages
              .where((m) => !m.isAiContentDisclaimer)
              .lastOrNull
              ?.localId;
          // Consecutive phone visits without a public message share one return card.
          final previous = _privateChatReturns.lastOrNull;
          if (previous != null &&
              previous.observing &&
              previous.anchor == anchor &&
              previous.identityIsCurrent()) {
            visit = previous;
            previous.revealed = false;
          } else {
            visit = _PrivateChatReturn(
              locationId: location,
              anchor: anchor,
              // Service cursor deliberately excludes transient WS event IDs.
              publicMessageId: state.lastMessageId,
              baselineMessageKeys: {
                for (final message in sourceMessages)
                  (message.messageId, message.conversationRoundId),
              },
              tick: _privateReturnTick(state),
              identityIsCurrent: () =>
                  mounted &&
                  widget.worldId == world &&
                  widget.locationId == location &&
                  identical(service, _service) &&
                  service.identity?.userId == serviceUser &&
                  services.sessionRevision.value == generation,
            );
            _privateChatReturns.add(visit!);
          }
        },
      );
      final returned = visit;
      if (returned == null || !returned.identityIsCurrent()) return;
      returned.revealed = true;
      _syncPrivateChatReturns(service!.state);
    });
    final returned = visit;
    if (returned == null || !returned.identityIsCurrent()) return;
    _notifyMessageViewport();
  }

  void _handlePhoneCharactersMoved(ChatroomPhoneCharactersMoved event) {
    if (event.worldId != widget.worldId) return;
    final visit = _privateChatReturns.lastOrNull;
    if (visit == null || !visit.observing || !visit.identityIsCurrent()) return;
    for (final movement in event.movements) {
      if (movement.oldLocationId == movement.toLocationId) continue;
      // Keep the latest destination even when it leaves this room's scope,
      // so consecutive notifications cannot leave a stale return card.
      visit.movements[movement.characterId] = movement;
    }
    if (_syncPrivateChatReturns(_service!.state)) _notifyMessageViewport();
  }

  bool _syncPrivateChatReturns(WorldChatroomState state) {
    var changed = false;
    _privateChatReturns.removeWhere((visit) {
      if (visit.identityIsCurrent()) return false;
      changed = true;
      return true;
    });
    for (final visit in _privateChatReturns) {
      final source =
          state.messagesByLocation[visit.locationId] ??
          const <WorldChatroomMessage>[];
      final newPublic = source.where(
        (m) =>
            m.messageId > visit.publicMessageId &&
            !visit.baselineMessageKeys.contains((
              m.messageId,
              m.conversationRoundId,
            )) &&
            m.timelinePayload is! ChatroomCharactersMovedPayload,
      );
      if (visit.observing &&
          (state.inputBlocked ||
              _privateReturnTick(state) != visit.tick ||
              newPublic.isNotEmpty)) {
        visit.observing = false;
        visit.closedAt =
            newPublic
                .map((m) => m.createdAt)
                .nonNulls
                .fold<DateTime?>(
                  null,
                  (first, time) =>
                      first == null || time.isBefore(first) ? time : first,
                ) ??
            DateTime.now();
      }
      // Reconcile public messages even after return-event collection is closed.
      // Transient movement event IDs and persisted message IDs are independent.
      final reported = visit.authoritativeDestinations;
      for (final message in source) {
        if (visit.baselineMessageKeys.contains((
          message.messageId,
          message.conversationRoundId,
        ))) {
          continue;
        }
        final transient =
            message.senderType == chatroomCharactersMovedSenderType &&
            message.conversationRoundId.startsWith('ws-event:');
        if (!transient && message.messageId <= visit.publicMessageId) continue;
        // A later ordinary arrival at the same destination is a different move.
        // After closing, accept only events whose occurrence is inside this
        // visit; an undated event cannot safely replace a retained return card.
        final closedAt = visit.closedAt;
        if (closedAt != null &&
            (message.createdAt == null ||
                message.createdAt!.isAfter(closedAt))) {
          continue;
        }
        if (message.timelinePayload
            case ChatroomCharactersMovedPayload payload) {
          for (final movement in payload.movements) {
            reported.add((
              movement.charId.trim(),
              movement.toLocationId.trim(),
            ));
          }
        }
        for (final movement
            in message.v2TickPayload?.charactersMoved ??
                const <ChatroomV2CharacterMovement>[]) {
          final before = visit.movements[movement.characterId.trim()];
          if (before == null ||
              movement.oldLocationId.trim() != before.oldLocationId) {
            continue;
          }
          reported.add((
            movement.characterId.trim(),
            movement.toLocationId.trim(),
          ));
        }
      }
      if (visit.row?.timelinePayload
          case ChatCharactersMovedPayloadVm previous) {
        final retained = previous.movements
            .where((m) => !reported.contains((m.characterId, m.toLocationId)))
            .toList();
        if (retained.length != previous.movements.length) {
          if (retained.isEmpty) {
            visit.row = null;
          } else {
            visit.row!.timelinePayload = ChatCharactersMovedPayloadVm(
              movements: retained,
            );
          }
          changed = true;
        }
      }
      if (!visit.observing) continue;
      final identity = _LocationChatTimelineIdentityIndex.fromState(
        state,
        currentUserIds: const [],
        currentSenderIds: const [],
      );
      final movements = <ChatCharacterMovementVm>[];
      for (final movement in visit.movements.values) {
        if (reported.contains((movement.characterId, movement.toLocationId)) ||
            (movement.oldLocationId != visit.locationId &&
                movement.toLocationId != visit.locationId)) {
          continue;
        }
        movements.add(
          ChatCharacterMovementVm(
            characterId: movement.characterId,
            characterName: identity.characterName(movement.characterId),
            oldLocationId: movement.oldLocationId,
            toLocationId: movement.toLocationId,
            toLocationName: identity.locationName(movement.toLocationId),
            isDestinationCurrentLocation:
                movement.toLocationId == visit.locationId,
          ),
        );
      }
      final payload = movements.isEmpty
          ? null
          : ChatCharactersMovedPayloadVm(movements: movements);
      if (visit.row?.timelinePayload == payload) continue;
      visit.row = payload == null
          ? null
          : ChatMessageVm(
              localId: visit.id,
              senderId: '',
              senderName: '',
              text: '',
              isMe: false,
              status: 'sent',
              senderType: chatroomCharactersMovedSenderType,
              timelinePayload: payload,
              createdAt: visit.createdAt,
            );
      changed = true;
    }
    return changed;
  }

  List<ChatMessageVm> _withPrivateChatReturns(List<ChatMessageVm> source) {
    final rows = _privateChatReturns.where(
      (v) => v.revealed && v.row != null && v.identityIsCurrent(),
    );
    if (rows.isEmpty) return source;
    final result = List<ChatMessageVm>.of(source);
    for (final visit in rows) {
      final anchor = result.indexWhere((m) => m.localId == visit.anchor);
      final next = result.indexWhere(
        (m) => m.createdAt.isAfter(visit.createdAt),
      );
      result.insert(
        anchor >= 0
            ? anchor + 1
            : next >= 0
            ? next
            : result.length,
        visit.row!,
      );
    }
    return result;
  }

  void _finishPrivateChatReturnObservation() {
    for (final visit in _privateChatReturns) {
      if (!visit.observing) continue;
      visit.observing = false;
      visit.closedAt = DateTime.now();
    }
  }
}
