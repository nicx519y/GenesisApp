part of 'origin_world_page.dart';

class _OriginSetupRoleSection extends StatefulWidget {
  const _OriginSetupRoleSection({
    required this.characters,
    required this.launching,
    required this.onSelectRole,
    required this.onCustomizeRole,
  });

  static const double _cardWidth = 240;
  static const double _buttonHeight = 93;
  static const double _toggleAreaHeight = 48;

  final List<OriginCharacter> characters;
  final bool launching;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final VoidCallback onCustomizeRole;

  @override
  State<_OriginSetupRoleSection> createState() =>
      _OriginSetupRoleSectionState();
}

class _OriginSetupRoleSectionState extends State<_OriginSetupRoleSection> {
  final ScrollController _cardsController = ScrollController();
  var _currentCardIndex = 0;
  var _cardStride = 1.0;

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

  @override
  Widget build(BuildContext context) {
    const cardWidth = _OriginSetupRoleSection._cardWidth;
    const cardGap = 12.0;
    final characters = originCharactersRecommendedFirst(widget.characters);
    final cardCount = characters.length + 1;
    _cardStride = cardWidth + cardGap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Select Your Role',
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
          const SizedBox(height: 8),
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
                if (index == characters.length) {
                  return SizedBox(
                    width: cardWidth,
                    child: _OriginSetupCustomRoleCard(
                      launching: widget.launching,
                      onTap: widget.onCustomizeRole,
                    ),
                  );
                }
                final character = characters[index];
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
    required this.launching,
    required this.onTap,
  });

  final bool launching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('origin-setup-role-custom-card'),
      color: const Color(0xCC000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x1FFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        highlightColor: Colors.transparent,
        onTap: launching ? null : onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '+',
                style: TextStyle(
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Custom',
                style: TextStyle(
                  fontSize: 16,
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
    );
  }
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
    final character = widget.character;
    final cardWidth = widget.cardWidth;
    final buttonHeight = widget.buttonHeight;
    final avatarUrl = _originRoleCardAvatarUrl(
      context,
      _resolveAssetUrl(character.avatar),
    );
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
                          ? _OriginSetupRoleDetails(
                              key: ValueKey<String>(
                                'origin-setup-role-details-$stableId',
                              ),
                              character: character,
                              controller: _detailsController,
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
                  ),
                ],
              ),
            ),
            SizedBox(
              key: ValueKey<String>('origin-setup-role-action-bar-$stableId'),
              height: buttonHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    key: ValueKey<String>(
                      'origin-setup-role-action-background-$stableId',
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF505056), Color(0xFF343438)],
                      ),
                    ),
                  ),
                  ColoredBox(
                    key: ValueKey<String>(
                      'origin-setup-role-action-scrim-$stableId',
                    ),
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                  Column(
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
                              onTap: widget.launching ? null : widget.onSelect,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (character.isRecommended) ...[
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
                                  ],
                                ),
                              ),
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
          bottom: 16,
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
    required this.character,
    required this.controller,
  });

  final OriginCharacter character;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFF202022),
        child: SingleChildScrollView(
          key: ValueKey<String>(
            'origin-setup-role-details-scroll-${_characterStableId(character)}',
          ),
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name.trim().isEmpty ? '—' : character.name.trim(),
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
      placeholder: (_) => ColoredBox(
        color: const Color(0xFF202022),
        child: SizedBox(width: width, height: height),
      ),
      errorWidget: (_, _) => fallback,
    );
  }
}
