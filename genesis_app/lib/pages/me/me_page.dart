import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../components/page_header.dart';
import '../../components/me/signed_out_me_view.dart';
import '../../components/me/user_profile_content.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/origin.dart';
import '../../platform/auth/auth_cancelled_exception.dart';
import '../../platform/auth/auth_session.dart';
import '../../platform/session/user_session_store.dart';
import '../../platform/session/user_info_cache.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/image_format_guards.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/text/genesis_text_input_formatters.dart';
import 'settings_page.dart';

class MePage extends StatefulWidget {
  const MePage({
    super.key,
    this.onLoggedOut,
    this.onLogin,
    this.activationListenable,
    this.isActiveListenable,
  });

  final VoidCallback? onLoggedOut;
  final Future<bool> Function(IdentityProvider provider)? onLogin;
  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool>? isActiveListenable;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  static final Uri _discordUri = Uri.parse('https://discord.gg/wuKHk7cyX7');

  late Future<_MePageContent> _future;
  final ValueNotifier<bool> _isUpdatingProfile = ValueNotifier<bool>(false);
  final ValueNotifier<String> _avatarUrl = ValueNotifier<String>('');
  final ValueNotifier<String> _displayName = ValueNotifier<String>('');
  IdentityProvider? _loggingInProvider;
  final ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>
  _originsState =
      ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>(
        const UserProfileCollectionState<UserProfileOriginItem>(
          items: <UserProfileOriginItem>[],
          isLoading: false,
        ),
      );
  final ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>
  _worldsState =
      ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>(
        const UserProfileCollectionState<UserProfileWorldItem>(
          items: <UserProfileWorldItem>[],
          isLoading: false,
        ),
      );
  int _loadGeneration = 0;
  bool _profileCollapsed = false;
  bool _isActivationRefreshing = false;
  bool _hasPendingActivationRefresh = false;
  int _selectedCollectionTabIndex = 0;
  ValueListenable<int>? _sessionRevisionListenable;
  bool _isDisposed = false;
  String _recentChatUid = '';
  String _recentChatWorldId = '';

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    widget.activationListenable?.addListener(_handleTabActivated);
    recentWorldChatStore.listenable.addListener(_handleRecentChatChanged);
  }

  @override
  void didUpdateWidget(covariant MePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_handleTabActivated);
      widget.activationListenable?.addListener(_handleTabActivated);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionRevision = AppServicesScope.of(context).sessionRevision;
    if (identical(_sessionRevisionListenable, sessionRevision)) return;
    _sessionRevisionListenable?.removeListener(_handleSessionChanged);
    _sessionRevisionListenable = sessionRevision;
    sessionRevision.addListener(_handleSessionChanged);
    unawaited(_loadRecentChatMarker());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _loadGeneration += 1;
    _sessionRevisionListenable?.removeListener(_handleSessionChanged);
    recentWorldChatStore.listenable.removeListener(_handleRecentChatChanged);
    widget.activationListenable?.removeListener(_handleTabActivated);
    _isUpdatingProfile.dispose();
    _avatarUrl.dispose();
    _displayName.dispose();
    _originsState.dispose();
    _worldsState.dispose();
    super.dispose();
  }

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
    final uid = await resolveRecentWorldChatUid(AppServicesScope.read(context));
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
    setState(() {
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
    final profile = services.identityAuth.currentProfile();
    final localUid = await _readCurrentBackendUid();
    final displayName = (profile?.displayName ?? '').trim().isNotEmpty
        ? profile!.displayName.trim()
        : ((profile?.email ?? '').trim().isNotEmpty
              ? profile!.email.trim()
              : 'User');
    final avatarUrl = (profile?.photoUrl ?? '').trim();
    final profileUid = (profile?.uid ?? '').trim();
    final uid = localUid.isNotEmpty ? localUid : profileUid;
    var resolvedDisplayName = displayName;
    var resolvedAvatarUrl = avatarUrl;
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
    setState(() {
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
          setState(() {
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
        setState(() {
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
    setState(() => _profileCollapsed = collapsed);
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

    final profileUid = (services.identityAuth.currentProfile()?.uid ?? '')
        .trim();
    debugPrint('[MePage] current uid from identity profile: $profileUid');
    return profileUid;
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
    setState(() {
      _future = Future<_MePageContent>.value(_MePageContent.signedIn(nextData));
    });
  }

  Future<void> _refresh() async {
    setState(() {
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

  Future<void> _login(IdentityProvider provider) async {
    if (_loggingInProvider != null) return;
    final login = widget.onLogin;
    if (login == null) {
      showGenesisToast(context, 'Sign-in unavailable');
      return;
    }
    setState(() => _loggingInProvider = provider);
    try {
      final ok = await login(provider);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _future = _loadData();
        });
      } else {
        showGenesisToast(context, 'Sign-in failed');
      }
    } on AuthCancelledException {
      // User cancelled provider UI.
    } catch (e, st) {
      debugPrint('[Auth][MePage] login failed: $e');
      debugPrint('[Auth][MePage] stacktrace:\n$st');
      if (!mounted) return;
      final message = e.toString().trim();
      showGenesisToast(context, message.isEmpty ? 'Sign-in failed' : message);
    } finally {
      if (mounted) setState(() => _loggingInProvider = null);
    }
  }

  Future<void> _openSettings() async {
    final services = AppServicesScope.read(context);
    final loggedOut = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AppServicesScope(services: services, child: const SettingsPage()),
      ),
    );
    if (loggedOut == true) {
      widget.onLoggedOut?.call();
    }
  }

  Future<void> _openDiscord() async {
    try {
      final launched = await launchUrl(
        _discordUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showGenesisToast(context, 'Could not open Discord');
      }
    } catch (_) {
      if (mounted) {
        showGenesisToast(context, 'Could not open Discord');
      }
    }
  }

  Future<void> _editAvatar() async {
    final Uint8List bytes;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      bytes = await image.readAsBytes();
      throwIfGifImage(
        bytes: bytes,
        filename: image.name,
        contentType: image.mimeType ?? '',
      );
    } on UnsupportedGifImageException {
      if (!mounted) return;
      showGenesisToast(context, unsupportedGifImageMessage);
      return;
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Image pick failed');
      return;
    }
    if (!mounted) return;
    final services = AppServicesScope.read(context);
    final avatarUrl = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => LocalImageCropPage(
          imageBytes: bytes,
          cropSize: const Size(512, 512),
          filename: 'avatar.png',
          contentType: 'image/png',
          onUpload: (result) async {
            final uploaded = await services.api.v1.upload.image(
              bytes: result.bytes,
              filename: result.filename,
              contentType: result.contentType,
            );
            return asResolvedImageUrl(uploaded, resolveAssetUrl);
          },
        ),
      ),
    );
    if (avatarUrl == null || avatarUrl.trim().isEmpty || !mounted) return;

    await _updateAvatar(
      update: () => services.api.v1.user.update(avatar: avatarUrl),
      apply: (updatedUser) {
        final updatedAvatar = asResolvedImageUrl(
          updatedUser['avatar'],
          resolveAssetUrl,
          fallback: avatarUrl,
        );
        return updatedAvatar;
      },
    );
  }

  Future<void> _editNickName() async {
    final currentDisplayName = _displayName.value.trim();
    final nickName = await showGenesisDialog<String>(
      context: context,
      builder: (_) => _NickNameDialog(initialValue: currentDisplayName),
    );

    final trimmedName = nickName?.trim() ?? '';
    if (trimmedName.isEmpty || trimmedName == currentDisplayName) return;
    if (!mounted) return;

    final services = AppServicesScope.read(context);
    await _updateDisplayName(
      update: () => services.api.v1.user.update(name: trimmedName),
      apply: (updatedUser) {
        final updatedName = _mapString(
          updatedUser,
          'name',
          fallback: trimmedName,
        );
        return updatedName;
      },
    );
  }

  Future<void> _updateDisplayName({
    required Future<Map<String, dynamic>> Function() update,
    required String Function(Map<dynamic, dynamic> updatedUser) apply,
  }) async {
    _isUpdatingProfile.value = true;
    try {
      final response = await update();
      final updatedUser = response['user'] is Map
          ? response['user'] as Map
          : response;
      await _cacheUpdatedUserInfo(updatedUser);
      final updatedDisplayName = apply(updatedUser);
      if (!mounted) return;
      _displayName.value = updatedDisplayName;
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Update failed');
    } finally {
      if (mounted) _isUpdatingProfile.value = false;
    }
  }

  Future<void> _updateAvatar({
    required Future<Map<String, dynamic>> Function() update,
    required String Function(Map<dynamic, dynamic> updatedUser) apply,
  }) async {
    _isUpdatingProfile.value = true;
    try {
      final response = await update();
      final updatedUser = response['user'] is Map
          ? response['user'] as Map
          : response;
      await _cacheUpdatedUserInfo(updatedUser);
      final updatedAvatarUrl = apply(updatedUser);
      if (!mounted) return;
      _avatarUrl.value = updatedAvatarUrl;
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Update failed');
    } finally {
      if (mounted) _isUpdatingProfile.value = false;
    }
  }

  Future<void> _cacheUpdatedUserInfo(Map<dynamic, dynamic> updatedUser) async {
    final services = AppServicesScope.read(context);
    final current = await services.sessionStore.readUserInfo();
    final merged = <String, dynamic>{
      if (current != null) ...current,
      for (final entry in updatedUser.entries)
        if (entry.key is String) (entry.key as String): entry.value,
    };
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isNotEmpty) {
      merged.putIfAbsent('uid', () => uid);
    }
    await services.sessionStore.saveUserInfo(merged);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MePageContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 8),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final content = snapshot.data;
        if (content == null) {
          return const SizedBox.shrink();
        }
        if (!content.isSignedIn) {
          return SignedOutMeView(
            loggingInProvider: _loggingInProvider,
            onLogin: _login,
          );
        }
        final data = content.data!;
        final gemWalletState = AppServicesScope.of(context).gemWallet.state;

        return GenesisTopSafeArea(
          backgroundColor: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: _profileCollapsed ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: const PageTitleText(pageName: 'Me'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _openDiscord,
                            icon: SvgPicture.asset(
                              'assets/custom-icons/svg/discord-svgrepo-com.svg',
                              width: 30,
                              height: 30,
                            ),
                          ),
                          IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings, size: 24),
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UserProfileContent(
                  data: data,
                  originsListenable: _originsState,
                  worldsListenable: _worldsState,
                  avatarUrlListenable: _avatarUrl,
                  displayNameListenable: _displayName,
                  isUpdatingProfileListenable: _isUpdatingProfile,
                  gemWalletStateListenable: gemWalletState,
                  onEditAvatar: _editAvatar,
                  onEditDisplayName: _editNickName,
                  onRefreshOrigins: _refreshOrigins,
                  onRefreshWorlds: _refreshWorlds,
                  onWorldDeleted: _handleWorldDeleted,
                  onCollectionTabChanged: _handleCollectionTabChanged,
                  onCollapsedChanged: _handleProfileCollapsedChanged,
                  recentChatWorldId: _recentChatWorldId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleWorldDeleted(UserProfileWorldItem item) {
    final worldId = item.wid.trim();
    if (worldId.isEmpty) return;
    final current = _worldsState.value;
    final nextItems = current.items
        .where((world) => world.wid.trim() != worldId)
        .toList(growable: false);
    _setWorldsState(nextItems, isLoading: current.isLoading);
  }
}

class _MePageContent {
  const _MePageContent.signedOut() : data = null;
  const _MePageContent.signedIn(this.data);

  final UserProfileData? data;

  bool get isSignedIn => data != null;
}

@visibleForTesting
UserProfileData mergeRemoteUserInfoForRenderForTest(
  UserProfileData currentData,
  Map<String, dynamic> remoteUser,
) {
  return _mergeRemoteUserInfoForRender(currentData, remoteUser);
}

@visibleForTesting
bool sameRenderedUserInfoForTest(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return _sameRenderedUserInfo(currentData, nextData);
}

UserProfileData _mergeRemoteUserInfoForRender(
  UserProfileData currentData,
  Map<String, dynamic> remoteUser,
) {
  final backendName = _mapString(remoteUser, 'name');
  final backendAvatar = _resolvedBackendAvatar(remoteUser);
  final backendUid = _mapString(remoteUser, 'uid');
  final deleted = entityDeleted(remoteUser['deleted']);
  final resolvedUid = deleted
      ? deletedEntityDisplayText
      : (backendUid.isEmpty ? currentData.uid : backendUid);
  final resolvedDisplayName = deleted
      ? deletedEntityDisplayText
      : _hasMapKey(remoteUser, 'name')
      ? _profileDisplayNameFromBackend(
          backendName,
          resolvedUid,
          fallback: currentData.displayName,
        )
      : currentData.displayName;
  final resolvedAvatarUrl = _hasAvatarPayload(remoteUser)
      ? backendAvatar
      : currentData.avatarUrl;
  return currentData.copyWith(
    avatarUrl: resolvedAvatarUrl,
    displayName: resolvedDisplayName,
    uid: resolvedUid,
    followingCount:
        _mapIntOrNull(remoteUser, 'following_cnt') ??
        currentData.followingCount,
    followerCount:
        _mapIntOrNull(remoteUser, 'follower_cnt') ?? currentData.followerCount,
    deleted: deleted,
  );
}

String _profileDisplayNameFromBackend(
  String backendName,
  String uid, {
  required String fallback,
}) {
  final name = backendName.trim();
  if (name.isNotEmpty) return name;
  final cleanUid = uid.trim();
  if (cleanUid.isNotEmpty) return cleanUid;
  return fallback;
}

bool _hasAvatarPayload(Map<dynamic, dynamic> user) {
  return _hasMapKey(user, 'avatar') || _hasMapKey(user, 'avatar_url');
}

bool _hasMapKey(Map<dynamic, dynamic> map, String key) {
  return map.containsKey(key);
}

String _resolvedBackendAvatar(Map<dynamic, dynamic> user) {
  if (_hasMapKey(user, 'avatar')) {
    return asResolvedImageUrl(user['avatar'], resolveAssetUrl);
  }
  return asResolvedImageUrl(user['avatar_url'], resolveAssetUrl);
}

bool _sameRenderedUserInfo(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return currentData.avatarUrl == nextData.avatarUrl &&
      _sameRenderedUserInfoExceptAvatar(currentData, nextData);
}

bool _sameRenderedUserInfoExceptAvatar(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return currentData.displayName == nextData.displayName &&
      _sameRenderedUserInfoExceptAvatarAndDisplayName(currentData, nextData);
}

bool _sameRenderedUserInfoExceptAvatarAndDisplayName(
  UserProfileData currentData,
  UserProfileData nextData,
) {
  return currentData.uid == nextData.uid &&
      currentData.followingCount == nextData.followingCount &&
      currentData.followerCount == nextData.followerCount &&
      currentData.deleted == nextData.deleted;
}

bool _sameOriginItems(
  List<UserProfileOriginItem> current,
  List<UserProfileOriginItem> next,
) {
  if (identical(current, next)) return true;
  if (current.length != next.length) return false;
  for (var index = 0; index < current.length; index += 1) {
    final a = current[index];
    final b = next[index];
    if (a.originId != b.originId ||
        a.oid != b.oid ||
        a.title != b.title ||
        a.subtitle != b.subtitle ||
        a.deleted != b.deleted ||
        a.imageUrl != b.imageUrl ||
        a.copyCount != b.copyCount ||
        a.interactCount != b.interactCount ||
        a.characterCount != b.characterCount) {
      return false;
    }
  }
  return true;
}

bool _sameWorldItems(
  List<UserProfileWorldItem> current,
  List<UserProfileWorldItem> next,
) {
  if (identical(current, next)) return true;
  if (current.length != next.length) return false;
  for (var index = 0; index < current.length; index += 1) {
    final a = current[index];
    final b = next[index];
    if (a.wid != b.wid ||
        a.title != b.title ||
        a.subtitle != b.subtitle ||
        a.deleted != b.deleted ||
        a.imageUrl != b.imageUrl ||
        a.progressCount != b.progressCount ||
        a.interactCount != b.interactCount ||
        a.characterCount != b.characterCount ||
        a.playerCount != b.playerCount ||
        a.ownerName != b.ownerName) {
      return false;
    }
  }
  return true;
}

UserProfileOriginItem _profileOriginItemFromSummary(OriginSummary item) {
  return UserProfileOriginItem(
    originId: item.id,
    oid: item.oid,
    title: item.name.trim().isEmpty ? item.oid : item.name.trim(),
    subtitle: _originSubtitle(item),
    deleted: item.deleted,
    imageUrl: resolveAssetUrl(item.mapImage),
    copyCount: item.copyCount,
    interactCount: item.interactCount,
    characterCount: item.characterCount,
  );
}

UserProfileWorldItem _profileWorldItemFromSummary(MyWorldSummary item) {
  return UserProfileWorldItem(
    wid: item.wid,
    title: item.name.trim().isEmpty ? item.wid : item.name.trim(),
    subtitle: _worldSubtitle(item.wid, item.ownerName, deleted: item.deleted),
    deleted: item.deleted,
    imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
    progressCount: item.progressCount,
    interactCount: item.interactCount,
    characterCount: item.characterCount,
    playerCount: item.playerCount,
    ownerName: item.ownerName,
  );
}

String _originSubtitle(OriginSummary item) {
  final oid = deletedAwareIdLabel(item.oid, deleted: item.deleted);
  final originator = item.originator.trim().isEmpty
      ? '-'
      : formatUidForDisplay(item.originator);
  final version = item.versionNum <= 0 ? '-' : 'V${item.versionNum}';
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version';
}

String _worldSubtitle(String wid, String ownerName, {bool deleted = false}) {
  final displayWid = deletedAwareIdLabel(wid, deleted: deleted);
  final owner = formatUidForDisplay(ownerName, fallback: '-');
  return 'WID: $displayWid  Owner: $owner';
}

class _NickNameDialog extends StatefulWidget {
  const _NickNameDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_NickNameDialog> createState() => _NickNameDialogState();
}

class _NickNameDialogState extends State<_NickNameDialog> {
  static const int _maxLength = 30;

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: genesisDisplaySafeText(widget.initialValue),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GenesisActionBox<String>(
      title: 'Edit name',
      titleHeight: 126,
      titleContentSpacing: 24,
      titleContent: Transform.translate(
        offset: const Offset(0, 4),
        child: _NickNameInput(
          controller: _controller,
          maxLength: _maxLength,
          onChanged: () => setState(() {}),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: const [GenesisActionBoxAction<String>(label: 'OK', value: 'ok')],
      onActionSelected: (_) => Navigator.of(context).pop(_controller.text),
      onCancel: () => Navigator.of(context).pop(),
    );
  }
}

class _NickNameInput extends StatelessWidget {
  const _NickNameInput({
    required this.controller,
    required this.maxLength,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    const border = UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFD8D8DE)),
    );
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            key: const ValueKey<String>('me-edit-nickname-input'),
            controller: controller,
            autofocus: true,
            maxLines: 1,
            maxLength: maxLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              isDense: true,
              counterText: '',
              enabledBorder: border,
              focusedBorder: border,
              contentPadding: EdgeInsets.only(bottom: 5),
            ),
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 14,
              height: 1.2,
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: 3),
          Text(
            '${controller.text.characters.length}/$maxLength',
            style: const TextStyle(
              color: Color(0xFF8C8C8C),
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

String _mapString(
  Map<dynamic, dynamic>? map,
  String key, {
  String fallback = '',
}) {
  final value = map == null ? null : map[key];
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _mapInt(Map<dynamic, dynamic>? map, String key) {
  return _mapIntOrNull(map, key) ?? 0;
}

int? _mapIntOrNull(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
