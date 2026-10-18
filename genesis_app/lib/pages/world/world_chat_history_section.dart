part of '../chat/location_chat_page.dart';

/// Read-only World archive. Shares chat rendering/parsers but never constructs
/// a live chat panel, joins a location, sends Enter, or enables reply actions.
class WorldChatHistorySection extends StatefulWidget {
  const WorldChatHistorySection({
    super.key,
    required this.world,
    required this.currentUid,
    required this.active,
    required this.scrollController,
    required this.onBackgroundChanged,
    required this.onLocationTap,
  });

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
    with AutomaticKeepAliveClientMixin {
  late final _worldHistory = _WorldHistoryLoader(this);
  late final _historySections = _WorldHistoryFolds(this);
  late LocationChatScrollCoordinator _scrollCoordinator;
  String? _reportedBackground;
  String _pendingBackground = '';
  bool _backgroundScheduled = false;
  bool _metadataReady = false;
  int _messageAppVersion = 0;

  WorldChatroomState get _chatroomState =>
      WorldChatroomState(world: widget.world);
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCoordinator = LocationChatScrollCoordinator(
      controller: widget.scrollController,
    );
    _scrollCoordinator.controller.addListener(_worldHistory.onScroll);
    unawaited(_loadMetadata());
  }

  Future<void> _loadMetadata() async {
    final version = await AppMetadataService.buildAppVersion();
    if (!mounted) return;
    setState(() {
      _messageAppVersion = chatroomAppVersionNumber(version.versionName);
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
      _historySections.reset();
      _scrollCoordinator.enter();
    }
    if (!widget.active && oldWidget.active) _worldHistory.pause();
  }

  @override
  void dispose() {
    _worldHistory.pause();
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

  ChatMentionCatalog _mentionCatalogForState(WorldChatroomState state) =>
      locationChatMentionCatalogForState(
        state,
        currentUserIds: [widget.currentUid],
        currentSenderIds: const [],
      );

  bool _messageVersionIsVisible(WorldChatroomMessage row) =>
      chatroomMessageVersionIsVisible(row.minAppVersion, _messageAppVersion);
  LocationChatMessageParser? _parserForMessage(WorldChatroomMessage row) =>
      locationChatMessageParserForTesting(row, appVersion: _messageAppVersion);
  bool _isMineMessage(WorldChatroomMessage row) =>
      _locationChatMessageBelongsToCurrentRole(
        messageBusinessType: row.businessType,
        messageUserId: row.userId,
        currentUserId: widget.currentUid,
      );
  String _messageSenderDisplayName(WorldChatroomMessage row) =>
      resolveLocationChatMessageSenderNameForTesting(
        senderId: row.senderId,
        senderName: row.senderName,
        characters: widget.world.characters,
      );
  String _messageAvatarUrl(WorldChatroomMessage row) =>
      resolveLocationChatMessageAvatarForTesting(
        businessType: row.businessType,
        userId: row.userId,
        senderId: row.senderId,
        characters: widget.world.characters,
        entitiesById: const {},
      );
  bool _messageSenderIsPlayerControlledRole(WorldChatroomMessage row) =>
      _isMineMessage(row) ||
      _mentionCatalogForState(_chatroomState).characters.any(
        (entry) => entry.id == row.senderId && entry.isPlayerControlled,
      );

  List<String>? _locationBoundaryParts(
    ChatMessageVm message,
    ChatMessageVm? previous,
  ) {
    if (previous != null &&
        _worldHistory.locationFor(message) ==
            _worldHistory.locationFor(previous)) {
      return null;
    }
    return _locationPathParts(_worldHistory.locationFor(message));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final messages = _worldHistory.project();
    _historySections.project(messages);
    _worldHistory.ensureVisibleWindow();
    final catalog = _mentionCatalogForState(_chatroomState);
    final locationId = _worldHistory.readingLocationId;
    final location = catalog.locations
        .where((l) => l.id == locationId)
        .firstOrNull;
    _reportBackground(location?.imageUrl ?? '');
    final hasFailure = _worldHistory._failed.isNotEmpty;
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
                            _worldHistory._retryAfter = null;
                            unawaited(_worldHistory.loadOlder());
                          },
                          child: Text(context.l10n.homeRetry),
                        )
                      : !_worldHistory.ready || _worldHistory.loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
              onNotification: _scrollCoordinator.handleScrollNotification,
              child: LocationChatAnchoredMessageList(
                key: ValueKey((widget.worldId, widget.currentUid)),
                coordinator: _scrollCoordinator,
                messages: messages,
                topTitle: '',
                active: widget.active,
                initialContentReady: _worldHistory.ready,
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
              ),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        if (_worldHistory.ready && hasFailure && messages.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () {
                  _worldHistory._retryAfter = null;
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

  List<String> _locationPathParts(String id) {
    final location = _mentionCatalogForState(
      _chatroomState,
    ).locations.where((l) => l.id == id).firstOrNull;
    final tree = _chatroomState.world?.processedLocationTree;
    var node = tree?.nodeById(id);
    final names = <String>[];
    final visited = <String>{};
    while (node != null && visited.add(node.id)) {
      final name = normalizeGenesisUgcTextForDisplay(
        _firstMapString(node.value, const ['location_name', 'name']),
      ).trim();
      if (name.isNotEmpty) names.insert(0, name);
      node = tree?.nodeById(node.parentId);
    }
    return names.isNotEmpty
        ? names
        : [
            if (location?.subtitle.isNotEmpty ?? false) location!.subtitle,
            location?.name ?? id,
          ];
  }

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
      );
    }
    final parts = _locationBoundaryParts(message, previous);
    return (parts?.join(' > '), footerVersion);
  }

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
          ],
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
    final location = _mentionCatalogForState(
      _chatroomState,
    ).locations.where((item) => item.id == locationId).firstOrNull;
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
