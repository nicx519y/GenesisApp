part of 'origin_world_page.dart';

extension _OriginWorldPageLocationChat on _OriginWorldPageState {
  void _handleCurrentTilemapLocationsChanged(
    String _,
    Set<String> locationIds,
  ) {
    _currentTilemapLocationIds = Set<String>.unmodifiable(locationIds);
    _preloadCurrentTilemapLocationBackgrounds(_origin);
  }

  void _preloadCurrentTilemapLocationBackgrounds(OriginDetail? origin) {
    if (origin == null || _currentTilemapLocationIds.isEmpty) return;
    _locationChatBackgroundPreloader.preload(
      _currentTilemapLocationIds.map((locationId) {
        final location = origin.processedLocationTree
            .nodeById(locationId)
            ?.value;
        if (location == null) return '';
        final xlUrl = location.imageResource.xlUrl.trim();
        return _resolveAssetUrl(xlUrl.isNotEmpty ? xlUrl : location.icon);
      }),
    );
  }

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
                  composerReplacement: _OriginLocationChatLaunchComposer(
                    key: ValueKey(
                      'origin-location-chat-composer-${descriptor.locationId}',
                    ),
                    launching: _launching,
                    role: _locationChatRoleOption(origin),
                    onSelectRole: () => _selectLocationChatRole(origin),
                    onSend: (message) => _launchLocationChatMessage(
                      origin,
                      locationId: descriptor.locationId,
                      message: message,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  _OriginLocationChatRoleOption _locationChatRoleOption(OriginDetail origin) {
    final selectedId = _selectedLocationChatRoleId;
    if (selectedId != _OriginWorldPageState._profileLocationChatRoleId) {
      for (final character in origin.characters) {
        if (_characterStableId(character) == selectedId) {
          return _OriginLocationChatRoleOption(
            id: selectedId,
            name: character.name.trim().isEmpty
                ? selectedId
                : character.name.trim(),
            subtitle: character.identity.trim(),
            avatarUrl: _resolveAssetUrl(character.avatar),
          );
        }
      }
    }
    final profileRole = _cachedProfileRole;
    return _OriginLocationChatRoleOption(
      id: _OriginWorldPageState._profileLocationChatRoleId,
      name: 'Your Profile',
      subtitle: profileRole?.name.trim() ?? '',
      avatarUrl: profileRole == null
          ? ''
          : _resolveAssetUrl(profileRole.avatarUrl),
    );
  }

  List<_OriginLocationChatRoleOption> _locationChatRoleOptions(
    OriginDetail origin,
  ) {
    final profileRole = _cachedProfileRole;
    return <_OriginLocationChatRoleOption>[
      _OriginLocationChatRoleOption(
        id: _OriginWorldPageState._profileLocationChatRoleId,
        name: 'Your Profile',
        subtitle: profileRole?.name.trim() ?? '',
        avatarUrl: profileRole == null
            ? ''
            : _resolveAssetUrl(profileRole.avatarUrl),
      ),
      for (final character in originCharactersRecommendedFirst(
        origin.characters,
      ))
        if (_characterStableId(character).isNotEmpty)
          _OriginLocationChatRoleOption(
            id: _characterStableId(character),
            name: character.name.trim().isEmpty
                ? _characterStableId(character)
                : character.name.trim(),
            subtitle: character.identity.trim(),
            avatarUrl: _resolveAssetUrl(character.avatar),
          ),
    ];
  }

  Future<void> _selectLocationChatRole(OriginDetail origin) async {
    if (_launching) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final roleId = await showGenesisModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OriginLocationChatRolePicker(
        roles: _locationChatRoleOptions(origin),
        selectedRoleId: _locationChatRoleOption(origin).id,
      ),
    );
    if (!mounted || roleId == null || roleId == _selectedLocationChatRoleId) {
      return;
    }
    _setLocationChatRoleId(roleId);
  }

  Future<void> _launchLocationChatMessage(
    OriginDetail origin, {
    required String locationId,
    required String message,
  }) async {
    if (_launching || message.trim().isEmpty) return;
    if (!await ensureGenesisLogin(context) || !mounted) return;

    final selectedRoleId = _selectedLocationChatRoleId;
    OriginRoleLaunchSelection roleSelection;
    String telemetryRoleId;
    if (selectedRoleId == _OriginWorldPageState._profileLocationChatRoleId) {
      final profileRole = await _customRoleFromProfile();
      if (!mounted || profileRole == null) return;
      roleSelection = OriginRoleLaunchSelection.custom(profileRole);
      telemetryRoleId = 'current_user';
    } else {
      final character = origin.characters
          .where((character) => _characterStableId(character) == selectedRoleId)
          .firstOrNull;
      if (character == null) {
        showGenesisToast(context, 'This role is no longer available');
        _setLocationChatRoleId(
          _OriginWorldPageState._profileLocationChatRoleId,
        );
        return;
      }
      final characterId = _characterStableId(character);
      roleSelection = OriginRoleLaunchSelection.preset(characterId);
      telemetryRoleId = characterId;
    }

    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_setup_role_launch',
      object1: origin.oid,
      object2: telemetryRoleId,
    );
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_launch_opening',
      object1: origin.oid,
    );
    await _launchOrigin(
      origin,
      roleSelection,
      initialLocationId: locationId,
      initialMessageToSend: message,
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

class _OriginLocationChatLaunchComposer extends StatefulWidget {
  const _OriginLocationChatLaunchComposer({
    super.key,
    required this.launching,
    required this.role,
    required this.onSelectRole,
    required this.onSend,
  });

  final bool launching;
  final _OriginLocationChatRoleOption role;
  final VoidCallback onSelectRole;
  final Future<void> Function(String message) onSend;

  @override
  State<_OriginLocationChatLaunchComposer> createState() =>
      _OriginLocationChatLaunchComposerState();
}

class _OriginLocationChatLaunchComposerState
    extends State<_OriginLocationChatLaunchComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (_hasText == hasText) return;
    setState(() => _hasText = hasText);
  }

