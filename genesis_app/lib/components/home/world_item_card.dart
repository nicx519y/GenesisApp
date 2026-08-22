import 'package:flutter/material.dart';

import '../../components/origin/stat_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../components/common/genesis_timestamp_text.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
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
    this.deleted = false,
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
    required this.lastProgressTickNo,
    required this.lastProgressSubTickNo,
    required this.lastProgressCurrentTime,
    required this.previewImages,
    required this.tags,
    required this.metric,
    this.myCharacter,
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
      deleted: entityDeleted(
        json['world_deleted'],
        fallback: entityDeleted(
          info['world_deleted'],
          fallback: info['deleted'],
        ),
      ),
      cover: resolveAssetUrl(
        asImageUrl(info['cover'], fallback: info['map_url']),
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
      lastProgressAt: asString(lastTick['created_at']),
      lastProgressSummary: asString(lastTick['narrator']),
      lastProgressTickNo: asInt(
        lastTick['tick_no'],
        fallback: asInt(lastTick['tick_index']),
      ),
      lastProgressSubTickNo: asInt(lastTick['sub_tick_no']),
      lastProgressCurrentTime: asString(
        lastTick['current_time'],
        fallback: asString(info['current_time']),
      ),
      previewImages: _previewImagesFromJson(info),
      tags: _tagsFromJson(info['tags']),
      metric: info['metric'] is Map
          ? asJsonMap(info['metric'])
          : const <String, dynamic>{},
      myCharacter: _myCharacterFromJson(json['my_character']),
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
  final bool deleted;
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
  final int lastProgressTickNo;
  final int lastProgressSubTickNo;
  final String lastProgressCurrentTime;
  final List<String> previewImages;
  final List<String> tags;
  final Map<String, dynamic> metric;
  final Map<String, dynamic>? myCharacter;
  final int tickCnt;
  final int connectCnt;
  final int aiCharacterCnt;
  final int playerCnt;
  final int locationCnt;
  final double coverHeight;

  String get title => name.trim().isEmpty ? wid : name.trim();

  String get ownerLabel {
    final owner = ownerName.trim();
    if (owner.isNotEmpty) return formatUidForDisplay(owner);
    final creator = createdUserName.trim();
    if (creator.isNotEmpty) return formatUidForDisplay(creator);
    return formatUidForDisplay(ownerUid, fallback: '-');
  }

  String get subtitle => displaySubtitle.trim().isEmpty
      ? 'Updated ${formatGenesisTimestamp(updatedAt)}'
      : displaySubtitle.trim();

  String get progressSummary => lastProgressSummary.trim();

  String get progressTickTimeLabel {
    final parts = <String>[];
    if (lastProgressTickNo > 0) {
      parts.add(
        'Tick $lastProgressTickNo'
        '${lastProgressSubTickNo > 0 ? '-$lastProgressSubTickNo' : ''}',
      );
    }
    final currentTime = lastProgressCurrentTime.trim();
    if (currentTime.isNotEmpty) parts.add(currentTime);
    return parts.join(' · ');
  }

  /// Right-hand tick state on the 9l Home row: `Tick 2-3`, or `Not started`
  /// before the world has run.
  String get tickStateLabel {
    if (lastProgressTickNo <= 0) return 'Not started';
    final sub = lastProgressSubTickNo > 0 ? '-$lastProgressSubTickNo' : '';
    return 'Tick $lastProgressTickNo$sub';
  }

  List<String> get resolvedPreviewImages {
    if (previewImages.isNotEmpty) return previewImages;
    final image = cover.trim();
    if (image.isEmpty) return const <String>[];
    return <String>[image, image];
  }
}

class WorldItemCard extends StatelessWidget {
  const WorldItemCard({
    super.key,
    required this.item,
    this.thumbnailBorderRadius = GenesisImageRadii.contentValue,
    this.showRecentChatTag = false,
    this.recentActivityTagLabel = '',
  });

