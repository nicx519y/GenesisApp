import '../../l10n/genesis_l10n.dart';
import '../gems/pro_user_name.dart';
import 'package:flutter/material.dart';

import '../../network/json_utils.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/genesis_localized_rich_text.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../common/genesis_image_viewer_overlay.dart';

class OriginDiscussRepliesList extends StatelessWidget {
  const OriginDiscussRepliesList({
    super.key,
    required this.discussId,
    required this.replies,
    required this.remainingReplyCount,
    required this.isLoading,
    required this.onLoadMore,
    this.onReplyTap,
  });

  final String discussId;
  final List<Map<String, dynamic>> replies;
  final int remainingReplyCount;
  final bool isLoading;
  final VoidCallback onLoadMore;
  final void Function(Map<String, dynamic> reply)? onReplyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFD9DDE2), width: 3)),
      ),
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final reply in replies) ...[
              _OriginDiscussReplyItem(
                reply: reply,
                onTap: onReplyTap == null ? null : () => onReplyTap!(reply),
              ),
              const SizedBox(height: 6),
            ],
            if (remainingReplyCount > 0)
              GestureDetector(
                key: ValueKey('origin-discuss-view-all-replies-$discussId'),
                behavior: HitTestBehavior.opaque,
                onTap: isLoading ? null : onLoadMore,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: isLoading
                      ? const SizedBox.square(
                          key: ValueKey('origin-discuss-replies-loading'),
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          GenesisL10n.current
                              .worldoViewAllRemainingReplyCount(
                                remainingReplyCount: (remainingReplyCount)
                                    .toString(),
                              ),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2F4F7A),
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

class _OriginDiscussReplyItem extends StatelessWidget {
  const _OriginDiscussReplyItem({required this.reply, this.onTap});

  final Map<String, dynamic> reply;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrlsFrom(reply['images'] ?? reply['image_urls']);
    final replyToName = _replyToName(reply);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenesisLocalizedRichText(
          template: _replyLineTemplate(context, reply),
          placeholders: _replyLinePlaceholders(reply),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _subtleStyle.copyWith(
            color: replyToName.isEmpty
                ? const Color(0xFF60636A)
                : const Color(0xFF111111),
            height: 1.35,
          ),
        ),
        if (imageUrls.isNotEmpty) ...[
          const SizedBox(height: 6),
          _OriginDiscussReplyImageThumbnails(urls: imageUrls),
        ],
      ],
    );
    if (onTap == null) return content;

    final replyId = asString(reply['discuss_id']);
    return GestureDetector(
      key: ValueKey('origin-discuss-reply-item-$replyId'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: double.infinity, child: content),
    );
  }
}

class _OriginDiscussReplyImageThumbnails extends StatelessWidget {
  const _OriginDiscussReplyImageThumbnails({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final visibleUrls = urls.take(6).toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in visibleUrls.indexed)
          _OriginDiscussReplyImageThumbnail(
            url: entry.$2,
            onTap: () => showGenesisImageViewer(
              context,
              imageUrls: urls,
              previewImageProviders: [
                for (final url in urls)
                  genesisImageViewerListPreviewProvider(
                    context,
                    source: url,
                    logicalWidth: _OriginDiscussReplyImageThumbnail._size,
                    logicalHeight: _OriginDiscussReplyImageThumbnail._size,
                  ),
              ],
              initialIndex: entry.$1,
            ),
          ),
      ],
    );
  }
}

class _OriginDiscussReplyImageThumbnail extends StatelessWidget {
  const _OriginDiscussReplyImageThumbnail({
    required this.url,
    required this.onTap,
  });

  final String url;
  final VoidCallback onTap;
  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();

    return GestureDetector(
      key: ValueKey('origin-discuss-reply-image-$imageUrl'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GenesisListImage(
        imageUrl: imageUrl,
        width: _size,
        height: _size,
        borderRadius: GenesisImageRadii.content,
      ),
    );
  }
}

String _replyLineTemplate(BuildContext context, Map<String, dynamic> json) {
  final authorName = GenesisLocalizedRichText.placeholder('authorName');
  final authorBadge = GenesisLocalizedRichText.placeholder('authorBadge');
  final content = GenesisLocalizedRichText.placeholder('content');
  return _replyToName(json).isEmpty
      ? context.l10n.discussReplyLineDirect(
          authorName: authorName,
          authorBadge: authorBadge,
          content: content,
        )
      : context.l10n.discussReplyLine(
          authorName: authorName,
          authorBadge: authorBadge,
          replyToName: GenesisLocalizedRichText.placeholder('replyToName'),
          replyToBadge: GenesisLocalizedRichText.placeholder('replyToBadge'),
          content: content,
        );
}

Map<String, InlineSpan> _replyLinePlaceholders(Map<String, dynamic> json) {
  final author = json['author'] is Map ? asJsonMap(json['author']) : null;
  final uid = asString(author?['uid'], fallback: asString(json['uid']));
  final name = asString(
    author?['name'] ??
        author?['user_name'] ??
        author?['nickname'] ??
        author?['display_name'] ??
        json['author_name'] ??
        json['user_name'],
    fallback: formatUidForDisplay(uid, fallback: GenesisL10n.current.userLabel),
  );
  final content = asString(json['content']);
  final authorName = formatUidForDisplay(
    name,
    fallback: GenesisL10n.current.userLabel,
  );
  final replyToName = _replyToName(json);
  return <String, InlineSpan>{
    'authorName': TextSpan(
      text: authorName,
      style: const TextStyle(color: Color(0xFF60636A)),
    ),
    'authorBadge': ProUserBadge.span(
      membershipStatus: asUserMembershipStatus(author?['membership_status']),
      fontSize: 12,
      deleted: asBool(author?['deleted'] ?? json['author_deleted']),
    ),
    'content': TextSpan(
      text: content,
      style: const TextStyle(color: Color(0xFF111111)),
    ),
    if (replyToName.isNotEmpty) ...{
      'replyToName': TextSpan(
        text: replyToName,
        style: const TextStyle(color: Color(0xFF60636A)),
      ),
      'replyToBadge': ProUserBadge.span(
        membershipStatus: asUserMembershipStatus(
          asOptionalJsonMap(json['reply_to_user'])['membership_status'],
        ),
        fontSize: 12,
        deleted: entityDeleted(
          asOptionalJsonMap(json['reply_to_user'])['deleted'],
        ),
      ),
    },
  };
}

String _replyToName(Map<String, dynamic> json) {
  final parentDiscussId = asString(json['parent_discuss_id']).trim();
  final rootDiscussId = asString(json['root_discuss_id']).trim();
  if (parentDiscussId.isEmpty ||
      rootDiscussId.isEmpty ||
      parentDiscussId == rootDiscussId) {
    return '';
  }
  final replyToUsername = asString(json['reply_to_username']).trim();
  return replyToUsername.isNotEmpty
      ? replyToUsername
      : asString(json['reply_to_uid']).trim();
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

const _subtleStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);
