part of 'me_page.dart';

extension _MePageData on _MePageState {
  Future<_MePageContent> _loadData() async {
    if (!await _hasLocalLoginSession()) {
      if (!_canUpdateAsyncState) {
        return const _MePageContent.signedOut();
      }
      _loadGeneration += 1;
      _setOriginsState(const <UserProfileOriginItem>[], isLoading: false);
      _setWorldsState(const <UserProfileWorldItem>[], isLoading: false);
      _setRecentChatMarker('', '');
      return const _MePageContent.signedOut();
    }
    return _MePageContent.signedIn(await _loadProfileData());
  }

  Future<void> _loadRecentChatMarker() async {
    final uid = await _readCurrentBackendUid();
    final record = await recentWorldChatStore.loadForUid(uid);
    if (!_canUpdateAsyncState) return;
    final nextWorldId = record?.uid == uid ? record?.worldId ?? '' : '';
    _setRecentChatMarker(uid, nextWorldId);
  }

  void _handleRecentChatChanged() {
    final record = recentWorldChatStore.listenable.value;
    if (record == null) return;
    if (_recentChatUid.isNotEmpty && record.uid != _recentChatUid) return;
    _setRecentChatMarker(record.uid, record.worldId);
  }

  void _setRecentChatMarker(String uid, String worldId) {
    if (_recentChatUid == uid && _recentChatWorldId == worldId) return;
    _updateState(() {
      _recentChatUid = uid;
      _recentChatWorldId = worldId;
    });
  }

  Future<UserProfileData> _loadProfileData({
    bool showCollectionLoading = true,
    int? refreshCollectionTabIndex = 0,
  }) async {
    final generation = _loadGeneration + 1;
    _loadGeneration = generation;
    final currentOrigins = _originsState.value.items;
    final currentWorlds = _worldsState.value.items;
    if (refreshCollectionTabIndex != null && showCollectionLoading) {
      _setCollectionLoading(refreshCollectionTabIndex, isLoading: true);
    }
    final services = AppServicesScope.read(context);
    final api = services.api;
    final uid = await _readCurrentBackendUid();
    const displayName = 'User';
    var resolvedDisplayName = displayName;
    var resolvedAvatarUrl = '';
    var resolvedFollowingCount = 0;
    var resolvedFollowerCount = 0;

    final cachedUser = await services.sessionStore.readUserInfo();
    if (cachedUser != null) {
      final cachedUid = _mapString(cachedUser, 'uid');
      final backendName = _mapString(cachedUser, 'name');
      final backendAvatar = _resolvedBackendAvatar(cachedUser);
      final cachedDeleted = entityDeleted(cachedUser['deleted']);
      if (cachedDeleted) {
        resolvedDisplayName = deletedEntityDisplayText;
      } else if (_hasMapKey(cachedUser, 'name')) {
        resolvedDisplayName = _profileDisplayNameFromBackend(
          backendName,
          cachedUid.isEmpty ? uid : cachedUid,
          fallback: displayName,
        );
      }
      if (_hasAvatarPayload(cachedUser)) {
        resolvedAvatarUrl = backendAvatar;
      }
      resolvedFollowingCount = _mapInt(cachedUser, 'following_cnt');
      resolvedFollowerCount = _mapInt(cachedUser, 'follower_cnt');
    }

    final remoteUserFuture = _fetchAndCacheUserInfo(
      api,
      services.sessionStore,
      fallbackUid: uid,
    );

    if (refreshCollectionTabIndex != null && _isTabActive) {
      unawaited(
        _refreshCollectionTab(
          refreshCollectionTabIndex,
          generation: generation,
          api: api,
          uid: uid,
          fallbackOrigins: currentOrigins,
          fallbackWorlds: currentWorlds,
        ),
      );
    }

    final data = UserProfileData(
      avatarUrl: resolvedAvatarUrl,
      displayName: resolvedDisplayName,
      uid: uid.isEmpty ? 'Unknown' : uid,
      followingCount: resolvedFollowingCount,
      followerCount: resolvedFollowerCount,
      deleted: entityDeleted(cachedUser?['deleted']),
      isSelf: true,
      isFollowed: false,
      origins: const [],
      worlds: const [],
    );
    if (!_canUpdateAsyncState || generation != _loadGeneration) return data;
    _avatarUrl.value = data.avatarUrl;
    _displayName.value = data.displayName;
    unawaited(
      remoteUserFuture.then((remoteUser) {
        _applyRemoteUserInfo(generation, data, remoteUser);
      }),
    );
    return data;
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
  }

