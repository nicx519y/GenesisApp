import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../discuss/origin_discuss_preview_list.dart';
import '../origin/stat_item.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import '../origin/origin_item_card.dart';

typedef PopularWorldSummaryLoader =
    Future<List<WorldSummaryLatestItem>> Function(String originId);

const double _popularOriginHeroImageHeight = 160.5;
const double _popularOriginSectionGap = 16;
const double _popularOriginSectionTitleFontSize = 13;
const double _popularOriginSectionBodyFontSize = 13;
const double _popularOriginSectionBodyLineHeight = 1.42;
const double _popularOriginProgressBodyHeight =
    _popularOriginSectionBodyFontSize *
        _popularOriginSectionBodyLineHeight *
        5 +
    6;

class PopularOriginList extends StatefulWidget {
  const PopularOriginList({
    super.key,
    required this.items,
    required this.onItemTap,
    this.controller,
    this.storageKey,
    this.isLoadingMore = false,
    this.preloadedDiscussItems =
        const <String, List<OriginDiscussPreviewItem>>{},
    this.discussLoader,
    this.summaryLoader,
    this.thumbnailBorderRadius = GenesisImageRadii.contentValue,
  });

  final List<OriginListItem> items;
  final ValueChanged<OriginListItem> onItemTap;
  final ScrollController? controller;
  final PageStorageKey<String>? storageKey;
  final bool isLoadingMore;
  final Map<String, List<OriginDiscussPreviewItem>> preloadedDiscussItems;
  final OriginDiscussPreviewLoader? discussLoader;
  final PopularWorldSummaryLoader? summaryLoader;
  final double thumbnailBorderRadius;

  @override
  State<PopularOriginList> createState() => _PopularOriginListState();
}

class _PopularOriginListState extends State<PopularOriginList> {
  final Map<String, Future<List<OriginDiscussPreviewItem>>> _discussFutures =
      <String, Future<List<OriginDiscussPreviewItem>>>{};
  final Map<String, Future<WorldSummaryLatestItem?>> _summaryFutures =
      <String, Future<WorldSummaryLatestItem?>>{};

  @override
  void didUpdateWidget(covariant PopularOriginList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.discussLoader != widget.discussLoader) {
      _discussFutures.clear();
    }
    if (oldWidget.summaryLoader != widget.summaryLoader) {
      _summaryFutures.clear();
    }

    final activeOids = widget.items.map((item) => item.oid.trim()).toSet();
    _discussFutures.removeWhere((oid, _) => !activeOids.contains(oid));
    _summaryFutures.removeWhere((oid, _) => !activeOids.contains(oid));
  }

  Future<List<OriginDiscussPreviewItem>> _loadDiscuss(String oid) {
    final resolvedOid = oid.trim();
    if (resolvedOid.isEmpty) {
      return Future<List<OriginDiscussPreviewItem>>.value(
        const <OriginDiscussPreviewItem>[],
      );
    }
    return _discussFutures.putIfAbsent(resolvedOid, () async {
      final loader = widget.discussLoader;
      if (loader != null) return loader(resolvedOid);

      return loadOriginDiscussPreviewItems(context, resolvedOid);
    });
  }

  Future<WorldSummaryLatestItem?> _loadSummary(String oid) {
    final resolvedOid = oid.trim();
    if (resolvedOid.isEmpty) {
      return Future<WorldSummaryLatestItem?>.value(null);
    }
    final loader = widget.summaryLoader;
    final api = loader == null ? AppServicesScope.read(context).api : null;
    return _summaryFutures.putIfAbsent(resolvedOid, () async {
      final summaries = loader == null
          ? await api!.getLatestWorldSummaries(originId: resolvedOid)
          : await loader(resolvedOid);
      for (final summary in summaries) {
        if (summary.summary.trim().isNotEmpty) return summary;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: widget.storageKey,
      controller: widget.controller,
      primary: false,
      scrollCacheExtent: ScrollCacheExtent.pixels(900),
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: widget.items.length + (widget.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(top: 24, bottom: 16),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFEFEFEF)),
      ),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final item = widget.items[index];
        final oid = item.oid.trim();
        final onOpenOrigin = item.deleted ? null : () => widget.onItemTap(item);
        final initialDiscussItems =
            widget.preloadedDiscussItems.containsKey(oid)
            ? widget.preloadedDiscussItems[oid] ??
                  const <OriginDiscussPreviewItem>[]
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PopularOriginListItem(
            item: item,
            onOpenOrigin: onOpenOrigin,
            initialDiscussItems: initialDiscussItems,
            discussLoader: _loadDiscuss,
            summaryFuture: _loadSummary(item.oid),
            thumbnailBorderRadius: widget.thumbnailBorderRadius,
          ),
        );
      },
    );
  }
}

class PopularOriginListItem extends StatelessWidget {
  const PopularOriginListItem({
    super.key,
    required this.item,
    this.onOpenOrigin,
    this.initialDiscussItems,
    this.discussLoader,
    this.summaryFuture,
    this.thumbnailBorderRadius = GenesisImageRadii.contentValue,
  });

