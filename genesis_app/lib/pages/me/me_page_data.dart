part of 'me_page.dart';

extension _MePageData on _MePageState {
  Future<_MePageContent> _loadData() async {
    final generation = ++_loadGeneration;
    final signedIn = await _hasLocalLoginSession();
    if (!_canUpdateAsyncState || generation != _loadGeneration) {
      return const _MePageContent.signedOut();
    }
    if (!signedIn) {
      _originsState.reset();
      _worldsState.reset();
      return const _MePageContent.signedOut();
    }
    return _MePageContent.signedIn(
      await _loadProfileData(refreshAllCollections: true),
    );
  }

  Future<UserProfileData> _loadProfileData({
    int? refreshCollectionTabIndex = 0,
    bool refreshAllCollections = false,
  }) async {
    final generation = _loadGeneration + 1;
    _loadGeneration = generation;
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

    if (_canUpdateAsyncState && generation == _loadGeneration && _isTabActive) {
      if (refreshAllCollections) {
        unawaited(
          Future.wait<void>([_originsState.refresh(), _worldsState.refresh()]),
        );
      } else if (refreshCollectionTabIndex != null) {
        unawaited(_refreshCollectionTab(refreshCollectionTabIndex));
      }
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
    return await services.sessionStore.readLoginUid() != null;
  }

  void _handleTabActivated() {
    if (!_isTabActive) return;
    _initialWalletRefreshStarted = true;
    _refreshGemWallet();
    unawaited(_refreshDataOnActivation());
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    _loadGeneration += 1;
    _originsState.reset();
    _worldsState.reset();
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
        final generation = _loadGeneration;
        final signedIn = await _hasLocalLoginSession();
        if (!_canUpdateAsyncState || generation != _loadGeneration) return;
        if (!signedIn) {
          _loadGeneration += 1;
          _originsState.reset();
          _worldsState.reset();
          _updateState(() {
            _future = SynchronousFuture<_MePageContent>(
              const _MePageContent.signedOut(),
            );
          });
          return;
        }
        final data = await _loadProfileData(
          refreshCollectionTabIndex: _selectedCollectionTabIndex,
          refreshAllCollections:
              !_originsState.hasLoaded || !_worldsState.hasLoaded,
        );
        if (!_canUpdateAsyncState || _loadGeneration != generation + 1) return;
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
    // Keep each tab's loaded pages when switching between the collections.
    final collection = index == 1 ? _worldsState : _originsState;
    if (!collection.hasLoaded && !collection.value.isLoading) {
      unawaited(_refreshCollectionTab(index));
    }
  }

  void _handleProfileCollapsedChanged(bool collapsed) {
    if (_profileCollapsed == collapsed) return;
    _updateState(() => _profileCollapsed = collapsed);
  }

  Future<void> _refreshCollectionTab(int tabIndex) async {
    if (!_canUpdateAsyncState || !_isTabActive) return;
    if (tabIndex == 1) {
      await _worldsState.refresh();
    } else {
      await _originsState.refresh();
    }
  }

  Future<void> _loadMoreOrigins() async {
    if (!_canUpdateAsyncState ||
        !_isTabActive ||
        _selectedCollectionTabIndex != 0) {
      return;
    }
    await _originsState.loadMore();
  }

  Future<void> _loadMoreWorlds() async {
    if (!_canUpdateAsyncState ||
        !_isTabActive ||
        _selectedCollectionTabIndex != 1) {
      return;
    }
    await _worldsState.loadMore();
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
      await api.ensureUid();
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

  Future<void> _refreshOrigins() => _refreshCollectionTab(0);

  Future<void> _refreshWorlds() => _refreshCollectionTab(1);
}
