part of 'location_chat_page.dart';

/// Display-only Tick placement and local content projection.
extension _LocationChatTickProjection on _LocationChatWorldHistory {
  /// A broadcast is not a visit. Keep it pending until actual dialogue or
  /// an entry row establishes that location's next chronological segment.
  List<ChatMessageVm> _placeTicksInLocationSegments(
    List<ChatMessageVm> source,
  ) {
    // Old HTTP/realtime rows can omit conversation metadata. Their explicit
    // conversational type still establishes a segment; missing metadata must
    // never delete a previously visible conversation.
    bool isAnchor(ChatMessageVm m) =>
        !m.isTick &&
        !m.isAiContentDisclaimer &&
        !m.isStoryEvents &&
        !m.isCharactersMoved &&
        (m.isUserEnterLocation ||
            m.isMe ||
            const {'user', 'character', 'narrator'}.contains(m.senderType) ||
            m.isImage);
    String? active;
    final pending = <String, List<ChatMessageVm>>{};
    final result = <ChatMessageVm>[];
    List<ChatMessageVm> arrivalContext(String location) {
      final waiting = pending.remove(location) ?? const <ChatMessageVm>[];
      final lastTick = waiting
          .where(
            (m) => m.isTick && m.timelinePayload is! ChatTickProgressPayloadVm,
          )
          .lastOrNull;
      if (lastTick == null) return waiting;
      // Arriving reveals the current Tick, not an entire backlog of events
      // that happened while away. Those remain available in World Events.
      return waiting
          .where(
            (m) =>
                (m.tickNo == lastTick.tickNo &&
                    m.subTickNo == lastTick.subTickNo) ||
                m.timelinePayload is ChatTickProgressPayloadVm,
          )
          .toList();
    }

    for (final message in source) {
      final location = locationFor(message);
      if (message.isTick ||
          message.isStoryEvents ||
          message.isCharactersMoved) {
        if (location == active) {
          result.add(message);
        } else {
          (pending[location] ??= []).add(message);
        }
        continue;
      }
      if (isAnchor(message) && location != active) {
        active = location;
        // Pre-existing Tick context belongs above the fresh entry viewport.
        result.addAll(arrivalContext(location));
        result.add(message);
      } else {
        result.add(message);
      }
    }
    // Entering the joined room is authoritative even before its entry response
    // arrives. Never flush broadcasts from another room merely for existing.
    if (active != owner.widget.locationId) {
      result.addAll(arrivalContext(owner.widget.locationId));
    }
    return result;
  }