  Future<void> _send() async {
    final message = _controller.text;
    if (widget.launching || message.trim().isEmpty) return;
    _focusNode.unfocus();
    await widget.onSend(message);
  }

  @override
  Widget build(BuildContext context) {
    return ChatComposer(
      controller: _controller,
      focusNode: _focusNode,
      hintText: 'Text...',
      inputEnabled: !widget.launching,
      sendEnabled: !widget.launching && _hasText,
      sending: widget.launching,
      onSend: _send,
      composerHeader: _OriginLocationChatRoleSelector(
        role: widget.role,
        enabled: !widget.launching,
        onTap: widget.onSelectRole,
      ),
      sendIcon: ChatComposerSendIcon.arrowUp,
      style: kLocationChatStyle,
    );
  }
}

@immutable
class _OriginLocationChatRoleOption {
  const _OriginLocationChatRoleOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String subtitle;
  final String avatarUrl;
}

class _OriginLocationChatRoleSelector extends StatelessWidget {
  const _OriginLocationChatRoleSelector({
    required this.role,
    required this.enabled,
    required this.onTap,
  });

  final _OriginLocationChatRoleOption role;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Select Your Role',
      child: InkWell(
        key: const ValueKey<String>('origin-location-chat-role-selector'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GenesisCharacterAvatar(
                url: role.avatarUrl,
                name: role.name,
                size: 22,
                borderRadius: 6,
                showFallbackWhileLoading: true,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  role.name,
                  key: const ValueKey<String>(
                    'origin-location-chat-role-label',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF4F3F6),
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: Color(0x99FFFFFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginLocationChatRolePicker extends StatelessWidget {
  const _OriginLocationChatRolePicker({
    required this.roles,
    required this.selectedRoleId,
  });

  final List<_OriginLocationChatRoleOption> roles;
  final String selectedRoleId;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;
    return Container(
      key: const ValueKey<String>('origin-location-chat-role-picker'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: GenesisColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: GenesisColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                'Select Your Role',
                style: GenesisTypography.pageTitle,
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final role = roles[index];
                  final selected = role.id == selectedRoleId;
                  return InkWell(
                    key: ValueKey<String>(
                      'origin-location-chat-role-option-${role.id}',
                    ),
                    onTap: () => Navigator.of(context).pop(role.id),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? GenesisColors.surfacePanel
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? GenesisColors.borderStrong
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          GenesisCharacterAvatar(
                            url: role.avatarUrl,
                            name: role.name,
                            size: 42,
                            borderRadius: 11,
                            showFallbackWhileLoading: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  role.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GenesisTypography.bodyStrong,
                                ),
                                if (role.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    role.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GenesisTypography.supporting,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 22,
                            color: selected
                                ? GenesisColors.textPrimary
                                : GenesisColors.borderStrong,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
  if (locationIds.isEmpty) return null;

  final sourceMessages = _originLocationOpeningPreviewMessages(
    origin,
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
          imageUrl: senderType == 'image' ? source.content : '',
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
  final initLocationGroup = origin.initLocationGroup;
  if (initLocationGroup != null) {
    final messages = originInitialLocationGroupPreviewMessagesForTesting(
      initLocationGroup,
      locationIds,
      createdAt: origin.createdAt,
    );
    if (messages.isNotEmpty) return messages;
  }
  return originLocationOpeningPreviewMessagesForTesting(
    origin.ticks,
    locationIds,
  );
}

@visibleForTesting
List<WorldChatroomMessage> originOpeningPreviewMessagesForTesting(
  OriginDetail origin,
  Iterable<String> locationIds,
) {
  return _originLocationOpeningPreviewMessages(origin, locationIds);
}

@visibleForTesting
List<WorldChatroomMessage> originInitialLocationGroupPreviewMessagesForTesting(
  OriginInitLocationGroup group,
  Iterable<String> locationIds, {
  DateTime? createdAt,
}) {
  return originLocationOpeningPreviewMessagesForTesting(<Map<String, dynamic>>[
    <String, dynamic>{
      'tick_no': 0,
      'created_at': createdAt,
      'tick_result': <String, dynamic>{
        'location_groups': <Map<String, dynamic>>[
          <String, dynamic>{
            'location_id': group.locationId,
            'initial_dialogue': <Map<String, dynamic>>[
              for (final line in group.initialDialogue)
                <String, dynamic>{
                  'char_id': line.charId,
                  'char_name': line.charName,
                  'content': line.content,
                },
            ],
          },
        ],
      },
    },
  ], locationIds);
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
              final normalizedCharId = charId.trim().toLowerCase();
              final isNarrator = normalizedCharId == 'nar';
              final isImage =
                  normalizedCharId == 'nar_pic' || normalizedCharId == 'image';
              return WorldChatroomMessage(
                messageId: 0,
                conversationRoundId: 'opening-preview-$index',
                roundOrder: index,
                tickNo: tickNo == 0 ? 1 : tickNo,
                locationId: groupLocationId,
                senderType: isImage
                    ? 'image'
                    : isNarrator
                    ? 'narrator'
                    : 'character',
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
