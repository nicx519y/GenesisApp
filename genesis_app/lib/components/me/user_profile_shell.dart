part of 'user_profile_library.dart';

class UserProfileContent extends StatefulWidget {
  const UserProfileContent({
    super.key,
    required this.data,
    this.originsListenable,
    this.worldsListenable,
    this.originsLoading = false,
    this.worldsLoading = false,
    this.isUpdatingProfile = false,
    this.avatarUrlListenable,
    this.displayNameListenable,
    this.isUpdatingProfileListenable,
    this.gemWalletStateListenable,
    this.onEditAvatar,
    this.onEditDisplayName,
    this.onRefreshOrigins,
    this.onRefreshWorlds,
    this.onWorldDeleted,
    this.onCollectionTabChanged,
    this.onCollapsedChanged,
    this.nameUidGap = 4,
    this.tabLabelFontSize = 16,
    this.originTabLabel = '#Worldo',
    this.worldTabLabel = 'World',
    this.showCollectionCounts = false,
    this.isBlocking = false,
    this.isBlocked = false,
  });

  final UserProfileData data;
  final ValueListenable<UserProfileCollectionState<UserProfileOriginItem>>?
  originsListenable;
  final ValueListenable<UserProfileCollectionState<UserProfileWorldItem>>?
  worldsListenable;
  final bool originsLoading;
  final bool worldsLoading;
  final bool isUpdatingProfile;
  final ValueListenable<String>? avatarUrlListenable;
  final ValueListenable<String>? displayNameListenable;
  final ValueListenable<bool>? isUpdatingProfileListenable;
  final ValueListenable<GemWalletState>? gemWalletStateListenable;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onEditDisplayName;
  final Future<void> Function()? onRefreshOrigins;
  final Future<void> Function()? onRefreshWorlds;
  final ValueChanged<UserProfileWorldItem>? onWorldDeleted;
  final ValueChanged<int>? onCollectionTabChanged;
  final ValueChanged<bool>? onCollapsedChanged;
  final double nameUidGap;
  final double? tabLabelFontSize;
  final String originTabLabel;
  final String worldTabLabel;
  final bool showCollectionCounts;
  final bool isBlocking;
  final bool isBlocked;

  @override
  State<UserProfileContent> createState() => _UserProfileContentState();
}

