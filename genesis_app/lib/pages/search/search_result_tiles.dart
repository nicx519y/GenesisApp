part of 'search_page.dart';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        style: TextStyle(
          color: context.genesisColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchMoreButton extends StatelessWidget {
  const _SearchMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              'More >',
              style: TextStyle(
                color: context.genesisColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final _SearchResultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUser = item.tab == _SearchTab.user;
    final titleStyle = TextStyle(
      color: context.genesisColors.textPrimary,
      fontSize: 14,
      height: 1.1,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = TextStyle(
      color: context.genesisColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
    // Same accent the Home row gives its tick/character line.
    final accentStyle = bodyStyle.copyWith(
      color: context.genesisColors.accentText,
    );
    final bodyLines = <({String text, TextStyle style, int maxLines})>[
      if (item.displayCreator.isNotEmpty)
        (text: '@${item.displayCreator}', style: bodyStyle, maxLines: 1),
      if (item.showStatusLine)
        (text: item.statusLine, style: accentStyle, maxLines: 1),
      if (item.displayBrief.isNotEmpty)
        (text: item.displayBrief, style: bodyStyle, maxLines: 2),
    ];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ResultThumb(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 5),
                  if (isUser)
                    Text(
                      'UID: ${formatCopyableIdValue(item.displaySubtitle)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle,
                    )
                  else if (item.deleted)
                    // A removed entity keeps its single explanatory line.
                    Text(
                      item.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle,
                    )
                  else
                    for (final (index, line) in bodyLines.indexed) ...[
                      if (index > 0) const SizedBox(height: 3),
                      Text(
                        line.text,
                        maxLines: line.maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: line.style,
                      ),
                    ],
                  if (!isUser) ...[
                    const SizedBox(height: 7),
                    _ResultStats(item: item),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultThumb extends StatelessWidget {
  const _ResultThumb({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    const width = 68.0;
    if (item.tab == _SearchTab.user) {
      return GenesisAvatar(
        url: item.coverImage,
        name: item.title,
        size: width,
        borderRadius: GenesisAvatarRadii.user,
      );
    }
    return GenesisListImage(
      imageUrl: item.coverImage,
      width: width,
      height: 88,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

class _ResultStats extends StatelessWidget {
  const _ResultStats({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    // Same three icons the Me collection rows use.
    final stats = [
      _StatData(
        iconAsset: originFeedPlayIconAsset,
        value: item.tab == _SearchTab.origin ? item.copyCount : item.tickCount,
      ),
      _StatData(
        iconAsset: originFeedCommentIconAsset,
        value: item.connectCount,
      ),
      _StatData(
        iconAsset: originFeedRoleIconAsset,
        preserveIconAssetColor: true,
        value: item.characterCount,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final stat in stats)
          Builder(
            builder: (context) {
              final color = stat.preserveIconAssetColor
                  ? colors.accentText
                  : colors.textMetadata;
              return StatItem(
                icon: stat.icon,
                iconAsset: stat.iconAsset,
                preserveIconAssetColor: stat.preserveIconAssetColor,
                iconSize: 12,
                iconColor: color,
                gap: 4,
                text: formatStatCount(stat.value),
                textStyle: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StatData {
  const _StatData({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;
}
