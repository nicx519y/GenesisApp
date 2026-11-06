part of 'origin_world_page.dart';

const Color _originSetupRoleSelectedAccentColor = Color(0x73FF2442);

class _OriginSetupRoleSection extends StatefulWidget {
  const _OriginSetupRoleSection({
    super.key,
    this.title,
    this.bottomPadding = _bottomPadding,
    this.indicatorGap = 14,
    this.titleStyle,
    this.shrinkWrap = false,
    required this.characters,
    required this.roleAvatarSnapshots,
    required this.launchBusy,
    required this.profileRole,
    required this.profileRoleRevision,
    required this.selectedRoleId,
    required this.onSelectedRoleChanged,
    required this.editorInteraction,
  });

  static const double _cardWidth = 240;
  static const double _bottomPadding = 28;
  static const double _composerClearance = 4;

  final String? title;
  final double bottomPadding;
  final double indicatorGap;
  final TextStyle? titleStyle;
  final bool shrinkWrap;
  final List<OriginCharacter> characters;
  final OriginRoleAvatarSnapshotStore roleAvatarSnapshots;
  final bool launchBusy;
  final OriginCustomRoleDraft? profileRole;
  final int profileRoleRevision;
  final String selectedRoleId;
  final ValueChanged<String> onSelectedRoleChanged;
  final _OriginRoleEditorInteractionController editorInteraction;

  @override
  State<_OriginSetupRoleSection> createState() =>
      _OriginSetupRoleSectionState();
}

