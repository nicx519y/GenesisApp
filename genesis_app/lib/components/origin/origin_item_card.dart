import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/origin.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../ui/tokens/genesis_origin_card_geometry.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/genesis_ugc_text.dart';
import '../../utils/stat_count_formatter.dart';
import '../common/list_loading_skeleton.dart';
import 'origin_item_cover_gradient_painter.dart';
import 'origin_item_cover_throttled_image_provider.dart';
import 'stat_item.dart';

const double _coverDetailsTransitionHeight = 50;
const Color _cardFooterColor = Color(0xFF111111);

@visibleForTesting
ImageProvider<Object> Function(ImageProvider<Object> provider)?
debugOriginItemCoverImageProvider;

@immutable
class OriginListItem {
  const OriginListItem({
    this.ownerUser = const OriginUserInfo(),
    required this.oid,
    this.wid = '',
    this.definitionVersion = 0,
    this.defaultMapLocationId = '',
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
      ownerUser: OriginUserInfo.fromJson(
        asOptionalJsonMap(info['owner_user'] ?? json['owner_user']),
      ),
      oid: oid,
      wid: asString(info['wid'], fallback: asString(info['world_id'])),
      definitionVersion: asInt(info['definition_version']),
      defaultMapLocationId: asString(info['default_map_location_id']),
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

  final OriginUserInfo ownerUser;
  final String oid;
  final String wid;
  final int definitionVersion;
  final String defaultMapLocationId;
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

class OriginItemCard extends StatefulWidget {
  const OriginItemCard({
    super.key,
    required this.item,
    this.onCoverLoaded,
    this.coverLoadPriority = OriginItemCoverLoadPriority.visible,
  });

  final OriginListItem item;
  final VoidCallback? onCoverLoaded;
  final OriginItemCoverLoadPriority coverLoadPriority;

  @override
  State<OriginItemCard> createState() => _OriginItemCardState();
}

class _OriginItemCardState extends State<OriginItemCard> {
  static const _cancelledLoadRetryDelay = Duration(milliseconds: 120);

  var _coverLoadNotified = false;
  var _coverLoadRevision = 0;
  Timer? _coverLoadRetryTimer;
  var _coverLoadCancellationToken = OriginItemCoverLoadCancellationToken();
  late final ValueNotifier<OriginItemCoverLoadPriority>
  _coverLoadPriorityListenable = ValueNotifier<OriginItemCoverLoadPriority>(
    widget.coverLoadPriority,
  );

  @override
  void didUpdateWidget(covariant OriginItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.oid != widget.item.oid ||
        oldWidget.item.cover != widget.item.cover) {
      _resetCoverLoad();
      _coverLoadNotified = false;
      _coverLoadRevision = 0;
    }
    if (oldWidget.coverLoadPriority != widget.coverLoadPriority) {
      _updateCoverLoadPriority(widget.coverLoadPriority);
    }
  }

  @override
  void dispose() {
    _coverLoadRetryTimer?.cancel();
    _coverLoadCancellationToken.cancel();
    _coverLoadPriorityListenable.dispose();
    super.dispose();
  }

  void _resetCoverLoad() {
    _coverLoadRetryTimer?.cancel();
    _coverLoadRetryTimer = null;
    _coverLoadCancellationToken.cancel();
    _coverLoadCancellationToken = OriginItemCoverLoadCancellationToken();
    _coverLoadPriorityListenable.value = widget.coverLoadPriority;
  }

  void _updateCoverLoadPriority(OriginItemCoverLoadPriority priority) {
    if (_coverLoadNotified) {
      _coverLoadPriorityListenable.value = priority;
      return;
    }
    final previous = _coverLoadPriorityListenable.value;
    if (priority == OriginItemCoverLoadPriority.disabled) {
      _coverLoadRetryTimer?.cancel();
      _coverLoadRetryTimer = null;
      _coverLoadPriorityListenable.value = priority;
      _coverLoadCancellationToken.cancel();
      return;
    }
    if (previous == OriginItemCoverLoadPriority.disabled) {
      _coverLoadCancellationToken = OriginItemCoverLoadCancellationToken();
      _coverLoadPriorityListenable.value = priority;
      _coverLoadRevision += 1;
      return;
    }
    _coverLoadPriorityListenable.value = priority;
  }

  void _notifyCoverLoaded() {
    if (_coverLoadNotified) return;
    _coverLoadNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      widget.onCoverLoaded?.call();
    });
  }