class _UserProfileContentState extends State<UserProfileContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _scrollController;
  final GlobalKey _profileHeaderKey = GlobalKey();
  bool? _isFollowedOverride;
  int? _followerCountOverride;
  bool _followLoading = false;
  bool _lastCollapsed = false;
  int _lastReportedTabIndex = 0;
  double _profileHeaderHeight = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lastReportedTabIndex = _tabController.index;
    _tabController.addListener(_handleTabControllerChanged);
    _scrollController = ScrollController();
    _scrollController.addListener(_updateCollapsedState);
  }

  @override
  void didUpdateWidget(covariant UserProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.uid != widget.data.uid) {
      _isFollowedOverride = null;
      _followerCountOverride = null;
      _followLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabControllerChanged);
    _scrollController.removeListener(_updateCollapsedState);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isFollowed = _isFollowedOverride ?? data.isFollowed;
    final followerCount = _followerCountOverride ?? data.followerCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureProfileHeader();
      _updateCollapsedState();
    });

    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: _buildProfileHeader(data, isFollowed, followerCount),
          ),
          if (!widget.isBlocking && !widget.isBlocked)
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileTabsHeaderDelegate(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildCollectionTabs(data),
                ),
              ),
            ),
        ];
      },
      body: _buildCollectionBody(data),
    );
  }

  Widget _buildCollectionTabs(UserProfileData data) {
    Widget buildTabs(int originCount, int worldCount) {
      return GenesisTabBar(
        controller: _tabController,
        labels: [
          widget.showCollectionCounts
              ? '${widget.originTabLabel} $originCount'
              : widget.originTabLabel,
          widget.showCollectionCounts
              ? '${widget.worldTabLabel} $worldCount'
              : widget.worldTabLabel,
        ],
        horizontalPadding: 8,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        labelFontSize: widget.tabLabelFontSize,
        onTap: _reportCollectionTab,
      );
    }

    if (!widget.showCollectionCounts) {
      return buildTabs(data.origins.length, data.worlds.length);
    }

    Widget buildWithWorldCount(int originCount) {
      final worldsListenable = widget.worldsListenable;
      if (worldsListenable == null) {
        return buildTabs(originCount, data.worlds.length);
      }
      return ValueListenableBuilder<
        UserProfileCollectionState<UserProfileWorldItem>
      >(
        valueListenable: worldsListenable,
        builder: (context, state, _) {
          return buildTabs(originCount, state.items.length);
        },
      );
    }

    final originsListenable = widget.originsListenable;
    if (originsListenable == null) {
      return buildWithWorldCount(data.origins.length);
    }
    return ValueListenableBuilder<
      UserProfileCollectionState<UserProfileOriginItem>
    >(
      valueListenable: originsListenable,
      builder: (context, state, _) {
        return buildWithWorldCount(state.items.length);
      },
    );
  }

  Widget _buildCollectionBody(UserProfileData data) {
    if (widget.isBlocking) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (widget.isBlocked) {
      return const Center(
        child: Text(
          'User blocked',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBarView(
        controller: _tabController,
        children: [
          _OriginProfileCollectionList(
            items: data.origins,
            isLoading: widget.originsLoading,
            listenable: widget.originsListenable,
            onRefresh: widget.onRefreshOrigins,
            canEditOrigins: data.isSelf,
          ),
          _WorldProfileCollectionList(
            items: data.worlds,
            isLoading: widget.worldsLoading,
            listenable: widget.worldsListenable,
            onRefresh: widget.onRefreshWorlds,
            canDeleteWorlds: data.isSelf,
            onWorldDeleted: widget.onWorldDeleted,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    UserProfileData data,
    bool isFollowed,
    int followerCount,
  ) {
    return KeyedSubtree(
      key: _profileHeaderKey,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  url: data.avatarUrl,
                  name: data.displayName,
                  urlListenable: widget.avatarUrlListenable,
                  nameListenable: widget.displayNameListenable,
                  isUpdating: widget.isUpdatingProfile,
                  updatingListenable: widget.isUpdatingProfileListenable,
                  onEdit: widget.onEditAvatar,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: _DisplayNameText(
                              displayName: data.displayName,
                              displayNameListenable:
                                  widget.displayNameListenable,
                            ),
                          ),
                          if (widget.onEditDisplayName != null) ...[
                            const SizedBox(width: 4),
                            _ProfileEditButton(
                              isUpdating: widget.isUpdatingProfile,
                              updatingListenable:
                                  widget.isUpdatingProfileListenable,
                              onTap: widget.onEditDisplayName!,
                            ),
                          ],
                        ],
                      ),
                      if (widget.nameUidGap > 0)
                        SizedBox(height: widget.nameUidGap),
                      CopyableIdLabel(
                        label: 'UID',
                        value: data.uid,
                        displayValue: data.deleted
                            ? deletedEntityDisplayText
                            : formatUidForDisplay(data.uid),
                        enabled: !data.deleted,
                      ),
                      const SizedBox(height: 12),
                      _buildFollowStats(data, followerCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (data.isSelf) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _GemsBalanceEntry(
                stateListenable: widget.gemWalletStateListenable,
              ),
            ),
          ],
          if (!data.isSelf) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ProfileActionButtons(
                isFollowed: isFollowed,
                followLoading: _followLoading,
                onFollowToggle: () => _toggleFollow(isFollowed),
                onMessage: () => unawaited(_openMessages()),
              ),
            ),
          ],
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildFollowStats(UserProfileData data, int followerCount) {
    return KeyedSubtree(
      key: const ValueKey<String>('user-profile-follow-stats'),
      child: _FollowStats(
        followingCount: data.followingCount,
        followerCount: followerCount,
        onFollowingTap: () => _openFollows(0),
        onFollowersTap: () => _openFollows(1),
      ),
    );
  }

  void _measureProfileHeader() {
    final context = _profileHeaderKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    _profileHeaderHeight = renderObject.size.height;
  }

  void _updateCollapsedState() {
    if (!_scrollController.hasClients) return;
    final threshold = _profileHeaderHeight > 0 ? _profileHeaderHeight - 1 : 120;
    final collapsed = _scrollController.offset >= threshold;
    if (collapsed == _lastCollapsed) return;
    _lastCollapsed = collapsed;
    widget.onCollapsedChanged?.call(collapsed);
  }

  void _handleTabControllerChanged() {
    if (_tabController.indexIsChanging) return;
    _reportCollectionTab(_tabController.index);
  }

  void _reportCollectionTab(int index) {
    if (_lastReportedTabIndex == index) return;
    _lastReportedTabIndex = index;
    widget.onCollectionTabChanged?.call(index);
  }

  Future<void> _toggleFollow(bool isFollowed) async {
    if (_followLoading) return;
    final uid = widget.data.uid.trim();
    if (uid.isEmpty) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;

    setState(() => _followLoading = true);
    try {
      if (isFollowed) {
        await AppServicesScope.read(context).api.v1.follow.unfollow(uid: uid);
      } else {
        await AppServicesScope.read(context).api.v1.follow.follow(uid: uid);
      }
      if (!mounted) return;
      final nextFollowed = !isFollowed;
      final currentFollowerCount =
          _followerCountOverride ?? widget.data.followerCount;
      setState(() {
        _isFollowedOverride = nextFollowed;
        _followerCountOverride = nextFollowed
            ? currentFollowerCount + 1
            : _decrementCount(currentFollowerCount);
        _followLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      showGenesisToast(context, apiErrorMessage(error));
    }
  }

  Future<void> _openMessages() async {
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      RouteNames.chat,
      arguments: {
        'peer_uid': widget.data.uid,
        'peer_name': _currentDisplayName,
        'peer_avatar': widget.data.avatarUrl,
      },
    );
  }

  void _openFollows(int initialIndex) {
    Navigator.of(context).pushNamed(
      RouteNames.follows,
      arguments: {
        'uid': widget.data.uid,
        'title': _currentDisplayName,
        'initialIndex': initialIndex,
      },
    );
  }

  String get _currentDisplayName {
    final listenableName = widget.displayNameListenable?.value.trim() ?? '';
    if (listenableName.isNotEmpty) return listenableName;
    return widget.data.displayName;
  }

  int _decrementCount(int value) {
    return value > 0 ? value - 1 : 0;
  }
}

class _GemsBalanceEntry extends StatelessWidget {
  const _GemsBalanceEntry({this.stateListenable});

  final ValueListenable<GemWalletState>? stateListenable;

  @override
  Widget build(BuildContext context) {
    final listenable = stateListenable;
    if (listenable == null) return _buildEntry(context, null);
    return ValueListenableBuilder<GemWalletState>(
      valueListenable: listenable,
      builder: (context, state, _) => _buildEntry(context, state.balance),
    );
  }

  Widget _buildEntry(BuildContext context, int? balance) {
    return GestureDetector(
      key: const ValueKey('user-profile-gems-entry'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(RouteNames.gemWallet),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE0E6)),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              gemIconAsset,
              key: const ValueKey('user-profile-gem-icon'),
              width: gemLargeIconSize,
              height: gemLargeIconSize,
            ),
            const SizedBox(width: 8),
            Text(
              balance == null ? '0' : _formatGemBalance(balance),
              key: const ValueKey('user-profile-gems-balance'),
              style: const TextStyle(
                fontSize: 16,
                height: 20 / 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Gems',
              style: TextStyle(
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF999999)),
          ],
        ),
      ),
    );
  }
}

String _formatGemBalance(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

class _ProfileTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabsHeaderDelegate({required this.child});

  static const double _height = 5 + genesisTabHeight;

  final Widget child;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 5),
          SizedBox(height: genesisTabHeight, child: child),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
