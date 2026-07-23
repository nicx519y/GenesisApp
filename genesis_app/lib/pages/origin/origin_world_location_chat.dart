part of 'origin_world_page.dart';

extension _OriginWorldPageLocationChat on _OriginWorldPageState {
  Widget _buildLocationChatOverlay(OriginDetail origin) {
    final descriptor = _activeChatLocation;
    return Positioned.fill(
      child: LocationChatOverlayTransition(
        active: descriptor != null,
        child: descriptor == null
            ? null
            : GenesisEdgeSwipeBack(
                onBack: _closeLocationChat,
                child: LocationChatPanel(
                  key: ValueKey(
                    'origin-location-chat-${descriptor.locationId}',
                  ),
                  worldId: descriptor.originId,
                  locationId: descriptor.locationId,
                  locationName: descriptor.locationName,
                  backgroundImageUrl: descriptor.backgroundImageUrl,
                  backgroundPreviewImageUrl:
                      descriptor.backgroundPreviewImageUrl,
                  openingPreviewMessages: descriptor.openingPreviewMessages,
                  openingPreviewEntities: descriptor.openingPreviewEntities,
                  isLeafLocation: descriptor.isLeafLocation,
                  active: false,
                  leaveOnInactive: false,
                  showMoreButton: false,
                  onBack: _closeLocationChat,
                  composerReplacement: _OriginLocationChatLaunchBar(
                    launching: _launching,
                    onLaunch: () => _showLaunchRoleSheet(origin),
                  ),
                ),
              ),
      ),
    );
  }
}

class _OriginLocationChatDescriptor {
  const _OriginLocationChatDescriptor({
    required this.originId,
    required this.locationId,
    required this.locationName,
    required this.backgroundImageUrl,
    required this.backgroundPreviewImageUrl,
    required this.isLeafLocation,
    required this.openingPreviewMessages,
    required this.openingPreviewEntities,
  });

  final String originId;
  final String locationId;
  final String locationName;
  final String backgroundImageUrl;
  final String backgroundPreviewImageUrl;
  final bool isLeafLocation;
  final List<WorldChatroomMessage> openingPreviewMessages;
  final List<WorldChatroomEntity> openingPreviewEntities;
}

