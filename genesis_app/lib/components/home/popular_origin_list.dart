import 'package:flutter/material.dart';

import '../discuss/origin_discuss_preview_list.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import '../origin/origin_item_card.dart';

class PopularOriginList extends StatefulWidget {
  const PopularOriginList({
    super.key,
    required this.items,
    required this.onItemTap,
    this.controller,
    this.storageKey,
    this.isLoadingMore = false,
    this.discussLoader,
    this.thumbnailBorderRadius = 8,
  });

  final List<OriginListItem> items;
  final ValueChanged<OriginListItem> onItemTap;
  final ScrollController? controller;
  final PageStorageKey<String>? storageKey;
  final bool isLoadingMore;
  final OriginDiscussPreviewLoader? discussLoader;
  final double thumbnailBorderRadius;

  @override
  State<PopularOriginList> createState() => _PopularOriginListState();
}

class _PopularOriginListState extends State<PopularOriginList> {
  final Map<String, Future<List<OriginDiscussPreviewItem>>> _discussFutures =
      <String, Future<List<OriginDiscussPreviewItem>>>{};

  @override
  void didUpdateWidget(covariant PopularOriginList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.discussLoader != widget.discussLoader) {
      _discussFutures.clear();
      return;
    }

    final activeOids = widget.items.map((item) => item.oid.trim()).toSet();
    _discussFutures.removeWhere((oid, _) => !activeOids.contains(oid));
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

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: widget.storageKey,
      controller: widget.controller,
      primary: false,
      cacheExtent: 900,
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
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onItemTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PopularOriginListItem(
              item: item,
              discussLoader: _loadDiscuss,
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
    this.discussLoader,
    this.thumbnailBorderRadius = 8,
  });

  final OriginListItem item;
  final OriginDiscussPreviewLoader? discussLoader;
  final double thumbnailBorderRadius;

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final metaTime = _relativeTime(item.updatedAt);

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
        _ProgressBody(item: item),
        const SizedBox(height: 6),
        _MetaRow(item: item, timeText: metaTime),
        const SizedBox(height: 6),
        OriginDiscussPreviewList(
          oid: item.oid,
          count: item.discussCnt,
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
      spacing: 24,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _OriginStat(icon: MyFlutterApp.save, value: item.copyCnt),
        _OriginStat(iconAsset: connectIconAsset, value: item.connectCnt),
        _OriginStat(
          iconAsset: aiCharacterIconAsset,
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
      child: _OriginImage(imageUrl: item.cover, width: 107, borderRadius: 8),
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
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconAsset case final asset?)
          preserveIconAssetColor
              ? Transform.translate(
                  offset: const Offset(0, -0.8),
                  child: Image.asset(
                    asset,
                    width: customIconAssetRenderSize(asset, 13.75),
                    height: customIconAssetRenderSize(asset, 13.75),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                )
              : ImageIcon(
                  AssetImage(asset),
                  size: customIconAssetRenderSize(asset, 11),
                  color: Colors.black,
                )
        else
          Icon(icon, size: 11, color: Colors.black),
        const SizedBox(width: 4),
        Text(
          formatStatCount(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.item});

  final OriginListItem item;

  @override
  Widget build(BuildContext context) {
    final creator = item.createdUserName.trim();
    final body = item.worldView.trim().isEmpty ? item.subtitle : item.worldView;
    if (creator.isEmpty) {
      return Text(
        body,
        style: _bodyStyle,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: _bodyStyle,
        children: [
          TextSpan(
            text: creator,
            style: _bodyStyle.copyWith(
              color: const Color(0xFF6A80AE),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: body.startsWith(' ') ? body : ' $body'),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item, required this.timeText});

  final OriginListItem item;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'OID: ${item.oid}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle,
                ),
              ),
              const SizedBox(width: 9),
              _OriginTickChip(count: item.tickCount),
            ],
          ),
        ),
        if (timeText.isNotEmpty) Text(timeText, style: _metaStyle),
      ],
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

const _metaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.1,
  fontWeight: FontWeight.w400,
);

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
