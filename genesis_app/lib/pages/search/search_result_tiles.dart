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
                fontSize: 14,
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
      color: context.genesisColors.accentText,
      fontSize: 14,
      height: 1.1,
      fontWeight: FontWeight.w600,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultThumb(item: item),
          const SizedBox(width: 10),
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
                      style: CopyableIdLabel.textStyle.copyWith(
                        color: context.genesisColors.textMuted,
                      ),
                    )
                  else
                    Text(
                      item.displaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.genesisColors.textFaint,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  if (!isUser) ...[
                    const SizedBox(height: 8),
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
    const size = 52.0;
    if (item.tab == _SearchTab.user) {
      return GenesisAvatar(
        url: item.coverImage,
        name: item.title,
        size: size,
        borderRadius: GenesisAvatarRadii.user,
      );
    }
    return GenesisListImage(
      imageUrl: item.coverImage,
      width: size,
      height: size,
    );
  }
}

class _ResultStats extends StatelessWidget {
  const _ResultStats({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final stats = item.tab == _SearchTab.origin
        ? [
            _StatData(iconAsset: copyStatIconAsset, value: item.copyCount),
            _StatData(
              iconAsset: connectStatIconAsset,
              value: item.connectCount,
            ),
            _StatData(
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              value: item.characterCount,
            ),
          ]
        : [
            _StatData(iconAsset: tickStatIconAsset, value: item.tickCount),
            _StatData(
              iconAsset: connectStatIconAsset,
              value: item.connectCount,
            ),
            _StatData(
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              value: item.characterCount,
            ),
            _StatData(iconAsset: userStatIconAsset, value: item.playerCount),
          ];

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final stat in stats)
          StatItem(
            icon: stat.icon,
            iconAsset: stat.iconAsset,
            preserveIconAssetColor: stat.preserveIconAssetColor,
            iconSize: 11,
            iconColor: colors.navigationSelected,
            gap: 4,
            text: formatStatCount(stat.value),
            textStyle: TextStyle(
              color: colors.navigationSelected,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
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
