// ignore_for_file: use_key_in_widget_constructors

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/ai_content_disclaimer.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import 'world_constants.dart';
import 'world_header.dart';
import 'world_models.dart';
import 'world_value_helpers.dart';

class WorldDetailsLoadingContent extends StatelessWidget {
  const WorldDetailsLoadingContent();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        WorldHeaderLoadingSkeleton(),
        SizedBox(height: 4),
        WorldEventLoadingSkeleton(),
      ],
    );
  }
}

class WorldHeaderLoadingSkeleton extends StatelessWidget {
  const WorldHeaderLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 38),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: WorldLoadingBone(width: 168, height: 18),
              ),
            ),
            SizedBox(width: 38),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: WorldLoadingBone(width: 128, height: 12)),
            SizedBox(width: 18),
            WorldLoadingBone(width: 112, height: 12),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  WorldLoadingBone(width: 42, height: 12),
                  WorldLoadingBone(width: 46, height: 12),
                  WorldLoadingBone(width: 40, height: 12),
                  WorldLoadingBone(width: 44, height: 12),
                ],
              ),
            ),
            SizedBox(width: 14),
            WorldLoadingBone(width: 120, height: 28, radius: 8),
          ],
        ),
      ],
    );
  }
}

class WorldEventLoadingSkeleton extends StatelessWidget {
  const WorldEventLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorldLoadingBone(width: 96, height: 14),
        SizedBox(height: 14),
        WorldLoadingBone(widthFactor: 0.92, height: 12),
        SizedBox(height: 8),
        WorldLoadingBone(widthFactor: 0.78, height: 12),
        SizedBox(height: 8),
        WorldLoadingBone(widthFactor: 0.86, height: 12),
        SizedBox(height: 18),
        WorldLoadingBone(widthFactor: 0.48, height: 12),
        SizedBox(height: 14),
        WorldLoadingBone(widthFactor: 0.96, height: 92, radius: 6),
      ],
    );
  }
}

