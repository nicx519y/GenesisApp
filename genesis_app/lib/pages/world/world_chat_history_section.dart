part of '../chat/location_chat_page.dart';

/// Owned by WorldPage, never by a modal sheet or a global singleton.
class WorldHistoryViewCache {
  final projection = WorldHistoryProjection();
  final viewport = LocationChatViewportCache();
  final collapsedMessages = <String>{};
  WorldHistoryController? controller;
  AppServices? _services;
  String? _worldId, _uid;
  String? readingId;
  String readingLocationId = '';
  bool started = false;
  int? appVersion;
  String get backgroundImageUrl =>
      projection.metadata.locations[readingLocationId]?.imageUrl ?? '';
  int snapshot = -1;

  void bind(AppServices services, String worldId, String uid) {
    if (identical(services, _services) && worldId == _worldId && uid == _uid) {
      return;
    }
    dispose();
    _services = services;
    _worldId = worldId;
    _uid = uid;
    services.sessionRevision.addListener(clear);
  }

  void clear() {
    started = false;
    readingId = null;
    readingLocationId = '';
    projection.clear();
    viewport.clear();
    collapsedMessages.clear();
    controller?.clear();
    snapshot = controller?.snapshot ?? -1;
  }

  void dispose() {
    _services?.sessionRevision.removeListener(clear);
    _services = null;
    controller?.dispose();
    controller = null;
    clear();
  }
}

/// Read-only World archive. Shares chat rendering but never joins a location.
class WorldChatHistorySection extends StatefulWidget {
  const WorldChatHistorySection({
    super.key,
    this.cache,
    this.onDragDismissAllowedChanged,
    required this.world,
    required this.currentUid,
    required this.active,
    required this.scrollController,
    required this.onBackgroundChanged,
    required this.onLocationTap,
  });

  final WorldHistoryViewCache? cache;
  final ValueChanged<bool>? onDragDismissAllowedChanged;
  final WorldDetail world;
  final String currentUid;
  final bool active;
  final ScrollController scrollController;
  final ValueChanged<String> onBackgroundChanged;
  final ValueChanged<String> onLocationTap;
  String get worldId => world.worldId;

  @override
  State<WorldChatHistorySection> createState() =>
      _WorldChatHistorySectionState();
}