  final OriginListItem item;
  final VoidCallback? onOpenOrigin;
  final List<OriginDiscussPreviewItem>? initialDiscussItems;
  final OriginDiscussPreviewLoader? discussLoader;
  final Future<WorldSummaryLatestItem?>? summaryFuture;
  final double thumbnailBorderRadius;

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final metaTime = formatGenesisTimestamp(item.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OpenOriginTap(
              onTap: onOpenOrigin,
              child: _OriginImage(
                key: ValueKey('popular-origin-thumbnail-${item.oid}'),
                imageUrl: item.cover,
                width: 60,
                height: 60,
                borderRadius: thumbnailBorderRadius,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _OpenOriginTap(
                onTap: onOpenOrigin,
                child: _OriginSummary(item: item, title: title),
              ),
            ),
          ],
        ),
        const SizedBox(
          key: ValueKey('popular-origin-gap-meta-world-view'),
          height: _popularOriginSectionGap,
        ),
        _WorldViewSection(item: item, onOpenOrigin: onOpenOrigin),
        const SizedBox(
          key: ValueKey('popular-origin-gap-world-view-progress'),
          height: _popularOriginSectionGap,
        ),
        _OpenOriginTap(
          onTap: onOpenOrigin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressHeader(),
              const SizedBox(
                key: ValueKey('popular-origin-gap-progress-title-body'),
                height: 8,
              ),
              _ProgressSummary(
                item: item,
                fallbackTimeText: metaTime,
                future: summaryFuture,
              ),
            ],
          ),
        ),
        const SizedBox(
          key: ValueKey('popular-origin-gap-progress-discuss'),
          height: _popularOriginSectionGap,
        ),
        _DiscussSection(
          item: item,
          onOpenOrigin: onOpenOrigin,
          initialDiscussItems: initialDiscussItems,
          discussLoader: discussLoader,
        ),
        const SizedBox(height: _popularOriginSectionGap),
        _OpenOriginTap(
          onTap: onOpenOrigin,
          child: _EnterOriginRow(title: title),
        ),
      ],
    );
  }
}

class _WorldViewSection extends StatelessWidget {
  const _WorldViewSection({required this.item, this.onOpenOrigin});

  final OriginListItem item;
  final VoidCallback? onOpenOrigin;

  @override
  Widget build(BuildContext context) {
    final body = item.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OpenOriginTap(
          onTap: onOpenOrigin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(icon: MyFlutterApp.eye, title: 'World View'),
              const SizedBox(
                key: ValueKey('popular-origin-gap-world-view-title-body'),
                height: 8,
              ),
              Text(
                body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle,
              ),
            ],
          ),
        ),
        const SizedBox(
          key: ValueKey('popular-origin-gap-world-view-image'),
          height: 8,
        ),
        _OriginHeroImage(item: item),
      ],
    );
  }
}

class _OriginSummary extends StatelessWidget {
  const _OriginSummary({required this.item, required this.title});

  final OriginListItem item;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          originDisplayName(title),
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
                'OID: ${deletedAwareIdLabel(item.oid, deleted: item.deleted)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _metaStyle,
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              child: Text(
                'Originator: ${_originatorLabel(item)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _metaStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _OriginStatsRow(item: item),
      ],
    );
  }
}

class _OriginStatsRow extends StatelessWidget {
  const _OriginStatsRow({required this.item});

  final OriginListItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _OriginStat(iconAsset: copyStatIconAsset, value: item.copyCnt),
        _OriginStat(iconAsset: connectStatIconAsset, value: item.connectCnt),
        _OriginStat(
          iconAsset: characterStatIconAsset,
          preserveIconAssetColor: true,
          value: item.characterCnt,
        ),
      ],
    );
  }
}

class _OriginHeroImage extends StatelessWidget {
  const _OriginHeroImage({required this.item});

  final OriginListItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('popular-origin-cover-${item.oid}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _showCover(context, item.cover),
      child: SizedBox(
        width: double.infinity,
        height: _popularOriginHeroImageHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _OriginImage(
            imageUrl: item.cover,
            height: _popularOriginHeroImageHeight,
            borderRadius: GenesisImageRadii.contentValue,
          ),
        ),
      ),
    );
  }
}

