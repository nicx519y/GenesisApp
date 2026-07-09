import 'package:flutter/material.dart';

import '../../components/origin/stat_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../components/common/genesis_timestamp_text.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
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
  String get displayTitle {
    final value = title.trim();
    if (value.isEmpty || value.startsWith('#')) return value;
    return '#$value';
  }

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
    if (lastProgressTickNo > 0) parts.add('Tick $lastProgressTickNo');
    final currentTime = lastProgressCurrentTime.trim();
    if (currentTime.isNotEmpty) parts.add(currentTime);
    return parts.join(' · ');
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
    this.showPreviewImages = true,
  });

  final WorldListItem item;
  final double thumbnailBorderRadius;
  final bool showPreviewImages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WorldImage(
              imageUrl: item.cover,
              width: 60,
              height: 60,
              borderRadius: thumbnailBorderRadius,
            ),
            const SizedBox(width: 14),
            Expanded(child: _WorldSummary(item: item)),
          ],
        ),
        const SizedBox(height: 16),
        _ProgressHeader(timestamp: item.lastProgressAt),
        if (item.progressTickTimeLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ProgressTickTime(label: item.progressTickTimeLabel),
        ],
        const SizedBox(height: 8),
        Text(
          item.progressSummary,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
        ),
        _CurrentUserStatusPreview(item: item),
        if (showPreviewImages) _WorldPreviewImages(item: item),
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
  const _CurrentUserStatusRow({required this.data});

  final _CurrentUserStatusData data;

  @override
  Widget build(BuildContext context) {
    final character = data.character;
    final name = _mapString(character, const ['name'], fallback: 'Character');
    final playerUid = _mapString(character, const ['player_uid']);
    final username = _mapString(character, const ['player_username']);
    final suffix = _characterNameSuffix(
      currentUid: data.currentUid,
      playerUid: playerUid,
      username: username,
      playerDeleted: entityDeleted(character['player_deleted']),
    );
    final isCharacterRole = _isCharacterRole(character);
    final roleLabel = isCharacterRole ? 'Character' : 'Player';
    final subtitle = _metricStatusText(data.metric, character);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: isCharacterRole ? 6 : 0),
          child: GenesisCharacterAvatar(
            url: _mapImageUrl(character, const ['avatar']),
            name: name,
            showStar: isCharacterRole,
            starSize: 20,
            showFallbackWhileLoading: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: name,
                          children: [
                            if (suffix.isNotEmpty)
                              TextSpan(
                                text: ' $suffix',
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                ),
                              ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      roleLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8F8F8F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressTickTime extends StatelessWidget {
  const _ProgressTickTime({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 12,
          height: 1.1,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _WorldSummary extends StatelessWidget {
  const _WorldSummary({required this.item});

  final WorldListItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                'WID: ${deletedAwareIdLabel(item.wid, deleted: item.deleted)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _worldMetaStyle,
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              child: Text(
                'Owner: ${item.ownerLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _worldMetaStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _WorldStatsRow(item: item),
      ],
    );
  }
}

class _WorldPreviewImages extends StatelessWidget {
  const _WorldPreviewImages({required this.item});

  final WorldListItem item;

  @override
  Widget build(BuildContext context) {
    final previewImages = item.resolvedPreviewImages.take(2).toList();
    if (previewImages.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          for (final entry in previewImages.indexed) ...[
            Expanded(
              child: _WorldImage(
                imageUrl: entry.$2,
                height: 120,
                borderRadius: GenesisImageRadii.contentValue,
              ),
            ),
            if (entry.$1 != previewImages.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
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
        _Stat(iconAsset: tickStatIconAsset, value: item.tickCnt),
        _Stat(iconAsset: connectStatIconAsset, value: item.connectCnt),
        _Stat(
          iconAsset: characterStatIconAsset,
          preserveIconAssetColor: true,
          value: item.aiCharacterCnt,
        ),
        _Stat(iconAsset: userStatIconAsset, value: item.playerCnt),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  });

  final String iconAsset;
  final bool preserveIconAssetColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 11,
      iconColor: Colors.black,
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.timestamp});

  final Object? timestamp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          MyFlutterApp.lastProgress,
          color: Color(0xFFFF2442),
          size: 14,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Last Progress',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (formatGenesisTimestamp(timestamp).isNotEmpty) ...[
          const SizedBox(width: 10),
          GenesisTimestampText(
            timestamp: timestamp,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8B8B8B),
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w400,
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
    );
  }
}

const _worldMetaStyle = TextStyle(
  color: Color(0xFF666666),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

bool _isCharacterRole(Map<String, dynamic> character) {
  return _mapString(character, const ['player_uid']).isEmpty;
}

String _characterNameSuffix({
  required String currentUid,
  required String playerUid,
  required String username,
  required bool playerDeleted,
}) {
  if (playerUid.isNotEmpty && playerDeleted) {
    return '($deletedEntityDisplayText)';
  }
  if (currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid) {
    return '(Me)';
  }
  if (playerUid.isNotEmpty && username.isNotEmpty) return '($username)';
  return '';
}

String _metricStatusText(
  Map<String, dynamic> metric,
  Map<String, dynamic> character,
) {
  final label = _mapString(metric, const ['label']);
  final unit = _mapString(metric, const ['unit']);
  final value = _resolvedMetricValueText(
    character['metric_value'],
    metric['default'],
  );
  if (label.isEmpty) return '$value$unit';
  return '$label: $value$unit';
}

String _resolvedMetricValueText(Object? metricValue, Object? defaultValue) {
  final parsedMetricValue = _metricNumber(metricValue);
  final resolved = parsedMetricValue == null || parsedMetricValue == 0
      ? defaultValue
      : metricValue;
  return _metricDisplayValue(resolved);
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
