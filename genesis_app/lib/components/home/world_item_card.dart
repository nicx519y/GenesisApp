import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../utils/stat_count_formatter.dart';

@immutable
class WorldListItem {
  const WorldListItem({
    required this.oid,
    required this.originVersionNum,
    required this.originVersionCreateAt,
    required this.wid,
    required this.status,
    required this.name,
    required this.cover,
    required this.displaySubtitle,
    required this.createdUid,
    required this.createdUserName,
    required this.ownerUid,
    required this.ownerName,
    required this.createdAt,
    required this.updatedAt,
    required this.lastProgressAt,
    required this.lastProgressSummary,
    required this.previewImages,
    required this.tags,
    required this.tickCnt,
    required this.connectCnt,
    required this.aiCharacterCnt,
    required this.playerCnt,
    required this.locationCnt,
    required this.coverHeight,
  });

  factory WorldListItem.fromJson(Map<String, dynamic> json) {
    final info = json['info'] is Map ? asJsonMap(json['info']) : json;
    final stats = json['stats'] is Map ? asJsonMap(json['stats']) : json;
    final lastTick = json['last_tick'] is Map
        ? asJsonMap(json['last_tick'])
        : (info['last_tick'] is Map
              ? asJsonMap(info['last_tick'])
              : const <String, dynamic>{});
    final wid = asString(info['wid'], fallback: asString(info['world_id']));
    final name = asString(
      info['name'],
      fallback: asString(info['world_name'], fallback: wid),
    );
    return WorldListItem(
      oid: asString(info['oid'], fallback: asString(info['origin_id'])),
      originVersionNum: asInt(info['origin_version_num']),
      originVersionCreateAt: asString(
        info['origin_version_create_at'],
        fallback: asString(info['origin_version_time']),
      ),
      wid: wid,
      status: asInt(info['status']),
      name: name.trim().isEmpty ? wid : name,
      cover: resolveAssetUrl(
        asString(info['cover'], fallback: asString(info['map_url'])),
      ),
      displaySubtitle: asString(
        info['display_subtitle'],
        fallback: asString(info['brief']),
      ),
      createdUid: asString(info['created_uid']),
      createdUserName: asString(info['created_user_name']),
      ownerUid: asString(
        info['owner_uid'],
        fallback: asString(info['created_uid']),
      ),
      ownerName: asString(
        info['owner_name'],
        fallback: asString(info['created_user_name']),
      ),
      createdAt: asString(info['created_at']),
      updatedAt: asString(info['updated_at']),
      lastProgressAt: asString(
        info['last_progress_at'],
        fallback: asString(info['updated_at']),
      ),
      lastProgressSummary: asString(lastTick['narrator']),
      previewImages: _previewImagesFromJson(info),
      tags: _tagsFromJson(info['tags']),
      tickCnt: asInt(stats['tick_cnt']),
      connectCnt: asInt(stats['connect_cnt']),
      aiCharacterCnt: asInt(
        stats['ai_character_cnt'],
        fallback: asInt(stats['character_cnt']),
      ),
      playerCnt: asInt(stats['player_cnt']),
      locationCnt: asInt(stats['location_cnt']),
      coverHeight: _coverHeightFor(wid.isEmpty ? name : wid),
    );
  }

  final String oid;
  final int originVersionNum;
  final String originVersionCreateAt;
  final String wid;
  final int status;
  final String name;
  final String cover;
  final String displaySubtitle;
  final String createdUid;
  final String createdUserName;
  final String ownerUid;
  final String ownerName;
  final String createdAt;
  final String updatedAt;
  final String lastProgressAt;
  final String lastProgressSummary;
  final List<String> previewImages;
  final List<String> tags;
  final int tickCnt;
  final int connectCnt;
  final int aiCharacterCnt;
  final int playerCnt;
  final int locationCnt;
  final double coverHeight;

  String get title => name.trim().isEmpty ? wid : name.trim();
  String get ownerLabel {
    final owner = ownerName.trim();
    if (owner.isNotEmpty) return owner;
    final creator = createdUserName.trim();
    if (creator.isNotEmpty) return creator;
    return ownerUid.trim().isEmpty ? '-' : ownerUid.trim();
  }

