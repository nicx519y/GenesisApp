part of 'origin_world_page.dart';

class _WorldViewSection extends StatelessWidget {
  const _WorldViewSection({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final body = origin.worldView.trim().isEmpty
        ? origin.description.trim()
        : origin.worldView.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: Color(0xFFFF2442),
          title: 'Worldo Brief',
        ),
        const SizedBox(height: 8),
        Text(body, style: _bodyTextStyle),
        const SizedBox(height: 8),
        _OriginPreviewImage(url: _resolveAssetUrl(origin.mapImage)),
      ],
    );
  }
}

class _OriginPreviewImage extends StatelessWidget {
  const _OriginPreviewImage({required this.url});

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final imageUrl = viewerUrl;
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9A9A9A)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = mediaHeight.isFinite
            ? _maxHeight.clamp(0.0, mediaHeight * 0.35).toDouble()
            : _maxHeight;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxHeight * _aspectRatio;
        final width = maxWidth.clamp(0.0, maxHeight * _aspectRatio).toDouble();
        final height = width / _aspectRatio;
        final preview = Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isEmpty
                  ? fallback
                  : imageUrl.startsWith('assets/')
                  ? Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => fallback,
                    )
                  : GenesisStaticNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_) => fallback,
                      errorWidget: (_, _) => fallback,
                    ),
            ),
          ),
        );
        if (viewerUrl.isEmpty) return preview;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showGenesisImageViewer(context, imageUrls: [viewerUrl]),
          child: preview,
        );
      },
    );
  }
}

class _LaunchPreviewSection extends StatelessWidget {
  const _LaunchPreviewSection({
    required this.origin,
    required this.previewTick,
  });

  final OriginDetail origin;
  final Map<String, dynamic> previewTick;

  @override
  Widget build(BuildContext context) {
    final tickResult = previewTick['tick_result'] is Map
        ? (previewTick['tick_result'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final globalBody = _mapString(tickResult, const ['narrator']);
    final metricUnit = _mapString(origin.metric, const ['unit']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.auto_awesome,
          iconColor: Color(0xFF6554FF),
          title: 'Launch Preview',
        ),
        const SizedBox(height: 8),
        WorldTickEventItem(
          tick: previewTick,
          tickNumber: 1,
          fallbackBody: globalBody,
          locationsById: _originLocationsById(origin.allLocations),
          dateLabel: origin.startTime.trim().isEmpty
              ? 'Day 1, 18:00'
              : formatGenesisTimestamp(origin.startTime),
          timeAgoLabel: '',
          stackedContent: true,
          contentLabelStyle: _originTickContentLabelStyle,
          contentTextStyle: _originTickContentTextStyle,
          contentTimestampStyle: _originTickContentTimestampStyle,
          metricUnit: metricUnit,
        ),
      ],
    );
  }
}

class _DiscussSection extends StatelessWidget {
  const _DiscussSection({required this.origin, required this.controller});

  final OriginDetail origin;
  final OriginDiscussListController controller;

  bool get _hasDiscussContent =>
      origin.discussCount > 0 ||
      controller.totalAll > 0 ||
      controller.items.isNotEmpty;

  Future<void> _handleDiscussAreaTap(BuildContext context) {
    if (_hasDiscussContent) return _openDiscussPage(context);
    return _openPostComposer(context);
  }

  Future<void> _openDiscussPage(BuildContext context) {
    return Navigator.of(context).pushNamed(
      RouteNames.discuss,
      arguments: {'oid': origin.oid, 'originId': origin.id},
    );
  }

