import 'package:flutter/material.dart';

import '../../network/json_utils.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../utils/display_name_formatter.dart';
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
                          'View all $remainingReplyCount replies',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _replyLine(reply),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _subtleStyle.copyWith(
            color: const Color(0xFF60636A),
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

  @override
  Widget build(BuildContext context) {
    const size = 32.0;
    final imageUrl = url.trim();

    return GestureDetector(
      key: ValueKey('origin-discuss-reply-image-$imageUrl'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GenesisListImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

String _replyLine(Map<String, dynamic> json) {
  final author = json['author'] is Map ? asJsonMap(json['author']) : null;
  final uid = asString(author?['uid'], fallback: asString(json['uid']));
  final name = asString(
    author?['name'] ??
        author?['user_name'] ??
        author?['nickname'] ??
        author?['display_name'] ??
        json['author_name'] ??
        json['user_name'],
    fallback: formatUidForDisplay(uid, fallback: 'User'),
  );
  final content = asString(json['content']);
  return '${formatUidForDisplay(name, fallback: 'User')}: $content';
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
          return asString(map['url'] ?? map['image_url'] ?? map['image']);
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
