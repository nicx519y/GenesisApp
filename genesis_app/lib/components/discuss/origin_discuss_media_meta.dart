part of 'origin_discuss_library.dart';

class _DiscussImageThumbnail extends StatelessWidget {
  const _DiscussImageThumbnail({required this.url, required this.onTap});

  static const double size = 48;

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();

    return GestureDetector(
      key: ValueKey('origin-discuss-image-$imageUrl'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GenesisListImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        borderRadius: GenesisImageRadii.content,
      ),
    );
  }
}

class _DiscussPreviewMeta extends StatelessWidget {
  const _DiscussPreviewMeta({
    required this.item,
    this.disabled = false,
    this.onAuthorTap,
  });

  final OriginDiscussListItem item;
  final bool disabled;
  final OriginDiscussItemTap? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final authorMeta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            item.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.genesisColors.textFaint,
              fontSize: 12,
              height: 1.18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DiscussStoryBadge(count: item.storyCount),
      ],
    );
    final authorTap = onAuthorTap;
    final canOpenAuthor =
        !disabled &&
        (authorTap != null ||
            (item.authorUid.trim().isNotEmpty && !item.authorDeleted));

    return SizedBox(
      key: ValueKey('origin-discuss-meta-${item.discussId}'),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: canOpenAuthor
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (authorTap != null) {
                        authorTap(item);
                        return;
                      }
                      Navigator.of(context).pushNamed(
                        RouteNames.userInfo,
                        arguments: {'uid': item.authorUid},
                      );
                    },
                    child: authorMeta,
                  )
                : authorMeta,
          ),
          if (item.createdAt != null) ...[
            const SizedBox(width: 8),
            GenesisTimestampText(
              timestamp: item.createdAt,
              style: _subtleStyle.copyWith(
                color: context.genesisColors.textTimestamp,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscussAvatarLink extends StatelessWidget {
  const _DiscussAvatarLink({
    required this.item,
    this.disabled = false,
    this.onTap,
  });

  final OriginDiscussListItem item;
  final bool disabled;
  final OriginDiscussItemTap? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = _DiscussAvatar(item: item);
    if (disabled) return avatar;
    final authorTap = onTap;
    if (authorTap == null &&
        (item.authorUid.trim().isEmpty || item.authorDeleted)) {
      return avatar;
    }
    return GestureDetector(
      key: ValueKey('origin-discuss-avatar-${item.authorUid}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (authorTap != null) {
          authorTap(item);
          return;
        }
        Navigator.of(
          context,
        ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.authorUid});
      },
      child: avatar,
    );
  }
}

class _DiscussAvatar extends StatelessWidget {
  const _DiscussAvatar({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    final avatar = item.avatar.trim();
    return GenesisAvatar(
      url: avatar,
      name: item.authorName,
      size: _discussAvatarSize,
      borderRadius: GenesisAvatarRadii.user,
    );
  }
}

const _subtleStyle = TextStyle(
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

List<String> _imageUrlsFrom(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }
  if (value is! List) return const <String>[];
  return value
      .map((raw) {
        if (raw is Map) {
          final map = asJsonMap(raw);
          return asImageUrl(
            map['url'] ?? map['image_url'] ?? map['image'],
            fallback: raw,
          );
        }
        return asString(raw);
      })
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}
