part of 'origin_world_page.dart';

ChatUiStyleConfig get _originDetailSheetChatComposerStyle =>
    kLocationChatStyle.copyWith(
      composerBackgroundColor: originWorldDetailSheetBackgroundColor,
      clearComposerBackgroundGradient: true,
      composerBackdropBlurSigma: 0,
      composerSendButtonColor: GenesisColors.surface,
      composerSendButtonDisabledColor: GenesisColors.surfaceMuted,
      composerSendButtonIconColor: GenesisColors.textPrimary,
      composerSendButtonBackdropBlurSigma: 0,
      inputBackgroundColor: GenesisColors.surface,
      inputBackdropBlurSigma: 0,
      inputTextStyle: kLocationChatStyle.inputTextStyle.copyWith(
        color: GenesisColors.textPrimary,
      ),
    );

ChatUiStyleConfig get _originLocationChatLaunchComposerStyle =>
    kLocationChatStyle.copyWith(
      composerBackgroundColor: Colors.transparent,
      clearComposerBackgroundGradient: true,
    );

const double _originLocationChatRolePillAvatarSize = 22;
const double _originLocationChatRolePillHeight =
    _originLocationChatRolePillAvatarSize + 12;
const double _originLocationChatRoleInputGap = 4;
const double _originLocationChatDockRoleOffsetY = -2;