  final WorldListItem item;
  final double thumbnailBorderRadius;
  final bool showRecentChatTag;
  final String recentActivityTagLabel;

  String get _resolvedRecentActivityTagLabel {
    final label = recentActivityTagLabel.trim();
    if (label.isNotEmpty) return label;
    return showRecentChatTag ? 'Last Message' : '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;

    // 9l Home row: 52x78 cover, then world name + recency, a two-line story
    // summary, and the player's character with its tick state. WID, owner,
    // the stats strip, the Last Progress header and the tick chip are not
    // part of this row in the design.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorldImage(
          imageUrl: item.cover,
          width: 52,
          height: 78,
          borderRadius: thumbnailBorderRadius,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  // 9l marks an in-progress world with a 6px red dot after the
                  // name — one marker, not a per-activity coloured pill.
                  if (_resolvedRecentActivityTagLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Semantics(
                      label: _resolvedRecentActivityTagLabel,
                      child: Container(
                        key: const ValueKey<String>('world-activity-dot'),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const SizedBox(width: 8),
                  Text(
                    formatGenesisRelativeTimestamp(item.lastProgressAt),
                    style: TextStyle(
                      color: colors.textTimestamp,
                      fontSize: 9.5,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              if (item.progressSummary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.progressSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textBody,
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              _CurrentUserStatusPreview(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentUserStatusPreview extends StatelessWidget {
  const _CurrentUserStatusPreview({required this.item});

  final WorldListItem item;

  @override
  Widget build(BuildContext context) {
    final character = item.myCharacter;
    if (character == null) return const SizedBox.shrink();
    final playerUid = _mapString(character, const ['player_uid']);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _CurrentUserStatusRow(
        data: _CurrentUserStatusData(
          metric: item.metric,
          character: character,
          currentUid: playerUid,
        ),
        tickLabel: item.tickStateLabel,
      ),
    );
  }
}

class _CurrentUserStatusData {
  const _CurrentUserStatusData({
    required this.metric,
    required this.character,
    required this.currentUid,
  });

  final Map<String, dynamic> metric;
  final Map<String, dynamic> character;
  final String currentUid;
}

class _CurrentUserStatusRow extends StatelessWidget {
  const _CurrentUserStatusRow({required this.data, required this.tickLabel});

  final _CurrentUserStatusData data;
  final String tickLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final character = data.character;
    final name = _mapString(character, const ['name'], fallback: 'Character');

    // 9l Home: a 20px avatar ringed in the action red, the character name, and
    // the tick state pushed to the right edge.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GenesisCharacterAvatar(
          url: _mapImageUrl(character, const ['avatar']),
          name: name,
          size: 20,
          borderRadius: 10,
          border: Border.all(color: colors.primary, width: 2),
          showFallbackWhileLoading: false,
          maxDevicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 8),
        Text(
          tickLabel,
          style: TextStyle(
            color: colors.textTimestamp,
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _WorldImage extends StatelessWidget {
  const _WorldImage({
    required this.imageUrl,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GenesisListImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(borderRadius),
      maxDevicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }
}

num? _metricNumber(Object? value) {
  if (value is num) return value;
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return num.tryParse(text);
}

String _metricDisplayValue(Object? value) {
  if (value is num) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '0';
  return text;
}

String _mapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = asString(map[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _mapImageUrl(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final imageUrl = resolveAssetUrl(asImageUrl(value));
    if (imageUrl.trim().isNotEmpty) return imageUrl;
  }
  return '';
}

Map<String, dynamic>? _myCharacterFromJson(Object? value) {
  if (value is! Map) return null;
  final character = asJsonMap(value);
  final hasContent = const [
    'char_id',
    'name',
    'player_uid',
  ].any((key) => asString(character[key]).trim().isNotEmpty);
  return hasContent ? character : null;
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
          .map((e) => resolveAssetUrl(asImageUrl(e)))
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
