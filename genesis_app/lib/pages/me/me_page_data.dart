part of 'me_page.dart';

extension _MePageData on _MePageState {
  Future<_MePageContent> _loadData() async {
    final generation = ++_loadGeneration;
    final signedIn = await _hasLocalLoginSession();
    if (!mounted || !_canUpdateAsyncState || generation != _loadGeneration) {
      return const _MePageContent.signedOut();
    }
    if (!signedIn) {
      _profileData.value = null;
      _originsState.reset();
      _worldsState.reset();
      return const _MePageContent.signedOut();
    }
    if (_isTabActive) {
      unawaited(_refreshMembershipData(AppServicesScope.read(context)));
    }
    return _MePageContent.signedIn(await _loadProfileData());
  }

  Future<UserProfileData> _loadProfileData({
    bool waitForRefresh = false,
  }) async {
    final generation = _loadGeneration + 1;
    _loadGeneration = generation;
    final services = AppServicesScope.read(context);
    final api = services.api;
    final uid = await _readCurrentBackendUid();
    final displayName = GenesisL10n.current.worldoUser;
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
      generation: generation,
    );

    final collections =
        _canUpdateAsyncState && generation == _loadGeneration && _isTabActive
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
    if (!_canUpdateAsyncState || generation != _loadGeneration) return data;
    _publishProfileData(data);
    _avatarUrl.value = data.avatarUrl;
    _displayName.value = data.displayName;
    final refresh = Future.wait<void>([
      remoteUserFuture.then((remoteUser) {
        _applyRemoteUserInfo(generation, data, remoteUser);
      }),
      collections,
    ]);
    if (waitForRefresh) {
      await refresh;
    } else {
      unawaited(refresh);
    }
    return data;
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    return await services.sessionStore.readLoginUid() != null;
  }

  void _handleTabActivated() {
    if (!_isTabActive) return;
    if (languageDataStale) {
      checkLanguageData();
      return;
    }
    unawaited(_refreshAfterPending());
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    _avatarPreviewBytes.value = null;
    if (_avatarEditToken != null) {
      _avatarEditToken = null;
      _isUpdatingProfile.value = false;
    }
    _loadGeneration += 1;
    _pageRefresh = null;
    _originsState.reset();
    _worldsState.reset();
    if (_profileData.value != null) {
      unawaited(_refreshSignedInContentAfterSessionChange());
      return;
    }
    _updateState(() {
      _future = _loadData();
    });
  }

  Future<void> _refreshSignedInContentAfterSessionChange() async {
    final generation = _loadGeneration;
    final signedIn = await _hasLocalLoginSession();
    if (!_canUpdateAsyncState || generation != _loadGeneration) return;
    if (!signedIn) {
      _loadGeneration += 1;
      _profileData.value = null;
      _updateState(() {
        _future = SynchronousFuture<_MePageContent>(
          const _MePageContent.signedOut(),
        );
      });
      return;
    }
    await _loadProfileData();
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
    refresh = _reloadPage().whenComplete(() {
      if (identical(_pageRefresh, refresh)) _pageRefresh = null;
    });
    return _pageRefresh = refresh;
  }

  Future<void> _reloadPage() async {
    final generation = _loadGeneration;
    final signedIn = await _hasLocalLoginSession();
    if (!mounted ||
        !_canUpdateAsyncState ||
        !_isTabActive ||
        generation != _loadGeneration) {
      return;
    }
    if (!signedIn) {
      _loadGeneration += 1;
      _profileData.value = null;
      _originsState.reset();
      _worldsState.reset();
      _updateState(() {
        _future = SynchronousFuture<_MePageContent>(
          const _MePageContent.signedOut(),
        );
      });
      return;
    }
    final hadProfileData = _profileData.value != null;
    final membership = _refreshMembershipData(AppServicesScope.read(context));
    final data = await _loadProfileData(waitForRefresh: true);
    if (_canUpdateAsyncState &&
        _loadGeneration == generation + 1 &&
        !hadProfileData) {
      _updateState(() {
        _future = SynchronousFuture<_MePageContent>(
          _MePageContent.signedIn(data),
        );
      });
    }
    await membership;
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
