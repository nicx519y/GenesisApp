import 'package:flutter/material.dart';

import 'stat_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/stat_count_formatter.dart';

const double _coverAspectRatio = 2 / 3;

@immutable
class OriginListItem {
  const OriginListItem({
    required this.oid,
    this.wid = '',
    required this.status,
    required this.versionNum,
    this.tickCount = 0,
    required this.name,
    this.deleted = false,
    required this.cover,
    required this.displaySubtitle,
    required this.worldView,
    required this.createdUid,
    required this.createdUserName,
    this.ownerName = '',
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.copyCnt,
    required this.connectCnt,
    required this.discussCnt,
    required this.characterCnt,
    required this.locationCnt,
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
      wid: asString(info['wid'], fallback: asString(info['world_id'])),
      status: asInt(info['status']),
      versionNum: asInt(
        info['version_num'],
        fallback: asInt(info['origin_version']),
      ),
      tickCount: asInt(
        stats['story_cnt'],
        fallback: asInt(
          stats['tick_cnt'],
          fallback: asInt(stats['max_tick_cnt']),
        ),
      ),
      name: name.trim().isEmpty ? oid : name,
      deleted: entityDeleted(info['deleted'], fallback: info['origin_deleted']),
      cover: resolveAssetUrl(
        asImageUrl(info['cover'], fallback: info['map_url']),
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
      ownerName: asString(info['owner_name']),
      createdAt: asString(info['created_at']),
      updatedAt: asString(info['updated_at']),
      tags: _tagsFromJson(info['tags']),
      copyCnt: asInt(stats['copy_cnt']),
      connectCnt: asInt(stats['connect_cnt']),
      discussCnt: asInt(stats['discuss_cnt']),
      characterCnt: asInt(stats['character_cnt']),
      locationCnt: asInt(stats['location_cnt']),
    );
  }

  final String oid;
  final String wid;
  final int status;
  final int versionNum;
  final int tickCount;
  final String name;
  final bool deleted;
  final String cover;
  final String displaySubtitle;
  final String worldView;
  final String createdUid;
  final String createdUserName;
  final String ownerName;
  final String createdAt;
  final String updatedAt;
  final List<String> tags;
  final int copyCnt;
  final int connectCnt;
  final int discussCnt;
  final int characterCnt;
  final int locationCnt;

  String get title => name.trim().isEmpty ? oid : name.trim();
  String get subtitle {
    final display = displaySubtitle.trim();
    if (display.isNotEmpty) return display;
    final view = worldView.trim();
    if (view.isNotEmpty) return view;
    return 'Updated ${formatGenesisTimestamp(updatedAt)}';
  }
}

class OriginItemCard extends StatelessWidget {
  const OriginItemCard({super.key, required this.item});

  final OriginListItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: GenesisImageRadii.content,
          child: AspectRatio(
            aspectRatio: _coverAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(child: GenesisListImage(imageUrl: item.cover)),
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
                          iconAsset: copyStatIconAsset,
                          value: item.copyCnt,
                        ),
                        const SizedBox(width: 10),
                        _ImageStat(
                          iconAsset: connectStatIconAsset,
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
            color: Color(0xFF888888),
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.2,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _TagWrap(tags: item.tags),
      ],
    );
  }
}

class _ImageStat extends StatelessWidget {
  const _ImageStat({required this.iconAsset, required this.value});

  final String iconAsset;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: StatItem(
        iconAsset: iconAsset,
        iconSize: 11,
        iconColor: Colors.white,
        gap: 4,
        text: formatStatCount(value),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});

  final List<String> tags;

  static const double _spacing = 6;
  static const double _runSpacing = 6;
  static const double _horizontalPadding = 4;
  static const TextStyle _textStyle = TextStyle(
    color: Color(0xFF4B6192),
    fontSize: 10,
    height: 1.7,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleTags = _visibleTagsForRows(
          tags: tags,
          maxWidth: constraints.maxWidth,
          textDirection: Directionality.of(context),
        );
        if (visibleTags.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: _spacing,
          runSpacing: _runSpacing,
          children: [
            for (final tag in visibleTags)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  tag,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: _textStyle,
                ),
              ),
          ],
        );
      },
    );
  }

  List<String> _visibleTagsForRows({
    required List<String> tags,
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    if (!maxWidth.isFinite) return tags;

    const maxRows = 2;
    final visibleTags = <String>[];
    var row = 1;
    var rowWidth = 0.0;

    for (final tag in tags) {
      final tagWidth = _measureTagWidth(tag, textDirection);
      final nextWidth = rowWidth == 0
          ? tagWidth
          : rowWidth + _spacing + tagWidth;
      if (nextWidth <= maxWidth || rowWidth == 0) {
        visibleTags.add(tag);
        rowWidth = nextWidth;
        continue;
      }

      row += 1;
      if (row > maxRows) break;
      visibleTags.add(tag);
      rowWidth = tagWidth;
    }

    return visibleTags;
  }

  double _measureTagWidth(String tag, TextDirection textDirection) {
    final painter = TextPainter(
      text: TextSpan(text: tag, style: _textStyle),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();
    return painter.width + _horizontalPadding * 2;
  }
}

List<String> _tagsFromJson(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