class WorldLoadingBone extends StatelessWidget {
  const WorldLoadingBone({
    this.width,
    this.widthFactor,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return child;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class WorldDetailSection extends StatelessWidget {
  const WorldDetailSection({
    required this.world,
    required this.currentUid,
    this.newUserJoinNotice,
  });

  final WorldDetail world;
  final String currentUid;
  final WorldNewUserJoinNotice? newUserJoinNotice;

  @override
  Widget build(BuildContext context) {
    final title = world.name.trim().isEmpty ? world.worldId : world.name.trim();
    final owner = worldOwnerDisplayName(world);
    final ownerUid = world.ownerUid.trim();
    final version = world.origin.versionNum <= 0 ? 1 : world.origin.versionNum;
    final sourceWorldoOid = world.origin.oid.trim();
    final sourceWorldoRouteId = sourceWorldoOid.isNotEmpty
        ? sourceWorldoOid
        : world.originId > 0
        ? '${world.originId}'
        : '';
    final sourceOid = sourceWorldoOid.isEmpty
        ? '${world.originId}'
        : sourceWorldoOid;
    final canOpenSourceWorldo = sourceWorldoRouteId.isNotEmpty;
    final brief = world.brief.trim().isEmpty ? '-' : world.brief.trim();
    final cover = worldResolveAssetUrl(world.cover).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B6192),
                ),
              ),
            ),
            SizedBox(
              width: 38,
              child: GenesisMoreActionMenuButton(
                buttonSize: 18 * 1.25,
                items: [
                  genesisReportMenuItem(
                    context: context,
                    targetType: 'world',
                    targetId: world.worldId,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GenesisPairedMetaRow(
          leftLabel: 'WID',
          leftValue: world.worldId,
          leftDisplayValue: world.deleted ? deletedEntityDisplayText : null,
          leftCopyEnabled: !world.deleted,
          leftStyle: worldHeaderMetaTextStyle,
          leftIconColor: worldHeaderMetaColor,
          rightText: 'Owner: $owner',
          rightOnTap: ownerUid.isEmpty || world.ownerDeleted
              ? null
              : () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': ownerUid}),
          rightStyle: worldHeaderMetaTextStyle,
          rightIconColor: worldHeaderMetaColor,
        ),
        const SizedBox(height: 0),
        GenesisInlineMetaLabel(
          text: 'Source Worldo: $sourceOid · V$version',
          onTap: !canOpenSourceWorldo
              ? null
              : () => Navigator.of(context).pushNamed(
                  RouteNames.originWorld,
                  arguments: {
                    'oid': sourceWorldoRouteId,
                    'originId': world.originId,
                  },
                ),
          style: CopyableIdLabel.textStyle,
          trailingIcon: canOpenSourceWorldo ? Icons.chevron_right : null,
          trailingIconColor: worldHeaderMetaColor,
          trailingIconSize: 16,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (newUserJoinNotice == null)
              const Spacer()
            else
              Expanded(
                child: SizedBox(
                  height: 35,
                  child: _WorldNewUserJoinNoticeSwitcher(
                    notice: newUserJoinNotice!,
                  ),
                ),
              ),
            const SizedBox(width: 16),
            GenesisPrimaryButton(
              label: 'Invite',
              onPressed: () => _copyInviteText(context, worldName: title),
              height: 35,
              width: 140,
              backgroundColor: const Color(0xFFFF2442),
              disabledBackgroundColor: const Color(
                0xFFFF2442,
              ).withValues(alpha: 0.62),
              foregroundColor: Colors.white,
              fontSize: 16,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const WorldDetailSectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: Color(0xFFFF2442),
          title: 'World Brief',
        ),
        const SizedBox(height: 8),
        Text(brief, style: worldDetailBodyTextStyle),
        const SizedBox(height: 8),
        WorldDetailCoverImage(url: cover),
        const SizedBox(height: 24),
        const WorldDetailSectionTitle(
          asset: worldSectionCastIconAsset,
          iconSize: 17,
          iconColor: Color(0xFF666666),
          title: 'Cast',
        ),
        const SizedBox(height: 8),
        WorldCharactersSection(world: world, currentUid: currentUid),
      ],
    );
  }

  Future<void> _copyInviteText(
    BuildContext context, {
    required String worldName,
  }) async {
    await Clipboard.setData(
      ClipboardData(
        text: worldInviteShareTextForTesting(
          worldName: worldName,
          wid: world.worldId,
        ),
      ),
    );
    if (!context.mounted) return;
    showGenesisToast(context, 'Link copied. Share it with your friends.');
  }
}

String worldInviteShareTextForTesting({
  required String worldName,
  required String wid,
}) {
  final resolvedWid = wid.trim();
  final resolvedWorldName = worldName.trim().isEmpty
      ? resolvedWid
      : worldName.trim();
  return 'Join my world "$resolvedWorldName" on Worldo!\n'
      '$resolvedWid\n'
      'Search this WID on Worldo to find and join.\n'
      'https://worldo.ai/download';
}

class _WorldNewUserJoinNoticeSwitcher extends StatelessWidget {
  const _WorldNewUserJoinNoticeSwitcher({required this.notice});

  final WorldNewUserJoinNotice notice;

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<String>(_noticeAnimationKey(notice));
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == currentKey;
          final offset = isIncoming
              ? Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation)
              : Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(animation);
          return SlideTransition(position: offset, child: child);
        },
        child: _WorldNewUserJoinNoticeText(key: currentKey, notice: notice),
      ),
    );
  }

  String _noticeAnimationKey(WorldNewUserJoinNotice notice) {
    return [
      notice.characterId,
      notice.playerUid,
      notice.playerUsername,
      notice.characterName,
      notice.ts?.millisecondsSinceEpoch ?? 0,
    ].join('|');
  }
}

class _WorldNewUserJoinNoticeText extends StatelessWidget {
  const _WorldNewUserJoinNoticeText({super.key, required this.notice});

  final WorldNewUserJoinNotice notice;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: worldHeaderMetaColor,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w400,
    );
    const emphasisStyle = TextStyle(
      color: Color(0xFF111111),
      fontWeight: FontWeight.w700,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.clip,
                text: TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(
                      text: notice.displayPlayerUsername,
                      style: emphasisStyle,
                    ),
                    const TextSpan(text: ' joined and is playing the role of '),
                    TextSpan(
                      text: notice.displayCharacterName,
                      style: emphasisStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WorldDetailSectionTitle extends StatelessWidget {
  const WorldDetailSectionTitle({
    this.icon,
    this.asset,
    this.iconSize = 14,
    required this.iconColor,
    required this.title,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
  final double iconSize;
  final Color iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    return Row(
      children: [
        if (asset != null)
          SvgPicture.asset(
            asset,
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          )
        else
          Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}

class WorldDetailCoverImage extends StatelessWidget {
  const WorldDetailCoverImage({required this.url});

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9A9A9A)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = mediaHeight.isFinite
            ? _maxHeight.clamp(0.0, mediaHeight * 0.35).toDouble()
            : _maxHeight;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxHeight * _aspectRatio;
        final width = maxWidth.clamp(0.0, maxHeight * _aspectRatio).toDouble();
        final height = width / _aspectRatio;

        final preview = Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: GenesisImageRadii.content,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageUrl = selectGenesisImageUrl(
                    url,
                    logicalWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : null,
                    logicalHeight: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : null,
                    devicePixelRatio:
                        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
                  );
                  return imageUrl.isEmpty
                      ? fallback
                      : imageUrl.startsWith('assets/')
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                        )
                      : GenesisStaticNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_) => fallback,
                          errorWidget: (_, _) => fallback,
                        );
                },
              ),
            ),
          ),
        );
        if (viewerUrl.isEmpty) return preview;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showGenesisImageViewer(context, imageUrls: [viewerUrl]),
          child: preview,
        );
      },
    );
  }
}

