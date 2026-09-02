part of 'origin_world_page.dart';

class _OriginSetupRoleSection extends StatefulWidget {
  const _OriginSetupRoleSection({
    required this.scrollController,
    required this.characters,
    required this.launching,
    required this.profileRole,
    required this.onSelectRole,
    required this.onSelectEditedPresetRole,
    required this.onSelectProfileRole,
    required this.onRoleEditingChanged,
  });

  static const double _cardWidth = 240;
  static const double _buttonHeight = 93;
  static const double _toggleAreaHeight = 48;

  final ScrollController scrollController;
  final List<OriginCharacter> characters;
  final bool launching;
  final OriginCustomRoleDraft? profileRole;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final Future<void> Function(
    OriginCharacter character,
    OriginPresetRoleOverride roleOverride,
  )
  onSelectEditedPresetRole;
  final Future<void> Function(OriginCustomRoleDraft role) onSelectProfileRole;
  final ValueChanged<bool> onRoleEditingChanged;

  @override
  State<_OriginSetupRoleSection> createState() =>
      _OriginSetupRoleSectionState();
}

class _OriginSetupRoleSectionState extends State<_OriginSetupRoleSection> {
  final ScrollController _cardsController = ScrollController();
  final ValueNotifier<int> _currentCardIndex = ValueNotifier<int>(0);
  final Set<String> _preloadedAvatarKeys = <String>{};
  var _cardStride = 1.0;

