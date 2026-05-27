import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/json_utils.dart';
import '../../utils/stat_count_formatter.dart';

typedef OriginDiscussPreviewLoader =
    Future<List<OriginDiscussPreviewItem>> Function(String oid);

Future<List<OriginDiscussPreviewItem>> loadOriginDiscussPreviewItems(
  BuildContext context,
  String oid,
) async {
  final resolvedOid = oid.trim();
  if (resolvedOid.isEmpty) return const <OriginDiscussPreviewItem>[];

  final data = await AppServicesScope.read(
    context,
  ).api.v1.discuss.list(bizId: resolvedOid, pn: 1, rn: 2);
  final rawList = data['list'];
  if (rawList is! List) return const <OriginDiscussPreviewItem>[];
  return rawList
      .whereType<Map>()
      .map((raw) => asJsonMap(raw))
      .map((raw) => raw['comment'] is Map ? asJsonMap(raw['comment']) : raw)
      .map(OriginDiscussPreviewItem.fromJson)
      .where((item) => item.content.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);
}

class OriginDiscussPreviewItem {
  const OriginDiscussPreviewItem({
    required this.authorName,
    required this.avatar,
    required this.content,
    required this.replyCount,
    required this.createdAt,
    required this.seed,
  });

  final String authorName;
  final String avatar;
  final String content;
  final int replyCount;
  final DateTime? createdAt;
  final String seed;

  factory OriginDiscussPreviewItem.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map ? asJsonMap(json['author']) : null;
    final uid = asString(author?['uid'], fallback: asString(json['uid']));
    final name = asString(
      author?['name'] ??
          author?['user_name'] ??
          author?['nickname'] ??
          author?['display_name'] ??
          json['author_name'] ??
          json['user_name'],
      fallback: 'User',
    );
    return OriginDiscussPreviewItem(
      authorName: name,
      avatar: asString(author?['avatar'] ?? author?['avatar_url']),
      content: asString(json['content']),
      replyCount: asInt(json['reply_cnt']),
      createdAt: _parseDateTime(json['created_at']),
      seed: uid.isEmpty ? name : uid,
    );
  }
}

class OriginDiscussPreviewList extends StatefulWidget {
  const OriginDiscussPreviewList({
    super.key,
    required this.oid,
    required this.count,
    this.showHeader = true,
    this.loader,
  });

  final String oid;
  final int count;
  final bool showHeader;
  final OriginDiscussPreviewLoader? loader;

  @override
  State<OriginDiscussPreviewList> createState() =>
      _OriginDiscussPreviewListState();
}

class _OriginDiscussPreviewListState extends State<OriginDiscussPreviewList> {
  Future<List<OriginDiscussPreviewItem>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant OriginDiscussPreviewList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid || oldWidget.loader != widget.loader) {
      _future = _load();
    }
  }

  Future<List<OriginDiscussPreviewItem>> _load() async {
    final oid = widget.oid.trim();
    if (oid.isEmpty) return const <OriginDiscussPreviewItem>[];
    final loader = widget.loader;
    if (loader != null) return loader(oid);
    return loadOriginDiscussPreviewItems(context, oid);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) _DiscussHeader(count: widget.count),
        FutureBuilder<List<OriginDiscussPreviewItem>>(
          future: _future,
          builder: (context, snapshot) {
            final comments =
                snapshot.data ?? const <OriginDiscussPreviewItem>[];
            if (comments.isEmpty) {
              return SizedBox(height: widget.showHeader ? 12 : 0);
            }

            return Padding(
              padding: EdgeInsets.only(top: widget.showHeader ? 12 : 0),
              child: Column(
                children: [
                  for (final entry in comments.indexed) ...[
                    _DiscussPreviewRow(item: entry.$2),
                    if (entry.$1 != comments.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DiscussHeader extends StatelessWidget {
  const _DiscussHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(MyFlutterApp.discuss, size: 14, color: Color(0xFF1D1D1D)),
        const SizedBox(width: 6),
        Text(
          'Discuss (${formatStatCount(count)})',
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DiscussPreviewRow extends StatelessWidget {
  const _DiscussPreviewRow({required this.item});

  final OriginDiscussPreviewItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscussAvatar(item: item),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscussPreviewMeta(item: item),
              const SizedBox(height: 5),
              Text(
                item.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1D1D1D),
                  fontSize: 12,
                  height: 1.38,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscussPreviewMeta extends StatelessWidget {
  const _DiscussPreviewMeta({required this.item});

  final OriginDiscussPreviewItem item;

  @override
  Widget build(BuildContext context) {
    final date = _dateLabel(item.createdAt);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  item.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                MyFlutterApp.skipNext,
                size: 15,
                color: Color(0xFF8B8B8B),
              ),
              const SizedBox(width: 4),
              Text('${item.replyCount}', style: _metaStyle),
            ],
          ),
        ),
        if (date.isNotEmpty) ...[const Spacer(), Text(date, style: _metaStyle)],
      ],
    );
  }
}

class _DiscussAvatar extends StatelessWidget {
  const _DiscussAvatar({required this.item});

  final OriginDiscussPreviewItem item;

  @override
  Widget build(BuildContext context) {
    final avatar = item.avatar.trim();
    final fallback = _DiscussAvatarFallback(
      seed: item.seed,
      label: item.authorName,
    );
    if (avatar.isEmpty) return fallback;

    final image = avatar.startsWith('assets/')
        ? Image.asset(
            avatar,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.network(
            avatar,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return fallback;
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(width: 30, height: 30, child: image),
    );
  }
}

class _DiscussAvatarFallback extends StatelessWidget {
  const _DiscussAvatarFallback({required this.seed, required this.label});

  final String seed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim().characters.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _gradientFor(seed)),
        ),
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

const _metaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.1,
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

String _dateLabel(DateTime? value) {
  if (value == null) return '';
  return '${value.year}/${value.month}/${value.day}';
}

List<Color> _gradientFor(String seed) {
  final hash = seed.codeUnits.fold<int>(
    0,
    (a, b) => (a * 131 + b) & 0x7fffffff,
  );
  int tint(int v) => 0xFF000000 | (v & 0x00FFFFFF) | 0x00303030;
  return [Color(tint(hash)), Color(tint(hash * 17))];
}
