part of 'origin_world_page.dart';

class _OriginDetailDraggableSheet extends StatefulWidget {
  const _OriginDetailDraggableSheet({
    required this.origin,
    required this.baseStatusBarStyle,
    required this.minChildSize,
    required this.collapseRequest,
    required this.onOriginChanged,
  });

  static const double defaultInitialChildSize = 0.22;

  final OriginDetail origin;
  final SystemUiOverlayStyle baseStatusBarStyle;
  final double minChildSize;
  final int collapseRequest;
  final VoidCallback onOriginChanged;

  @override
  State<_OriginDetailDraggableSheet> createState() =>
      _OriginDetailDraggableSheetState();
}

class _OriginDetailDraggableSheetState
    extends State<_OriginDetailDraggableSheet> {
  static const double _absoluteMaxChildSize = 1.0;
  static const double _topOverlayTopOffset = 8.0;
  static const double _expandedTopOverlayGap = 20.0;
  static const double _extentUpdateEpsilon = 0.001;
  static const _snapAnimationDuration = Duration(milliseconds: 260);

  late final DraggableScrollableController _sheetController;
  late final OriginDiscussListController _discussController;
  var _currentUid = '';
  var _didLoadCurrentUid = false;
  var _sheetExtent = 0.0;

  double get _minChildSize => widget.minChildSize.clamp(0.08, 0.42).toDouble();

  double get _effectiveInitialChildSize => _minChildSize;

  double _expandedChildSize(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight =
        viewportHeight - _OriginBottomLaunchBar.heightFor(context);
    if (sheetHostHeight <= 0) return _minChildSize;
    final expandedTop =
        GenesisSafeAreaInsets.top(context) +
        _topOverlayTopOffset +
        genesisSearchFieldHeight +
        _expandedTopOverlayGap;
    return (1.0 - expandedTop / sheetHostHeight)
        .clamp(_minChildSize, _absoluteMaxChildSize)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _discussController = OriginDiscussListController();
    _configureDiscuss();
    unawaited(_discussController.loadInitialIfNeeded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialExtent = _effectiveInitialChildSize;
    if (_sheetExtent == 0.0 || _sheetExtent < initialExtent) {
      _sheetExtent = initialExtent;
    }
    if (!_didLoadCurrentUid) {
      _didLoadCurrentUid = true;
      unawaited(_loadCurrentUid());
    }
  }

  @override
  void didUpdateWidget(covariant _OriginDetailDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin.oid != widget.origin.oid) {
      _configureDiscuss();
      unawaited(_discussController.refreshFirstPage());
    }
    if (oldWidget.minChildSize != widget.minChildSize) {
      final maxChildSize = _expandedChildSize(context);
      final nextExtent = _sheetExtent
          .clamp(_minChildSize, maxChildSize)
          .toDouble();
      if (nextExtent != _sheetExtent) _sheetExtent = nextExtent;
    }
    if (oldWidget.baseStatusBarStyle != widget.baseStatusBarStyle) {
      SystemChrome.setSystemUIOverlayStyle(
        _statusBarStyleForExtent(context, _sheetExtent),
      );
    }
    if (oldWidget.collapseRequest != widget.collapseRequest) {
      _collapseToMinChildSize();
    }
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(widget.baseStatusBarStyle);
    _sheetController.dispose();
    _discussController.dispose();
    super.dispose();
  }

  void _collapseToMinChildSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      final targetExtent = _minChildSize;
      if ((_sheetController.size - targetExtent).abs() <=
          _extentUpdateEpsilon) {
        return;
      }
      unawaited(
        _sheetController.animateTo(
          targetExtent,
          duration: _snapAnimationDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  void _configureDiscuss() {
    _discussController.configure(
      oid: widget.origin.oid,
      loader: ({required String oid, required int pn, required int rn}) async {
        return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
      },
    );
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    final maxChildSize = _expandedChildSize(context);
    final extent = notification.extent
        .clamp(_minChildSize, maxChildSize)
        .toDouble();
    final extentChanged = (extent - _sheetExtent).abs() > _extentUpdateEpsilon;
    if (!extentChanged) return false;
    setState(() => _sheetExtent = extent);
    SystemChrome.setSystemUIOverlayStyle(
      _statusBarStyleForExtent(context, extent),
    );
    return false;
  }

  double _statusBarAlphaForExtent(BuildContext context, double extent) {
    final statusBarHeight = GenesisSafeAreaInsets.top(context);
    if (statusBarHeight <= 0) {
      return extent >= _expandedChildSize(context) ? 1.0 : 0.0;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight =
        viewportHeight - _OriginBottomLaunchBar.heightFor(context);
    final sheetTop = sheetHostHeight * (1.0 - extent);
    return ((statusBarHeight - sheetTop) / statusBarHeight)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  SystemUiOverlayStyle _statusBarStyleForExtent(
    BuildContext context,
    double extent,
  ) {
    final alpha = _statusBarAlphaForExtent(context, extent);
    if (alpha <= 0.001) return widget.baseStatusBarStyle;
    final darkIcons = alpha >= 0.5;
    return widget.baseStatusBarStyle.copyWith(
      statusBarColor: Colors.white.withValues(alpha: alpha),
      statusBarIconBrightness: darkIcons
          ? Brightness.dark
          : widget.baseStatusBarStyle.statusBarIconBrightness,
      statusBarBrightness: darkIcons
          ? Brightness.light
          : widget.baseStatusBarStyle.statusBarBrightness,
    );
  }

  double _sheetTopProgress(BuildContext context) {
    final alpha = _statusBarAlphaForExtent(context, _sheetExtent);
    if (alpha > 0) return alpha;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight =
        viewportHeight - _OriginBottomLaunchBar.heightFor(context);
    final statusBarHeight = GenesisSafeAreaInsets.top(context);
    final sheetTop = sheetHostHeight * (1.0 - _sheetExtent);
    final transitionDistance = statusBarHeight <= 0 ? 1.0 : statusBarHeight;
    return ((transitionDistance - (sheetTop - statusBarHeight)) /
            transitionDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final minChildSize = _minChildSize;
    final maxChildSize = _expandedChildSize(context);
    final initialChildSize = _effectiveInitialChildSize
        .clamp(minChildSize, maxChildSize)
        .toDouble();
    final topProgress = _sheetTopProgress(context);
    final topPadding =
        GenesisSafeAreaInsets.top(context) *
        _statusBarAlphaForExtent(context, _sheetExtent);
    final topRadius = 28.0 * (1.0 - topProgress);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBarStyleForExtent(context, _sheetExtent),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: _handleSheetNotification,
        child: DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          snap: true,
          snapAnimationDuration: _snapAnimationDuration,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(topRadius),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(topRadius),
                ),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(overscroll: false),
                  child: CustomScrollView(
                    controller: scrollController,
                    key: PageStorageKey<String>(
                      'origin-detail-bottom-sheet-${widget.origin.oid}',
                    ),
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _OriginSheetHeaderDelegate(
                          topPadding: topPadding,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          originDetailSheetHorizontalPaddingForTesting,
                          originDetailSheetHeaderBodyGapForTesting,
                          originDetailSheetHorizontalPaddingForTesting,
                          32,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _OriginSheetHeaderContent(
                              origin: widget.origin,
                              currentUid: _currentUid,
                              onOriginChanged: widget.onOriginChanged,
                            ),
                            const SizedBox(
                              height: originDetailSectionGapForTesting,
                            ),
                            _WorldViewSection(origin: widget.origin),
                            if (_originPreviewTick(widget.origin)
                                case final tick?) ...[
                              const SizedBox(
                                height: originDetailSectionGapForTesting,
                              ),
                              _LaunchPreviewSection(
                                origin: widget.origin,
                                previewTick: tick,
                              ),
                            ],
                            const SizedBox(
                              height: originDetailSectionGapForTesting,
                            ),
                            CopyWorldProgressSection(
                              originId: widget.origin.oid,
                            ),
                            const SizedBox(
                              height: originDetailSectionGapForTesting,
                            ),
                            _DiscussSection(
                              origin: widget.origin,
                              controller: _discussController,
                            ),
                            const SizedBox(
                              height: originDetailSectionGapForTesting,
                            ),
                            _OriginCharactersSection(
                              characters: widget.origin.characters,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OriginSheetDragHandle extends StatelessWidget {
  const _OriginSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Center(
        child: Container(
          width: 64,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD2D2D2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _OriginSheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OriginSheetHeaderDelegate({required this.topPadding});

  final double topPadding;

  @override
  double get minExtent => topPadding + originDetailSheetHeaderHeightForTesting;

  @override
  double get maxExtent => topPadding + originDetailSheetHeaderHeightForTesting;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: topPadding + originDetailSheetHandleTopOffsetForTesting,
            child: const _OriginSheetDragHandle(),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _OriginSheetHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding;
  }
}

class _OriginSheetHeaderContent extends StatelessWidget {
  const _OriginSheetHeaderContent({
    required this.origin,
    required this.currentUid,
    required this.onOriginChanged,
  });

  final OriginDetail origin;
  final String currentUid;
  final VoidCallback onOriginChanged;

  @override
  Widget build(BuildContext context) {
    final originator = origin.ownerDeleted
        ? deletedEntityDisplayText
        : origin.originator.trim().isEmpty
        ? '-'
        : formatUidForDisplay(origin.originator);
    final ownerUid = origin.ownerUid.trim();
    final canEditOrigin =
        currentUid.trim().isNotEmpty && currentUid.trim() == ownerUid;
    final version = origin.versionNum <= 0 ? 1 : origin.versionNum;
    final age = formatGenesisDateTime(origin.updatedAt, fallback: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: Text(
                originDisplayName(origin.name, fallback: origin.oid),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B6192),
                  decoration: TextDecoration.none,
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
                    targetType: 'origin',
                    targetId: origin.oid,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GenesisPairedMetaRow(
          leftLabel: 'OID',
          leftValue: origin.oid,
          leftDisplayValue: origin.deleted ? deletedEntityDisplayText : null,
          leftCopyEnabled: !origin.deleted,
          rightText: 'Originator: ${formatUidForDisplay(originator)}',
          rightOnTap: ownerUid.isEmpty || origin.ownerDeleted
              ? null
              : () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': ownerUid}),
        ),
        const SizedBox(height: 0),
        Text(
          'Latest Version: V$version${age.isEmpty ? '' : ' · $age'}',
          style: CopyableIdLabel.textStyle,
        ),
        if (canEditOrigin) ...[
          const SizedBox(height: 8),
          GenesisPrimaryButton(
            label: 'Edit Worldo',
            onPressed: () async {
              await Navigator.of(context).pushNamed(
                RouteNames.edit,
                arguments: {'origin_id': origin.oid},
              );
              if (!context.mounted) return;
              onOriginChanged();
            },
            backgroundColor: const Color(0xFF3B2468),
            foregroundColor: Colors.white,
          ),
        ],
      ],
    );
  }
}