  String get subtitle => displaySubtitle.trim().isEmpty
      ? 'Updated $updatedAt'
      : displaySubtitle.trim();

  String get progressSummary => lastProgressSummary.trim();

  List<String> get resolvedPreviewImages {
    if (previewImages.isNotEmpty) return previewImages;
    final image = cover.trim();
    if (image.isEmpty) return const <String>[];
    return <String>[image, image];
  }
}

class WorldItemCard extends StatelessWidget {
  const WorldItemCard({super.key, required this.item});

  final WorldListItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorldImage(
          imageUrl: item.cover,
          seed: item.wid.isEmpty ? item.title : item.wid,
          label: _badgeText(item.title),
          width: 48,
          height: 48,
          borderRadius: 8,
        ),
        const SizedBox(width: 14),
        Expanded(child: _WorldItemBody(item: item)),
      ],
    );
  }
}

class _WorldItemBody extends StatelessWidget {
  const _WorldItemBody({required this.item});

  final WorldListItem item;

  @override
  Widget build(BuildContext context) {
    final previewImages = item.resolvedPreviewImages.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#${item.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'WID: ${item.wid}   Owner: ${item.ownerLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF8B8B8B),
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        _WorldStatsRow(item: item),
        const SizedBox(height: 12),
        _ProgressHeader(timeText: _relativeTime(item.lastProgressAt)),
        const SizedBox(height: 10),
        Text(
          item.progressSummary,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 12,
            height: 1.33,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (previewImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              for (final entry in previewImages.indexed) ...[
                Expanded(
                  child: _WorldImage(
                    imageUrl: entry.$2,
                    seed: '${item.wid}-${entry.$1}',
                    label: _badgeText(item.title),
                    height: 120,
                    borderRadius: 5,
                  ),
                ),
                if (entry.$1 != previewImages.length - 1)
                  const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _WorldStatsRow extends StatelessWidget {
  const _WorldStatsRow({required this.item});

  final WorldListItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Stat(icon: MyFlutterApp.pregress, value: item.tickCnt),
        _Stat(icon: MyFlutterApp.copy, value: item.connectCnt),
        _Stat(icon: MyFlutterApp.userStar, value: item.aiCharacterCnt),
        _Stat(icon: MyFlutterApp.user, value: item.playerCnt),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.black),
        const SizedBox(width: 4),
        Text(
          formatStatCount(value),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.timeText});

  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(MyFlutterApp.pregress, color: Color(0xFFFF2344), size: 11),
        const SizedBox(width: 5),
        const Text(
          'Last Progress',
          style: TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (timeText.isNotEmpty) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              timeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8B8B8B),
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WorldImage extends StatelessWidget {
  const _WorldImage({
    required this.imageUrl,
    required this.seed,
    required this.label,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final String seed;
  final String label;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _CoverPlaceholder(seed: seed, label: label);
    final image = imageUrl.trim().isEmpty
        ? placeholder
        : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => placeholder,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.seed, required this.label});

  final String seed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _tagsFromJson(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

List<String> _previewImagesFromJson(Map<String, dynamic> info) {
  for (final key in const [
    'last_progress_images',
    'progress_images',
    'preview_images',
    'images',
  ]) {
    final value = info[key];
    if (value is List) {
      return value
          .map((e) => resolveAssetUrl(e.toString()))
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false);
    }
  }
  return const <String>[];
}

double _coverHeightFor(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return (160 + (hash % 120)).clamp(140, 260).toDouble();
}

List<Color> _gradientFor(String seed) {
  final hash = seed.codeUnits.fold<int>(
    0,
    (a, b) => (a * 131 + b) & 0x7fffffff,
  );
  int tint(int v) => 0xFF000000 | (v & 0x00FFFFFF) | 0x00303030;
  return [Color(tint(hash)), Color(tint(hash * 17))];
}

String _badgeText(String name) {
  final cleaned = name.replaceAll('#', '').trim();
  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .toList();
  if (words.isEmpty) return 'ENTER\nWORLD';
  return words.take(4).map((e) => e.toUpperCase()).join('\n');
}

String _relativeTime(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} mins ago';
  if (diff.inDays < 1) return '${diff.inHours} hrs ago';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mos ago';
  return '${(diff.inDays / 365).floor()} yrs ago';
}