class _OriginImage extends StatelessWidget {
  const _OriginImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final double? width;
  final double? height;
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

class _OpenOriginTap extends StatelessWidget {
  const _OpenOriginTap({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    if (tap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: child,
    );
  }
}

class _OriginStat extends StatelessWidget {
  const _OriginStat({
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({this.icon, this.iconAsset, required this.title})
    : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (iconAsset case final asset?)
          Image.asset(
            asset,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        else
          Icon(icon, color: const Color(0xFFFF2344), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: _popularOriginSectionTitleFontSize,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const _SectionHeader(
      icon: MyFlutterApp.lastProgress,
      title: 'Copy World Progress',
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.item,
    required this.fallbackTimeText,
    this.future,
  });

  final OriginListItem item;
  final String fallbackTimeText;
  final Future<WorldSummaryLatestItem?>? future;

  static const _emptyText = 'No launched world';

  @override
  Widget build(BuildContext context) {
    final summaryFuture = future;
    if (summaryFuture == null) {
      return _buildContent(null);
    }
    return FutureBuilder<WorldSummaryLatestItem?>(
      future: summaryFuture,
      builder: (context, snapshot) {
        return _buildContent(snapshot.data);
      },
    );
  }

  Widget _buildContent(WorldSummaryLatestItem? summary) {
    final body = summary?.summary.trim() ?? '';
    final worldId = summary?.worldId.trim() ?? item.wid.trim();
    final worldDeleted = summary?.deleted ?? false;
    final tickNo = summary?.tickNo ?? item.tickCount;
    final timeText = summary == null
        ? fallbackTimeText
        : formatGenesisTimestamp(
            summary.tickTime == 0 ? summary.createdAt : summary.tickTime,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: const ValueKey('popular-origin-progress-body'),
          height: _popularOriginProgressBodyHeight,
          child: Text(
            body.isEmpty ? _emptyText : body,
            style: body.isEmpty ? _emptyBodyStyle : _bodyStyle,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            strutStyle: const StrutStyle(
              fontSize: _popularOriginSectionBodyFontSize,
              height: _popularOriginSectionBodyLineHeight,
              forceStrutHeight: true,
            ),
          ),
        ),
        const SizedBox(
          key: ValueKey('popular-origin-gap-progress-meta'),
          height: 0,
        ),
        _MetaRow(
          worldId: worldId,
          worldDeleted: worldDeleted,
          tickCount: tickNo,
          timeText: timeText,
        ),
      ],
    );
  }
}

class _DiscussSection extends StatelessWidget {
  const _DiscussSection({
    required this.item,
    this.onOpenOrigin,
    this.initialDiscussItems,
    this.discussLoader,
  });

  final OriginListItem item;
  final VoidCallback? onOpenOrigin;
  final List<OriginDiscussPreviewItem>? initialDiscussItems;
  final OriginDiscussPreviewLoader? discussLoader;

  @override
  Widget build(BuildContext context) {
    return _OpenOriginTap(
      onTap: onOpenOrigin,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              iconAsset: discussIconAsset,
              title: 'Discuss (${formatStatCount(item.discussCnt)})',
            ),
            const SizedBox(
              key: ValueKey('popular-origin-gap-discuss-list'),
              height: 8,
            ),
            OriginDiscussPreviewList(
              oid: item.oid,
              count: item.discussCnt,
              showHeader: false,
              initialItems: initialDiscussItems,
              loader: discussLoader,
              onPreviewTap: onOpenOrigin == null
                  ? null
                  : () async => onOpenOrigin!(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.worldId,
    required this.worldDeleted,
    required this.tickCount,
    required this.timeText,
  });

  final String worldId;
  final bool worldDeleted;
  final int tickCount;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final displayWorldId = worldId.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final hasTime = timeText.isNotEmpty;
        final timeWidth = hasTime
            ? constraints.maxWidth.clamp(0, 96).toDouble()
            : 0.0;
        final leftWidth =
            (constraints.maxWidth - (hasTime ? timeWidth + gap : 0))
                .clamp(0.0, constraints.maxWidth)
                .toDouble();
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'WID: ${deletedAwareIdLabel(displayWorldId, deleted: worldDeleted)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _metaStyle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  _OriginTickChip(count: tickCount),
                ],
              ),
            ),
            if (hasTime) ...[
              const SizedBox(width: gap),
              SizedBox(
                width: timeWidth,
                child: Text(
                  timeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _metaStyle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OriginTickChip extends StatelessWidget {
  const _OriginTickChip({required this.count});

  final int count;

  static const Color _chipBackground = Color(0xFFFEF3C7);
  static const Color _chipForeground = Color(0xFF92400E);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('popular-origin-tick-chip-$count'),
      padding: const EdgeInsetsDirectional.fromSTEB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(MyFlutterApp.pregress, size: 9, color: _chipForeground),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
              color: _chipForeground,
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterOriginRow extends StatelessWidget {
  const _EnterOriginRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            originDisplayName(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4B6192),
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Enter',
          style: TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: Color(0xFF4B6192), size: 20),
      ],
    );
  }
}

String _originatorLabel(OriginListItem item) {
  final owner = item.ownerName.trim();
  if (owner.isNotEmpty) return formatUidForDisplay(owner);
  final name = item.createdUserName.trim();
  if (name.isNotEmpty) return formatUidForDisplay(name);
  return formatUidForDisplay(item.createdUid, fallback: '-');
}

void _showCover(BuildContext context, String cover) {
  final url = cover.trim();
  if (url.isEmpty) return;
  showGenesisImageViewer(context, imageUrls: [url]);
}

const _bodyStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: _popularOriginSectionBodyFontSize,
  height: 1.42,
  fontWeight: FontWeight.w400,
);

const _emptyBodyStyle = TextStyle(
  color: Color(0xFF999999),
  fontSize: 12,
  height: 1.3,
  fontWeight: FontWeight.w600,
);

const _metaStyle = TextStyle(
  color: Color(0xFF666666),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);
