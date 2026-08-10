part of 'location_chat_page.dart';

extension _LocationChatPanelActions on _LocationChatPanelState {
  void _clearUnseenIncomingCount() {
    if (_unseenIncomingCount == 0 || !mounted) return;
    _setLocationChatState(() => _unseenIncomingCount = 0);
  }

  void _openUnseenIncomingMessages() {
    _clearUnseenIncomingCount();
    _scrollCoordinator.requestBottom(
      reason: LocationChatBottomReason.unseenMessageNotice,
      behavior: LocationChatBottomBehavior.jump,
    );
  }

  void _showMessageActionMenu(
    BuildContext menuContext,
    ChatMessageVm message,
    LongPressStartDetails details,
  ) {
    final items = <GenesisActionMenuItem>[
      GenesisActionMenuItem(
        label: 'Copy',
        iconData: Icons.copy_outlined,
        onSelected: () => _copyMessageText(message),
      ),
      if (!message.isMe)
        GenesisActionMenuItem(
          label: 'Report',
          iconAsset: genesisReportIconAsset,
          onSelected: () {
            showGenesisReportDialog(
              context: context,
              targetType: 'message',
              targetId: _messageReportTargetId(message),
            );
          },
        ),
    ];
    showGenesisActionMenuAt(
      context: menuContext,
      globalPosition: details.globalPosition,
      items: items,
      appearance: GenesisActionMenuAppearance.message,
    );
  }

  Future<void> _copyMessageText(ChatMessageVm message) async {
    final text = message.isTick ? _tickReportText(message) : message.text;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showGenesisToast(context, 'Copied');
  }

  String _messageReportTargetId(ChatMessageVm message) {
    return locationChatMessageReportTargetIdForTesting(message);
  }

  String _tickReportText(ChatMessageVm message) {
    final tick = message.tickNo > 0
        ? 'Tick ${message.tickNo}${message.subTickNo > 0 ? '-${message.subTickNo}' : ''}'
        : 'Tick';
    final text = message.text.trim();
    return text.isEmpty ? tick : '$tick · $text';
  }

  List<WorldChatroomEntity> _realUsersForCurrentLocation(
    WorldChatroomState state,
  ) {
    final locationIds = _currentLocationIds();
    final users = <WorldChatroomEntity>[];
    final seen = <String>{};

    void addUser(WorldChatroomEntity entity) {
      if (!_isRealUserEntity(entity)) return;
      final key = _realUserDedupKey(entity);
      if (key.isEmpty || !seen.add(key)) return;
      users.add(entity);
    }

    for (final locationId in locationIds) {
      for (final entity
          in state.entitiesByLocation[locationId] ??
              const <WorldChatroomEntity>[]) {
        addUser(entity);
      }
    }

    if (state.joinedLocationId == widget.locationId) {
      final selfId = firstNonEmpty([_myUserId, _mySenderId]);
      final selfName = _localSelfDisplayName();
      if (selfId.isNotEmpty || selfName.isNotEmpty) {
        addUser(
          WorldChatroomEntity(
            id: selfId.isEmpty ? selfName : selfId,
            name: selfName,
            avatarUrl: _localSelfAvatarUrl(),
            type: WorldChatroomEntityType.player,
            locationId: widget.locationId,
            isAi: false,
          ),
        );
      }
    }

    return users;
  }

  List<String> _currentLocationIds() {
    final seen = <String>{};
    final ids = <String>[];
    void add(String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty || !seen.add(trimmed)) return;
      ids.add(trimmed);
    }

    add(widget.locationId);
    for (final locationId in widget.localMessageLocationIds) {
      add(locationId);
    }
    return ids;
  }

  bool _isRealUserEntity(WorldChatroomEntity entity) {
    return !entity.isAi;
  }

  String _realUserDedupKey(WorldChatroomEntity entity) {
    final idKey = _chatroomIdentityKey(entity.id);
    if (idKey.isNotEmpty) return 'id:$idKey';
    final nameKey = entity.name.trim().toLowerCase();
    return nameKey.isEmpty ? '' : 'name:$nameKey';
  }
}