String _originLaunchChatLocationId(OriginDetail origin) {
  final previewLocationId =
      _originFirstInitialDialoguePreview(origin)?.locationId.trim() ?? '';
  if (previewLocationId.isNotEmpty) return previewLocationId;

  final initLocationId = origin.initLocationGroup?.locationId.trim() ?? '';
  if (initLocationId.isNotEmpty) return initLocationId;

  for (final character in origin.characters) {
    final initialLocationId = character.initialLocationBusinessId.trim();
    if (initialLocationId.isNotEmpty) return initialLocationId;
  }
  for (final location in origin.allLocations) {
    final locationId = location.locationId.trim();
    if (locationId.isNotEmpty && location.locations.isEmpty) {
      return locationId;
    }
  }
  for (final location in origin.allLocations) {
    final locationId = location.locationId.trim();
    if (locationId.isNotEmpty) return locationId;
  }
  return '';
}

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
    final launchComposerStyle = _originLocationChatLaunchComposerStyle;
    final launchRole = _locationChatRoleOption(origin);
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
                  composerTopOverlay: _OriginLocationChatRoleRegion(
                    role: launchRole,
                    enabled: !_launching,
                    onTap: () => _selectLocationChatRole(origin),
                    style: launchComposerStyle,
                    foregroundColor: const Color(0xFFF4F3F6),
                    mutedColor: const Color(0x99FFFFFF),
                    backgroundColor: launchComposerStyle.inputBackgroundColor,
                  ),
                  composerReplacement: _OriginLocationChatLaunchComposer(
                    key: ValueKey(
                      'origin-location-chat-composer-${descriptor.locationId}',
                    ),
                    launching: _launching,
                    role: launchRole,
                    onSelectRole: () => _selectLocationChatRole(origin),
                    style: launchComposerStyle,
                    showRoleSelector: false,
                    roleBackgroundColor:
                        launchComposerStyle.inputBackgroundColor,
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
    final profileName = profileRole?.name.trim() ?? '';
    return _OriginLocationChatRoleOption(
      id: _OriginWorldPageState._profileLocationChatRoleId,
      name: profileName.isEmpty ? 'Your Profile' : profileName,
      subtitle: profileRole?.identity.trim() ?? '',
      avatarUrl: profileRole == null
          ? ''
          : _resolveAssetUrl(profileRole.avatarUrl),
    );
  }

  List<_OriginLocationChatRoleOption> _locationChatRoleOptions(
    OriginDetail origin,
  ) {
    final profileRole = _cachedProfileRole;
    final profileName = profileRole?.name.trim() ?? '';
    return <_OriginLocationChatRoleOption>[
      _OriginLocationChatRoleOption(
        id: _OriginWorldPageState._profileLocationChatRoleId,
        name: profileName.isEmpty ? 'Your Profile' : profileName,
        subtitle: profileRole?.identity.trim() ?? '',
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
    final roles = _locationChatRoleOptions(origin);
    final roleId = await showGenesisModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OriginLocationChatRolePicker(
        roles: roles,
        selectedRoleId: _locationChatRoleOption(origin).id,
        onSelectRole: _precacheLocationChatRolePillAvatar,
      ),
    );
    if (!mounted || roleId == null || roleId == _selectedLocationChatRoleId) {
      return;
    }
    final selectedRole = roles.where((role) => role.id == roleId).firstOrNull;
    if (selectedRole != null) {
      await _precacheLocationChatRolePillAvatar(selectedRole);
    }
    if (!mounted) return;
    _setLocationChatRoleId(roleId);
  }

  Future<void> _precacheLocationChatRolePillAvatar(
    _OriginLocationChatRoleOption role,
  ) async {
    if (!mounted || role.avatarUrl.trim().isEmpty) return;
    final rawDevicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final resolvedUrl = selectGenesisImageUrl(
      role.avatarUrl,
      logicalWidth: _originLocationChatRolePillAvatarSize,
      logicalHeight: _originLocationChatRolePillAvatarSize,
      devicePixelRatio: rawDevicePixelRatio,
    ).trim();
    if (resolvedUrl.isEmpty) return;
    final ImageProvider<Object> provider;
    if (resolvedUrl.startsWith('assets/')) {
      provider = AssetImage(resolvedUrl);
    } else {
      final devicePixelRatio = genesisImageDevicePixelRatio(
        rawDevicePixelRatio,
      );
      final decodeSize = math.max(
        1,
        (_originLocationChatRolePillAvatarSize * devicePixelRatio).ceil(),
      );
      provider = GenesisStaticNetworkImageProvider(
        imageUrl: resolvedUrl,
        cacheWidth: decodeSize,
        cacheHeight: decodeSize,
        fit: BoxFit.cover,
      );
    }
    try {
      await precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {
          debugPrint(
            '[OriginWorldPage] role pill avatar precache failed '
            'url="$resolvedUrl": $error',
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[OriginWorldPage] role pill avatar precache failed '
        'url="$resolvedUrl": $error\n$stackTrace',
      );
    }
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
    this.style,
    this.inputDockBackgroundColor,
    this.showRoleSelector = true,
    this.roleForegroundColor = const Color(0xFFF4F3F6),
    this.roleMutedColor = const Color(0x99FFFFFF),
    this.roleBackgroundColor = const Color(0xCC151517),
    this.onInputDockHeightChanged,
    this.onHeightChanged,
  });

  final bool launching;
  final _OriginLocationChatRoleOption role;
  final VoidCallback onSelectRole;
  final Future<void> Function(String message) onSend;
  final ChatUiStyleConfig? style;
  final Color? inputDockBackgroundColor;
  final bool showRoleSelector;
  final Color roleForegroundColor;
  final Color roleMutedColor;
  final Color roleBackgroundColor;
  final ValueChanged<double>? onInputDockHeightChanged;
  final ValueChanged<double>? onHeightChanged;

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
    final style = widget.style ?? kLocationChatStyle;
    final inputDockBackgroundColor = widget.inputDockBackgroundColor;
    final composerStyle = style.copyWith(
      composerBackgroundColor:
          inputDockBackgroundColor ?? style.composerBackgroundColor,
      clearComposerBackgroundGradient: inputDockBackgroundColor != null,
      composerPadding: style.composerPadding.copyWith(
        top: _originLocationChatRoleInputGap,
      ),
    );
    final composer = ChatComposer(
      controller: _controller,
      focusNode: _focusNode,
      hintText: 'Text...',
      inputEnabled: !widget.launching,
      sendEnabled: !widget.launching && _hasText,
      sending: widget.launching,
      onSend: _send,
      onHeightChanged: widget.onInputDockHeightChanged,
      composerHeader: null,
      sendIcon: ChatComposerSendIcon.arrowUp,
      style: composerStyle,
    );
    final Widget content;
    if (!widget.showRoleSelector) {
      content = composer;
    } else {
      final roleRegion = _OriginLocationChatRoleRegion(
        role: widget.role,
        enabled: !widget.launching,
        onTap: widget.onSelectRole,
        style: style,
        foregroundColor: widget.roleForegroundColor,
        mutedColor: widget.roleMutedColor,
        backgroundColor: widget.roleBackgroundColor,
      );
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [roleRegion, composer],
      );
    }
    final onHeightChanged = widget.onHeightChanged;
    if (onHeightChanged == null) return content;
    return _OriginLocationChatComposerHeightObserver(
      onHeightChanged: onHeightChanged,
      child: content,
    );
  }
}

