part of 'origin_world_page.dart';

class _OriginCharactersSection extends StatelessWidget {
  const _OriginCharactersSection({required this.characters});

  final List<OriginCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final sortedCharacters = originCharactersRecommendedFirst(characters);
    final characterAvatarUrls = characters
        .map((character) => _resolveAssetUrl(character.avatar).trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginInfoSectionHeading(
          title: 'Cast',
          count: '(${characters.length})',
        ),
        const SizedBox(height: 10),
        if (characters.isEmpty)
          Text('No characters', style: _mutedBodyTextStyle(context))
        else
          for (final character in sortedCharacters)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: context.genesisColors.foregroundStrong.withValues(
                      alpha: 0.14,
                    ),
                    width: 1,
                  ),
                ),
              ),
              child: _OriginCharacterRow(
                character: character,
                imageUrls: characterAvatarUrls,
              ),
            ),
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
      key: ValueKey<String>(
        'origin-character-row-${_characterStableId(character)}',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginCharacterPortrait(
          characterId: _characterStableId(character),
          url: avatarUrl,
          name: character.name,
          imageUrls: imageUrls,
          recommended: character.isRecommended,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: context.genesisColors.foregroundStrong,
                  decoration: TextDecoration.none,
                ),
              ),
              if (identity.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(identity, style: _characterBodyTextStyle(context)),
              ],
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tagline,
                  style: _characterBodyTextStyle(
                    context,
                  ).copyWith(color: context.genesisColors.accentText),
                ),
              ],
              if (goal.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Goal ',
                        style: TextStyle(
                          color: context.genesisColors.foregroundStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: goal),
                    ],
                  ),
                  style: _characterBodyTextStyle(context).copyWith(
                    color: context.genesisColors.foregroundStrong.withValues(
                      alpha: 0.72,
                    ),
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

class _OriginCharacterPortrait extends StatelessWidget {
  const _OriginCharacterPortrait({
    required this.characterId,
    required this.url,
    required this.name,
    required this.imageUrls,
    required this.recommended,
  });

  static const double _width = 40;
  static const double _borderRadius = 12;

  final String characterId;
  final String url;
  final String name;
  final List<String> imageUrls;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _originRoleCardAvatarUrl(context, url);
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
            height: _width,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : GenesisStaticNetworkImage(
            imageUrl: resolvedUrl,
            width: _width,
            height: _width,
            fit: BoxFit.cover,
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
          height: _width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadius),
            child: image,
          ),
        ),
        if (recommended)
          Positioned(
            right: -4,
            bottom: -4,
            child: OriginRecommendedRoleMark(
              badgeKey: ValueKey<String>(
                'origin-character-recommended-$characterId',
              ),
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
        previewImageProviders: [
          for (final imageUrl in imageUrls)
            genesisImageViewerPreviewProvider(
              context,
              imageUrl: _originRoleCardAvatarUrl(context, imageUrl),
              logicalWidth: _width,
              logicalHeight: _width,
              fit: BoxFit.cover,
            ),
        ],
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
      ),
      child: portrait,
    );
  }
}

TextStyle _bodyTextStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.textPrimary,
  decoration: TextDecoration.none,
);

TextStyle _characterBodyTextStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  height: 1.5,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.foregroundStrong.withValues(alpha: 0.92),
  decoration: TextDecoration.none,
);

TextStyle _mutedBodyTextStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.3,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.textPlaceholder,
  decoration: TextDecoration.none,
);

TextStyle _originTickContentLabelStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w600,
  color: context.genesisColors.textPrimary,
  decoration: TextDecoration.none,
);

TextStyle _originTickContentTextStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.textQuaternary,
  decoration: TextDecoration.none,
);

TextStyle _originTickContentTimestampStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: context.genesisColors.textPrimary,
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
      'current_time': _mapString(result, const ['current_time']),
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
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: context.genesisColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