class WorldSectionListView extends StatelessWidget {
  const WorldSectionListView({required this.storageKey, required this.child});

  final String storageKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: PageStorageKey<String>(storageKey),
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
      children: [child],
    );
  }
}

List<Map<String, dynamic>> worldEventTicksAscending(
  List<Map<String, dynamic>> ticks,
) {
  final indexedTicks = ticks.indexed.toList(growable: false);
  indexedTicks.sort((a, b) {
    final tickCompare = worldEventTickNumber(
      a.$2,
    ).compareTo(worldEventTickNumber(b.$2));
    if (tickCompare != 0) return tickCompare;
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexedTicks) entry.$2];
}

List<Map<String, dynamic>> worldMergeEventTicksAscending(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  final keyedTicks = <String, Map<String, dynamic>>{};
  final unkeyedTicks = <Map<String, dynamic>>[];
  for (final tick in [...existing, ...incoming]) {
    final key = worldEventTickIdentity(tick);
    if (key.isEmpty) {
      unkeyedTicks.add(tick);
      continue;
    }
    keyedTicks[key] = tick;
  }
  return worldEventTicksAscending([...keyedTicks.values, ...unkeyedTicks]);
}

String worldEventTickIdentity(Map<String, dynamic> tick) {
  final tickId = worldMapString(tick, const ['tick_id', 'id']);
  if (tickId.isNotEmpty) return 'id:$tickId';
  final tickNo = worldEventTickNumber(tick);
  if (tickNo > 0) return 'no:$tickNo';
  return '';
}

int worldEventTickNumber(Map<String, dynamic> tick) {
  final tickNo = worldMapString(tick, const ['tick_no', 'tick_number', 'no']);
  final parsed = int.tryParse(tickNo);
  if (parsed != null) return parsed;

  final id = worldMapString(tick, const ['tick_id', 'id']);
  final suffix = RegExp(r'(\d+)$').firstMatch(id)?.group(1);
  return int.tryParse(suffix ?? '') ?? 0;
}

class WorldEventsSection extends StatefulWidget {
  const WorldEventsSection({
    super.key,
    required this.world,
    required this.ticks,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.latestRevision,
    required this.targetTickNumber,
    required this.contentPadding,
    required this.onLoadMore,
  });

  final WorldDetail world;
  final List<Map<String, dynamic>> ticks;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final int latestRevision;
  final int? targetTickNumber;
  final EdgeInsetsGeometry contentPadding;
  final VoidCallback onLoadMore;

  @override
  State<WorldEventsSection> createState() => WorldEventsSectionState();
}

class WorldEventsSectionState extends State<WorldEventsSection> {
  static const int _loadMorePageThreshold = 3;
  static const Duration _pageTurnDuration = Duration(milliseconds: 260);

  late final PageController _pageController = PageController();
  final _tickCardResetRevisions = <String, int>{};
  var _currentPage = 0;
  var _currentTickIdentity = '';
  var _animatingPage = false;
  var _showLatestWhenTicksArrive = true;

  int? get _requestedTickNumber {
    final target = widget.targetTickNumber;
    return target == null || target <= 0 ? null : target;
  }

