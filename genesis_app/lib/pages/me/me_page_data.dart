part of 'me_page.dart';

extension _MePageData on _MePageState {
  Future<void> _loadData({
    bool waitForRefresh = false,
    bool refreshUserInfo = true,
  }) async {
    final generation = ++_loadGeneration;
    final services = AppServicesScope.read(context);
    final sessionRevision = services.sessionRevision.value;
    final signedIn = await services.sessionStore.readLoginUid() != null;
    if (!mounted ||
        _isDisposed ||
        sessionRevision != services.sessionRevision.value ||
        !identical(services, AppServicesScope.read(context))) {
      return;
    }
    // Apply a current session read even when a newer profile load is pending.
    if (generation > _lastAppliedSessionRead) {
      _lastAppliedSessionRead = generation;
      if (_signedIn != signedIn) {
        _updateState(() => _signedIn = signedIn);
      }
    }
    if (generation != _loadGeneration) return;
    if (!signedIn) {
      _profileData.value = null;
      _originsState.reset();
      _worldsState.reset();
      return;
    }
    final membership = _isTabActive
        ? _refreshMembershipData(services)
        : Future<void>.value();
    await _loadProfileData(
      generation: generation,
      waitForRefresh: waitForRefresh,
      refreshUserInfo: refreshUserInfo,
    );
    if (waitForRefresh) await membership;
  }

  Future<void> _loadProfileData({
    required int generation,
    required bool waitForRefresh,
    required bool refreshUserInfo,
  }) async {
    final services = AppServicesScope.read(context);
    final uid = await _readCurrentBackendUid();
    final displayName = GenesisL10n.current.worldoUser;
    var resolvedDisplayName = displayName;
    var resolvedAvatarUrl = '';
    var resolvedFollowingCount = 0;
    var resolvedFollowerCount = 0;

    final cachedUser = await services.sessionStore.readUserInfo();
    if (!_canUpdateAsyncState || generation != _loadGeneration) return;
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

    final collections = _isTabActive
        ? Future.wait<void>([_originsState.refresh(), _worldsState.refresh()])
        : Future<void>.value();

    final data = UserProfileData(
      avatarUrl: resolvedAvatarUrl,
      gender: asString(cachedUser?['gender']),
      age: asString(cachedUser?['age']),
      membershipStatus: asUserMembershipStatus(
        cachedUser?['membership_status'],
      ),
      membershipDeluxeStatus: asUserMembershipStatus(
        cachedUser?['membership_deluxe_status'],
      ),
      displayName: resolvedDisplayName,
      uid: uid.isEmpty ? GenesisL10n.current.meUnknown : uid,
      followingCount: resolvedFollowingCount,
      followerCount: resolvedFollowerCount,
      deleted: entityDeleted(cachedUser?['deleted']),
      isSelf: true,
      isFollowed: false,
      origins: const [],
      worlds: const [],
    );
    if (_profileData.value == null) {
      _updateState(() => _publishProfileData(data));
    } else {
      _publishProfileData(data);
    }
    _avatarUrl.value = data.avatarUrl;
    _displayName.value = data.displayName;
    final refresh = Future.wait<void>([
      if (refreshUserInfo)
        _fetchAndCacheUserInfo(
          services.api,
          services.sessionStore,
          fallbackUid: uid,
          generation: generation,
        ).then(
          (remoteUser) => _applyRemoteUserInfo(generation, data, remoteUser),
        ),
      collections,
    ]);
    if (waitForRefresh) {
      await refresh;
    } else {
      unawaited(refresh);
    }
  }

  void _handleTabActivated() {
    if (!_isTabActive) return;
    if (languageDataStale) {
      checkLanguageData();
      return;
    }
    unawaited(_refreshAfterPending());
  }

  void _handleSessionChanged({required bool refreshUserInfo}) {
    if (!mounted) return;
    _avatarPreviewBytes.value = null;
    if (_avatarEditToken != null) {
      _avatarEditToken = null;
      _isUpdatingProfile.value = false;
    }
    _pageRefresh = null;
    _originsState.reset();
    _worldsState.reset();
    if (_profileData.value != null) {
      unawaited(_loadData(refreshUserInfo: refreshUserInfo));
      return;
    }
    _updateState(() {
      _future = _loadData(refreshUserInfo: refreshUserInfo);
    });
  }

  Future<void> _refreshAfterPending() async {
    final pending = _pageRefresh;
    if (pending != null) await pending;
    await _refreshPage();
  }

  Future<void> _refreshPage() {
    if (!_canUpdateAsyncState || !_isTabActive) return Future<void>.value();
    final pending = _pageRefresh;
    if (pending != null) return pending;
    late final Future<void> refresh;
    refresh = _loadData(waitForRefresh: true).whenComplete(() {
      if (identical(_pageRefresh, refresh)) _pageRefresh = null;
    });
    _pageRefresh = refresh;
    if (_profileData.value == null) {
      _updateState(() {
        _future = refresh;
      });
    }
    return refresh;
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
    if (_profileCollapsed.value == collapsed) return;
    _profileCollapsed.value = collapsed;
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
    required int generation,
  }) async {
    try {
      await api.ensureUid();
      final userInfo = await api.v1.user.info();
      return await cacheCurrentUserInfoResponse(
        sessionStore: sessionStore,
        response: userInfo,
        fallbackUid: fallbackUid,
        canSave: () => _canUpdateAsyncState && generation == _loadGeneration,
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
    _publishProfileData(nextData);
  }

  void _publishProfileData(UserProfileData data) {
    final current = _profileData.value;
    if (current != null && _sameRenderedUserInfo(current, data)) return;
    _profileData.value = data;
  }

  Future<void> _refreshOrigins() => _refreshCollectionTab(0);

  Future<void> _refreshWorlds() => _refreshCollectionTab(1);
}