class _WorldChatHistorySectionState extends State<WorldChatHistorySection>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final _cache = widget.cache ?? WorldHistoryViewCache();
  late final _worldHistory = _WorldHistoryLoader(this);
  late final _historySections = _WorldHistoryFolds(this);
  late LocationChatScrollCoordinator _scrollCoordinator;
  String? _reportedBackground;
  String _pendingBackground = '';
  bool _backgroundScheduled = false;
  bool? _reportedDragDismissAllowed;
  bool _metadataReady = false;
  int _messageAppVersion = 0;

  AppServices? _services;
  PagePresentationController? _presentation;
  bool _foreground = true;
  bool _routeCurrent = true;
  bool _tickerEnabled = true;
  bool get _requestsEnabled =>
      widget.active &&
      _foreground &&
      _routeCurrent &&
      _tickerEnabled &&
      !(_presentation?.paused ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    if (!identical(services, _services)) {
      _services?.sessionRevision.removeListener(_sessionChanged);
      if (_services != null) _worldHistory.reset();
      _services = services;
      services.sessionRevision.addListener(_sessionChanged);
    }
    final presentation = PagePresentationScope.maybeRead(context);
    if (!identical(presentation, _presentation)) {
      _presentation?.removeListener(_visibilityChanged);
      _presentation = presentation;
      presentation?.addListener(_visibilityChanged);
    }
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _cache.bind(services, widget.worldId, widget.currentUid);
    if (!_requestsEnabled) _worldHistory.pause();
  }

  void _sessionChanged() {
    _worldHistory.reset();
    _historySections.reset();
    _scrollCoordinator.enter();
    _changed();
  }

  void _visibilityChanged() {
    if (!_requestsEnabled) _worldHistory.pause();
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _visibilityChanged();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scrollCoordinator = LocationChatScrollCoordinator(
      controller: widget.scrollController,
    );
    _scrollCoordinator.controller.addListener(_worldHistory.onScroll);
    _metadataReady = _cache.appVersion != null;
    _messageAppVersion = _cache.appVersion ?? 0;
    if (!_metadataReady) unawaited(_loadMetadata());
  }

  Future<void> _loadMetadata() async {
    final version = await AppMetadataService.buildAppVersion();
    if (!mounted) return;
    setState(() {
      _messageAppVersion = chatroomAppVersionNumber(version.versionName);
      _cache.appVersion = _messageAppVersion;
      _metadataReady = true;
    });
  }

  @override
  void didUpdateWidget(covariant WorldChatHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      final previous = _scrollCoordinator;
      previous.controller.removeListener(_worldHistory.onScroll);
      _scrollCoordinator = LocationChatScrollCoordinator(
        controller: widget.scrollController,
      );
      _scrollCoordinator.controller.addListener(_worldHistory.onScroll);
      _historySections.reveal = null;
      // The child detaches listeners from the old coordinator this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    if (oldWidget.worldId != widget.worldId ||
        oldWidget.currentUid != widget.currentUid) {
      _worldHistory.reset();
      _cache.bind(_services!, widget.worldId, widget.currentUid);
      _historySections.reset();
      _scrollCoordinator.enter();
    }
    if (!widget.active && oldWidget.active) {
      _worldHistory.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _services?.sessionRevision.removeListener(_sessionChanged);
    _presentation?.removeListener(_visibilityChanged);
    _worldHistory.detach();
    if (widget.cache == null) _cache.dispose();
    _scrollCoordinator.controller.removeListener(_worldHistory.onScroll);
    _scrollCoordinator.dispose();
    super.dispose();
  }

  void _update(VoidCallback update) {
    if (mounted) setState(update);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _returnToBottom() {
    final controller = _worldHistory.controller;
    if (!_requestsEnabled || controller == null || controller.loading) return;
    _scrollCoordinator.beginHistoryNavigation();
    _worldHistory.cancelScheduledLoad();
    if (!controller.returnToNewest()) return;
    _historySections.reveal = null;
    _cache.readingId = null;
    _scrollCoordinator.requestBottom(
      reason: LocationChatBottomReason.unseenMessageNotice,
      behavior: LocationChatBottomBehavior.jump,
    );
  }

  List<String>? _locationBoundaryParts(
    ChatMessageVm message,
    ChatMessageVm? previous,
  ) {
    if (_worldHistory.locationFor(message).isEmpty) return null;
    if (previous != null &&
        _worldHistory.sectionFor(message) ==
            _worldHistory.sectionFor(previous)) {
      return null;
    }
    return _locationPathParts(_worldHistory.locationFor(message));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final messages = _worldHistory.project();
    _historySections.project(_worldHistory.projection.rows);
    _worldHistory.restoreReading();
    _worldHistory.ensureVisibleWindow();
    final dragDismissAllowed =
        _worldHistory.ready && !_worldHistory.loading && !_worldHistory.hasMore;
    if (_reportedDragDismissAllowed != dragDismissAllowed) {
      _reportedDragDismissAllowed = dragDismissAllowed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reportedDragDismissAllowed == dragDismissAllowed) {
          widget.onDragDismissAllowedChanged?.call(dragDismissAllowed);
        }
      });
    }
    final catalog = _worldHistory.projection.metadata.catalog;
    final locationId = _worldHistory.readingLocationId;
    final location = catalog.locations
        .where((l) => l.id == locationId)
        .firstOrNull;
    _reportBackground(location?.imageUrl ?? '');
    final hasFailure = _worldHistory.failed;
    final body = !_worldHistory.ready || messages.isEmpty
        ? CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: hasFailure
                      ? TextButton(
                          onPressed: () {
                            unawaited(_worldHistory.loadOlder());
                          },
                          child: Text(context.l10n.homeRetry),
                        )
                      : !_worldHistory.ready || _worldHistory.loading
                      ? const _WorldHistoryLoadingSkeleton()
                      : _worldHistory.hasMore || _worldHistory.hasNewer
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_worldHistory.hasMore)
                              TextButton(
                                onPressed: () =>
                                    unawaited(_worldHistory.loadOlder()),
                                child: Text(
                                  context.l10n.chatLoadEarlierMessages,
                                ),
                              ),
                            if (_worldHistory.hasNewer) _loadNewerButton(),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.worldHistoryEmpty,
                            textAlign: TextAlign.center,
                            style: kLocationChatStyle.bubbleTextStyle.copyWith(
                              color: GenesisColors.darkTextSecondary,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          )
        : ChatMentionScope(
            catalog: catalog,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null &&
                    notification.depth == 0 &&
                    notification.metrics.axis == Axis.vertical) {
                  _worldHistory.controller?.allowContinuation();
                }
                return _scrollCoordinator.handleScrollNotification(
                  notification,
                );
              },
              child: LocationChatAnchoredMessageList(
                key: ValueKey((widget.worldId, widget.currentUid)),
                coordinator: _scrollCoordinator,
                viewportCache: _cache.viewport,
                captureReadingAnchorOnDragStart: true,
                messages: messages,
                topTitle: '',
                active: _requestsEnabled,
                initialContentReady: _worldHistory.ready,
                initialViewportPlaceholder:
                    const _WorldHistoryLoadingSkeleton(),
                restoreInitialCompletedContent: true,
                replyActionsVisible: false,
                replyWaitingPositioningEnabled: false,
                showDateDividers: false,
                style: kLocationChatStyle,
                oldestEdgeLoading: _worldHistory.loading,
                onOldestEdgeLoadingCollapsed: _worldHistory.ensureVisibleWindow,
                hiddenMessageIds: _historySections.hidden,
                historyReveal: _historySections.reveal,
                expandedHistoryHeaders: _historySections.expandedHeaders,
                pinnedHistoryHeaderBuilder: _historySections.pinnedHeader,
                messageDecorator: _decorateLocationBoundary,
                messageDecorationVersion: _locationBoundaryVersion,
                messageReadingMarkerKey: _worldHistory.existingBoundaryKey,
                onReadingMessageChanged: _historySections.reading,
                onVisibleMessagesChanged: _worldHistory.visible,
                historyGapLoaders: {
                  if (_worldHistory.hasMore && !_worldHistory.loading)
                    messages.first.localId: () =>
                        unawaited(_worldHistory.loadOlder()),
                },
              ),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        if (_worldHistory.ready &&
            (messages.isNotEmpty || _worldHistory.hasNewer))
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: AnimatedBuilder(
                animation: _scrollCoordinator,
                builder: (context, _) => AnimatedBuilder(
                  animation: widget.scrollController,
                  builder: (context, _) {
                    final visible =
                        widget.active &&
                        (_worldHistory.hasNewer ||
                            !_scrollCoordinator.isAtBottom);
                    if (!visible) return const SizedBox.shrink();
                    final disabled = _worldHistory.loading;
                    return Tooltip(
                      message: MaterialLocalizations.of(
                        context,
                      ).lastPageTooltip,
                      child: _LocationChatFloatingNotice(
                        actionKey: const ValueKey(
                          'world-history-return-to-bottom',
                        ),
                        onTap: disabled ? null : _returnToBottom,
                        child: Icon(
                          Icons.keyboard_double_arrow_down,
                          size: 24,
                          color: disabled
                              ? GenesisColors.darkTextTertiary
                              : Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        if (_worldHistory.ready && hasFailure && messages.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () {
                  unawaited(_worldHistory.loadOlder());
                },
                child: Text(context.l10n.homeRetry),
              ),
            ),
          ),
      ],
    );
  }

  // Parent paints one continuous backdrop behind title and scrolling content.
  // Publish after layout; never rebuild the ancestor during this child's build.
  void _reportBackground(String url) {
    _pendingBackground = url;
    if (!widget.active || _reportedBackground == url || _backgroundScheduled) {
      return;
    }
    _backgroundScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backgroundScheduled = false;
      if (!mounted || !widget.active) return;
      _reportedBackground = _pendingBackground;
      widget.onBackgroundChanged(_pendingBackground);
    });
  }

  List<String> _locationPathParts(String id) =>
      _worldHistory.projection.metadata.paths[id] ?? [id];

  Object? _locationBoundaryVersion(
    ChatMessageVm message,
    ChatMessageVm? previous,
  ) {
    final continueLocation = _historySections.continueLocationFor(message);
    final footerVersion = continueLocation == null
        ? null
        : (
            continueLocation,
            widget.world.characterPositions,
            widget.world.processedLocationTree,
            widget.world.locations,
            Localizations.localeOf(context),
          );
    final section = _historySections.headerFor(message);
    if (section != null) {
      return (
        section.id,
        _historySections.expanded.contains(section.id),
        _locationPathParts(section.locationId).join(' > '),
        footerVersion,
        _worldHistory.hasNewer,
        _worldHistory.loading,
      );
    }
    final parts = _locationBoundaryParts(message, previous);
    return (
      parts?.join(' > '),
      footerVersion,
      _newerBoundary(message),
      _worldHistory.loading,
    );
  }

  bool _newerBoundary(ChatMessageVm message) =>
      _worldHistory.hasNewer &&
      _worldHistory.projection.rows.lastOrNull?.id == message.localId;

  Widget _loadNewerButton() => TextButton.icon(
    onPressed: _worldHistory.loading
        ? null
        : () => unawaited(_worldHistory.loadNewer()),
    icon: const Icon(Icons.keyboard_arrow_down),
    label: Text(context.l10n.loadMoreAction),
  );

  Widget _decorateLocationBoundary(
    ChatMessageVm message,
    ChatMessageVm? previous,
    Widget child,
  ) {
    final continueLocation = _historySections.continueLocationFor(message);
    if (continueLocation != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child, _continueLocationCard(continueLocation)],
      );
    }
    if (_newerBoundary(message)) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          TextButton.icon(
            onPressed: _worldHistory.loading
                ? null
                : () => unawaited(_worldHistory.loadNewer()),
            icon: const Icon(Icons.keyboard_arrow_down),
            label: Text(context.l10n.loadMoreAction),
          ),
        ],
      );
    }
    final section = _historySections.headerFor(message);
    if (section != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _historySections.toggle(section),
            child: _locationPathDivider(
              _locationPathParts(section.locationId),
              key: _worldHistory.boundaryKey(message.localId),
              trailing: _historySections.button(section),
            ),
          ),
          if (_historySections.expanded.contains(section.id)) ...[
            const SizedBox(height: 12),
            child,
          ] else if (_worldHistory.hasNewer &&
              _worldHistory.projection.rows.lastOrNull?.id ==
                  section.messageIds.last)
            _loadNewerButton(),
        ],
      );
    }
    final parts = _locationBoundaryParts(message, previous);
    if (parts == null) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _locationPathDivider(
          parts,
          key: _worldHistory.boundaryKey(message.localId),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _continueLocationCard(String locationId) {
    final location = _worldHistory.projection.metadata.locations[locationId];
    final path = _locationPathParts(locationId);
    // Use current World occupancy, never infer "now at" from old speakers.
    final occupants =
        worldAvatarsByLocationFromCharacterPositions(
          widget.world.characterPositions,
          currentUid: '',
        )[locationId] ??
        const [];
    final names = occupants
        .map((item) => item.name?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    final l10n = context.l10n;
    return Padding(
      key: ValueKey('world-history-continue-$locationId'),
      // The preceding chat row already includes its normal bottom spacing.
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.worldHistoryContinueHere,
            textAlign: TextAlign.center,
            style: kLocationChatStyle.bubbleTextStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: GenesisColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ChatLocationJumpCard(
            localizedTemplate: names.isEmpty
                ? GenesisLocalizedRichText.placeholder('locationName')
                : l10n.originCharactersAtLocation(
                    count: names.length,
                    names: GenesisLocalizedRichText.placeholder('names'),
                    locationName: GenesisLocalizedRichText.placeholder(
                      'locationName',
                    ),
                  ),
            names: names.join(', '),
            action: '',
            locationName: path.last,
            parentPath: path.take(path.length - 1).join(' > '),
            imageUrl: location?.imageUrl ?? '',
            onTap: () => widget.onLocationTap(locationId),
          ),
        ],
      ),
    );
  }

  Widget _locationPathDivider(
    List<String> parts, {
    Key? key,
    Widget? trailing,
  }) {
    final visibleParts = parts.skip(math.max(0, parts.length - 2)).toList();
    final pathStyle = kLocationChatStyle.bubbleTextStyle.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: GenesisColors.darkTextSecondary,
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(0, constraints.maxWidth - 24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: GenesisColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (visibleParts.length > 1)
                                    TextSpan(text: '${visibleParts.first} > '),
                                  TextSpan(
                                    text: visibleParts.last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              softWrap: true,
                              style: pathStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0x29FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ] else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// Shared full-sheet backdrop for the World History title and message viewport.
class WorldChatHistoryBackground extends StatelessWidget {
  const WorldChatHistoryBackground({super.key, required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    switchInCurve: Curves.easeInOut,
    switchOutCurve: Curves.easeInOut,
    layoutBuilder: (current, previous) => Stack(
      fit: StackFit.expand,
      children: [...previous, if (current != null) current],
    ),
    child: KeyedSubtree(
      key: ValueKey(imageUrl),
      child: _LocationChatBackground(
        imageUrl: imageUrl,
        previewImageUrl: null,
        color: kLocationChatStyle.conversationBackgroundColor,
        enabled: true,
      ),
    ),
  );
}

/// Static placeholders follow the archive's location header and message rows.
class _WorldHistoryLoadingSkeleton extends StatelessWidget {
  const _WorldHistoryLoadingSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('world-history-loading-skeleton'),
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var section = 0; section < 3; section++) ...[
          _bone(0.38, 16),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: GenesisColors.darkFaintFill,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _bone(0.3, 12)),
            ],
          ),
          const SizedBox(height: 12),
          _bone(1, 14),
          const SizedBox(height: 8),
          _bone(0.76, 14),
          const SizedBox(height: 32),
        ],
      ],
    ),
  );

  Widget _bone(double width, double height) => FractionallySizedBox(
    widthFactor: width,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: GenesisColors.darkFaintFill,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