  List<ChatMessageVm> _projectTicks(
    List<ChatMessageVm> source, {
    Map<String, int>? chronology,
    List<ChatMessageVm>? tickSnapshots,
  }) {
    final order =
        chronology ??
        {for (var i = 0; i < source.length; i++) source[i].localId: i};
    ChatMessageVm? latestSnapshot(Iterable<ChatMessageVm> versions) {
      ChatMessageVm? latest;
      for (final version in versions) {
        if (latest == null ||
            (order[version.localId] ?? -1) >= (order[latest.localId] ?? -1)) {
          latest = version;
        }
      }
      return latest;
    }

    Object? worldTickKey(ChatMessageVm m) {
      if (!m.isTick || m.timelinePayload is ChatTickProgressPayloadVm) {
        return null;
      }
      if (m.tickNo >= 0) return (m.tickNo, m.subTickNo);
      if (m.timelinePayload == null && m.text.trim().isEmpty) return null;
      return (m.timelinePayload, m.text.trim(), m.currentTime);
    }

    final groups = <Object, List<ChatMessageVm>>{};
    final globals = <Object, List<ChatMessageVm>>{};
    for (final m in source) {
      final tick = worldTickKey(m);
      if (tick == null) continue;
      (groups[(tick, locationFor(m))] ??= []).add(m);
      final p = m.timelinePayload;
      if (p is ChatTickPayloadVm) (globals[tick] ??= []).add(m);
    }
    // Movements are Tick-level events. A room's latest text snapshot may
    // omit them, and the emitting room need not have a visited segment.
    // Gather event identities from the original full Tick replicas without
    // introducing any new room segments or duplicating their story content.
    final tickMovements = <Object, Map<Object, ChatCharacterMovementVm>>{};
    for (final snapshot in tickSnapshots ?? source) {
      final tick = worldTickKey(snapshot);
      final payload = snapshot.timelinePayload;
      if (tick == null ||
          payload is! ChatTickPayloadVm ||
          payload.isMalformed) {
        continue;
      }
      for (final movement
          in payload.charactersMoved?.movements ??
              const <ChatCharacterMovementVm>[]) {
        (tickMovements[tick] ??= {})[(
              movement.characterId,
              movement.oldLocationId,
              movement.toLocationId,
            )] =
            movement;
      }
    }
    final emitted = <Object>{};
    final emittedGlobal = <Object>{};
    final result = <ChatMessageVm>[];
    for (final m in source) {
      final tick = worldTickKey(m);
      if (tick == null) {
        result.add(m);
        continue;
      }
      final location = locationFor(m);
      final key = (tick, location);
      if (!emitted.add(key)) continue;
      final showGlobal = emittedGlobal.add(tick);
      // A full Tick identity is (tickNo, subTickNo). Distinct sub-ticks
      // carry new events/times and must stay in their chronological positions.
      // Replicas of that exact identity are snapshots, not extra paragraphs.
      final globalMessage = latestSnapshot(
        (globals[tick] ?? []).where((c) {
          final p = c.timelinePayload as ChatTickPayloadVm;
          return !p.isMalformed && (p.hasGlobal || p.globalStatuses.isNotEmpty);
        }),
      );
      final globalPayloads = showGlobal && globalMessage != null
          ? [globalMessage.timelinePayload as ChatTickPayloadVm]
          : const <ChatTickPayloadVm>[];
      final versions = groups[key]!;
      final latest =
          latestSnapshot(
            versions.where((c) {
              final p = c.timelinePayload;
              return p is ChatTickPayloadVm &&
                  !p.isMalformed &&
                  (p.hasStructuredSections ||
                      p.fallbackContent.trim().isNotEmpty);
            }),
          ) ??
          latestSnapshot(versions)!;
      final copies = [latest];
      final relevantMovements =
          (tickMovements[tick]?.values ?? const <ChatCharacterMovementVm>[])
              .where(
                (move) =>
                    move.oldLocationId == location ||
                    move.toLocationId == location,
              )
              .toList();
      final signature = Object.hash(
        m.localId,
        Object.hashAll(relevantMovements),
        showGlobal,
        Object.hashAll(globalPayloads),
        Object.hashAll(
          copies.map(
            (c) => (
              c.localId,
              c.timelinePayload,
              c.text,
              c.currentTime,
              c.subTickNo,
            ),
          ),
        ),
      );
      final cached = _mergedTicks[key];
      if (cached != null && cached.$1 == signature) {
        result.add(cached.$2);
        continue;
      }
      final payloads = copies
          .map((c) => c.timelinePayload)
          .whereType<ChatTickPayloadVm>()
          .toList();
      String normalized(String text) =>
          text.trim().replaceAll(RegExp(r'\s+'), ' ');
      // sourceIndex and resolved display metadata are not event identities.
      // Keep place/time in the key so distinct events remain distinct.
      final paragraphsByContent = <Object, ChatStoryEventParagraphVm>{};
      for (final p in payloads) {
        for (final paragraph
            in p.storyEvents?.paragraphs ??
                const <ChatStoryEventParagraphVm>[]) {
          if (paragraph.locationId.isNotEmpty &&
              paragraph.locationId != location) {
            continue;
          }
          final roles = paragraph.visibleRoles.map((r) => r.roleId).toList()
            ..sort();
          final key = (
            paragraph.locationId,
            normalized(paragraph.timestamp),
            normalized(paragraph.text),
            normalized(paragraph.clue),
            paragraph.visibilityLabel,
            Object.hashAll(roles),
          );
          final existing = paragraphsByContent[key];
          paragraphsByContent[key] = existing == null
              ? paragraph
              : ChatStoryEventParagraphVm(
                  timestamp: existing.timestamp,
                  text: existing.text,
                  clue: existing.clue,
                  visibilityLabel: existing.visibilityLabel,
                  visibleRoles: existing.visibleRoles,
                  locationId: existing.locationId,
                  locationName: existing.locationName,
                  sourceIndex: existing.sourceIndex,
                  statuses: {
                    ...existing.statuses,
                    ...paragraph.statuses,
                  }.toList(),
                );
        }
      }
      final paragraphs = paragraphsByContent.values.toList();
      // Legacy/plain tick contributions must remain visible even when another
      // copy supplies structured sections (the renderer otherwise hides fallback).
      final visibleText = <String>{
        for (final p in payloads)
          if (p.globalText.trim().isNotEmpty) normalized(p.globalText),
        for (final p in paragraphs) normalized(p.text),
      };
      for (final copy in copies) {
        final payload = copy.timelinePayload;
        final fallback = payload is ChatTickPayloadVm
            ? (payload.hasStructuredSections ? '' : payload.fallbackContent)
            : copy.text;
        if (fallback.trim().isEmpty || !visibleText.add(normalized(fallback))) {
          continue;
        }
        final locationId = locationFor(copy);
        paragraphs.add(
          ChatStoryEventParagraphVm(
            timestamp: '',
            text: fallback.trim(),
            clue: '',
            visibilityLabel: '',
            locationId: locationId,
            locationName:
                owner
                    ._mentionCatalogForState(owner._chatroomState)
                    .locations
                    .where((l) => l.id == locationId)
                    .firstOrNull
                    ?.name ??
                '',
            sourceIndex: paragraphs.length,
          ),
        );
      }
      final movements = [
        for (final move in relevantMovements)
          ChatCharacterMovementVm(
            characterId: move.characterId,
            characterName: move.characterName,
            oldLocationId: move.oldLocationId,
            toLocationId: move.toLocationId,
            toLocationName: move.toLocationName,
            isDestinationCurrentLocation: move.toLocationId == location,
          ),
      ];
      final merged = freezeLocationChatReplyMessage(m);
      merged.subTickNo = latest.subTickNo;
      merged.currentTime = latest.currentTime;
      final projectedPayload = ChatTickPayloadVm(
        globalText: globalPayloads
            .map((p) => p.globalText.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .join('\n\n'),
        globalStatuses: {
          for (final p in globalPayloads) ...p.globalStatuses,
        }.toList(),
        storyEvents: paragraphs.isEmpty
            ? null
            : ChatStoryEventsPayloadVm(
                locationId: location,
                locationName: paragraphs.first.locationName,
                paragraphs: paragraphs,
              ),
        charactersMoved: movements.isEmpty
            ? null
            : ChatCharactersMovedPayloadVm(movements: movements),
        isMalformed: false,
      );
      if (!projectedPayload.hasStructuredSections) continue;
      merged.timelinePayload = projectedPayload;
      merged.text = projectedPayload.copyText;
      _mergedTicks[key] = (signature, merged);
      result.add(merged);
    }
    _mergedTicks.removeWhere((key, _) => !groups.containsKey(key));
    return result;
  }
}