  Future<void> _loadOrigins(
    int generation,
    GenesisApi api,
    String uid, {
    required List<UserProfileOriginItem> fallbackItems,
  }) async {
    try {
      final originPage = await api.getMyLaunchedOrigins(
        uid: uid.trim().isEmpty ? null : uid,
        scene: 'mine',
        limit: 30,
        offset: 0,
      );
      if (!mounted || generation != _loadGeneration) return;
      _setOriginsState(
        originPage.data
            .map(_profileOriginItemFromSummary)
            .toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _setOriginsState(fallbackItems, isLoading: false);
    }
  }

  void _handleTabActivated() {
    if (!_isTabActive) return;
    unawaited(_refreshDataOnActivation());
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    _updateState(() {
      _future = _loadData();
    });
  }

  Future<void> _refreshDataOnActivation() async {
    if (!mounted || !_isTabActive) return;
    if (_isActivationRefreshing) {
      _hasPendingActivationRefresh = true;
      return;
    }
    _isActivationRefreshing = true;
    try {
      do {
        _hasPendingActivationRefresh = false;
        if (!_isTabActive) return;
        if (!await _hasLocalLoginSession()) {
          if (!mounted) return;
          _updateState(() {
            _future = SynchronousFuture<_MePageContent>(
              const _MePageContent.signedOut(),
            );
          });
          return;
        }
        final data = await _loadProfileData(
          showCollectionLoading: false,
          refreshCollectionTabIndex: _selectedCollectionTabIndex,
        );
        if (!mounted) return;
        _updateState(() {
          _future = SynchronousFuture<_MePageContent>(
            _MePageContent.signedIn(data),
          );
        });
      } while (_hasPendingActivationRefresh && mounted);
    } finally {
      _isActivationRefreshing = false;
    }
  }

  bool get _isTabActive => widget.isActiveListenable?.value ?? true;
  bool get _canUpdateAsyncState => mounted && !_isDisposed;

  void _handleCollectionTabChanged(int index) {
    if (_selectedCollectionTabIndex == index) return;
    _selectedCollectionTabIndex = index;
    if (!_isTabActive) return;
    unawaited(_refreshSelectedCollectionTab(showLoading: true));
  }

  void _handleProfileCollapsedChanged(bool collapsed) {
    if (_profileCollapsed == collapsed) return;
    _updateState(() => _profileCollapsed = collapsed);
  }

  Future<void> _loadWorlds(
    int generation,
    GenesisApi api,
    String uid, {
    required List<UserProfileWorldItem> fallbackItems,
  }) async {
    try {
      final worlds = await api.getMyWorlds(
        uid: uid.trim().isEmpty ? null : uid,
        scene: 'mine',
        limit: 30,
        offset: 0,
      );
      if (!mounted || generation != _loadGeneration) return;
      _setWorldsState(
        worlds.map(_profileWorldItemFromSummary).toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _setWorldsState(fallbackItems, isLoading: false);
    }
  }

  Future<void> _refreshSelectedCollectionTab({required bool showLoading}) {
    return _refreshCollectionTabForCurrentUser(
      _selectedCollectionTabIndex,
      showLoading: showLoading,
    );
  }

  Future<void> _refreshCollectionTabForCurrentUser(
    int tabIndex, {
    required bool showLoading,
  }) async {
    if (!mounted || !_isTabActive) return;
    final services = AppServicesScope.read(context);
    final uid = await _readCurrentBackendUid();
    if (!mounted || !_isTabActive) return;
    final generation = _loadGeneration;
    if (showLoading) {
      _setCollectionLoading(tabIndex, isLoading: true);
    }
    await _refreshCollectionTab(
      tabIndex,
      generation: generation,
      api: services.api,
      uid: uid,
      fallbackOrigins: _originsState.value.items,
      fallbackWorlds: _worldsState.value.items,
    );
  }

  Future<void> _refreshCollectionTab(
    int tabIndex, {
    required int generation,
    required GenesisApi api,
    required String uid,
    required List<UserProfileOriginItem> fallbackOrigins,
    required List<UserProfileWorldItem> fallbackWorlds,
  }) {
    if (tabIndex == 1) {
      return _loadWorlds(generation, api, uid, fallbackItems: fallbackWorlds);
    }
    return _loadOrigins(generation, api, uid, fallbackItems: fallbackOrigins);
  }

  void _setCollectionLoading(int tabIndex, {required bool isLoading}) {
    if (!_canUpdateAsyncState) return;
    if (tabIndex == 1) {
      _setWorldsState(_worldsState.value.items, isLoading: isLoading);
      return;
    }
    _setOriginsState(_originsState.value.items, isLoading: isLoading);
  }

  void _setOriginsState(
    List<UserProfileOriginItem> items, {
    required bool isLoading,
  }) {
    if (!_canUpdateAsyncState) return;
    final current = _originsState.value;
    if (current.isLoading == isLoading &&
        _sameOriginItems(current.items, items)) {
      return;
    }
    _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
      items: items,
      isLoading: isLoading,
    );
  }

  void _setWorldsState(
    List<UserProfileWorldItem> items, {
    required bool isLoading,
  }) {
    if (!_canUpdateAsyncState) return;
    final current = _worldsState.value;
    if (current.isLoading == isLoading &&
        _sameWorldItems(current.items, items)) {
      return;
    }
    _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
      items: items,
      isLoading: isLoading,
    );
  }

