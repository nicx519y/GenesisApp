part of 'origin_world_page.dart';

class _OriginSetupRoleSection extends StatefulWidget {
  const _OriginSetupRoleSection({
    super.key,
    required this.scrollController,
    required this.characters,
    required this.roleAvatarSnapshots,
    required this.launchBusy,
    required this.launching,
    required this.profileRole,
    required this.selectedRoleId,
    required this.onSelectedRoleChanged,
    required this.onSelectRole,
    required this.onSelectProfileRole,
    required this.onRoleEditingChanged,
  });

  static const double _cardWidth = 240;
  static const double _buttonHeight = 93;
  static const double _toggleAreaHeight = 48;

  final ScrollController scrollController;
  final List<OriginCharacter> characters;
  final OriginRoleAvatarSnapshotStore roleAvatarSnapshots;
  final bool launchBusy;
  final bool launching;
  final OriginCustomRoleDraft? profileRole;
  final String selectedRoleId;
  final ValueChanged<String> onSelectedRoleChanged;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final Future<void> Function(OriginCustomRoleDraft role) onSelectProfileRole;
  final ValueChanged<bool> onRoleEditingChanged;

  @override
  State<_OriginSetupRoleSection> createState() =>
      _OriginSetupRoleSectionState();
}

class _OriginSetupRoleSectionState extends State<_OriginSetupRoleSection> {
  PageController? _cardsController;
  final Set<String> _preloadedAvatarKeys = <String>{};
  var _currentCardIndex = 0;
  var _viewportFraction = 1.0;
  var _roleEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheUpcomingRoleAvatars(_currentCardIndex);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final nextViewportFraction = viewportWidth <= 0
        ? 1.0
        : ((_OriginSetupRoleSection._cardWidth + 12) / viewportWidth)
              .clamp(0.0, 1.0)
              .toDouble();
    if (_cardsController != null &&
        (_viewportFraction - nextViewportFraction).abs() < 0.001) {
      return;
    }
    final initialPage = _selectedCardIndex;
    _cardsController?.dispose();
    _viewportFraction = nextViewportFraction;
    _currentCardIndex = initialPage;
    _cardsController = PageController(
      initialPage: initialPage,
      viewportFraction: nextViewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant _OriginSetupRoleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _selectedCardIndex;
    _currentCardIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _cardsController;
      if (controller != null && controller.hasClients) {
        final currentPage = controller.page?.round() ?? controller.initialPage;
        if (currentPage != nextIndex) controller.jumpToPage(nextIndex);
      }
      _precacheUpcomingRoleAvatars(nextIndex);
    });
  }

  List<String> get _roleIds => <String>[
    if (widget.profileRole != null)
      _OriginWorldPageState._profileLocationChatRoleId,
    for (final character in originCharactersRecommendedFirst(widget.characters))
      if (_characterStableId(character).isNotEmpty)
        _characterStableId(character),
  ];

  int get _cardCount => _roleIds.length;

  int get _selectedCardIndex {
    final roleIds = _roleIds;
    if (roleIds.isEmpty) return 0;
    final selectedIndex = roleIds.indexOf(widget.selectedRoleId);
    return selectedIndex < 0 ? 0 : selectedIndex;
  }

  @override
  void dispose() {
    _cardsController?.dispose();
    super.dispose();
  }

  void _handleCardChanged(int nextIndex) {
    final roleIds = _roleIds;
    if (!mounted || nextIndex < 0 || nextIndex >= roleIds.length) return;
    if (_roleEditing || widget.launchBusy) {
      final selectedIndex = _selectedCardIndex;
      if (nextIndex != selectedIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final controller = _cardsController;
          if (!mounted || controller == null || !controller.hasClients) return;
          controller.jumpToPage(selectedIndex);
        });
      }
      return;
    }
    if (_currentCardIndex != nextIndex) {
      setState(() => _currentCardIndex = nextIndex);
    }
    _precacheUpcomingRoleAvatars(nextIndex);
    final roleId = roleIds[nextIndex];
    if (widget.selectedRoleId ==
            _OriginWorldPageState._profileLocationChatRoleId &&
        widget.profileRole == null) {
      return;
    }
    if (roleId != widget.selectedRoleId) {
      widget.onSelectedRoleChanged(roleId);
    }
  }

  void _centerCard(int index) {
    if (_roleEditing || widget.launchBusy) return;
    final controller = _cardsController;
    if (controller == null || !controller.hasClients) return;
    unawaited(
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _handleRoleEditingChanged(bool editing) {
    if (_roleEditing != editing && mounted) {
      setState(() {
        _roleEditing = editing;
        if (editing) _currentCardIndex = _selectedCardIndex;
      });
    }
    widget.onRoleEditingChanged(editing);
  }

  void _precacheUpcomingRoleAvatars(int currentIndex) {
    if (!mounted) return;
    final avatarSourceKeys = <String>[
      if (widget.profileRole case final profileRole?)
        _resolveAssetUrl(profileRole.avatarUrl).trim(),
      ...originCharactersRecommendedFirst(widget.characters)
          .where((character) => _characterStableId(character).isNotEmpty)
          .map((character) => _resolveAssetUrl(character.avatar).trim()),
    ];
    if (avatarSourceKeys.isEmpty || currentIndex >= avatarSourceKeys.length) {
      return;
    }

    final devicePixelRatio = genesisImageDevicePixelRatio(
      MediaQuery.devicePixelRatioOf(context),
      maxDevicePixelRatio: originWorldOpeningRoleAvatarMaxDevicePixelRatio,
    );
    final decodeSize = (_OriginSetupRoleSection._cardWidth * devicePixelRatio)
        .ceil();
    final snapshotSize = math.max(
      1,
      (_originLocationChatRolePillAvatarSize * devicePixelRatio).ceil(),
    );
    final lastIndex = math.min(currentIndex + 2, avatarSourceKeys.length - 1);
    for (var index = currentIndex; index <= lastIndex; index += 1) {
      final avatarSourceKey = avatarSourceKeys[index];
      final avatarUrl = _originRoleCardAvatarUrl(context, avatarSourceKey);
      if (avatarUrl.isEmpty) continue;
      final cacheKey = '$avatarUrl@$decodeSize';
      if (!_preloadedAvatarKeys.add(cacheKey)) continue;

      final provider = OriginRolePortraitImageProvider.fromUrl(
        imageUrl: avatarUrl,
        outputSize: decodeSize,
        snapshotStore: widget.roleAvatarSnapshots,
        snapshotSourceKey: avatarSourceKey,
        snapshotSize: snapshotSize,
      );
      unawaited(
        precacheImage(
          provider,
          context,
          onError: (error, stackTrace) {
            _preloadedAvatarKeys.remove(cacheKey);
            debugPrint(
              '[OriginWorldPage] role avatar decode precache failed '
              'url="$avatarUrl": $error',
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = _OriginSetupRoleSection._cardWidth;
    final characters = originCharactersRecommendedFirst(widget.characters)
        .where((character) => _characterStableId(character).isNotEmpty)
        .toList(growable: false);
    final profileRole = widget.profileRole;
    final profileCardCount = profileRole == null ? 0 : 1;
    final cardCount = _cardCount;
    if (cardCount == 0) return const SizedBox.shrink();
    final currentCardIndex = _currentCardIndex.clamp(0, cardCount - 1);
    final cardsController = _cardsController;
    if (cardsController == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Text(
              'Select Your Role',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: originWorldDetailSheetPrimaryTextColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: cardWidth + _OriginSetupRoleSection._buttonHeight,
            child: PageView.builder(
              key: const ValueKey<String>('origin-setup-role-cards'),
              controller: cardsController,
              scrollDirection: Axis.horizontal,
              physics: _roleEditing || widget.launchBusy
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(parent: BouncingScrollPhysics()),
              padEnds: true,
              allowImplicitScrolling: true,
              onPageChanged: _handleCardChanged,
              itemCount: cardCount,
              itemBuilder: (context, index) {
                final selected = index == currentCardIndex;
                if (profileRole != null && index == 0) {
                  return Center(
                    child: SizedBox(
                      width: cardWidth,
                      child: GestureDetector(
                        key: const ValueKey<String>(
                          'origin-setup-role-page-current-user',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: selected ? null : () => _centerCard(index),
                        child: IgnorePointer(
                          ignoring: !selected,
                          child: _OriginSetupRoleCard(
                            content: _OriginSetupRoleCardContent.fromProfile(
                              profileRole,
                            ),
                            roleAvatarSnapshots: widget.roleAvatarSnapshots,
                            selected: selected,
                            cardWidth: cardWidth,
                            buttonHeight: _OriginSetupRoleSection._buttonHeight,
                            busy: widget.launchBusy,
                            launching: widget.launching,
                            revealScrollController: widget.scrollController,
                            editableRole: profileRole,
                            onEditingChanged: _handleRoleEditingChanged,
                            onSelectEditedRole: (role) =>
                                unawaited(widget.onSelectProfileRole(role)),
                            onSelect: () => unawaited(
                              widget.onSelectProfileRole(profileRole),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final characterIndex = index - profileCardCount;
                final character = characters[characterIndex];
                final stableId = _characterStableId(character);
                return Center(
                  child: SizedBox(
                    width: cardWidth,
                    child: GestureDetector(
                      key: ValueKey<String>('origin-setup-role-page-$stableId'),
                      behavior: HitTestBehavior.opaque,
                      onTap: selected ? null : () => _centerCard(index),
                      child: IgnorePointer(
                        ignoring: !selected,
                        child: _OriginSetupRoleCard(
                          content: _OriginSetupRoleCardContent.fromCharacter(
                            character,
                          ),
                          roleAvatarSnapshots: widget.roleAvatarSnapshots,
                          selected: selected,
                          cardWidth: cardWidth,
                          buttonHeight: _OriginSetupRoleSection._buttonHeight,
                          busy: widget.launchBusy,
                          launching: widget.launching,
                          onSelect: () =>
                              unawaited(widget.onSelectRole(character)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _OriginRoleCardsIndicator(
            count: cardCount,
            currentIndex: currentCardIndex,
          ),
        ],
      ),
    );
  }
}

String _limitOriginProfileRoleField(String value, int maxLength) {
  final characters = value.characters;
  if (characters.length <= maxLength) return value;
  return characters.take(maxLength).toString();
}

class _OriginRoleCardsIndicator extends StatelessWidget {
  const _OriginRoleCardsIndicator({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey<String>('origin-setup-role-page-indicator'),
      label: '${currentIndex + 1} of $count role cards',
      child: Row(
        key: ValueKey<String>(
          'origin-setup-role-page-current-${currentIndex + 1}-of-$count',
        ),
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(count, (index) {
          final selected = index == currentIndex;
          return AnimatedContainer(
            key: ValueKey<String>('origin-setup-role-page-dot-$index'),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: selected ? 8 : 6,
            height: selected ? 8 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? GenesisColors.brand
                  : originWorldDetailSheetInactiveIndicatorColor,
            ),
          );
        }),
      ),
    );
  }
}

@immutable
class _OriginSetupRoleCardContent {
  const _OriginSetupRoleCardContent({
    required this.stableId,
    required this.name,
    required this.avatar,
    required this.identity,
    required this.personality,
    required this.goal,
    required this.isRecommended,
    required this.isProfile,
  });

  factory _OriginSetupRoleCardContent.fromCharacter(OriginCharacter character) {
    return _OriginSetupRoleCardContent(
      stableId: _characterStableId(character),
      name: character.name,
      avatar: character.avatar,
      identity: character.tags,
      personality: character.tagline,
      goal: character.goal,
      isRecommended: character.isRecommended,
      isProfile: false,
    );
  }

  factory _OriginSetupRoleCardContent.fromProfile(
    OriginCustomRoleDraft profileRole,
  ) {
    return _OriginSetupRoleCardContent(
      stableId: 'current-user',
      name: profileRole.name,
      avatar: profileRole.avatarUrl,
      identity: profileRole.identity,
      personality: profileRole.personality.trim().isNotEmpty
          ? profileRole.personality
          : profileRole.bio,
      goal: '',
      isRecommended: false,
      isProfile: true,
    );
  }

  final String stableId;
  final String name;
  final String avatar;
  final String identity;
  final String personality;
  final String goal;
  final bool isRecommended;
  final bool isProfile;
}

class _OriginSetupRoleCard extends StatefulWidget {
  const _OriginSetupRoleCard({
    required this.content,
    required this.roleAvatarSnapshots,
    required this.selected,
    required this.cardWidth,
    required this.buttonHeight,
    required this.busy,
    required this.launching,
    required this.onSelect,
    this.revealScrollController,
    this.editableRole,
    this.onEditingChanged,
    this.onSelectEditedRole,
  });

  final _OriginSetupRoleCardContent content;
  final OriginRoleAvatarSnapshotStore roleAvatarSnapshots;
  final bool selected;
  final double cardWidth;
  final double buttonHeight;
  final bool busy;
  final bool launching;
  final VoidCallback onSelect;
  final ScrollController? revealScrollController;
  final OriginCustomRoleDraft? editableRole;
  final ValueChanged<bool>? onEditingChanged;
  final ValueChanged<OriginCustomRoleDraft>? onSelectEditedRole;

  @override
  State<_OriginSetupRoleCard> createState() => _OriginSetupRoleCardState();
}

class _OriginSetupRoleCardState extends State<_OriginSetupRoleCard> {
  final ScrollController _detailsController = ScrollController(
    keepScrollOffset: false,
  );
  final GlobalKey _cardPositionKey = GlobalKey();
  late final OriginCharacterForm? _editForm;
  var _showDetails = false;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _editForm = widget.editableRole == null
        ? null
        : OriginCharacterForm.empty(charId: 'current_user_custom_role');
    _editForm?.addListener(_handleEditFormChanged);
    _seedEditForm();
  }

  @override
  void didUpdateWidget(covariant _OriginSetupRoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.editableRole != widget.editableRole) {
      _seedEditForm();
    }
  }

  void _handleEditFormChanged() {
    if (mounted && _editing) setState(() {});
  }

  void _setEditFieldText(
    TextEditingController controller,
    String text, {
    bool showFromStart = false,
  }) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: showFromStart ? 0 : text.length,
      ),
    );
  }

  void _seedEditForm() {
    final form = _editForm;
    final role = widget.editableRole;
    if (form == null || role == null) return;
    _setEditFieldText(form.avatarUrl, role.avatarUrl.trim());
    _setEditFieldText(
      form.name,
      _limitOriginProfileRoleField(
        role.name.trim(),
        originCharacterNameMaxLength,
      ),
    );
    _setEditFieldText(
      form.identity,
      _limitOriginProfileRoleField(
        role.identity.trim(),
        originCharacterIdentityMaxLength,
      ),
      showFromStart: true,
    );
    _setEditFieldText(
      form.personality,
      _limitOriginProfileRoleField(
        role.personality.trim().isNotEmpty
            ? role.personality.trim()
            : role.bio.trim(),
        originCharacterPersonalityMaxLength,
      ),
      showFromStart: true,
    );
  }

  void _toggleEditing() {
    if (widget.busy || _editForm == null) return;
    if (_editing) {
      _closeEditing();
      return;
    }

    _seedEditForm();
    setState(() {
      _showDetails = false;
      _editing = true;
    });
    widget.onEditingChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final form = _editForm;
      if (!mounted || !_editing) return;
      _positionEditingCard();
      form.name.selection = TextSelection.collapsed(
        offset: form.name.text.length,
      );
      form.focusNodes.name.requestFocus();
    });
  }

  void _positionEditingCard() {
    final scrollController = widget.revealScrollController;
    final cardContext = _cardPositionKey.currentContext;
    final renderObject = cardContext?.findRenderObject();
    if (scrollController == null ||
        !scrollController.hasClients ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return;
    }
    final desiredTop =
        originWorldDetailExpandedSheetTopFor(
          topSafeArea: MediaQuery.paddingOf(context).top,
        ) +
        56;
    final cardTop = renderObject.localToGlobal(Offset.zero).dy;
    final position = scrollController.position;
    final target = (position.pixels + cardTop - desiredTop)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    position.jumpTo(target);
  }

  void _closeEditing() {
    if (!_editing) return;
    FocusScope.of(context).unfocus();
    _seedEditForm();
    setState(() => _editing = false);
    widget.onEditingChanged?.call(false);
  }

  void _handleSelect() {
    if (!_editing) {
      widget.onSelect();
      return;
    }

    final form = _editForm;
    final onSelectEditedRole = widget.onSelectEditedRole;
    if (form == null || onSelectEditedRole == null) return;
    if (form.name.text.trim().isEmpty) {
      showGenesisToast(context, 'Please enter a name');
      return;
    }
    if (form.identity.text.trim().isEmpty) {
      showGenesisToast(context, 'Please enter an identity');
      return;
    }
    FocusScope.of(context).unfocus();
    onSelectEditedRole(
      OriginCustomRoleDraft(
        avatarUrl: form.avatarUrl.text,
        name: form.name.text,
        identity: form.identity.text,
        personality: form.personality.text,
      ),
    );
  }

  void _toggleDetails() {
    final showDetails = !_showDetails;
    setState(() => _showDetails = showDetails);
    if (!showDetails) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_detailsController.hasClients) return;
      _detailsController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _editForm
      ?..removeListener(_handleEditFormChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final cardWidth = widget.cardWidth;
    final buttonHeight = widget.buttonHeight;
    final stableId = content.stableId;
    final topLabel = content.isProfile
        ? 'Your Profile'
        : content.isRecommended
        ? 'Originator Suggested'
        : null;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        key: ValueKey<String>('origin-setup-role-card-frame-$stableId'),
        decoration: BoxDecoration(
          color: const Color(0xFF202022),
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: widget.selected
                ? GenesisColors.brand
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: cardWidth,
          height: cardWidth + buttonHeight,
          child: Stack(
            children: [
              if (_editForm != null)
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: cardWidth + _OriginSetupRoleSection._toggleAreaHeight,
                  child: Offstage(
                    offstage: !_editing,
                    child: _OriginSetupRoleInlineEditor(
                      key: ValueKey<String>(
                        'origin-setup-role-inline-editor-$stableId',
                      ),
                      form: _editForm,
                      stableId: stableId,
                      launching: widget.busy,
                      onChanged: _handleEditFormChanged,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: cardWidth,
                child: Offstage(
                  offstage: _editing,
                  child: _OriginSetupRolePreview(
                    content: content,
                    roleAvatarSnapshots: widget.roleAvatarSnapshots,
                    cardWidth: cardWidth,
                    showDetails: _showDetails,
                    detailsController: _detailsController,
                    topLabel: topLabel,
                    onToggleDetails: _toggleDetails,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                key: ValueKey<String>('origin-setup-role-action-bar-$stableId'),
                height: _editing
                    ? buttonHeight - _OriginSetupRoleSection._toggleAreaHeight
                    : buttonHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      key: ValueKey<String>(
                        'origin-setup-role-action-background-$stableId',
                      ),
                      decoration: const BoxDecoration(
                        color: originWorldDetailSheetBackgroundColor,
                      ),
                    ),
                    Column(
                      children: [
                        if (!_editing)
                          SizedBox(
                            height: _OriginSetupRoleSection._toggleAreaHeight,
                            child: GestureDetector(
                              key: ValueKey<String>(
                                'origin-setup-role-toggle-$stableId',
                              ),
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleDetails,
                              child: Center(
                                child: Icon(
                                  _showDetails
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  key: ValueKey<String>(
                                    _showDetails
                                        ? 'origin-setup-role-arrow-up-$stableId'
                                        : 'origin-setup-role-arrow-down-$stableId',
                                  ),
                                  size: 32,
                                  color: const Color(0xFF999999),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: TextFieldTapRegion(
                              groupId: createFormTextFieldTapRegionGroup,
                              child: Row(
                                children: [
                                  if (_editForm != null) ...[
                                    SizedBox.square(
                                      dimension: 35,
                                      child: Material(
                                        key: ValueKey<String>(
                                          'origin-setup-role-edit-surface-$stableId',
                                        ),
                                        color: const Color(0x667A7A7A),
                                        borderRadius: BorderRadius.circular(8),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          key: ValueKey<String>(
                                            'origin-setup-role-edit-$stableId',
                                          ),
                                          onTap: widget.busy
                                              ? null
                                              : _toggleEditing,
                                          child: Icon(
                                            _editing
                                                ? Icons.close_rounded
                                                : Icons.edit_rounded,
                                            key: ValueKey<String>(
                                              _editing
                                                  ? 'origin-setup-role-edit-close-icon-$stableId'
                                                  : 'origin-setup-role-edit-icon-$stableId',
                                            ),
                                            size: 18,
                                            color: Colors.white.withValues(
                                              alpha: widget.busy ? 0.6 : 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Material(
                                      key: ValueKey<String>(
                                        'origin-setup-role-select-surface-$stableId',
                                      ),
                                      color: const Color(0x667A7A7A),
                                      borderRadius: BorderRadius.circular(8),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        key: ValueKey<String>(
                                          'origin-setup-role-$stableId',
                                        ),
                                        onTap: widget.busy
                                            ? null
                                            : _handleSelect,
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (content.isRecommended) ...[
                                                OriginRecommendedRoleMark(
                                                  badgeKey: ValueKey<String>(
                                                    'origin-setup-role-recommended-$stableId',
                                                  ),
                                                  showBackground: true,
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  widget.launching
                                                      ? 'Launching...'
                                                      : 'Select to Launch',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    height: 1,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: widget.busy
                                                              ? 0.6
                                                              : 1,
                                                        ),
                                                    decoration:
                                                        TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return TapRegion(
      enabled: _editing,
      consumeOutsideTaps: _editing,
      onTapOutside: (_) => _closeEditing(),
      child: KeyedSubtree(key: _cardPositionKey, child: card),
    );
  }
}

class _OriginSetupRoleInlineEditor extends StatelessWidget {
  const _OriginSetupRoleInlineEditor({
    super.key,
    required this.form,
    required this.stableId,
    required this.launching,
    required this.onChanged,
  });

  final OriginCharacterForm form;
  final String stableId;
  final bool launching;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: originWorldDetailSheetBackgroundColor,
      child: AbsorbPointer(
        absorbing: launching,
        child: SingleChildScrollView(
          key: ValueKey<String>(
            'origin-setup-role-inline-editor-scroll-$stableId',
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CreateUploadBox(
                  key: ValueKey<String>(
                    'origin-setup-role-inline-avatar-$stableId',
                  ),
                  controller: form.avatarUrl,
                  label: 'AVATAR\n(Optional)',
                  onChanged: onChanged,
                  width: 104,
                  height: 104,
                  iconSize: 38,
                  borderRadius: GenesisAvatarRadii.character,
                  cropSize: originCharacterAvatarUploadSize,
                  maxOutputSize: originCharacterAvatarUploadSize,
                  previewAlignment: Alignment.topCenter,
                  showRemoveLinkWhenFilled: true,
                  emptyLabelFontWeight: FontWeight.w600,
                  emptyIconLabelGap: 4,
                  emptyBackgroundColor: originWorldDetailSheetBackgroundColor,
                  emptyBorderColor: originWorldDetailSheetTertiaryTextColor,
                  emptyIconColor: GenesisColors.createAdd,
                  emptyLabelColor: originWorldDetailSheetTertiaryTextColor,
                  previewMaxDevicePixelRatio:
                      originWorldOpeningRoleAvatarMaxDevicePixelRatio,
                ),
              ),
              const SizedBox(height: 10),
              _OriginSetupRoleInlineField(
                fieldKey: ValueKey<String>(
                  'origin-setup-role-inline-name-$stableId',
                ),
                tapTargetKey: ValueKey<String>(
                  'origin-setup-role-inline-name-tap-$stableId',
                ),
                label: 'Name',
                controller: form.name,
                focusNode: form.focusNodes.name,
                nextFocusNode: form.focusNodes.identity,
                maxLength: originCharacterNameMaxLength,
                showLabel: false,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                verticalTapPadding: 8,
                onChanged: onChanged,
              ),
              const SizedBox(height: 8),
              _OriginSetupRoleInlineField(
                fieldKey: ValueKey<String>(
                  'origin-setup-role-inline-identity-$stableId',
                ),
                tapTargetKey: ValueKey<String>(
                  'origin-setup-role-inline-identity-tap-$stableId',
                ),
                label: 'Identity *',
                controller: form.identity,
                focusNode: form.focusNodes.identity,
                nextFocusNode: form.focusNodes.personality,
                maxLength: originCharacterIdentityMaxLength,
                maxLines: 2,
                onChanged: onChanged,
              ),
              const SizedBox(height: 8),
              _OriginSetupRoleInlineField(
                fieldKey: ValueKey<String>(
                  'origin-setup-role-inline-brief-$stableId',
                ),
                tapTargetKey: ValueKey<String>(
                  'origin-setup-role-inline-brief-tap-$stableId',
                ),
                label: 'Personality (Optional)',
                controller: form.personality,
                focusNode: form.focusNodes.personality,
                maxLength: originCharacterPersonalityMaxLength,
                maxLines: 2,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginSetupRoleInlineField extends StatelessWidget {
  const _OriginSetupRoleInlineField({
    required this.fieldKey,
    required this.tapTargetKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.onChanged,
    this.nextFocusNode,
    this.maxLines = 1,
    this.showLabel = true,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w400,
    this.verticalTapPadding = 0,
  });

  final Key fieldKey;
  final Key tapTargetKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final int maxLength;
  final int maxLines;
  final bool showLabel;
  final double fontSize;
  final FontWeight fontWeight;
  final double verticalTapPadding;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateKeyboardSafeFocusRegion(
      focusNode: focusNode,
      visibilityAxis: Axis.vertical,
      builder: (context, resolvedFocusNode) => TextFieldTapRegion(
        groupId: createFormTextFieldTapRegionGroup,
        child: GestureDetector(
          key: tapTargetKey,
          behavior: HitTestBehavior.opaque,
          onTap: resolvedFocusNode.requestFocus,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: verticalTapPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLabel) ...[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0x99FFFFFF),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                TextField(
                  key: fieldKey,
                  groupId: createFormTextFieldTapRegionGroup,
                  controller: controller,
                  focusNode: resolvedFocusNode,
                  maxLength: maxLength,
                  minLines: maxLines,
                  maxLines: maxLines,
                  keyboardType: maxLines > 1
                      ? TextInputType.multiline
                      : TextInputType.text,
                  textInputAction: nextFocusNode == null
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onEditingComplete: () {
                    final next = nextFocusNode;
                    if (next == null) {
                      resolvedFocusNode.unfocus();
                    } else {
                      next.requestFocus();
                    }
                  },
                  onChanged: (_) => onChanged(),
                  cursorColor: originWorldDetailSheetPrimaryTextColor,
                  scrollPadding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    kMinInteractiveDimension,
                  ),
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.25,
                    fontWeight: fontWeight,
                    color: originWorldDetailSheetPrimaryTextColor,
                    decoration: TextDecoration.none,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginSetupRolePreview extends StatelessWidget {
  const _OriginSetupRolePreview({
    required this.content,
    required this.roleAvatarSnapshots,
    required this.cardWidth,
    required this.showDetails,
    required this.detailsController,
    required this.topLabel,
    required this.onToggleDetails,
  });

  final _OriginSetupRoleCardContent content;
  final OriginRoleAvatarSnapshotStore roleAvatarSnapshots;
  final double cardWidth;
  final bool showDetails;
  final ScrollController detailsController;
  final String? topLabel;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final stableId = content.stableId;
    final resolvedTopLabel = topLabel;
    final avatarUrl = _originRoleCardAvatarUrl(
      context,
      _resolveAssetUrl(content.avatar),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: ValueKey<String>('origin-setup-role-card-body-toggle-$stableId'),
          behavior: HitTestBehavior.opaque,
          onTap: onToggleDetails,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: showDetails
                ? _OriginSetupRoleDetails(
                    key: ValueKey<String>(
                      'origin-setup-role-details-$stableId',
                    ),
                    content: content,
                    controller: detailsController,
                  )
                : _OriginSetupRolePortrait(
                    key: ValueKey<String>(
                      'origin-setup-role-portrait-$stableId',
                    ),
                    content: content,
                    roleAvatarSnapshots: roleAvatarSnapshots,
                    avatarUrl: avatarUrl,
                    cardWidth: cardWidth,
                  ),
          ),
        ),
        if (resolvedTopLabel != null && !showDetails)
          Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(
              child: Container(
                key: ValueKey<String>(
                  content.isProfile
                      ? 'origin-setup-role-profile-label'
                      : 'origin-setup-role-suggested-label-$stableId',
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  resolvedTopLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OriginSetupRolePortrait extends StatelessWidget {
  const _OriginSetupRolePortrait({
    super.key,
    required this.content,
    required this.roleAvatarSnapshots,
    required this.avatarUrl,
    required this.cardWidth,
  });

  final _OriginSetupRoleCardContent content;
  final OriginRoleAvatarSnapshotStore roleAvatarSnapshots;
  final String avatarUrl;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _OriginSetupRoleImage(
          url: avatarUrl,
          snapshotSourceKey: _resolveAssetUrl(content.avatar).trim(),
          snapshotStore: roleAvatarSnapshots,
          name: content.name,
          width: cardWidth,
          height: cardWidth,
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              if (content.identity.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  content.identity.trim(),
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                    color: Color(0xE6FFFFFF),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginSetupRoleDetails extends StatelessWidget {
  const _OriginSetupRoleDetails({
    super.key,
    required this.content,
    required this.controller,
  });

  final _OriginSetupRoleCardContent content;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        key: ValueKey<String>(
          'origin-setup-role-details-background-${content.stableId}',
        ),
        color: originWorldDetailSheetBackgroundColor,
        child: SingleChildScrollView(
          key: ValueKey<String>(
            'origin-setup-role-details-scroll-${content.stableId}',
          ),
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.name.trim().isEmpty ? '—' : content.name.trim(),
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              _OriginSetupRoleDetailField(
                label: 'Identity',
                value: content.identity,
              ),
              _OriginSetupRoleDetailField(
                label: 'Personality',
                value: content.personality,
                addBottomGap: !content.isProfile,
              ),
              if (!content.isProfile) ...[
                _OriginSetupRoleDetailField(
                  label: 'Goal',
                  value: content.goal,
                  addBottomGap: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginSetupRoleDetailField extends StatelessWidget {
  const _OriginSetupRoleDetailField({
    required this.label,
    required this.value,
    this.addBottomGap = true,
  });

  final String label;
  final String value;
  final bool addBottomGap;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(bottom: addBottomGap ? 14 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0x99FFFFFF),
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayValue,
              softWrap: true,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginSetupRoleImage extends StatelessWidget {
  const _OriginSetupRoleImage({
    required this.url,
    required this.snapshotSourceKey,
    required this.snapshotStore,
    required this.name,
    required this.width,
    required this.height,
  });

  final String url;
  final String snapshotSourceKey;
  final OriginRoleAvatarSnapshotStore snapshotStore;
  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = Stack(
      fit: StackFit.expand,
      children: [
        GenesisAvatarFallback(
          name: name,
          width: width,
          height: height,
          borderRadius: 0,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: originRolePortraitGradient),
        ),
      ],
    );
    if (url.isEmpty) return fallback;
    final devicePixelRatio = genesisImageDevicePixelRatio(
      MediaQuery.devicePixelRatioOf(context),
      maxDevicePixelRatio: originWorldOpeningRoleAvatarMaxDevicePixelRatio,
    );
    final outputSize = (math.max(width, height) * devicePixelRatio).ceil();
    final snapshotSize = math.max(
      1,
      (_originLocationChatRolePillAvatarSize * devicePixelRatio).ceil(),
    );
    return Image(
      image: OriginRolePortraitImageProvider.fromUrl(
        imageUrl: url,
        outputSize: outputSize,
        snapshotStore: snapshotStore,
        snapshotSourceKey: snapshotSourceKey,
        snapshotSize: snapshotSize,
      ),
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return ColoredBox(
          color: const Color(0xFF202022),
          child: SizedBox(width: width, height: height),
        );
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
