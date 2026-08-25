part of 'origin_world_page.dart';

class _OriginSetupRoleSection extends StatefulWidget {
  const _OriginSetupRoleSection({
    required this.characters,
    required this.launching,
    required this.profileRole,
    required this.onSelectRole,
    required this.onSelectProfileRole,
    required this.onEditProfileRole,
    required this.onCustomizeRole,
  });

  static const double _cardWidth = 216;
  static const double _cardHeight = 300;
  static const double _buttonHeight = 34;
  static const double _toggleAreaHeight = 18;

  final List<OriginCharacter> characters;
  final bool launching;
  final OriginCustomRoleDraft? profileRole;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final Future<void> Function(OriginCustomRoleDraft role) onSelectProfileRole;
  final VoidCallback onEditProfileRole;
  final VoidCallback onCustomizeRole;

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
    if (_currentCardIndex.value > lastIndex) {
      _currentCardIndex.value = lastIndex;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheUpcomingRoleAvatars(_currentCardIndex.value);
    });
  }

  int get _cardCount =>
      widget.characters.length + (widget.profileRole == null ? 1 : 2);

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
    );
    final decodeWidth = (_OriginSetupRoleSection._cardWidth * devicePixelRatio)
        .ceil();
    final decodeHeight =
        (_OriginSetupRoleSection._cardHeight * devicePixelRatio).ceil();
    final lastIndex = math.min(currentIndex + 2, avatarSources.length - 1);
    for (var index = currentIndex; index <= lastIndex; index += 1) {
      final avatarUrl = _originRoleCardAvatarUrl(
        context,
        _resolveAssetUrl(avatarSources[index]),
      );
      if (avatarUrl.isEmpty) continue;
      final cacheKey = '$avatarUrl@${decodeWidth}x$decodeHeight';
      if (!_preloadedAvatarKeys.add(cacheKey)) continue;

      final provider = OriginRolePortraitImageProvider.fromUrl(
        imageUrl: avatarUrl,
        outputWidth: decodeWidth,
        outputHeight: decodeHeight,
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
    const cardGap = 10.0;
    final characters = originCharactersRecommendedFirst(widget.characters);
    final profileRole = widget.profileRole;
    final profileCardCount = profileRole == null ? 0 : 1;
    final cardCount = characters.length + profileCardCount + 1;
    _cardStride = cardWidth + cardGap;
    // 上方留出分区级断点:开场白对话和选角是两个板块,对话列表自带 10 的
    // 尾距,这里补到 28,与详情页的分区间距同级。
    // 下方只留 6:浮窗自身的底部安全区(>=24)已经提供了收尾空间,
    // 再叠一层分区间距会让卡片区浮得太高。
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: originDetailSheetHorizontalPaddingForTesting,
            ),
            child: Text(
              'Pick who you play, and the story starts here.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: context.genesisColors.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: _OriginSetupRoleSection._cardHeight,
            child: ListView.builder(
              key: const ValueKey<String>('origin-setup-role-cards'),
              controller: _cardsController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: originDetailSheetHorizontalPaddingForTesting,
              ),
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
                        onEdit: widget.onEditProfileRole,
                        onSelect: () =>
                            unawaited(widget.onSelectProfileRole(profileRole)),
                      ),
                    ),
                  );
                }
                final characterIndex = index - profileCardCount;
                if (characterIndex == characters.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: cardWidth,
                      child: _OriginSetupCustomRoleCard(
                        launching: widget.launching,
                        onTap: widget.onCustomizeRole,
                      ),
                    ),
                  );
                }
                final character = characters[characterIndex];
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
                      onSelect: () => unawaited(widget.onSelectRole(character)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 11),
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
            width: selected ? 14 : 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: selected
                  ? context.genesisColors.textHighEmphasis
                  : context.genesisColors.foregroundStrong.withValues(
                      alpha: 0.25,
                    ),
            ),
          );
        }),
      ),
    );
  }
}

class _OriginSetupCustomRoleCard extends StatelessWidget {
  const _OriginSetupCustomRoleCard({
    required this.launching,
    required this.onTap,
  });