  @override
  void initState() {
    super.initState();
    if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
      _jumpToCurrentPage();
    }
  }

  @override
  void didUpdateWidget(covariant WorldEventsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final worldChanged = oldWidget.world.worldId != widget.world.worldId;
    if (worldChanged) {
      _currentPage = 0;
      _currentTickIdentity = '';
      _showLatestWhenTicksArrive = true;
      if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
      }
      return;
    }

    if (oldWidget.latestRevision != widget.latestRevision ||
        oldWidget.targetTickNumber != widget.targetTickNumber) {
      _showLatestWhenTicksArrive = true;
      if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
        _maybeLoadPendingTarget();
      }
      return;
    }

    if (_currentTickIdentity.isEmpty) {
      if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
        _maybeLoadMoreForPage(_currentPage);
      }
      return;
    }

    final nextIndex = _findPageByIdentity(_currentTickIdentity);
    if (_isPendingTargetIdentity(_currentTickIdentity)) {
      _maybeLoadPendingTarget();
    }
    if (nextIndex < 0) {
      if (_isPendingTargetIdentity(_currentTickIdentity) &&
          _setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
        _maybeLoadMoreForPage(_currentPage);
        _maybeLoadPendingTarget();
        return;
      }
      _currentPage = _currentPage.clamp(0, _maxRenderedPage).toInt();
      _currentTickIdentity = _pageIdentityAt(_currentPage);
      _bumpTickCardResetRevisionAt(_currentPage);
      _jumpToCurrentPage();
      return;
    }
    if (nextIndex != _currentPage) {
      _currentPage = nextIndex;
      _bumpTickCardResetRevisionAt(_currentPage);
      _jumpToCurrentPage();
      _maybeLoadMoreForPage(_currentPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleTicks {
    return widget.ticks;
  }

  int get _maxRenderedPage => math.max(0, _pageCount - 1);

  int get _pageCount {
    final pendingTargetPage = _pendingTargetPage;
    if (pendingTargetPage == null) return _visibleTicks.length;
    return _visibleTicks.length + 1;
  }

  int? get _pendingTargetPage {
    final target = _requestedTickNumber;
    if (target == null || _pageIndexForTickNumber(target) != null) {
      return null;
    }
    if (!widget.initialLoading && !widget.loadingMore && !widget.hasMore) {
      return null;
    }
    return _insertionPageForTickNumber(target);
  }

  bool _setCurrentPageToRequestedTargetOrLatestIfAvailable() {
    final visibleTicks = _visibleTicks;
    final requestedTickNumber = _requestedTickNumber;
    if (requestedTickNumber != null) {
      final resolvedTargetPage = _pageIndexForTickNumber(requestedTickNumber);
      final pendingTargetPage = _pendingTargetPage;
      if (resolvedTargetPage != null || pendingTargetPage != null) {
        final targetPage = resolvedTargetPage ?? pendingTargetPage!;
        _currentPage = targetPage.clamp(0, _maxRenderedPage).toInt();
        _currentTickIdentity = _pageIdentityAt(_currentPage);
        _showLatestWhenTicksArrive = false;
        _bumpTickCardResetRevisionAt(_currentPage);
        return _pageCount > 0;
      }
    }
    if (visibleTicks.isEmpty) return false;
    final target = _showLatestWhenTicksArrive ? _maxRenderedPage : _currentPage;
    _currentPage = target.clamp(0, _maxRenderedPage).toInt();
    _currentTickIdentity = _pageIdentityAt(_currentPage);
    _showLatestWhenTicksArrive = false;
    _bumpTickCardResetRevisionAt(_currentPage);
    return true;
  }

  void _jumpToCurrentPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_pageController.hasClients) {
        _jumpToCurrentPage();
        return;
      }
      final target = _currentPage.clamp(0, _maxRenderedPage).toInt();
      _pageController.jumpToPage(target);
    });
  }

  void _handlePageChanged(int page) {
    _currentPage = page.clamp(0, _maxRenderedPage).toInt();
    _currentTickIdentity = _pageIdentityAt(_currentPage);
    _maybeLoadMoreForPage(_currentPage);
  }

  void _maybeLoadMoreForPage(int page) {
    if (!widget.hasMore || widget.loadingMore || widget.initialLoading) return;
    if (page <= _loadMorePageThreshold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.hasMore ||
            widget.loadingMore ||
            widget.initialLoading) {
          return;
        }
        widget.onLoadMore();
      });
    }
  }

  void _maybeLoadPendingTarget() {
    if (_requestedTickNumber == null ||
        _pendingTargetPage == null ||
        !widget.hasMore ||
        widget.loadingMore ||
        widget.initialLoading) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _requestedTickNumber == null ||
          _pendingTargetPage == null ||
          !widget.hasMore ||
          widget.loadingMore ||
          widget.initialLoading) {
        return;
      }
      widget.onLoadMore();
    });
  }

  void _bumpTickCardResetRevisionAt(int page) {
    final identity = _pageIdentityAt(page);
    if (identity.isEmpty) return;
    _tickCardResetRevisions[identity] =
        (_tickCardResetRevisions[identity] ?? 0) + 1;
  }

  void _turnPage(int delta) {
    if (_animatingPage || !_pageController.hasClients) return;
    final target = (_currentPage + delta).clamp(0, _maxRenderedPage).toInt();
    if (target == _currentPage) {
      _maybeLoadMoreForPage(_currentPage);
      return;
    }
    _animatingPage = true;
    setState(() => _bumpTickCardResetRevisionAt(target));
    unawaited(
      _pageController
          .animateToPage(
            target,
            duration: _pageTurnDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (!mounted) return;
            _animatingPage = false;
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingTargetPage = _pendingTargetPage;
    final hasPendingTargetPage = pendingTargetPage != null;
    if (widget.ticks.isEmpty &&
        widget.initialLoading &&
        !hasPendingTargetPage) {
      return Padding(
        padding: widget.contentPadding,
        child: const WorldEventLoadingSkeleton(),
      );
    }
    if (widget.ticks.isEmpty && !hasPendingTargetPage) {
      return Padding(
        padding: widget.contentPadding,
        child: WorldEmptySection(
          text: widget.error == null ? 'No events yet.' : 'Load events failed.',
        ),
      );
    }

    final locationsById = <String, Map<String, dynamic>>{
      for (final location in widget.world.locations)
        worldMapString(location, const ['location_id', 'id']): location,
    }..remove('');
    final fallbackBody = worldEventBody(widget.world);
    final metricUnit = worldMapString(widget.world.metric, const ['unit']);
    final visibleTicks = _visibleTicks;

    return Stack(
      children: [
        PageView.builder(
          key: const ValueKey<String>('world-events-tick-pager'),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pageCount,
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            if (index == pendingTargetPage) {
              final tickNumber = _requestedTickNumber ?? widget.world.tickCount;
              return WorldTickEventCardPage(
                key: ValueKey<String>('world-event-tick-pending-$tickNumber'),
                resetRevision:
                    _tickCardResetRevisions['pending_tick:$tickNumber'] ?? 0,
                hasTopEdgePage: index > 0,
                hasBottomEdgePage: index < _pageCount - 1,
                padding: widget.contentPadding,
                onTurnPage: _turnPage,
                child: WorldTickPendingEventPage(tickNumber: tickNumber),
              );
            }
            final tickIndex = _tickIndexForPage(index);
            if (tickIndex == null) return const SizedBox.shrink();
            final tick = visibleTicks[tickIndex];
            final identity = worldEventTickIdentity(tick);
            final tickNumber = worldTickEventNumber(
              tick,
              fallback: tickIndex + 1,
            );
            return WorldTickEventCardPage(
              key: ValueKey<String>('world-event-tick-$identity'),
              resetRevision: _tickCardResetRevisions[identity] ?? 0,
              hasTopEdgePage: index > 0,
              hasBottomEdgePage: index < _pageCount - 1,
              padding: widget.contentPadding,
              onTurnPage: _turnPage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tickNumber == 1)
                    const AiContentDisclaimer(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 18),
                      textAlign: TextAlign.left,
                    ),
                  WorldTickEventItem(
                    key: ValueKey<String>('world-event-tick-item-$identity'),
                    tick: tick,
                    tickNumber: tickNumber,
                    fallbackBody: fallbackBody,
                    locationsById: locationsById,
                    dateLabel: worldTickParagraphTimestamp(tick),
                    stackedContent: true,
                    contentLabelStyle: _worldEventContentLabelStyle,
                    contentTextStyle: _worldEventContentTextStyle,
                    contentTimestampStyle: _worldEventContentTimestampStyle,
                    metricUnit: metricUnit,
                    isLast: true,
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.loadingMore)
          const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: WorldEventsLoadingMoreIndicator(),
            ),
          ),
      ],
    );
  }

  int? _tickIndexForPage(int page) {
    final pendingTargetPage = _pendingTargetPage;
    final tickIndex = pendingTargetPage != null && page > pendingTargetPage
        ? page - 1
        : page;
    if (tickIndex < 0 || tickIndex >= _visibleTicks.length) return null;
    return tickIndex;
  }

  String _pageIdentityAt(int page) {
    final pendingTargetPage = _pendingTargetPage;
    if (pendingTargetPage != null && page == pendingTargetPage) {
      return 'pending_tick:${_requestedTickNumber ?? 0}';
    }
    final tickIndex = _tickIndexForPage(page);
    if (tickIndex == null) return '';
    return worldEventTickIdentity(_visibleTicks[tickIndex]);
  }

  int _findPageByIdentity(String identity) {
    for (var page = 0; page < _pageCount; page += 1) {
      if (_pageIdentityAt(page) == identity) return page;
    }
    return -1;
  }

  bool _isPendingTargetIdentity(String identity) {
    final target = _requestedTickNumber;
    return target != null && identity == 'pending_tick:$target';
  }

  int? _pageIndexForTickNumber(int targetTickNumber) {
    final tickIndex = _visibleTicks.indexWhere(
      (tick) => worldTickEventNumber(tick) == targetTickNumber,
    );
    if (tickIndex < 0) return null;
    return tickIndex;
  }

  int _insertionPageForTickNumber(int targetTickNumber) {
    final visibleTicks = _visibleTicks;
    for (var index = 0; index < visibleTicks.length; index += 1) {
      final tickNumber = worldTickEventNumber(visibleTicks[index]);
      if (tickNumber >= targetTickNumber) return index;
    }
    return visibleTicks.length;
  }
}

