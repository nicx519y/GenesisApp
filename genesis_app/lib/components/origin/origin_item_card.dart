import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'stat_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../ui/tokens/genesis_origin_card_geometry.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/genesis_ugc_text.dart';
import '../../utils/stat_count_formatter.dart';

const double _coverDetailsTransitionHeight = 50;
const Color _cardFooterColor = Color(0xFF111111);
const Color _transparentCardFooterColor = Color(0x00111111);

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
    return ClipRRect(
      borderRadius: GenesisImageRadii.content,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: genesisOriginCoverAspectRatio,
                child: GenesisListImage(
                  imageUrl: item.cover,
                  borderRadius: BorderRadius.zero,
                  maxDevicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                ),
              ),
              const SizedBox(
                height: genesisOriginCardBottomExtension,
                child: ColoredBox(
                  key: ValueKey<String>('origin-item-card-footer-extension'),
                  color: _cardFooterColor,
                ),
              ),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: genesisOriginCardBottomExtension,
            height: _coverDetailsTransitionHeight,
            child: DecoratedBox(
              key: ValueKey<String>('origin-item-card-cover-transition'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_transparentCardFooterColor, _cardFooterColor],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey<String>('origin-item-card-details'),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        originDisplayName(item.title),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Padding(
                  key: const ValueKey<String>('origin-item-card-stats'),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ImageStat(
                        iconAsset: copyStatIconAsset,
                        value: item.copyCnt,
                      ),
                      const SizedBox(width: 8),
                      _ImageStat(
                        iconAsset: connectStatIconAsset,
                        value: item.connectCnt,
                      ),
                      const SizedBox(width: 8),
                      _ImageStat(
                        iconAsset: characterStatIconAsset,
                        preserveIconAssetColor: true,
                        iconColorMapper: const _WhiteCharacterColorMapper(),
                        value: item.characterCnt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageStat extends StatelessWidget {
  const _ImageStat({
    required this.iconAsset,
    this.preserveIconAssetColor = false,
    this.iconColorMapper,
    required this.value,
  });

  final String iconAsset;
  final bool preserveIconAssetColor;
  final ColorMapper? iconColorMapper;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconColorMapper: iconColorMapper,
      crossAxisAlignment: CrossAxisAlignment.start,
      iconSize: 10,
      iconColor: Colors.white,
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _WhiteCharacterColorMapper extends ColorMapper {
  const _WhiteCharacterColorMapper();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    return color == const Color(0xFF111111) ? Colors.white : color;
  }
}

List<String> _tagsFromJson(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