class _OriginLocationChatComposerHeightObserver extends StatefulWidget {
  const _OriginLocationChatComposerHeightObserver({
    required this.child,
    required this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double> onHeightChanged;

  @override
  State<_OriginLocationChatComposerHeightObserver> createState() =>
      _OriginLocationChatComposerHeightObserverState();
}

class _OriginLocationChatComposerHeightObserverState
    extends State<_OriginLocationChatComposerHeightObserver> {
  double? _lastHeight;
  var _reportScheduled = false;

  void _scheduleReport() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      final height = context.size?.height;
      if (height == null || height <= 0 || height == _lastHeight) return;
      _lastHeight = height;
      widget.onHeightChanged(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReport();
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

class _OriginLocationChatRoleRegion extends StatelessWidget {
  const _OriginLocationChatRoleRegion({
    required this.role,
    required this.enabled,
    required this.onTap,
    required this.style,
    required this.foregroundColor,
    required this.mutedColor,
    required this.backgroundColor,
  });

  final _OriginLocationChatRoleOption role;
  final bool enabled;
  final VoidCallback onTap;
  final ChatUiStyleConfig style;
  final Color foregroundColor;
  final Color mutedColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final roleSelector = _OriginLocationChatRoleSelector(
      role: role,
      enabled: enabled,
      onTap: onTap,
      foregroundColor: foregroundColor,
      mutedColor: mutedColor,
      backgroundColor: backgroundColor,
      backdropBlurSigma: style.inputBackdropBlurSigma,
    );
    return ColoredBox(
      key: const ValueKey<String>('origin-location-chat-role-region'),
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          left: style.composerPadding.left,
          top: style.composerPadding.top,
          right: style.composerPadding.right,
        ),
        child: Transform.translate(
          key: const ValueKey<String>(
            'origin-location-chat-dock-role-translation',
          ),
          offset: const Offset(0, _originLocationChatDockRoleOffsetY),
          child: roleSelector,
        ),
      ),
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
    required this.foregroundColor,
    required this.mutedColor,
    required this.backgroundColor,
    required this.backdropBlurSigma,
  });

  final _OriginLocationChatRoleOption role;
  final bool enabled;
  final VoidCallback onTap;
  final Color foregroundColor;
  final Color mutedColor;
  final Color backgroundColor;
  final double backdropBlurSigma;

  @override
  Widget build(BuildContext context) {
    final pill = Material(
      key: const ValueKey<String>('origin-location-chat-role-pill'),
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey<String>('origin-location-chat-role-selector'),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GenesisCharacterAvatar(
                url: role.avatarUrl,
                name: role.name,
                size: _originLocationChatRolePillAvatarSize,
                borderRadius: 6,
                showFallbackWhileLoading: false,
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
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: 'Select Your Role',
      child: backdropBlurSigma <= 0
          ? pill
          : ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                key: const ValueKey<String>(
                  'origin-location-chat-role-pill-backdrop',
                ),
                filterConfig: ImageFilterConfig.blur(
                  sigmaX: backdropBlurSigma,
                  sigmaY: backdropBlurSigma,
                  bounded: false,
                ),
                child: pill,
              ),
            ),
    );
  }
}

class _OriginLocationChatRolePicker extends StatefulWidget {
  const _OriginLocationChatRolePicker({
    required this.roles,
    required this.selectedRoleId,
    required this.onSelectRole,
  });

  final List<_OriginLocationChatRoleOption> roles;
  final String selectedRoleId;
  final Future<void> Function(_OriginLocationChatRoleOption role) onSelectRole;

  @override
  State<_OriginLocationChatRolePicker> createState() =>
      _OriginLocationChatRolePickerState();
}

class _OriginLocationChatRolePickerState
    extends State<_OriginLocationChatRolePicker> {
  static const Duration _selectionFeedbackDuration = Duration(
    milliseconds: 180,
  );

  late String _selectedRoleId;
  bool _selectionPending = false;

  @override
  void initState() {
    super.initState();
    _selectedRoleId = widget.selectedRoleId;
  }

  Future<void> _selectRole(_OriginLocationChatRoleOption role) async {
    if (_selectionPending) return;
    setState(() {
      _selectedRoleId = role.id;
      _selectionPending = true;
    });
    await Future.wait<void>([
      widget.onSelectRole(role),
      Future<void>.delayed(_selectionFeedbackDuration),
    ]);
    if (mounted) Navigator.of(context).pop(role.id);
  }

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
                itemCount: widget.roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final role = widget.roles[index];
                  final selected = role.id == _selectedRoleId;
                  final deselectingPreviousRole =
                      _selectionPending &&
                      role.id == widget.selectedRoleId &&
                      !selected;
                  return InkWell(
                    key: ValueKey<String>(
                      'origin-location-chat-role-option-${role.id}',
                    ),
                    onTap: _selectionPending ? null : () => _selectRole(role),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      key: ValueKey<String>(
                        'origin-location-chat-role-option-surface-${role.id}',
                      ),
                      duration: deselectingPreviousRole
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
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
                            key: ValueKey<String>(
                              'origin-location-chat-role-option-indicator-'
                              '${role.id}',
                            ),
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