  void _scheduleCancelledCoverLoadRetry() {
    if (widget.coverLoadPriority == OriginItemCoverLoadPriority.disabled) {
      return;
    }
    if (_coverLoadRetryTimer != null) return;
    final oid = widget.item.oid;
    final cover = widget.item.cover;
    _coverLoadRetryTimer = Timer(_cancelledLoadRetryDelay, () {
      _coverLoadRetryTimer = null;
      if (!mounted || widget.item.oid != oid || widget.item.cover != cover) {
        return;
      }
      if (widget.coverLoadPriority == OriginItemCoverLoadPriority.disabled) {
        return;
      }
      if (Scrollable.recommendDeferredLoadingForContext(context)) {
        _scheduleCancelledCoverLoadRetry();
        return;
      }
      setState(() => _coverLoadRevision += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final coverHeight = width / genesisOriginCoverAspectRatio;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final effectiveDevicePixelRatio =
            devicePixelRatio.isFinite && devicePixelRatio > 0
            ? devicePixelRatio
            : 1.0;
        final resolvedImageUrl = selectGenesisImageUrl(
          widget.item.cover,
          logicalWidth: width,
          logicalHeight: coverHeight,
          devicePixelRatio: effectiveDevicePixelRatio,
          maxDevicePixelRatio: effectiveDevicePixelRatio,
        ).trim();
        final totalHeight = coverHeight + genesisOriginCardBottomExtension;

        return ClipRRect(
          borderRadius: GenesisImageRadii.content,
          child: SizedBox(
            width: width,
            height: totalHeight,
            child: Stack(
              key: const ValueKey<String>('origin-item-card-content'),
              fit: StackFit.expand,
              children: [
                const SizedBox(
                  key: ValueKey<String>('origin-item-card-loading'),
                  child: GenesisOriginCardLoadingBone(borderRadius: 0),
                ),
                if (resolvedImageUrl.isNotEmpty &&
                    (_coverLoadNotified ||
                        widget.coverLoadPriority !=
                            OriginItemCoverLoadPriority.disabled))
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: coverHeight,
                    child: _buildCover(
                      resolvedImageUrl,
                      width: width,
                      coverHeight: coverHeight,
                      devicePixelRatio: effectiveDevicePixelRatio,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: coverHeight,
                  child: const IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey<String>('origin-item-card-painted-cover'),
                      foregroundPainter: OriginItemCoverGradientPainter(
                        transitionHeight: _coverDetailsTransitionHeight,
                      ),
                    ),
                  ),
                ),
                _OriginItemCardDetails(item: widget.item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover(
    String imageUrl, {
    required double width,
    required double coverHeight,
    required double devicePixelRatio,
  }) {
    final sourceProvider = _originCoverProvider(
      imageUrl,
      outputWidth: math.max(1, (width * devicePixelRatio).ceil()),
      outputHeight: math.max(1, (coverHeight * devicePixelRatio).ceil()),
      cancellationToken: _coverLoadCancellationToken,
      priorityListenable: _coverLoadPriorityListenable,
    );
    final ImageProvider<Object> coverProvider =
        debugOriginItemCoverImageProvider?.call(sourceProvider) ??
        sourceProvider;
    return KeyedSubtree(
      key: ValueKey<String>(
        'origin-item-card-cover-attempt-$_coverLoadRevision',
      ),
      child: Image(
        key: const ValueKey<String>('origin-item-card-cover-loader'),
        image: coverProvider,
        width: width,
        height: coverHeight,
        fit: BoxFit.cover,
        gaplessPlayback: false,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, cover, frame, wasSynchronouslyLoaded) {
          if (!wasSynchronouslyLoaded && frame == null) {
            return const SizedBox.expand(
              key: ValueKey<String>('origin-item-card-loading-frame'),
            );
          }
          _notifyCoverLoaded();
          return KeyedSubtree(
            key: const ValueKey<String>('origin-item-card-ready'),
            child: KeyedSubtree(
              key: const ValueKey<String>('origin-item-card-rendered-cover'),
              child: cover,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (error is OriginItemCoverLoadCancelledException) {
            _scheduleCancelledCoverLoadRetry();
            return const SizedBox.expand(
              key: ValueKey<String>('origin-item-card-loading-cancelled'),
            );
          }
          return const SizedBox.expand(
            key: ValueKey<String>('origin-item-card-cover-error'),
          );
        },
      ),
    );
  }
}

ImageProvider<Object> _originCoverProvider(
  String imageUrl, {
  required int outputWidth,
  required int outputHeight,
  required OriginItemCoverLoadCancellationToken cancellationToken,
  required ValueListenable<OriginItemCoverLoadPriority> priorityListenable,
}) {
  if (imageUrl.startsWith('assets/')) return AssetImage(imageUrl);
  return OriginItemCoverThrottledImageProvider(
    sourceProvider: GenesisStaticNetworkImageProvider(
      imageUrl: imageUrl,
      cacheWidth: outputWidth,
      cacheHeight: outputHeight,
      fit: BoxFit.cover,
      cancellationToken: cancellationToken.networkToken,
    ),
    cancellationToken: cancellationToken,
    priorityListenable: priorityListenable,
  );
}

class _OriginItemCardDetails extends StatelessWidget {
  const _OriginItemCardDetails({required this.item});

  final OriginListItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: genesisOriginCardBottomExtension,
          child: ColoredBox(
            key: ValueKey<String>('origin-item-card-footer-extension'),
            color: _cardFooterColor,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
