part of 'chat_ui_library.dart';

/// Shared location recommendation and character-movement presentation.
class ChatLocationJumpCard extends StatelessWidget {
  const ChatLocationJumpCard({
    super.key,
    required this.names,
    required this.action,
    required this.locationName,
    this.parentPath = '',
    this.imageUrl = '',
    this.onTap,
    this.locationKey,
  });
  final String names;
  final String action;
  final String locationName;
  final String parentPath;
  final String imageUrl;
  final VoidCallback? onTap;
  final Key? locationKey;

  @override
  Widget build(BuildContext context) {
    final body = kLocationChatStyle.bubbleTextStyle;
    final normalizedImage = imageUrl.trim();
    final hasRealImage =
        normalizedImage.isNotEmpty &&
        localDefaultMapImageAssetForBackendImageUrl(normalizedImage) == null &&
        !normalizedImage.startsWith('assets/images/map_default/');
    final fallback = ColoredBox(
      color: GenesisColors.darkCardBackground,
      child: Center(
        child: SvgPicture.asset(
          createOriginLocationsIconAsset,
          width: 18,
          height: 18,
          colorFilter: const ColorFilter.mode(
            GenesisColors.darkTextSecondary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
    final surface = Material(
      color: GenesisColors.darkCardBackground,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: locationKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 34,
                  height: 51,
                  child: !hasRealImage
                      ? fallback
                      : GenesisStaticNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_) => fallback,
                          errorWidget: (_, _) => fallback,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (names.isNotEmpty)
                            TextSpan(
                              text: names,
                              style: body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: GenesisColors.darkTextPrimary,
                              ),
                            ),
                          TextSpan(
                            text: '${names.isEmpty ? '' : ' '}$action',
                            style: body.copyWith(
                              color: GenesisColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      style: body,
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (parentPath.isNotEmpty)
                            TextSpan(
                              text: '$parentPath >\n',
                              style: body.copyWith(
                                fontSize: 12,
                                height: 1.3,
                                color: GenesisColors.darkTextSecondary,
                              ),
                            ),
                          TextSpan(
                            text: locationName,
                            style: body.copyWith(
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: GenesisColors.redSecondary,
                            ),
                          ),
                        ],
                      ),
                      style: body.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: GenesisColors.darkTextSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return ChatStableBackdropSurface(
      sigma: GenesisBlur.strong,
      borderRadius: BorderRadius.circular(8),
      child: surface,
    );
  }
}