class _OriginSetupRoleSectionState extends State<_OriginSetupRoleSection> {
  PageController? _cardsController;
  final Set<String> _preloadedAvatarKeys = <String>{};
  var _currentCardIndex = 0;
  var _viewportFraction = 1.0;

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
    for (final character in _remainingCharacters)
      if (_characterStableId(character).isNotEmpty)
        _characterStableId(character),
  ];

  Iterable<OriginCharacter> get _remainingCharacters =>
      originCharactersRecommendedFirst(widget.characters);

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
    if (widget.launchBusy) {
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
    if (roleId != widget.selectedRoleId) {
      widget.onSelectedRoleChanged(roleId);
    }
  }

  void _centerCard(int index) {
    if (widget.launchBusy) return;
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

  void _precacheUpcomingRoleAvatars(int currentIndex) {
    if (!mounted) return;
    final profileRole = widget.profileRole;
    final avatarSourceKeys = <String>[
      if (profileRole != null)
        profileRole.avatarPreviewBytes == null
            ? _resolveAssetUrl(profileRole.avatarUrl).trim()
            : '',
      ..._remainingCharacters
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
      final avatarUrl = _originRoleAvatarUrl(
        avatarSourceKey,
        _OriginSetupRoleSection._cardWidth,
      );
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
    final characters = _remainingCharacters
        .where((character) => _characterStableId(character).isNotEmpty)
        .toList(growable: false);
    final profileRole = widget.profileRole;
    final profileRoleRevision = widget.profileRoleRevision;
    final cardCount = _cardCount;
    if (cardCount == 0) return const SizedBox.shrink();
    final currentCardIndex = _currentCardIndex.clamp(0, cardCount - 1);
    final cardsController = _cardsController;
    if (cardsController == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Column(
        mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                widget.title ?? GenesisL10n.current.worldoLaunchSelectRole,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    widget.titleStyle ??
                    const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: originWorldDetailSheetPrimaryTextColor,
                      decoration: TextDecoration.none,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: cardWidth,
            child: PageView.builder(
              key: const ValueKey<String>('origin-setup-role-cards'),
              controller: cardsController,
              scrollDirection: Axis.horizontal,
              physics: widget.launchBusy
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
                          'origin-setup-role-page-${_OriginWorldPageState._profileLocationChatRoleId}',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: selected ? null : () => _centerCard(index),
                        child: IgnorePointer(
                          ignoring: !selected,
                          child: _OriginSetupRoleCard(
                            key: ValueKey<String>(
                              '${_OriginWorldPageState._profileLocationChatRoleId}-$profileRoleRevision',
                            ),
                            content: _OriginSetupRoleCardContent.fromProfile(
                              profileRole,
                            ),
                            roleAvatarSnapshots: widget.roleAvatarSnapshots,
                            selected: selected,
                            cardWidth: cardWidth,
                            busy: widget.launchBusy,
                            onBeginEditing:
                                widget.editorInteraction.beginEditing,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final character =
                    characters[index - (profileRole == null ? 0 : 1)];
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
                          key: ValueKey<String>(stableId),
                          content: _OriginSetupRoleCardContent.fromCharacter(
                            character,
                          ),
                          roleAvatarSnapshots: widget.roleAvatarSnapshots,
                          selected: selected,
                          cardWidth: cardWidth,
                          busy: widget.launchBusy,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: widget.indicatorGap),
          _OriginRoleCardsIndicator(
            count: cardCount,
            currentIndex: currentCardIndex,
          ),
        ],
      ),
    );
  }
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
      label: GenesisL10n.current.a11yRoleCards(
        index: currentIndex + 1,
        count: count,
      ),
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
                  ? _originSetupRoleSelectedAccentColor
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
    required this.bio,
    required this.goal,
    required this.isRecommended,
    required this.isProfile,
    this.avatarPreviewBytes,
  });

  factory _OriginSetupRoleCardContent.fromCharacter(OriginCharacter character) {
    return _OriginSetupRoleCardContent(
      stableId: _characterStableId(character),
      name: character.name,
      avatar: character.avatar,
      identity: character.tags,
      personality: character.tagline,
      bio: character.description,
      goal: character.goal,
      isRecommended: character.isRecommended,
      isProfile: false,
    );
  }

  factory _OriginSetupRoleCardContent.fromProfile(
    OriginCustomRoleDraft profileRole,
  ) {
    return _OriginSetupRoleCardContent(
      stableId: _OriginWorldPageState._profileLocationChatRoleId,
      name: profileRole.name,
      avatar: profileRole.avatarUrl,
      avatarPreviewBytes: profileRole.avatarPreviewBytes,
      identity: profileRole.identity,
      personality: profileRole.personality,
      bio: profileRole.bio,
      goal: profileRole.goal,
      isRecommended: false,
      isProfile: true,
    );
  }

  final String stableId;
  final String name;
  final String avatar;
  final Uint8List? avatarPreviewBytes;
  final String identity;
  final String personality;
  final String bio;
  final String goal;
  final bool isRecommended;
  final bool isProfile;
}

class _OriginSetupRoleCard extends StatefulWidget {
  const _OriginSetupRoleCard({
    super.key,
    required this.content,
    required this.roleAvatarSnapshots,
    required this.selected,
    required this.cardWidth,
    required this.busy,
    this.onBeginEditing,
  });

  final _OriginSetupRoleCardContent content;
  final OriginRoleAvatarSnapshotStore roleAvatarSnapshots;
  final bool selected;
  final double cardWidth;
  final bool busy;

  /// Set on the player's own card, the only one that can be edited.
  final VoidCallback? onBeginEditing;

  @override
  State<_OriginSetupRoleCard> createState() => _OriginSetupRoleCardState();
}

