import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/stat_count_formatter.dart';

const String _connectIconAsset = 'assets/custom-icons/png/connect.png';

@immutable
class OriginListItem {
  const OriginListItem({
    required this.oid,
    required this.status,
    required this.versionNum,
    required this.name,
    required this.cover,
    required this.displaySubtitle,
    required this.worldView,
    required this.createdUid,
    required this.createdUserName,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.copyCnt,
    required this.connectCnt,
    required this.discussCnt,
    required this.characterCnt,
    required this.locationCnt,
    required this.coverHeight,
  });

  factory OriginListItem.fromJson(Map<String, dynamic> json) {
    final info = json['info'] is Map ? asJsonMap(json['info']) : json;
    final stats = json['stats'] is Map ? asJsonMap(json['stats']) : json;
    final oid = asString(info['oid'], fallback: asString(info['origin_id']));
    final name = asString(
      info['name'],
      fallback: asString(info['origin_name'], fallback: oid),
    );
    return OriginListItem(
      oid: oid,
      status: asInt(info['status']),
      versionNum: asInt(
        info['version_num'],
        fallback: asInt(info['origin_version']),
      ),
      name: name.trim().isEmpty ? oid : name,
      cover: resolveAssetUrl(
        asString(info['cover'], fallback: asString(info['map_url'])),
      ),
      displaySubtitle: asString(
        info['display_subtitle'],
        fallback: asString(info['brief']),
      ),
      worldView: asString(
        info['world_view'],
        fallback: asString(info['setting']),
      ),
      createdUid: asString(info['created_uid']),
      createdUserName: asString(info['created_user_name']),
      createdAt: asString(info['created_at']),
      updatedAt: asString(info['updated_at']),
      tags: _tagsFromJson(info['tags']),
      copyCnt: asInt(stats['copy_cnt']),
      connectCnt: asInt(stats['connect_cnt']),
      discussCnt: asInt(stats['discuss_cnt']),
      characterCnt: asInt(stats['character_cnt']),
      locationCnt: asInt(stats['location_cnt']),
      coverHeight: _coverHeightFor(oid.isEmpty ? name : oid),
    );
  }

  final String oid;
  final int status;
  final int versionNum;
  final String name;
  final String cover;
  final String displaySubtitle;
  final String worldView;
  final String createdUid;
  final String createdUserName;
  final String createdAt;
  final String updatedAt;
  final List<String> tags;
  final int copyCnt;
  final int connectCnt;
  final int discussCnt;
  final int characterCnt;
  final int locationCnt;
  final double coverHeight;

  String get title => name.trim().isEmpty ? oid : name.trim();
  String get subtitle {
    final display = displaySubtitle.trim();
    if (display.isNotEmpty) return display;
    final view = worldView.trim();
    if (view.isNotEmpty) return view;
    return 'Updated $updatedAt';
  }
}

class OriginItemCard extends StatelessWidget {
  const OriginItemCard({super.key, required this.item});

  final OriginListItem item;

  @override
  Widget build(BuildContext context) {
    final coverPlaceholder = _CoverPlaceholder(
      seed: item.oid.isEmpty ? item.title : item.oid,
      label: _badgeText(item.title),
    );
    final cover = item.cover.trim().isEmpty
        ? coverPlaceholder
        : Image.network(
            item.cover,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => coverPlaceholder,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return coverPlaceholder;
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: item.coverHeight,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(child: cover),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        _ImageStat(
                          icon: MyFlutterApp.save,
                          value: item.copyCnt,
                        ),
                        const SizedBox(width: 10),
                        _ImageStat(
                          iconAsset: _connectIconAsset,
                          value: item.connectCnt,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          originDisplayName(item.title),
          style: const TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.subtitle,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w400,
            fontSize: 10,
            height: 1.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _TagWrap(tags: item.tags),
      ],
    );
  }
}

class _ImageStat extends StatelessWidget {
  const _ImageStat({this.icon, this.iconAsset, required this.value})
    : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset case final asset?)
            ImageIcon(AssetImage(asset), size: 11, color: Colors.white)
          else
            Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              formatStatCount(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
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

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags.take(3))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Color(0xFF4B6192),
                fontSize: 10,
                height: 1.7,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
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
