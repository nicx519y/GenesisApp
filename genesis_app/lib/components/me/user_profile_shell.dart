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
    this.isBlocking = false,
    this.isBlocked = false,
    this.recentChatWorldId = '',
    this.appearance = UserProfileAppearance.standard,
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
  final bool isBlocking;
  final bool isBlocked;
  final String recentChatWorldId;
  final UserProfileAppearance appearance;

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
                appearance: widget.appearance,
              ),
            ),
        ];
      },
      body: _buildCollectionBody(data),
    );
  }

  Widget _buildCollectionTabs(UserProfileData data) {
    Widget buildTabs() {
      final originState = widget.originsListenable?.value;
      final worldState = widget.worldsListenable?.value;
      return _ProfileCollectionTabs(
        controller: _tabController,
        appearance: widget.appearance,
        originCount: originState?.total ?? 0,
        worldCount: worldState?.total ?? 0,
        labelFontSize: widget.tabLabelFontSize,
        onTap: _reportCollectionTab,
      );
    }

    if (widget.appearance != UserProfileAppearance.worldoMe) {
      return buildTabs();
    }
    final countListenables = <Listenable>[
      if (widget.originsListenable case final listenable?) listenable,
      if (widget.worldsListenable case final listenable?) listenable,
    ];
    if (countListenables.isEmpty) return buildTabs();
    return AnimatedBuilder(
      animation: Listenable.merge(countListenables),
      builder: (context, _) => buildTabs(),
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
      return Center(
        child: Text(
          'User blocked',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.genesisColors.textFaint,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final isWorldoMe = widget.appearance == UserProfileAppearance.worldoMe;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWorldoMe ? 22 : 16),
      child: TabBarView(
        controller: _tabController,
        children: [
          _OriginProfileCollectionList(
            items: data.origins,
            isLoading: widget.originsLoading,
            listenable: widget.originsListenable,
            onRefresh: widget.onRefreshOrigins,
            redesigned: isWorldoMe,
          ),
          _WorldProfileCollectionList(
            items: data.worlds,
            isLoading: widget.worldsLoading,
            listenable: widget.worldsListenable,
            onRefresh: widget.onRefreshWorlds,
            recentChatWorldId: widget.recentChatWorldId,
            canDeleteWorlds: data.isSelf,
            onWorldDeleted: widget.onWorldDeleted,
            redesigned: isWorldoMe,
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
    if (widget.appearance == UserProfileAppearance.worldoMe) {
      return _buildWorldoMeProfileHeader(data, isFollowed, followerCount);
    }
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FollowStats(
              followingCount: data.followingCount,
              followerCount: followerCount,
              onFollowingTap: () => _openFollows(0),
              onFollowersTap: () => _openFollows(1),
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

  Widget _buildWorldoMeProfileHeader(
    UserProfileData data,
    bool isFollowed,
    int followerCount,
  ) {
    return KeyedSubtree(
      key: _profileHeaderKey,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            key: const ValueKey<String>('worldo-me-profile-identity'),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Avatar(
                  url: data.avatarUrl,
                  name: data.displayName,
                  urlListenable: widget.avatarUrlListenable,
                  nameListenable: widget.displayNameListenable,
                  isUpdating: widget.isUpdatingProfile,
                  updatingListenable: widget.isUpdatingProfileListenable,
                  onEdit: widget.onEditAvatar,
                  size: 72,
                  radius: 22,
                  redesigned: true,
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
                              redesigned: true,
                            ),
                          ),
                          if (widget.onEditDisplayName != null) ...[
                            const SizedBox(width: 4),
                            _ProfileEditButton(
                              isUpdating: widget.isUpdatingProfile,
                              updatingListenable:
                                  widget.isUpdatingProfileListenable,
                              onTap: widget.onEditDisplayName!,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      CopyableIdLabel(
                        label: 'UID',
                        value: data.uid,
                        displayValue: data.deleted
                            ? deletedEntityDisplayText
                            : formatUidForDisplay(data.uid),
                        enabled: !data.deleted,
                        showCopyIcon: false,
                        customTextStyle: TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: context.genesisColors.textFaint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _FollowStats(
                        followingCount: data.followingCount,
                        followerCount: followerCount,
                        onFollowingTap: () => _openFollows(0),
                        onFollowersTap: () => _openFollows(1),
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (data.isSelf) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _GemsBalanceEntry(
                stateListenable: widget.gemWalletStateListenable,
                redesigned: true,
              ),
            ),
          ],
          if (!data.isSelf) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _ProfileActionButtons(
                isFollowed: isFollowed,
                followLoading: _followLoading,
                onFollowToggle: () => _toggleFollow(isFollowed),
                onMessage: () => unawaited(_openMessages()),
              ),
            ),
          ],
          const SizedBox(height: 22),
        ],
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
  const _GemsBalanceEntry({this.stateListenable, this.redesigned = false});

  final ValueListenable<GemWalletState>? stateListenable;
  final bool redesigned;

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
    if (redesigned) return _buildRedesignedEntry(context, balance);
    return GestureDetector(
      key: const ValueKey('user-profile-gems-entry'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(RouteNames.gemWallet),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.genesisColors.dangerSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.genesisColors.dangerBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              key: const ValueKey('user-profile-gem-icon'),
              width: gemLargeIconSize,
              height: gemLargeIconSize,
              child: SvgPicture.asset(gemIconAsset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Text(
              balance == null ? '0' : _formatGemBalance(balance),
              key: const ValueKey('user-profile-gems-balance'),
              style: TextStyle(
                fontSize: 15,
                height: 20 / 16,
                fontWeight: FontWeight.w600,
                color: context.genesisColors.textBody,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Gems',
              style: TextStyle(
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w500,
                color: context.genesisColors.textMuted,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 22,
              color: context.genesisColors.textPlaceholder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedesignedEntry(BuildContext context, int? balance) {
    final colors = context.genesisColors;
    return GestureDetector(
      key: const ValueKey('user-profile-gems-entry'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(RouteNames.gemWallet),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderNeutral),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: colors.textTimestamp,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      SizedBox(
                        key: const ValueKey('user-profile-gem-icon'),
                        width: 15,
                        height: 23,
                        child: SvgPicture.asset(
                          gemIconAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: GenesisMetricValueText(
                          value: balance == null
                              ? '0'
                              : _formatGemBalance(balance),
                          textKey: const ValueKey('user-profile-gems-balance'),
                          style: TextStyle(color: colors.foregroundStrong),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Gems',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: colors.textTimestamp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Top up',
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: colors.onDanger,
                ),
              ),
            ),
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
  const _ProfileTabsHeaderDelegate({
    required this.child,
    required this.appearance,
  });

  static const double _standardHeight = 5 + genesisTabHeight;
  static const double _worldoMeHeight = 39;

  final Widget child;
  final UserProfileAppearance appearance;

  bool get _isWorldoMe => appearance == UserProfileAppearance.worldoMe;

  @override
  double get minExtent => _isWorldoMe ? _worldoMeHeight : _standardHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.genesisColors.surface,
        // 9k has no rule under the tabs: the only underline is the red
        // indicator on the active label.
      ),
      child: _isWorldoMe
          ? Align(alignment: Alignment.bottomLeft, child: child)
          : Column(
              children: [
                const SizedBox(height: 5),
                SizedBox(height: genesisTabHeight, child: child),
              ],
            ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || appearance != oldDelegate.appearance;
  }
}

class _ProfileCollectionTabs extends StatelessWidget {
  const _ProfileCollectionTabs({
    required this.controller,
    required this.appearance,
    required this.originCount,
    required this.worldCount,
    required this.labelFontSize,
    required this.onTap,
  });

  final TabController controller;
  final UserProfileAppearance appearance;
  final int originCount;
  final int worldCount;
  final double? labelFontSize;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (appearance != UserProfileAppearance.worldoMe) {
      return GenesisTabBar(
        verticalPadding: 0,
        controller: controller,
        labels: const ['#Worldo', 'World'],
        horizontalPadding: 8,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        labelFontSize: labelFontSize,
        onTap: onTap,
      );
    }

    return GenesisTabBar(
      verticalPadding: 0,
      controller: controller,
      labels: ['Creation $originCount', 'Playing $worldCount'],
      horizontalPadding: 22,
      labelPadding: const EdgeInsets.only(right: 20),
      // 9k: Creation / Playing / Bookmarks are 14/1.2, w700 when active and
      // w500 when idle, with the idle label on the 45% tier.
      labelFontSize: 14,
      labelStyle: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
      labelColor: context.genesisColors.textPrimary,
      unselectedLabelColor: context.genesisColors.textTimestamp,
      indicatorHeight: 2.5,
      indicatorBottomPadding: 0,
      indicatorMatchesLabelWidth: true,
      tabHeight: 39,
      onTap: onTap,
    );
  }
}