  Future<String> _readCurrentBackendUid() async {
    final services = AppServicesScope.read(context);
    final cachedUser = await services.sessionStore.readUserInfo();
    if (cachedUser != null) {
      final cachedUid = _mapString(cachedUser, 'uid');
      if (cachedUid.isNotEmpty) {
        debugPrint('[MePage] current uid from cached userInfo: $cachedUid');
        return cachedUid;
      }
    }

    final sessionUid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (sessionUid.isNotEmpty) {
      debugPrint('[MePage] current uid from sessionStore: $sessionUid');
      return sessionUid;
    }
    return '';
  }

  Future<Map<String, dynamic>?> _fetchAndCacheUserInfo(
    GenesisApi api,
    UserSessionStore sessionStore, {
    required String fallbackUid,
  }) async {
    try {
      final userInfo = await api.v1.user.info();
      return cacheCurrentUserInfoResponse(
        sessionStore: sessionStore,
        response: userInfo,
        fallbackUid: fallbackUid,
      );
    } catch (_) {
      return null;
    }
  }

  void _applyRemoteUserInfo(
    int generation,
    UserProfileData currentData,
    Map<String, dynamic>? remoteUser,
  ) {
    if (remoteUser == null || !mounted || generation != _loadGeneration) return;
    final nextData = _mergeRemoteUserInfoForRender(currentData, remoteUser);
    if (currentData.avatarUrl != nextData.avatarUrl) {
      _avatarUrl.value = nextData.avatarUrl;
    }
    if (currentData.displayName != nextData.displayName) {
      _displayName.value = nextData.displayName;
    }
    if (_sameRenderedUserInfo(currentData, nextData)) return;
    if (_sameRenderedUserInfoExceptAvatarAndDisplayName(
      currentData,
      nextData,
    )) {
      return;
    }
    _updateState(() {
      _future = Future<_MePageContent>.value(_MePageContent.signedIn(nextData));
    });
  }

  Future<void> _refresh() async {
    _updateState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _refreshOrigins() async {
    final services = AppServicesScope.read(context);
    final uid = await _readCurrentBackendUid();
    if (!_canUpdateAsyncState) return;
    debugPrint('[MePage] refresh origins uid: $uid');
    final current = _originsState.value;
    _setOriginsState(current.items, isLoading: true);
    try {
      final originPage = await services.api.getMyLaunchedOrigins(
        uid: uid.isEmpty ? null : uid,
        scene: 'mine',
        limit: 30,
        offset: 0,
      );
      if (!mounted) return;
      _setOriginsState(
        originPage.data
            .map(_profileOriginItemFromSummary)
            .toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      _setOriginsState(current.items, isLoading: false);
    }
  }

  Future<void> _refreshWorlds() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (!_canUpdateAsyncState) return;
    final current = _worldsState.value;
    _setWorldsState(current.items, isLoading: true);
    try {
      final worlds = await services.api.getMyWorlds(
        uid: uid.isEmpty ? null : uid,
        scene: 'mine',
        limit: 30,
        offset: 0,
      );
      if (!mounted) return;
      _setWorldsState(
        worlds.map(_profileWorldItemFromSummary).toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      _setWorldsState(current.items, isLoading: false);
    }
  }
}