  final bool launching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('origin-setup-role-custom-card'),
      color: context.genesisColors.surfaceSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        highlightColor: Colors.transparent,
        onTap: launching ? null : onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+',
                style: TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: context.genesisColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Custom',
                style: TextStyle(
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: context.genesisColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
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
    required this.brief,
    required this.goal,
    required this.background,
    required this.isRecommended,
    required this.isProfile,
  });

  factory _OriginSetupRoleCardContent.fromCharacter(OriginCharacter character) {
    return _OriginSetupRoleCardContent(
      stableId: _characterStableId(character),
      name: character.name,
      avatar: character.avatar,
      identity: character.tags,
      brief: character.tagline,
      goal: character.goal,
      background: '',
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
      identity: '',
      brief: '',
      goal: '',
      background: profileRole.bio,
      isRecommended: false,
      isProfile: true,
    );
  }

  final String stableId;
  final String name;
  final String avatar;
  final String identity;
  final String brief;
  final String goal;
  final String background;
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
    this.onEdit,
  });

  final _OriginSetupRoleCardContent content;
  final double cardWidth;
  final double buttonHeight;
  final bool launching;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;

  @override
  State<_OriginSetupRoleCard> createState() => _OriginSetupRoleCardState();
}

class _OriginSetupRoleCardState extends State<_OriginSetupRoleCard> {
  final ScrollController _detailsController = ScrollController(
    keepScrollOffset: false,
  );
  var _showDetails = false;

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
    final content = widget.content;
    final cardWidth = widget.cardWidth;
    final buttonHeight = widget.buttonHeight;
    final avatarUrl = _originRoleCardAvatarUrl(
      context,
      _resolveAssetUrl(content.avatar),
    );
    final stableId = content.stableId;
    final topLabel = content.isProfile
        ? 'Your Profile'
        : content.isRecommended
        ? 'Creator pick'
        : null;