  @override
  void initState() {
    super.initState();
    _cardsController.addListener(_handleCardsScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheUpcomingRoleAvatars(_currentCardIndex.value);
    });
  }

  @override
  void didUpdateWidget(covariant _OriginSetupRoleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastIndex = _cardCount - 1;
    if (lastIndex < 0) {
      _currentCardIndex.value = 0;
    } else if (_currentCardIndex.value > lastIndex) {
      _currentCardIndex.value = lastIndex;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheUpcomingRoleAvatars(_currentCardIndex.value);
    });
  }

  int get _cardCount =>
      widget.characters.length + (widget.profileRole == null ? 0 : 1);

  @override
  void dispose() {
    _cardsController.removeListener(_handleCardsScroll);
    _cardsController.dispose();
    _currentCardIndex.dispose();
    super.dispose();
  }

  void _handleCardsScroll() {
    if (!_cardsController.hasClients || _cardStride <= 0) return;
    final cardCount = _cardCount;
    if (cardCount <= 0) return;
    final nextIndex = (_cardsController.offset / _cardStride).round().clamp(
      0,
      cardCount - 1,
    );
    if (nextIndex == _currentCardIndex.value || !mounted) return;
    _currentCardIndex.value = nextIndex;
    _precacheUpcomingRoleAvatars(nextIndex);
  }

  void _precacheUpcomingRoleAvatars(int currentIndex) {
    if (!mounted) return;
    final avatarSources = <String>[
      if (widget.profileRole case final profileRole?) profileRole.avatarUrl,
      ...originCharactersRecommendedFirst(
        widget.characters,
      ).map((character) => character.avatar),
    ];
    if (avatarSources.isEmpty || currentIndex >= avatarSources.length) return;

    final devicePixelRatio = genesisImageDevicePixelRatio(
      MediaQuery.devicePixelRatioOf(context),
      maxDevicePixelRatio: originWorldOpeningRoleAvatarMaxDevicePixelRatio,
    );
    final decodeSize = (_OriginSetupRoleSection._cardWidth * devicePixelRatio)
        .ceil();
    final lastIndex = math.min(currentIndex + 2, avatarSources.length - 1);
    for (var index = currentIndex; index <= lastIndex; index += 1) {
      final avatarUrl = _originRoleCardAvatarUrl(
        context,
        _resolveAssetUrl(avatarSources[index]),
      );
      if (avatarUrl.isEmpty) continue;
      final cacheKey = '$avatarUrl@$decodeSize';
      if (!_preloadedAvatarKeys.add(cacheKey)) continue;

      final provider = OriginRolePortraitImageProvider.fromUrl(
        imageUrl: avatarUrl,
        outputSize: decodeSize,
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
    const cardGap = 12.0;
    final characters = originCharactersRecommendedFirst(widget.characters);
    final profileRole = widget.profileRole;
    final profileCardCount = profileRole == null ? 0 : 1;
    final cardCount = characters.length + profileCardCount;
    if (cardCount == 0) return const SizedBox.shrink();
    _cardStride = cardWidth + cardGap;
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
            child: ListView.builder(
              key: const ValueKey<String>('origin-setup-role-cards'),
              controller: _cardsController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: cardCount,
              itemExtent: _cardStride,
              // Keep every role card laid out so scrolling never rebuilds a
              // previously visited card.
              scrollCacheExtent: ScrollCacheExtent.pixels(
                _cardStride * cardCount,
              ),
              itemBuilder: (context, index) {
                if (profileRole != null && index == 0) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: cardWidth,
                      child: _OriginSetupRoleCard(
                        content: _OriginSetupRoleCardContent.fromProfile(
                          profileRole,
                        ),
                        cardWidth: cardWidth,
                        buttonHeight: _OriginSetupRoleSection._buttonHeight,
                        launching: widget.launching,
                        revealScrollController: widget.scrollController,
                        editableRole: profileRole,
                        onEditingChanged: widget.onRoleEditingChanged,
                        onSelectEditedRole: (role) =>
                            unawaited(widget.onSelectProfileRole(role)),
                        onSelect: () =>
                            unawaited(widget.onSelectProfileRole(profileRole)),
                      ),
                    ),
                  );
                }
                final characterIndex = index - profileCardCount;
                final character = characters[characterIndex];
                final editableRole = OriginCustomRoleDraft(
                  avatarUrl: character.avatar,
                  name: character.name,
                  identity: character.identity,
                  personality: character.brief,
                );
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: cardWidth,
                    child: _OriginSetupRoleCard(
                      content: _OriginSetupRoleCardContent.fromCharacter(
                        character,
                      ),
                      cardWidth: cardWidth,
                      buttonHeight: _OriginSetupRoleSection._buttonHeight,
                      launching: widget.launching,
                      revealScrollController: widget.scrollController,
                      editableRole: editableRole,
                      onEditingChanged: widget.onRoleEditingChanged,
                      onSelectEditedRole: (role) => unawaited(
                        widget.onSelectEditedPresetRole(
                          character,
                          OriginPresetRoleOverride(
                            avatarUrl: role.avatarUrl,
                            name: role.name,
                            identity: role.identity,
                            personality: role.personality,
                          ),
                        ),
                      ),
                      onSelect: () => unawaited(widget.onSelectRole(character)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<int>(
            valueListenable: _currentCardIndex,
            builder: (context, currentIndex, child) =>
                _OriginRoleCardsIndicator(
                  count: cardCount,
                  currentIndex: currentIndex.clamp(0, cardCount - 1),
                ),
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
                  ? originWorldDetailSheetSoftWhiteColor
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
    required this.cardWidth,
    required this.buttonHeight,
    required this.launching,
    required this.onSelect,
    this.revealScrollController,
    this.editableRole,
    this.onEditingChanged,
    this.onSelectEditedRole,
  });

  final _OriginSetupRoleCardContent content;
  final double cardWidth;
  final double buttonHeight;
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
    if (widget.launching || _editForm == null) return;
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              width: cardWidth,
              height: _editing
                  ? cardWidth + _OriginSetupRoleSection._toggleAreaHeight
                  : cardWidth,
              child: _editing
                  ? _OriginSetupRoleInlineEditor(
                      key: ValueKey<String>(
                        'origin-setup-role-inline-editor-$stableId',
                      ),
                      form: _editForm!,
                      stableId: stableId,
                      launching: widget.launching,
                      onChanged: _handleEditFormChanged,
                    )
                  : _OriginSetupRolePreview(
                      content: content,
                      cardWidth: cardWidth,
                      showDetails: _showDetails,
                      detailsController: _detailsController,
                      topLabel: topLabel,
                      onToggleDetails: _toggleDetails,
                    ),
            ),
            SizedBox(
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
                                        onTap: widget.launching
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
                                            alpha: widget.launching ? 0.6 : 1,
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
                                      onTap: widget.launching
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
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white
                                                      .withValues(
                                                        alpha: widget.launching
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
    required this.cardWidth,
    required this.showDetails,
    required this.detailsController,
    required this.topLabel,
    required this.onToggleDetails,
  });

  final _OriginSetupRoleCardContent content;
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
    required this.avatarUrl,
    required this.cardWidth,
  });

  final _OriginSetupRoleCardContent content;
  final String avatarUrl;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _OriginSetupRoleImage(
          url: avatarUrl,
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
    required this.name,
    required this.width,
    required this.height,
  });

  final String url;
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
    return Image(
      image: OriginRolePortraitImageProvider.fromUrl(
        imageUrl: url,
        outputSize: outputSize,
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