class _OriginLocationChatLaunchBar extends StatelessWidget {
  const _OriginLocationChatLaunchBar({
    required this.launching,
    required this.onLaunch,
  });

  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final style = kLocationChatStyle;
    final bottomInset = GenesisSafeAreaInsets.bottom(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.composerBackdropBlurSigma,
          sigmaY: style.composerBackdropBlurSigma,
        ),
        child: Container(
          padding: style.composerPadding.copyWith(
            bottom: style.composerPadding.bottom + bottomInset,
          ),
          decoration: BoxDecoration(
            color: style.composerBackgroundGradient == null
                ? style.composerBackgroundColor
                : null,
            gradient: style.composerBackgroundGradient,
          ),
          child: Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.7,
              child: GenesisPrimaryButton(
                label: launching ? 'Launching...' : 'Launch to send',
                onPressed: launching ? null : onLaunch,
                height: style.inputMinHeight,
                borderRadius: BorderRadius.circular(
                  style.systemMessageBorderRadius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginInitialDialoguePreview {
  const _OriginInitialDialoguePreview({
    required this.locationId,
    required this.locationName,
    required this.messages,
  });

  final String locationId;
  final String locationName;
  final List<ChatMessageVm> messages;
}

_OriginInitialDialoguePreview? _originFirstInitialDialoguePreview(
  OriginDetail origin,
) {
  final locationIds = <String>{
    for (final location in origin.allLocations)
      if (location.locationId.trim().isNotEmpty) location.locationId.trim(),
  };
  if (locationIds.isEmpty || origin.ticks.isEmpty) return null;

  final sourceMessages = originLocationOpeningPreviewMessagesForTesting(
    origin.ticks,
    locationIds,
  );
  if (!sourceMessages.any((message) => message.senderType != 'tick')) {
    return null;
  }

  final locationId = sourceMessages
      .map((message) => message.locationId.trim())
      .firstWhere((id) => id.isNotEmpty, orElse: () => '');
  final location = origin.allLocations
      .where((item) => item.locationId.trim() == locationId)
      .firstOrNull;
  final entities = _originLocationOpeningPreviewEntities(
    origin.characters,
    sourceMessages,
    locationId,
  );
  final entitiesById = <String, WorldChatroomEntity>{
    for (final entity in entities) entity.id.trim().toLowerCase(): entity,
  };
  final messages = sourceMessages.indexed
      .map((entry) {
        final index = entry.$1;
        final source = entry.$2;
        final rawSenderType = source.senderType.trim().toLowerCase();
        final senderType = switch (rawSenderType) {
          'ai' => 'character',
          '' => 'user',
          _ => rawSenderType,
        };
        final entity = entitiesById[source.senderId.trim().toLowerCase()];
        final senderName = entity?.name.trim().isNotEmpty == true
            ? entity!.name.trim()
            : source.senderName.trim();
        final currentTime =
            senderType == 'user' ||
                senderType == 'tick' ||
                senderType == 'system'
            ? ''
            : source.currentTime.trim();
        return ChatMessageVm(
          localId: 'origin-initial-dialogue-${source.tickNo}-$index',
          globalMessageId: source.globalMessageId,
          messageId: source.messageId,
          locationMessageId: source.locationMessageId,
          roundId: source.conversationRoundId,
          tickNo: source.tickNo,
          senderId: source.senderId,
          senderName: senderName,
          avatarUrl: entity?.avatarUrl ?? '',
          text: source.content,
          currentTime: currentTime,
          isMe: false,
          status: 'sent',
          senderType: senderType,
          createdAt: source.createdAt,
        );
      })
      .toList(growable: false);

  return _OriginInitialDialoguePreview(
    locationId: locationId,
    locationName: location?.name.trim().isNotEmpty == true
        ? location!.name.trim()
        : locationId,
    messages: messages,
  );
}

Map<String, Map<String, dynamic>> _originLocationsById(
  List<OriginLocation> locations,
) {
  final out = <String, Map<String, dynamic>>{};
  for (final location in locations) {
    final locationId = location.locationId.trim();
    if (locationId.isEmpty) continue;
    out[locationId] = <String, dynamic>{
      'location_name': location.name,
      'name': location.name,
    };
  }
  return out;
}

List<WorldChatroomMessage> _originLocationOpeningPreviewMessages(
  OriginDetail origin,
  Iterable<String> locationIds,
) {
  return originLocationOpeningPreviewMessagesForTesting(
    origin.ticks,
    locationIds,
  );
}

@visibleForTesting
List<WorldChatroomMessage> originLocationOpeningPreviewMessagesForTesting(
  List<Map<String, dynamic>> ticks,
  Iterable<String> locationIds,
) {
  final locationIdSet = locationIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (locationIdSet.isEmpty) return const <WorldChatroomMessage>[];

  final orderedTicks = ticks.toList(growable: false);
  orderedTicks.sort((left, right) {
    final leftTickNo = _mapInt(left, const ['tick_no']);
    final rightTickNo = _mapInt(right, const ['tick_no']);
    if (leftTickNo == 1 && rightTickNo != 1) return -1;
    if (rightTickNo == 1 && leftTickNo != 1) return 1;
    if (leftTickNo != 0 && rightTickNo != 0 && leftTickNo != rightTickNo) {
      return leftTickNo.compareTo(rightTickNo);
    }
    return 0;
  });

  for (final tick in orderedTicks) {
    final tickNo = _mapInt(tick, const ['tick_no']);
    final createdAt = asDateTime(tick['created_at']);
    final result = tick['tick_result'] is Map
        ? (tick['tick_result'] as Map).cast<String, dynamic>()
        : tick;
    final resultCurrentTime = _mapString(result, const [
      'current_time',
      'time',
    ]);
    final currentTime = resultCurrentTime.isNotEmpty
        ? resultCurrentTime
        : _mapString(tick, const ['current_time', 'time']);
    final groupsRaw = result['location_groups'] ?? tick['location_groups'];
    if (groupsRaw is! List) continue;
    for (final rawGroup in groupsRaw.whereType<Map>()) {
      final group = rawGroup.cast<String, dynamic>();
      final groupLocationId = _mapString(group, const [
        'location_id',
        'loc_id',
        'id',
      ]);
      if (!locationIdSet.contains(groupLocationId)) continue;
      final dialogueRaw =
          group['initial_dialogue'] ??
          group['initialDialogue'] ??
          group['dialogue'];
      if (dialogueRaw is! List) continue;
      final messages = <WorldChatroomMessage>[];
      if (tickNo > 0 || currentTime.isNotEmpty) {
        messages.add(
          WorldChatroomMessage(
            messageId: 0,
            conversationRoundId:
                'opening-preview-tick-${tickNo == 0 ? 1 : tickNo}',
            roundOrder: 0,
            tickNo: tickNo == 0 ? 1 : tickNo,
            locationId: groupLocationId,
            senderType: 'tick',
            senderId: 'tick',
            senderName: 'Time',
            content: currentTime,
            createdAt: createdAt,
          ),
        );
      }
      messages.addAll(
        dialogueRaw
            .whereType<Map>()
            .indexed
            .map((entry) {
              final index = entry.$1;
              final line = entry.$2.cast<String, dynamic>();
              final content = _mapString(line, const ['content', 'text']);
              if (content.isEmpty) return null;
              final charId = _mapString(line, const [
                'char_id',
                'character_id',
                'sender_id',
              ]);
              final charName = _mapString(line, const [
                'char_name',
                'name',
                'sender_name',
              ]);
              final senderId = charId.isEmpty
                  ? 'opening-preview-$index'
                  : charId;
              final senderName = charName.isEmpty ? senderId : charName;
              final isNarrator =
                  charId.trim().toLowerCase() == 'nar' &&
                  charName.trim().toLowerCase() == 'narrator';
              return WorldChatroomMessage(
                messageId: 0,
                conversationRoundId: 'opening-preview-$index',
                roundOrder: index,
                tickNo: tickNo == 0 ? 1 : tickNo,
                locationId: groupLocationId,
                senderType: isNarrator ? 'narrator' : 'character',
                senderId: senderId,
                senderName: senderName,
                currentTime: currentTime,
                content: content,
                createdAt:
                    createdAt ?? DateTime.fromMillisecondsSinceEpoch(index),
              );
            })
            .whereType<WorldChatroomMessage>()
            .toList(growable: false),
      );
      return messages;
    }
  }
  return const <WorldChatroomMessage>[];
}

List<WorldChatroomEntity> _originLocationOpeningPreviewEntities(
  List<OriginCharacter> characters,
  List<WorldChatroomMessage> messages,
  String locationId,
) {
  return originLocationOpeningPreviewEntitiesForTesting(
    characters,
    messages,
    locationId,
  );
}

@visibleForTesting
List<WorldChatroomEntity> originLocationOpeningPreviewEntitiesForTesting(
  List<OriginCharacter> characters,
  List<WorldChatroomMessage> messages,
  String locationId,
) {
  final charactersByKey = <String, OriginCharacter>{};
  for (final character in characters) {
    void addKey(String value) {
      final key = value.trim().toLowerCase();
      if (key.isEmpty) return;
      charactersByKey.putIfAbsent(key, () => character);
    }

    addKey(character.characterId);
    if (character.id > 0) addKey('${character.id}');
    addKey(character.name);
  }

  final entities = <WorldChatroomEntity>[];
  final seen = <String>{};
  for (final message in messages) {
    final senderId = message.senderId.trim();
    if (senderId.isEmpty || !seen.add(senderId.toLowerCase())) continue;
    final character =
        charactersByKey[senderId.toLowerCase()] ??
        charactersByKey[message.senderName.trim().toLowerCase()];
    if (character == null) continue;
    entities.add(
      WorldChatroomEntity(
        id: senderId,
        name: message.senderName.trim().isNotEmpty
            ? message.senderName.trim()
            : character.name,
        avatarUrl: _resolveAssetUrl(character.avatar),
        type: WorldChatroomEntityType.character,
        locationId: locationId,
        isAi: true,
      ),
    );
  }
  return entities;
}