  Future<void> _openPostComposer(BuildContext context) async {
    final submitted = await showDiscussPostComposer(
      context: context,
      title: 'New post',
      placeholder: 'Write a post',
      submitter: (content, images) async {
        await AppServicesScope.read(context).api.v1.discuss.post(
          bizId: origin.oid.trim(),
          bizType: 1,
          content: content,
          images: images,
        );
      },
    );
    if (!context.mounted || !submitted) return;
    unawaited(controller.refreshFirstPage());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasDiscussContent = _hasDiscussContent;
        final showDiscussList =
            hasDiscussContent ||
            controller.isInitialLoading ||
            controller.error != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const ValueKey('origin-discuss-summary-area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_handleDiscussAreaTap(context)),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      iconAsset: discussIconAsset,
                      title: 'Discuss (${origin.discussCount})',
                    ),
                    if (showDiscussList) ...[
                      const SizedBox(height: 8),
                      OriginDiscussList(
                        controller: controller,
                        count: origin.discussCount,
                        showHeader: false,
                        showActions: false,
                        showReplies: false,
                        disableAvatarProfileTap: true,
                        onViewMoreTap: () => _openDiscussPage(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!hasDiscussContent) ...[
              const SizedBox(height: 8),
              DiscussPostInput(
                bizId: origin.oid,
                onSubmitted: () => unawaited(controller.refreshFirstPage()),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OriginInitialDialogueSection extends StatelessWidget {
  const _OriginInitialDialogueSection({required this.preview});

  final _OriginInitialDialoguePreview preview;

  @override
  Widget build(BuildContext context) {
    final style = kLocationChatStyle.copyWith(
      headerTitleTextStyle: kLocationChatStyle.headerTitleTextStyle.copyWith(
        color: const Color(0xFF111111),
      ),
      headerTitleIconColor: const Color(0xFF111111),
      senderNameTextStyle: kLocationChatStyle.senderNameTextStyle.copyWith(
        color: const Color(0xFF111111),
      ),
    );
    return Padding(
      padding: style.messageListPadding.copyWith(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: style.headerTitleIconSize,
                color: style.headerTitleIconColor,
              ),
              SizedBox(width: style.headerTitleIconGap),
              Expanded(
                child: Text(
                  preview.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: style.headerTitleTextStyle.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final message in preview.messages)
            ChatMessageRow(
              key: ValueKey<String>(message.localId),
              message: message,
              showDateDivider: false,
              style: style,
            ),
        ],
      ),
    );
  }
}

class _OriginSetupRoleSection extends StatefulWidget {
  const _OriginSetupRoleSection({
    required this.characters,
    required this.launching,
    required this.onSelectRole,
    required this.onLaunchCustomRole,
    required this.onFillCustomRoleFromProfile,
  });

  static const double _cardWidthFactor = 0.8;
  static const double _buttonHeight = 58;

  final List<OriginCharacter> characters;
  final bool launching;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final Future<void> Function(OriginCustomRoleDraft role) onLaunchCustomRole;
  final OriginRoleProfileLoader onFillCustomRoleFromProfile;

  @override
  State<_OriginSetupRoleSection> createState() =>
      _OriginSetupRoleSectionState();
}

class _OriginSetupRoleSectionState extends State<_OriginSetupRoleSection> {
  late final OriginCharacterForm _customForm = OriginCharacterForm.empty(
    charId: 'inline_custom_role',
  );
  final ScrollController _cardsController = ScrollController();
  var _fillingProfile = false;
  var _currentCardIndex = 0;
  var _cardStride = 1.0;

  bool get _customReady {
    return _customForm.name.text.trim().isNotEmpty &&
        _customForm.identity.text.trim().isNotEmpty &&
        !_fillingProfile;
  }

  @override
  void initState() {
    super.initState();
    _cardsController.addListener(_handleCardsScroll);
  }

  @override
  void didUpdateWidget(covariant _OriginSetupRoleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastIndex = widget.characters.length;
    if (_currentCardIndex > lastIndex) {
      _currentCardIndex = lastIndex;
    }
  }

  @override
  void dispose() {
    _cardsController.removeListener(_handleCardsScroll);
    _cardsController.dispose();
    _customForm.dispose();
    super.dispose();
  }

  void _handleCardsScroll() {
    if (!_cardsController.hasClients || _cardStride <= 0) return;
    final cardCount = widget.characters.length + 1;
    final nextIndex = (_cardsController.offset / _cardStride).round().clamp(
      0,
      cardCount - 1,
    );
    if (nextIndex == _currentCardIndex || !mounted) return;
    setState(() => _currentCardIndex = nextIndex);
  }

  void _handleCustomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fillCustomFromProfile() async {
    if (_fillingProfile) return;
    FocusScope.of(context).unfocus();
    setState(() => _fillingProfile = true);
    try {
      final draft = await widget.onFillCustomRoleFromProfile();
      if (!mounted || draft == null) return;
      final name = draft.name.trim();
      final identity = draft.identity.trim();
      final bio = draft.bio.trim();
      final avatar = draft.avatarUrl.trim();
      if (name.isNotEmpty) {
        _customForm.name.text = _limitInlineCustomRoleValue(
          name,
          originCharacterNameMaxLength,
        );
      }
      if (identity.isNotEmpty) {
        _customForm.identity.text = _limitInlineCustomRoleValue(
          identity,
          originCharacterIdentityMaxLength,
        );
      }
      if (bio.isNotEmpty) {
        _customForm.bio.text = _limitInlineCustomRoleValue(
          bio,
          originCharacterBioMaxLength,
        );
      }
      _customForm.avatarUrl.text = avatar;
    } finally {
      if (mounted) setState(() => _fillingProfile = false);
    }
  }

  void _launchCustomRole() {
    if (_customForm.name.text.trim().isEmpty) {
      showGenesisToast(context, 'Please enter a name');
      return;
    }
    if (_customForm.identity.text.trim().isEmpty) {
      showGenesisToast(context, 'Please enter an identity');
      return;
    }
    unawaited(
      widget.onLaunchCustomRole(
        OriginCustomRoleDraft(
          avatarUrl: _customForm.avatarUrl.text,
          name: _customForm.name.text,
          identity: _customForm.identity.text,
          bio: _customForm.bio.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        MediaQuery.sizeOf(context).width *
        _OriginSetupRoleSection._cardWidthFactor;
    const cardGap = 12.0;
    final cardCount = widget.characters.length + 1;
    _cardStride = cardWidth + cardGap;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Setup Your Role',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: cardWidth + _OriginSetupRoleSection._buttonHeight,
            child: ListView.separated(
              key: const ValueKey<String>('origin-setup-role-cards'),
              controller: _cardsController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: cardCount,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: cardGap),
              itemBuilder: (context, index) {
                if (index == widget.characters.length) {
                  return SizedBox(
                    width: cardWidth,
                    child: _OriginSetupCustomRoleCard(
                      form: _customForm,
                      cardWidth: cardWidth,
                      buttonHeight: _OriginSetupRoleSection._buttonHeight,
                      launching: widget.launching,
                      fillingProfile: _fillingProfile,
                      canLaunch: _customReady,
                      onChanged: _handleCustomChanged,
                      onFillFromProfile: () =>
                          unawaited(_fillCustomFromProfile()),
                      onLaunch: _launchCustomRole,
                    ),
                  );
                }
                final character = widget.characters[index];
                return SizedBox(
                  width: cardWidth,
                  child: _OriginSetupRoleCard(
                    character: character,
                    cardWidth: cardWidth,
                    buttonHeight: _OriginSetupRoleSection._buttonHeight,
                    launching: widget.launching,
                    onSelect: () => unawaited(widget.onSelectRole(character)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _OriginRoleCardsIndicator(
            count: cardCount,
            currentIndex: _currentCardIndex.clamp(0, cardCount - 1),
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
            width: selected ? 8 : 6,
            height: selected ? 8 : 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? GenesisColors.brand : const Color(0xFFB7B7B7),
            ),
          );
        }),
      ),
    );
  }
}

class _OriginSetupCustomRoleCard extends StatelessWidget {
  const _OriginSetupCustomRoleCard({
    required this.form,
    required this.cardWidth,
    required this.buttonHeight,
    required this.launching,
    required this.fillingProfile,
    required this.canLaunch,
    required this.onChanged,
    required this.onFillFromProfile,
    required this.onLaunch,
  });

  final OriginCharacterForm form;
  final double cardWidth;
  final double buttonHeight;
  final bool launching;
  final bool fillingProfile;
  final bool canLaunch;
  final VoidCallback onChanged;
  final VoidCallback onFillFromProfile;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x1F111111)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              width: cardWidth,
              height: cardWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Role',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: OriginCustomRoleForm(
                        key: const ValueKey<String>('origin-setup-custom-form'),
                        form: form,
                        fillingProfile: fillingProfile,
                        canFillProfile: true,
                        onChanged: onChanged,
                        onFillFromProfile: onFillFromProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: buttonHeight,
              child: Material(
                color: canLaunch
                    ? GenesisColors.brand
                    : const Color(0xFFC8D9D1),
                child: InkWell(
                  key: const ValueKey<String>(
                    'origin-setup-role-custom-launch',
                  ),
                  onTap: launching || fillingProfile ? null : onLaunch,
                  child: Center(
                    child: Text(
                      launching ? 'Launching...' : 'Launch',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(
                          alpha: launching ? 0.6 : 1,
                        ),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _limitInlineCustomRoleValue(String value, int maxLength) {
  final characters = value.characters;
  if (characters.length <= maxLength) return value;
  return characters.take(maxLength).toString();
}

class _OriginSetupRoleCard extends StatefulWidget {
  const _OriginSetupRoleCard({
    required this.character,
    required this.cardWidth,
    required this.buttonHeight,
    required this.launching,
    required this.onSelect,
  });

  final OriginCharacter character;
  final double cardWidth;
  final double buttonHeight;
  final bool launching;
  final VoidCallback onSelect;

  @override
  State<_OriginSetupRoleCard> createState() => _OriginSetupRoleCardState();
}

class _OriginSetupRoleCardState extends State<_OriginSetupRoleCard> {
  var _showDetails = false;

  void _toggleDetails() {
    setState(() => _showDetails = !_showDetails);
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final cardWidth = widget.cardWidth;
    final buttonHeight = widget.buttonHeight;
    final avatarUrl = selectGenesisImageUrl(
      _resolveAssetUrl(character.avatar),
      logicalWidth: cardWidth,
      logicalHeight: cardWidth,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    ).trim();
    final stableId = _characterStableId(character);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF202022),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              width: cardWidth,
              height: cardWidth,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _showDetails
                        ? _OriginSetupRoleDetails(
                            key: ValueKey<String>(
                              'origin-setup-role-details-$stableId',
                            ),
                            character: character,
                          )
                        : _OriginSetupRolePortrait(
                            key: ValueKey<String>(
                              'origin-setup-role-portrait-$stableId',
                            ),
                            character: character,
                            avatarUrl: avatarUrl,
                            cardWidth: cardWidth,
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 2,
                    child: Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey<String>(
                            'origin-setup-role-toggle-$stableId',
                          ),
                          onTap: _toggleDetails,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              _showDetails
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              key: ValueKey<String>(
                                _showDetails
                                    ? 'origin-setup-role-arrow-up-$stableId'
                                    : 'origin-setup-role-arrow-down-$stableId',
                              ),
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: buttonHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Transform.scale(
                        scale: 1.2,
                        child: _OriginSetupRoleImage(
                          url: avatarUrl,
                          name: character.name,
                          width: cardWidth,
                          height: buttonHeight,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey<String>('origin-setup-role-$stableId'),
                      onTap: widget.launching ? null : widget.onSelect,
                      child: Center(
                        child: Text(
                          widget.launching
                              ? 'Launching...'
                              : 'Select to Launch',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(
                              alpha: widget.launching ? 0.6 : 1,
                            ),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginSetupRolePortrait extends StatelessWidget {
  const _OriginSetupRolePortrait({
    super.key,
    required this.character,
    required this.avatarUrl,
    required this.cardWidth,
  });

  final OriginCharacter character;
  final String avatarUrl;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _OriginSetupRoleImage(
          url: avatarUrl,
          name: character.name,
          width: cardWidth,
          height: cardWidth,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.42, 0.72, 1],
              colors: [
                Colors.transparent,
                Color(0x66151517),
                Color(0xF0151517),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 42,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
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
              if (character.tags.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  character.tags.trim(),
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 12,
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
  const _OriginSetupRoleDetails({super.key, required this.character});

  final OriginCharacter character;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF202022),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OriginSetupRoleDetailField(label: 'Name', value: character.name),
            _OriginSetupRoleDetailField(
              label: 'Identity',
              value: character.tags,
            ),
            _OriginSetupRoleDetailField(
              label: 'Brief',
              value: character.tagline,
            ),
            _OriginSetupRoleDetailField(
              label: 'Goal',
              value: character.goal,
              addBottomGap: false,
            ),
          ],
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
    return Padding(
      padding: EdgeInsets.only(bottom: addBottomGap ? 14 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
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
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
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
    this.alignment = Alignment.center,
  });

  final String url;
  final String name;
  final double width;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final fallback = GenesisAvatarFallback(
      name: name,
      width: width,
      height: height,
      borderRadius: 0,
    );
    if (url.isEmpty) return fallback;
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return GenesisStaticNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: alignment,
      placeholder: (_) => fallback,
      errorWidget: (_, _) => fallback,
    );
  }
}

class _OriginCharactersSection extends StatelessWidget {
  const _OriginCharactersSection({required this.characters});

  final List<OriginCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final characterAvatarUrls = characters
        .map((character) => _resolveAssetUrl(character.avatar).trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          iconAsset: characterStatIconAsset,
          title: 'Characters (${characters.length})',
        ),
        const SizedBox(height: 14),
        if (characters.isEmpty)
          const Text('No characters', style: _mutedBodyTextStyle)
        else
          for (int i = 0; i < characters.length; i++) ...[
            _OriginCharacterRow(
              character: characters[i],
              imageUrls: characterAvatarUrls,
            ),
            if (i != characters.length - 1) const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _OriginCharacterRow extends StatelessWidget {
  const _OriginCharacterRow({required this.character, required this.imageUrls});

  final OriginCharacter character;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final identity = _splitTags(character.tags).join(' · ');
    final tagline = character.tagline.trim();
    final goal = character.goal.trim();
    final avatarUrl = _resolveAssetUrl(character.avatar);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginCharacterPortrait(
          characterId: _characterStableId(character),
          url: avatarUrl,
          name: character.name,
          imageUrls: imageUrls,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                  decoration: TextDecoration.none,
                ),
              ),
              if (identity.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(identity, style: _bodyTextStyle),
              ],
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  tagline,
                  style: _bodyTextStyle.copyWith(
                    color: const Color(0xFFFF2442),
                  ),
                ),
              ],
              if (goal.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text('Goal: $goal', style: _characterBodyTextStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginCharacterPortrait extends StatelessWidget {
  const _OriginCharacterPortrait({
    required this.characterId,
    required this.url,
    required this.name,
    required this.imageUrls,
  });

  static const double _width = 86;
  static const double _borderRadius = GenesisAvatarRadii.character;
  static const double _starSize = 20;

  final String characterId;
  final String url;
  final String name;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = selectGenesisImageUrl(
      url,
      logicalWidth: _width,
      logicalHeight: _width,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    ).trim();
    final fallback = GenesisAvatarFallback(
      name: name,
      width: _width,
      height: _width,
      borderRadius: _borderRadius,
    );
    final image = resolvedUrl.isEmpty
        ? fallback
        : resolvedUrl.startsWith('assets/')
        ? Image.asset(
            resolvedUrl,
            width: _width,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : GenesisStaticNetworkImage(
            imageUrl: resolvedUrl,
            width: _width,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            placeholder: (_) => const SizedBox(width: _width, height: _width),
            errorWidget: (_, _) => fallback,
          );
    final initialIndex = imageUrls.indexOf(url.trim());
    final portrait = Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: _width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadius),
            child: image,
          ),
        ),
        const Positioned(
          top: -_starSize / 4 - 2,
          right: -_starSize / 4 - 3,
          child: Icon(
            MyFlutterApp.redstarCharIcon,
            size: _starSize,
            color: Color(0xFFFF2442),
          ),
        ),
      ],
    );
    if (resolvedUrl.isEmpty) return portrait;
    return GestureDetector(
      key: ValueKey('origin-character-portrait-$characterId'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showGenesisImageViewer(
        context,
        imageUrls: imageUrls,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
      ),
      child: portrait,
    );
  }
}

const _bodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
  decoration: TextDecoration.none,
);

const _characterBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
  decoration: TextDecoration.none,
);

const _mutedBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.3,
  fontWeight: FontWeight.w400,
  color: Color(0xFF999999),
  decoration: TextDecoration.none,
);

const _originTickContentLabelStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w600,
  color: Color(0xFF111111),
  decoration: TextDecoration.none,
);

const _originTickContentTextStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w400,
  color: Color(0xFF444444),
  decoration: TextDecoration.none,
);

const _originTickContentTimestampStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
  decoration: TextDecoration.none,
);

String _characterStableId(OriginCharacter character) {
  final explicitId = character.characterId.trim();
  if (explicitId.isNotEmpty) return explicitId;
  if (character.id > 0) return '${character.id}';
  return character.name.trim();
}

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const [];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

Map<String, dynamic>? _originPreviewTick(OriginDetail origin) {
  final tick = _originTick1(origin);
  if (tick == null) return null;
  final result = tick['tick_result'] is Map
      ? (tick['tick_result'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final narrator = _mapString(result, const ['narrator']);
  final paragraphsRaw = result['paragraphs'];
  final paragraphs = paragraphsRaw is List
      ? paragraphsRaw
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .where(_originPreviewParagraphHasText)
            .toList(growable: false)
      : const <Map<String, dynamic>>[];

  return <String, dynamic>{
    'created_at': tick['created_at'] ?? origin.updatedAt,
    'tick_result': <String, dynamic>{
      'narrator': narrator,
      'paragraphs': paragraphs,
    },
  };
}

Map<String, dynamic>? _originTick1(OriginDetail origin) {
  for (final tick in origin.ticks) {
    if (_mapInt(tick, const ['tick_no']) == 1) return tick;
  }
  return origin.ticks.isEmpty ? null : origin.ticks.first;
}

bool _originPreviewParagraphHasText(Map<String, dynamic> paragraph) {
  return _mapString(paragraph, const [
    'content',
    'text',
    'summary',
    'narrator',
  ]).isNotEmpty;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    this.icon,
    this.iconAsset,
    this.iconColor,
    required this.title,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final Color? iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    final asset = iconAsset;
    final isCharacterIcon = asset == characterStatIconAsset;
    const assetSize = 16.0;
    return Row(
      children: [
        if (asset case final asset?)
          Transform.translate(
            offset: Offset(0, isCharacterIcon ? -1.2 : 0),
            child: asset.endsWith('.svg')
                ? SvgPicture.asset(
                    asset,
                    width: assetSize,
                    height: assetSize,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  )
                : Image.asset(
                    asset,
                    width: assetSize,
                    height: assetSize,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
          )
        else
          Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: originDetailSectionTitleIconGapForTesting),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}
