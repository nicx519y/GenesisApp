import 'package:flutter/material.dart';

import 'stat_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/genesis_ugc_text.dart';
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
    final name = decodeGenesisUgcTextForDisplay(
      asString(
        info['name'],
        fallback: asString(info['origin_name'], fallback: oid),
      ),
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
      displaySubtitle: decodeGenesisUgcTextForDisplay(
        asString(info['display_subtitle'], fallback: asString(info['brief'])),
      ),
      worldView: decodeGenesisUgcTextForDisplay(
        asString(info['world_view'], fallback: asString(info['setting'])),
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
    final colors = context.genesisColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: AspectRatio(
            aspectRatio: _coverAspectRatio,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GenesisListImage(
                    imageUrl: item.cover,
                    maxDevicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0, 0.46, 1],
                        colors: [
                          colors.textInverse.withValues(alpha: 0.92),
                          colors.textInverse.withValues(alpha: 0.62),
                          colors.textInverse.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        _ImageStat(
                          iconAsset: originFeedPlayIconAsset,
                          value: item.copyCnt,
                        ),
                        const SizedBox(width: 11),
                        _ImageStat(
                          iconAsset: originFeedCommentIconAsset,
                          value: item.connectCnt,
                        ),
                        const SizedBox(width: 11),
                        _ImageStat(
                          iconAsset: originFeedRoleIconAsset,
                          iconColor: colors.accentText,
                          value: item.characterCnt,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          originDisplayName(item.title),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          item.subtitle,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.55,
          ),
        ),
        if (item.tags.isNotEmpty) ...[
          const SizedBox(height: 5),
          _TagWrap(tags: item.tags),
        ],
      ],
    );
  }
}

class _ImageStat extends StatelessWidget {
  const _ImageStat({
    required this.iconAsset,
    this.iconColor,
    required this.value,
  });

  final String iconAsset;
  final Color? iconColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: StatItem(
          iconAsset: iconAsset,
          iconSize: 12,
          iconColor:
              iconColor ??
              context.genesisColors.textPrimary.withValues(alpha: 0.92),
          gap: 4,
          text: formatStatCount(value),
          textStyle: TextStyle(
            color: context.genesisColors.textPrimary,
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w600,
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
    final colors = context.genesisColors;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final tag in tags)
          Builder(
            builder: (context) {
              final trending = tag.toLowerCase() == 'trending';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: trending
                      ? colors.primary.withValues(alpha: 0.18)
                      : colors.surfaceTag,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  softWrap: false,
                  style: TextStyle(
                    color: trending ? colors.accentText : colors.textSecondary,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
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