class WorldTickPendingEventPage extends StatelessWidget {
  const WorldTickPendingEventPage({required this.tickNumber});

  final int tickNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Tick $tickNumber',
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey<String>('world-event-pending-tombstone'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 168),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorldTickPendingSkeletonLine(widthFactor: 0.28, height: 10),
              SizedBox(height: 12),
              WorldTickPendingSkeletonLine(widthFactor: 0.92),
              SizedBox(height: 8),
              WorldTickPendingSkeletonLine(widthFactor: 0.76),
              SizedBox(height: 18),
              WorldTickPendingSkeletonLine(widthFactor: 0.34, height: 10),
              SizedBox(height: 12),
              WorldTickPendingSkeletonLine(widthFactor: 0.86),
              SizedBox(height: 8),
              WorldTickPendingSkeletonLine(widthFactor: 0.58),
            ],
          ),
        ),
      ],
    );
  }
}

class WorldTickPendingSkeletonLine extends StatelessWidget {
  const WorldTickPendingSkeletonLine({
    required this.widthFactor,
    this.height = 12,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE1E4EA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class WorldTickEventCardPage extends StatefulWidget {
  const WorldTickEventCardPage({
    super.key,
    required this.child,
    required this.resetRevision,
    required this.hasTopEdgePage,
    required this.hasBottomEdgePage,
    required this.padding,
    required this.onTurnPage,
  });

  final Widget child;
  final int resetRevision;
  final bool hasTopEdgePage;
  final bool hasBottomEdgePage;
  final EdgeInsetsGeometry padding;
  final ValueChanged<int> onTurnPage;

  @override
  State<WorldTickEventCardPage> createState() => WorldTickEventCardPageState();
}

class WorldTickEventCardPageState extends State<WorldTickEventCardPage> {
  static const double _turnDragThreshold = 56;
  static const double _edgeArrowMinSize = 18;
  static const double _edgeArrowMaxSize = 24;

  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  var _dragDeltaY = 0.0;
  var _dragStartedAtTop = true;
  var _dragStartedAtBottom = true;
  var _topPullDistance = 0.0;
  var _bottomPullDistance = 0.0;

  @override
  void didUpdateWidget(covariant WorldTickEventCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetRevision != widget.resetRevision) {
      _jumpScrollToTop();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  bool get _atTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentBefore <= 0;
  }

  bool get _atBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentAfter <= 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _dragDeltaY = 0;
    _dragStartedAtTop = _atTop;
    _dragStartedAtBottom = _atBottom;
    _setEdgePullDistance(top: 0, bottom: 0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _dragDeltaY += event.delta.dy;
    _setEdgePullDistance(
      top: _dragStartedAtTop && widget.hasTopEdgePage
          ? math.max(0, _dragDeltaY)
          : 0,
      bottom: _dragStartedAtBottom && widget.hasBottomEdgePage
          ? math.max(0, -_dragDeltaY)
          : 0,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    final dragDeltaY = _dragDeltaY;
    _dragDeltaY = 0;
    _setEdgePullDistance(top: 0, bottom: 0);
    if (dragDeltaY <= -_turnDragThreshold && _dragStartedAtBottom) {
      widget.onTurnPage(1);
    } else if (dragDeltaY >= _turnDragThreshold && _dragStartedAtTop) {
      widget.onTurnPage(-1);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _dragDeltaY = 0;
    _setEdgePullDistance(top: 0, bottom: 0);
  }

  void _setEdgePullDistance({required double top, required double bottom}) {
    final nextTop = top.clamp(0, _turnDragThreshold).toDouble();
    final nextBottom = bottom.clamp(0, _turnDragThreshold).toDouble();
    if (nextTop == _topPullDistance && nextBottom == _bottomPullDistance) {
      return;
    }
    setState(() {
      _topPullDistance = nextTop;
      _bottomPullDistance = nextBottom;
    });
  }

  Widget _buildEdgeArrow({
    required bool top,
    required double pullDistance,
    required IconData icon,
    required Key key,
  }) {
    if (pullDistance <= 0) {
      return const SizedBox.shrink();
    }
    final progress = (pullDistance / _turnDragThreshold).clamp(0.0, 1.0);
    final iconSize =
        _edgeArrowMinSize +
        ((_edgeArrowMaxSize - _edgeArrowMinSize) * progress);
    final offset = 6 + (8 * progress);
    return Positioned(
      top: top ? offset : null,
      bottom: top ? null : offset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.3 + (0.7 * progress),
          child: Align(
            alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
            child: Icon(
              icon,
              key: key,
              size: iconSize,
              color: const Color(0xFF111111),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: widget.padding,
              physics: WorldTickCardScrollPhysics(
                allowLeadingOverscroll: widget.hasTopEdgePage,
                allowTrailingOverscroll: widget.hasBottomEdgePage,
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: widget.child,
            ),
          ),
          _buildEdgeArrow(
            top: true,
            pullDistance: _topPullDistance,
            icon: Icons.keyboard_arrow_down_rounded,
            key: const ValueKey<String>('world-event-top-edge-arrow'),
          ),
          _buildEdgeArrow(
            top: false,
            pullDistance: _bottomPullDistance,
            icon: Icons.keyboard_arrow_up_rounded,
            key: const ValueKey<String>('world-event-bottom-edge-arrow'),
          ),
        ],
      ),
    );
  }
}

class WorldTickCardScrollPhysics extends BouncingScrollPhysics {
  const WorldTickCardScrollPhysics({
    required this.allowLeadingOverscroll,
    required this.allowTrailingOverscroll,
    super.parent,
  });

  final bool allowLeadingOverscroll;
  final bool allowTrailingOverscroll;

  @override
  WorldTickCardScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return WorldTickCardScrollPhysics(
      allowLeadingOverscroll: allowLeadingOverscroll,
      allowTrailingOverscroll: allowTrailingOverscroll,
      parent: buildParent(ancestor),
    );
  }

  @override
  double frictionFactor(double overscrollFraction) {
    return super.frictionFactor(overscrollFraction) * 0.5;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!allowLeadingOverscroll &&
        value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (!allowTrailingOverscroll &&
        position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

const TextStyle _worldEventContentLabelStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w600,
  color: Color(0xFF111111),
);

const TextStyle _worldEventContentTextStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w400,
  color: Color(0xFF444444),
);

const TextStyle _worldEventContentTimestampStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
);

String? worldTickParagraphTimestamp(Map<String, dynamic> tick) {
  final result = tick['tick_result'];
  if (result is! Map) return null;
  final paragraphs = result['paragraphs'];
  if (paragraphs is! List) return null;
  for (final paragraph in paragraphs) {
    if (paragraph is! Map) continue;
    final timestamp = '${paragraph['timestamp'] ?? ''}'.trim();
    if (timestamp.isNotEmpty) return formatGenesisTimestamp(timestamp);
  }
  return null;
}

class WorldEventsLoadingMoreIndicator extends StatelessWidget {
  const WorldEventsLoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class WorldStatusSection extends StatelessWidget {
  const WorldStatusSection({required this.world, required this.currentUid});

  final WorldDetail world;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return WorldCharacterList(
      characters: world.characters,
      currentUid: currentUid,
      emptyText: 'No character status yet.',
      subtitleBuilder: (character) =>
          worldMetricStatusText(world.metric, character),
      subtitleColor: const Color(0xFF666666),
      showCharacterDetails: false,
    );
  }
}

class WorldCharactersSection extends StatelessWidget {
  const WorldCharactersSection({required this.world, required this.currentUid});

  final WorldDetail world;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return WorldCharacterList(
      characters: world.characters,
      currentUid: currentUid,
      emptyText: 'No characters yet.',
      subtitleBuilder: worldCharacterDescriptionText,
      subtitleColor: const Color(0xFF666666),
      showCharacterDetails: true,
    );
  }
}

class WorldCharacterList extends StatelessWidget {
  const WorldCharacterList({
    required this.characters,
    required this.currentUid,
    required this.emptyText,
    required this.subtitleBuilder,
    required this.subtitleColor,
    required this.showCharacterDetails,
  });

  final List<Map<String, dynamic>> characters;
  final String currentUid;
  final String emptyText;
  final String Function(Map<String, dynamic> character) subtitleBuilder;
  final Color subtitleColor;
  final bool showCharacterDetails;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return WorldEmptySection(text: emptyText);
    }
    final hasCharacterRole = characters.any(worldIsCharacterRole);
    final sortedCharacters = worldSortedCharacters(characters, currentUid);

    return Padding(
      padding: EdgeInsets.only(top: hasCharacterRole ? 5 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sortedCharacters.length; i++) ...[
            WorldCharacterRow(
              character: sortedCharacters[i],
              currentUid: currentUid,
              subtitle: subtitleBuilder(sortedCharacters[i]),
              subtitleColor: subtitleColor,
              showCharacterDetails: showCharacterDetails,
            ),
            if (i != sortedCharacters.length - 1) const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class WorldCharacterRow extends StatelessWidget {
  const WorldCharacterRow({
    required this.character,
    required this.currentUid,
    required this.subtitle,
    required this.subtitleColor,
    required this.showCharacterDetails,
  });

  final Map<String, dynamic> character;
  final String currentUid;
  final String subtitle;
  final Color subtitleColor;
  final bool showCharacterDetails;

  @override
  Widget build(BuildContext context) {
    final name = worldMapString(character, const [
      'name',
    ], fallback: 'Character');
    final avatarUrl = worldResizedCharacterAvatarUrl(context, character);
    final playerUid = worldMapString(character, const ['player_uid']);
    final username = worldMapString(character, const ['player_username']);
    final playerDeleted = entityDeleted(character['player_deleted']);
    final suffix = worldCharacterNameSuffix(
      currentUid: currentUid,
      playerUid: playerUid,
      username: username,
      playerDeleted: playerDeleted,
    );
    final isCharacterRole = worldIsCharacterRole(character);
    final roleLabel = isCharacterRole ? 'Character' : 'Player';
    final showAiCharacterDetails = showCharacterDetails && isCharacterRole;
    final identity = worldMapString(character, const ['identity']);
    final brief = worldMapString(character, const ['brief']);
    final goal = worldMapString(character, const ['goal']);
    final hasOriginStyleDetails =
        identity.isNotEmpty || brief.isNotEmpty || goal.isNotEmpty;
    const bodyStyle = TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: Color(0xFF111111),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenesisCharacterAvatar(
          url: avatarUrl,
          name: name,
          showStar: isCharacterRole,
          starSize: 20,
          showFallbackWhileLoading: false,
        ),
        const SizedBox(width: 14),
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
                          fontSize: 14,
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
                if (showAiCharacterDetails) ...[
                  if (identity.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      identity,
                      style: bodyStyle,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (brief.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      brief,
                      style: bodyStyle.copyWith(color: const Color(0xFFFF2442)),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (goal.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Goal: $goal',
                      style: bodyStyle,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (!hasOriginStyleDetails) ...[
                    const SizedBox(height: 5),
                    Text(
                      'No character details yet.',
                      style: bodyStyle.copyWith(color: subtitleColor),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ] else if (showCharacterDetails) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: bodyStyle,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ).copyWith(color: subtitleColor),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String worldResizedCharacterAvatarUrl(
  BuildContext context,
  Map<String, dynamic> character,
) {
  final rawUrl = worldMapString(character, const ['avatar']).trim();
  final resizedUrl = resizeGenesisImageUrl(
    rawUrl,
    logicalWidth: worldCharacterAvatarLogicalSize,
    devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
  );
  return resizedUrl.isNotEmpty ? resizedUrl : rawUrl;
}

List<Map<String, dynamic>> worldSortedCharacters(
  List<Map<String, dynamic>> characters,
  String currentUid,
) {
  final indexed = characters.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final rankCompare = worldCharacterSortRank(
      a.$2,
      currentUid,
    ).compareTo(worldCharacterSortRank(b.$2, currentUid));
    if (rankCompare != 0) return rankCompare;
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

int worldCharacterSortRank(Map<String, dynamic> character, String currentUid) {
  if (worldIsCurrentUserCharacter(character, currentUid)) return 0;
  return worldIsCharacterRole(character) ? 2 : 1;
}

bool worldIsCurrentUserCharacter(
  Map<String, dynamic> character,
  String currentUid,
) {
  final playerUid = worldMapString(character, const ['player_uid']);
  return currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid;
}

bool worldIsCharacterRole(Map<String, dynamic> character) {
  return worldMapString(character, const ['player_uid']).isEmpty;
}

String worldCharacterNameSuffix({
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

class WorldEmptySection extends StatelessWidget {
  const WorldEmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}

String worldEventBody(WorldDetail world) {
  final candidates = [
    world.latestNarrator,
    world.origin.worldView,
    world.origin.description,
    world.name,
  ];
  for (final item in candidates) {
    final value = item.trim();
    if (value.isNotEmpty) return value;
  }
  return 'No world events yet.';
}

String worldCharacterDescriptionText(Map<String, dynamic> character) {
  final identity = worldMapString(character, const ['identity']);
  if (!worldIsCharacterRole(character)) {
    return identity.isEmpty ? 'No character details yet.' : identity;
  }

  final brief = worldMapString(character, const ['brief']);
  final goal = worldMapString(character, const ['goal']);
  final details = worldOrderedNonEmptyStrings([
    identity,
    brief,
    goal.isEmpty ? '' : 'Goal: $goal',
  ]);
  return details.isEmpty ? 'No character details yet.' : details.join('\n');
}

String worldMetricStatusText(
  Map<String, dynamic> metric,
  Map<String, dynamic> character,
) {
  final label = worldMapString(metric, const ['label']);
  final unit = worldMapString(metric, const ['unit']);
  final value = worldResolvedMetricValueText(
    character['metric_value'],
    metric['default'],
  );
  return '$label: $value$unit';
}

String worldResolvedMetricValueText(Object? metricValue, Object? defaultValue) {
  final parsedMetricValue = worldMetricNumber(metricValue);
  final resolved = parsedMetricValue == null || parsedMetricValue == 0
      ? defaultValue
      : metricValue;
  return worldMetricDisplayValue(resolved);
}

num? worldMetricNumber(Object? value) {
  if (value is num) return value;
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return num.tryParse(text);
}

String worldMetricDisplayValue(Object? value) {
  if (value is num) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '0';
  return text;
}
