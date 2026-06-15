import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../discuss/origin_discuss_preview_list.dart';
import '../origin/stat_item.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import '../origin/origin_item_card.dart';

typedef PopularWorldSummaryLoader =
    Future<List<WorldSummaryLatestItem>> Function(String originId);

const double _popularOriginHeroImageHeight = 160.5;

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
      scrollCacheExtent: const ScrollCacheExtent.pixels(900),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: widget.items.length + (widget.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          const Divider(height: 25, thickness: 1, color: Color(0xFFEFEFEF)),
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
        final initialDiscussItems =
            widget.preloadedDiscussItems.containsKey(oid)
            ? widget.preloadedDiscussItems[oid] ??
                  const <OriginDiscussPreviewItem>[]
            : null;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onItemTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PopularOriginListItem(
              item: item,
              initialDiscussItems: initialDiscussItems,
              discussLoader: _loadDiscuss,
              summaryFuture: _loadSummary(item.oid),
              thumbnailBorderRadius: widget.thumbnailBorderRadius,
            ),
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
    this.initialDiscussItems,
    this.discussLoader,
    this.summaryFuture,
    this.thumbnailBorderRadius = GenesisImageRadii.contentValue,
  });

  final OriginListItem item;
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
            _OriginImage(
              imageUrl: item.cover,
              width: 60,
              height: 60,
              borderRadius: thumbnailBorderRadius,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _OriginSummary(item: item, title: title),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 12,
            height: 1.33,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 14),
        _OriginHeroImage(item: item),
        const SizedBox(height: 16),
        _ProgressHeader(),
        const SizedBox(height: 6),
        _ProgressSummary(
          item: item,
          fallbackTimeText: metaTime,
          future: summaryFuture,
        ),
        const SizedBox(height: 6),
        OriginDiscussPreviewList(
          oid: item.oid,
          count: item.discussCnt,
          initialItems: initialDiscussItems,
          loader: discussLoader,
        ),
        const SizedBox(height: 14),
        _EnterOriginRow(title: title),
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
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                'OID: ${item.oid}',
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
    return Align(
      alignment: Alignment.centerLeft,
      child: _OriginImage(
        imageUrl: item.cover,
        height: _popularOriginHeroImageHeight,
        borderRadius: GenesisImageRadii.contentValue,
      ),
    );
  }
}

class _OriginImage extends StatelessWidget {
  const _OriginImage({
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

class _ProgressHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(MyFlutterApp.lastProgress, color: Color(0xFFF42C47), size: 14),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            'Copy World Progress',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
    final tickNo = summary?.tickNo ?? item.tickCount;
    final timeText = summary == null
        ? fallbackTimeText
        : formatGenesisTimestamp(
            summary.tickTime == 0 ? summary.createdAt : summary.tickTime,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body.isEmpty ? _emptyText : body,
          style: body.isEmpty ? _emptyBodyStyle : _bodyStyle,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _MetaRow(worldId: worldId, tickCount: tickNo, timeText: timeText),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.worldId,
    required this.tickCount,
    required this.timeText,
  });

  final String worldId;
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
                      'WID: ${displayWorldId.isEmpty ? '-' : displayWorldId}',
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
              fontWeight: FontWeight.w500,
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
              fontSize: 14,
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
            fontSize: 14,
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

const _bodyStyle = TextStyle(
  color: Color(0xFF1D1D1D),
  fontSize: 12,
  height: 1.42,
  fontWeight: FontWeight.w400,
);

const _emptyBodyStyle = TextStyle(
  color: Color(0xFF999999),
  fontSize: 12,
  height: 1.3,
  fontWeight: FontWeight.w500,
);

const _metaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.1,
  fontWeight: FontWeight.w400,
);