class _OriginSetupRoleCardState extends State<_OriginSetupRoleCard>
    with AutomaticKeepAliveClientMixin<_OriginSetupRoleCard> {
  final ScrollController _detailsController = ScrollController(
    keepScrollOffset: false,
  );
  var _showDetails = false;

  void _beginEditing() {
    if (widget.busy) return;
    if (_showDetails) setState(() => _showDetails = false);
    widget.onBeginEditing?.call();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = widget.content;
    final cardWidth = widget.cardWidth;
    final stableId = content.stableId;
    final topLabel = content.isProfile
        ? GenesisL10n.current.worldoLaunchProfile
        : content.isRecommended
        ? GenesisL10n.current.worldoLaunchSuggested
        : null;

    return ClipRRect(
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
                ? GenesisColors.redPrimary
                : Colors.white.withValues(alpha: 0.12),
            width: widget.selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: cardWidth,
          height: cardWidth,
          child: Stack(
            children: [
              Positioned.fill(
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
              if (widget.onBeginEditing != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    key: ValueKey<String>(
                      'origin-setup-role-edit-surface-$stableId',
                    ),
                    color: Colors.black.withValues(alpha: 0.68),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey<String>('origin-setup-role-edit-$stableId'),
                      onTap: widget.busy ? null : _beginEditing,
                      child: Center(
                        widthFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            // Include the label's 1px border inset.
                            horizontal: 9,
                            vertical: 6,
                          ),
                          child: Text(
                            GenesisL10n.current.chatEdit,
                            key: ValueKey<String>(
                              'origin-setup-role-edit-label-$stableId',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                              color: widget.busy
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : GenesisColors.redSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
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
    final avatarUrl = _originRoleAvatarUrl(content.avatar, cardWidth);
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (content.isRecommended) ...[
                      OriginRecommendedRoleMark(
                        badgeKey: ValueKey<String>(
                          'origin-setup-role-recommended-$stableId',
                        ),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      resolvedTopLabel,
                      style: TextStyle(
                        fontSize: content.isRecommended ? 12 : 13,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
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
          previewBytes: content.avatarPreviewBytes,
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
                  key: ValueKey<String>(
                    'origin-setup-role-identity-${content.stableId}',
                  ),
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
        color: originWorldDetailSheetSurfaceColor,
        child: SingleChildScrollView(
          key: ValueKey<String>(
            'origin-setup-role-details-scroll-${content.stableId}',
          ),
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: content.isProfile ? 36 : 0),
                child: Text(
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
              ),
              const SizedBox(height: 14),
              _OriginSetupRoleDetailField(
                label: GenesisL10n.current.worldoLaunchIdentity,
                value: content.identity,
              ),
              _OriginSetupRoleDetailField(
                label: GenesisL10n.current.worldoLaunchPersonality,
                value: content.personality,
              ),
              _OriginSetupRoleDetailField(
                label: GenesisL10n.current.worldoLaunchSetting,
                value: content.bio,
                addBottomGap: !content.isProfile,
              ),
              if (!content.isProfile) ...[
                _OriginSetupRoleDetailField(
                  label: GenesisL10n.current.worldoLaunchGoal,
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
    required this.previewBytes,
    required this.name,
    required this.width,
    required this.height,
  });

  final String url;
  final String snapshotSourceKey;
  final OriginRoleAvatarSnapshotStore snapshotStore;
  final Uint8List? previewBytes;
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
    Widget localPreview(Uint8List bytes, Widget placeholder) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: outputSize,
            cacheHeight: outputSize,
            errorBuilder: (context, error, stackTrace) => placeholder,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: originRolePortraitGradient),
          ),
        ],
      );
    }

    if (previewBytes case final bytes?) return localPreview(bytes, fallback);
    final snapshotSize = math.max(
      1,
      (_originLocationChatRolePillAvatarSize * devicePixelRatio).ceil(),
    );
    final profileCache = AppServicesScope.maybeOf(context)?.profileAvatarCache;
    Widget withProfilePreview(Widget placeholder) {
      if (profileCache == null) return placeholder;
      return ListenableBuilder(
        listenable: profileCache,
        builder: (context, _) {
          final bytes = profileCache.bytesFor(snapshotSourceKey);
          return bytes == null ? placeholder : localPreview(bytes, placeholder);
        },
      );
    }

    return Image(
      key: ValueKey(snapshotSourceKey),
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
        return withProfilePreview(
          ColoredBox(
            color: const Color(0xFF202022),
            child: SizedBox(width: width, height: height),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          withProfilePreview(fallback),
    );
  }
}
