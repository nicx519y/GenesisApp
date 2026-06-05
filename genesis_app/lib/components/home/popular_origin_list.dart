import 'package:flutter/material.dart';

import '../discuss/origin_discuss_preview_list.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import '../origin/origin_item_card.dart';

const String _connectIconAsset = 'assets/custom-icons/png/connect.png';

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginImage(
          imageUrl: item.cover,
          seed: item.oid.isEmpty ? title : item.oid,
          label: _badgeText(title),
          width: 48,
          height: 48,
          borderRadius: thumbnailBorderRadius,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
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
                  fontWeight: FontWeight.w500,
                ),
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
          ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _OriginImage(
              imageUrl: item.cover,
              seed: item.oid.isEmpty ? item.title : item.oid,
              label: _badgeText(item.title),
              borderRadius: 0,
            ),
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
                    _OverlayStat(icon: MyFlutterApp.save, value: item.copyCnt),
                    const SizedBox(width: 10),
                    _OverlayStat(
                      iconAsset: _connectIconAsset,
                      value: item.connectCnt,
                    ),
                    const SizedBox(width: 10),
                    _OverlayStat(
                      iconAsset: aiCharacterIconAsset,
                      value: item.characterCnt,
                    ),
                    const SizedBox(width: 10),
                    _OverlayStat(
                      icon: MyFlutterApp.user,
                      value: item.locationCnt,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginImage extends StatelessWidget {
  const _OriginImage({
    required this.imageUrl,
    required this.seed,
    required this.label,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final String seed;
  final String label;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _CoverPlaceholder(seed: seed, label: label);
    final resolved = imageUrl.trim();
    final image = resolved.isEmpty
        ? placeholder
        : resolved.startsWith('assets/')
        ? Image.asset(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => placeholder,
          )
        : Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => placeholder,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}

class _OverlayStat extends StatelessWidget {
  const _OverlayStat({this.icon, this.iconAsset, required this.value})
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
              const Icon(Icons.skip_next, size: 15, color: Color(0xFF8B8B8B)),
              const SizedBox(width: 4),
              Text('v${item.versionNum}', style: _metaStyle),
            ],
          ),
        ),
        if (timeText.isNotEmpty) Text(timeText, style: _metaStyle),
      ],
    );
  }
}

class _EnterOriginRow extends StatelessWidget {
  const _EnterOriginRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        color: const Color(0xFFF2F4F7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                originDisplayName(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1D1D1D),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Enter',
              style: TextStyle(
                color: Color(0xFF4B6192),
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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

const _bodyStyle = TextStyle(
  color: Color(0xFF1D1D1D),
  fontSize: 11,
  height: 1.32,
  fontWeight: FontWeight.w400,
);

const _metaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.1,
  fontWeight: FontWeight.w400,
);

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
