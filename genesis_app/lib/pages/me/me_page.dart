import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
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
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import 'settings_page.dart';

class MePage extends StatefulWidget {
  const MePage({
    super.key,
    this.onLoggedOut,
    this.onLogin,
    this.activationListenable,
  });

  final VoidCallback? onLoggedOut;
  final Future<bool> Function(IdentityProvider provider)? onLogin;
  final ValueListenable<int>? activationListenable;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
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
  UserProfileData? _renderedData;
  bool _profileCollapsed = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    widget.activationListenable?.addListener(_handleTabActivated);
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
  void dispose() {
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
      _loadGeneration += 1;
      _originsState.value =
          const UserProfileCollectionState<UserProfileOriginItem>(
            items: <UserProfileOriginItem>[],
            isLoading: false,
          );
      _worldsState.value =
          const UserProfileCollectionState<UserProfileWorldItem>(
            items: <UserProfileWorldItem>[],
            isLoading: false,
          );
      _renderedData = null;
      return const _MePageContent.signedOut();
    }
    return _MePageContent.signedIn(await _loadProfileData());
  }

  Future<UserProfileData> _loadProfileData() async {
    final generation = _loadGeneration + 1;
    _loadGeneration = generation;
    _originsState.value =
        const UserProfileCollectionState<UserProfileOriginItem>(
          items: <UserProfileOriginItem>[],
          isLoading: true,
        );
    _worldsState.value = const UserProfileCollectionState<UserProfileWorldItem>(
      items: <UserProfileWorldItem>[],
      isLoading: true,
    );
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
      final backendName = _mapString(cachedUser, 'name');
      final backendAvatar = asResolvedImageUrl(
        cachedUser['avatar'],
        resolveAssetUrl,
        fallback: cachedUser['avatar_url'],
      );
      if (backendName.isNotEmpty) resolvedDisplayName = backendName;
      if (backendAvatar.isNotEmpty) {
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

    unawaited(_loadOrigins(generation, api, uid));
    unawaited(_loadWorlds(generation, api, uid));

    final data = UserProfileData(
      avatarUrl: resolvedAvatarUrl,
      displayName: resolvedDisplayName,
      uid: uid.isEmpty ? 'Unknown' : uid,
      followingCount: resolvedFollowingCount,
      followerCount: resolvedFollowerCount,
      isSelf: true,
      isFollowed: false,
      origins: const [],
      worlds: const [],
    );
    _avatarUrl.value = data.avatarUrl;
    _displayName.value = data.displayName;
    _renderedData = data;
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

  Future<void> _loadOrigins(int generation, GenesisApi api, String uid) async {
    try {
      final originPage = await api.getMyLaunchedOrigins(
        uid: uid.trim().isEmpty ? null : uid,
        limit: 30,
        offset: 0,
      );
      if (!mounted || generation != _loadGeneration) return;
      _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
        items: originPage.data
            .map(_profileOriginItemFromSummary)
            .toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _originsState.value =
          const UserProfileCollectionState<UserProfileOriginItem>(
            items: <UserProfileOriginItem>[],
            isLoading: false,
          );
    }
  }

  void _handleTabActivated() {
    unawaited(_refreshUserInfoOnActivation());
  }

  Future<void> _refreshUserInfoOnActivation() async {
    if (!mounted) return;
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_') || authToken.isEmpty) return;
    final currentData = _renderedData;
    if (currentData == null) return;
    final remoteUser = await _fetchAndCacheUserInfo(
      services.api,
      services.sessionStore,
      fallbackUid: currentData.uid,
    );
    _applyRemoteUserInfo(_loadGeneration, currentData, remoteUser);
  }

  void _handleProfileCollapsedChanged(bool collapsed) {
    if (_profileCollapsed == collapsed) return;
    setState(() => _profileCollapsed = collapsed);
  }

  Future<void> _loadWorlds(int generation, GenesisApi api, String uid) async {
    try {
      final worlds = await api.getMyWorlds(
        uid: uid.trim().isEmpty ? null : uid,
        limit: 30,
        offset: 0,
      );
      if (!mounted || generation != _loadGeneration) return;
      _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
        items: worlds.map(_profileWorldItemFromSummary).toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _worldsState.value =
          const UserProfileCollectionState<UserProfileWorldItem>(
            items: <UserProfileWorldItem>[],
            isLoading: false,
          );
    }
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
      final user = userInfo['user'] is Map
          ? Map<String, dynamic>.from(userInfo['user'] as Map)
          : null;
      if (user == null || user.isEmpty) return null;
      final uid = fallbackUid.trim();
      if (uid.isNotEmpty) {
        user.putIfAbsent('uid', () => uid);
      }
      final current = await sessionStore.readUserInfo();
      final merged = <String, dynamic>{
        if (current != null) ...current,
        ...user,
      };
      await sessionStore.saveUserInfo(merged);
      return merged;
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
    _renderedData = nextData;
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
    debugPrint('[MePage] refresh origins uid: $uid');
    final current = _originsState.value;
    _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
      items: current.items,
      isLoading: true,
    );
    try {
      final originPage = await services.api.getMyLaunchedOrigins(
        uid: uid.isEmpty ? null : uid,
        limit: 30,
        offset: 0,
      );
      if (!mounted) return;
      _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
        items: originPage.data
            .map(_profileOriginItemFromSummary)
            .toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
        items: current.items,
        isLoading: false,
      );
    }
  }

  Future<void> _refreshWorlds() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final current = _worldsState.value;
    _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
      items: current.items,
      isLoading: true,
    );
    try {
      final worlds = await services.api.getMyWorlds(
        uid: uid.isEmpty ? null : uid,
        limit: 30,
        offset: 0,
      );
      if (!mounted) return;
      _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
        items: worlds.map(_profileWorldItemFromSummary).toList(growable: false),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
        items: current.items,
        isLoading: false,
      );
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

  Future<void> _editAvatar() async {
    final Uint8List bytes;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      bytes = await image.readAsBytes();
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
    final nickName = await showDialog<String>(
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

        return SafeArea(
          bottom: false,
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
                      child: IconButton(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings, size: 24),
                        color: Colors.black,
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
                  onEditAvatar: _editAvatar,
                  onEditDisplayName: _editNickName,
                  onRefreshOrigins: _refreshOrigins,
                  onRefreshWorlds: _refreshWorlds,
                  onCollapsedChanged: _handleProfileCollapsedChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
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
  final backendAvatar = asResolvedImageUrl(
    remoteUser['avatar'],
    resolveAssetUrl,
    fallback: remoteUser['avatar_url'],
  );
  final backendUid = _mapString(remoteUser, 'uid');
  return currentData.copyWith(
    avatarUrl: backendAvatar.isEmpty ? currentData.avatarUrl : backendAvatar,
    displayName: backendName.isEmpty ? currentData.displayName : backendName,
    uid: backendUid.isEmpty ? currentData.uid : backendUid,
    followingCount:
        _mapIntOrNull(remoteUser, 'following_cnt') ??
        currentData.followingCount,
    followerCount:
        _mapIntOrNull(remoteUser, 'follower_cnt') ?? currentData.followerCount,
  );
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
      currentData.followerCount == nextData.followerCount;
}

UserProfileOriginItem _profileOriginItemFromSummary(OriginSummary item) {
  return UserProfileOriginItem(
    originId: item.id,
    oid: item.oid,
    title: item.name.trim().isEmpty ? item.oid : item.name.trim(),
    subtitle: _originSubtitle(item),
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
    subtitle: _worldSubtitle(item.wid, item.ownerName),
    imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
    progressCount: item.progressCount,
    interactCount: item.interactCount,
    characterCount: item.characterCount,
    playerCount: item.playerCount,
    ownerName: item.ownerName,
  );
}

String _originSubtitle(OriginSummary item) {
  final oid = item.oid.trim().isEmpty ? '-' : item.oid.trim();
  final originator = item.originator.trim().isEmpty
      ? '-'
      : formatUidForDisplay(item.originator);
  final version = item.versionNum <= 0 ? '-' : 'V${item.versionNum}';
  final updated = formatGenesisDateTime(item.updatedAt);
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version · $updated';
}

String _worldSubtitle(String wid, String ownerName) {
  final displayWid = wid.trim().isEmpty ? '-' : wid.trim();
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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Nick Name',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        // decoration: const InputDecoration(labelText: 'Nick Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('OK'),
        ),
      ],
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