    return SizedBox(
      width: cardWidth,
      height: _OriginSetupRoleSection._cardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          key: ValueKey<String>('origin-setup-role-card-frame-$stableId'),
          decoration: BoxDecoration(
            color: context.genesisOriginColors.roleSetupPanel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                key: ValueKey<String>(
                  'origin-setup-role-card-body-toggle-$stableId',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleDetails,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _showDetails
                      ? Padding(
                          padding: const EdgeInsets.only(
                            bottom:
                                _OriginSetupRoleSection._toggleAreaHeight +
                                _OriginSetupRoleSection._buttonHeight +
                                10,
                          ),
                          child: _OriginSetupRoleDetails(
                            key: ValueKey<String>(
                              'origin-setup-role-details-$stableId',
                            ),
                            content: content,
                            controller: _detailsController,
                          ),
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
              if (topLabel != null && !_showDetails)
                Positioned(
                  top: 10,
                  left: 10,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          key: ValueKey<String>(
                            content.isProfile
                                ? 'origin-setup-role-profile-label'
                                : 'origin-setup-role-suggested-label-$stableId',
                          ),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: context.genesisColors.pageBackground
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: context.genesisColors.borderStrong,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (content.isRecommended) ...[
                                Container(
                                  key: ValueKey<String>(
                                    'origin-setup-role-recommended-$stableId',
                                  ),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: context.genesisColors.accentText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                topLabel,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  color: context.genesisColors.textPrimary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: SizedBox(
                  key: ValueKey<String>(
                    'origin-setup-role-action-bar-$stableId',
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: _OriginSetupRoleSection._toggleAreaHeight,
                        child: GestureDetector(
                          key: ValueKey<String>(
                            'origin-setup-role-toggle-$stableId',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleDetails,
                          child: Center(
                            child: GenesisChevronDownIcon(
                              key: ValueKey<String>(
                                _showDetails
                                    ? 'origin-setup-role-arrow-up-$stableId'
                                    : 'origin-setup-role-arrow-down-$stableId',
                              ),
                              pointUp: _showDetails,
                              width: 16,
                              color: context.genesisColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: buttonHeight,
                        child: Row(
                          children: [
                            if (widget.onEdit != null) ...[
                              GenesisCardActionButton.icon(
                                surfaceKey: ValueKey<String>(
                                  'origin-setup-role-edit-surface-$stableId',
                                ),
                                interactionKey: ValueKey<String>(
                                  'origin-setup-role-edit-$stableId',
                                ),
                                icon: Icons.edit_rounded,
                                tooltip: 'Edit profile',
                                onPressed: widget.launching
                                    ? null
                                    : widget.onEdit,
                                height: buttonHeight,
                                // 与同排 Select 一致的毛玻璃底。
                                backdropBlurSigma: 10,
                              ),
                              const SizedBox(width: 7),
                            ],
                            Expanded(
                              child: GenesisCardActionButton(
                                surfaceKey: ValueKey<String>(
                                  'origin-setup-role-select-surface-$stableId',
                                ),
                                interactionKey: ValueKey<String>(
                                  'origin-setup-role-$stableId',
                                ),
                                label: widget.launching
                                    ? 'Launching...'
                                    : 'Select',
                                onPressed: widget.launching
                                    ? null
                                    : widget.onSelect,
                                height: buttonHeight,
                                // 角色卡字阶:Select 12/800/1.3;
                                // 毛玻璃底(设计稿 9i:blur 10)。
                                fontSize: 12,
                                lineHeight: 1.3,
                                backdropBlurSigma: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        // 设计稿 9i 的卡片由整幅竖图铺满;方图之外的区域用上层背景色
        // (redesignRaised #1F1D24)打底 —— 用页面底色会让卡片底部
        // 和浮窗背景融成一片。
        const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF1F1D24))),
        _OriginSetupRoleImage(
          url: avatarUrl,
          name: content.name,
          width: cardWidth,
          height: _OriginSetupRoleSection._cardHeight,
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // 最底部收到比浮窗背景(#151517)更深一档的墨色(#0E0D10)
              // 并做实,靠明度差把卡片下缘从背景里区分出来;
              // 中段走深墨 #151517(灰紫 raised 会把模糊图抬灰发糊)。
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFF0E0D10),
                  Color(0x73151517),
                  Color(0x00151517),
                ],
                stops: [0, 0.58, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 65,
          // 文案顺序:name / identity / personality。
          // 字阶(产品定稿):name 17/800,identity 11/600,
          // personality 11/400,行距统一 1.3,行间距 4。
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                content.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: context.genesisColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              if (content.identity.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  content.identity.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: context.genesisColors.textBody,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
              if (content.brief.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  content.brief.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    // personality 配色与 detail 页 Cast 行一致:强调粉。
                    color: context.genesisColors.accentText,
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
        color: context.genesisOriginColors.roleSetupPanel,
        child: SingleChildScrollView(
          key: ValueKey<String>(
            'origin-setup-role-details-scroll-${content.stableId}',
          ),
          controller: controller,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.name.trim().isEmpty ? '—' : content.name.trim(),
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: context.genesisColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              _OriginSetupRoleDetailField(
                label: 'Identity',
                value: content.identity,
              ),
              if (content.isProfile)
                _OriginSetupRoleDetailField(
                  label: 'Background',
                  value: content.background,
                  addBottomGap: false,
                )
              else ...[
                _OriginSetupRoleDetailField(
                  label: 'Brief',
                  value: content.brief,
                ),
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
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: context.genesisColors.textMuted,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayValue,
              softWrap: true,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
                color: context.genesisColors.textPrimary,
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
        DecoratedBox(
          decoration: BoxDecoration(gradient: originRolePortraitGradient),
        ),
      ],
    );
    if (url.isEmpty) return fallback;
    final devicePixelRatio = genesisImageDevicePixelRatio(
      MediaQuery.devicePixelRatioOf(context),
    );
    final outputWidth = (width * devicePixelRatio).ceil();
    final outputHeight = (height * devicePixelRatio).ceil();
    return Image(
      image: OriginRolePortraitImageProvider.fromUrl(
        imageUrl: url,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      ),
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return ColoredBox(
          color: context.genesisOriginColors.roleSetupPanel,
          child: SizedBox(width: width, height: height),
        );
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
