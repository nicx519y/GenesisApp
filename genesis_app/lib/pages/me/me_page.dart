import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../components/me/user_profile_content.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../utils/relative_time_formatter.dart';
import 'settings_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  late Future<UserProfileData> _future;
  bool _isUpdatingProfile = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<UserProfileData> _loadData() async {
    final services = AppServicesScope.read(context);
    final api = services.api;
    final profile = services.identityAuth.currentProfile();
    final localUid = (await services.sessionStore.readUid())?.trim() ?? '';
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

    try {
      final userInfo = await api.v1.user.info();
      final user = userInfo['user'] is Map ? userInfo['user'] as Map : null;
      final backendName = _mapString(user, 'name');
      final backendAvatar = _mapString(user, 'avatar');
      if (backendName.isNotEmpty) resolvedDisplayName = backendName;
      if (backendAvatar.isNotEmpty) {
        resolvedAvatarUrl = resolveAssetUrl(backendAvatar);
      }
      resolvedFollowingCount = _mapInt(user, 'following_cnt');
      resolvedFollowerCount = _mapInt(user, 'follower_cnt');
    } catch (_) {}

    List<UserProfileOriginItem> origins = const [];
    try {
      final originPage = await api.getMyLaunchedOrigins(limit: 30, offset: 0);
      origins = originPage.data
          .map(
            (item) => UserProfileOriginItem(
              originId: item.id,
              oid: item.oid,
              title: item.name.trim().isEmpty ? item.oid : item.name.trim(),
              subtitle: _originSubtitle(item),
              imageUrl: resolveAssetUrl(item.mapImage),
              copyCount: item.copyCount,
              interactCount: item.interactCount,
              characterCount: item.characterCount,
            ),
          )
          .toList(growable: false);
    } catch (_) {}

    List<UserProfileWorldItem> worldItems = const [];
    try {
      final worlds = await api.getMyWorlds(limit: 30, offset: 0);
      worldItems = worlds
          .map(
            (item) => UserProfileWorldItem(
              wid: item.wid,
              title: item.name.trim().isEmpty ? item.wid : item.name.trim(),
              subtitle: _worldSubtitle(item.wid, item.ownerName),
              imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
              progressCount: item.progressCount,
              interactCount: item.interactCount,
              characterCount: item.characterCount,
              playerCount: item.playerCount,
              ownerName: item.ownerName,
            ),
          )
          .toList(growable: false);
    } catch (_) {}

    return UserProfileData(
      avatarUrl: resolvedAvatarUrl,
      displayName: resolvedDisplayName,
      uid: uid.isEmpty ? 'Unknown' : uid,
      followingCount: resolvedFollowingCount,
      followerCount: resolvedFollowerCount,
      isSelf: true,
      isFollowed: false,
      origins: origins,
      worlds: worldItems,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _copyUid(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('UID copied')));
  }

  Future<void> _openSettings() async {
    final loggedOut = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const SettingsPage()));
    if (loggedOut == true) {
      widget.onLoggedOut?.call();
    }
  }

  Future<void> _editAvatar(UserProfileData data) async {
    final Uint8List bytes;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      bytes = await image.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image pick failed')));
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
            return _mapString(uploaded, 'url');
          },
        ),
      ),
    );
    if (avatarUrl == null || avatarUrl.trim().isEmpty || !mounted) return;

    await _updateProfile(
      update: () => services.api.v1.user.update(avatar: avatarUrl),
      apply: (updatedUser) {
        final updatedAvatar = _mapString(
          updatedUser,
          'avatar',
          fallback: avatarUrl,
        );
        return data.copyWith(avatarUrl: resolveAssetUrl(updatedAvatar));
      },
    );
  }

  Future<void> _editNickName(UserProfileData data) async {
    final nickName = await showDialog<String>(
      context: context,
      builder: (_) => _NickNameDialog(initialValue: data.displayName),
    );

    final trimmedName = nickName?.trim() ?? '';
    if (trimmedName.isEmpty || trimmedName == data.displayName) return;
    if (!mounted) return;

    final services = AppServicesScope.read(context);
    await _updateProfile(
      update: () => services.api.v1.user.update(name: trimmedName),
      apply: (updatedUser) {
        final updatedName = _mapString(
          updatedUser,
          'name',
          fallback: trimmedName,
        );
        return data.copyWith(displayName: updatedName);
      },
    );
  }

  Future<void> _updateProfile({
    required Future<Map<String, dynamic>> Function() update,
    required UserProfileData Function(Map<dynamic, dynamic> updatedUser) apply,
  }) async {
    setState(() {
      _isUpdatingProfile = true;
    });
    try {
      final response = await update();
      final updatedUser = response['user'] is Map
          ? response['user'] as Map
          : response;
      final updatedData = apply(updatedUser);
      if (!mounted) return;
      setState(() {
        _future = Future<UserProfileData>.value(updatedData);
        _isUpdatingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUpdatingProfile = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Update failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileData>(
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

        final data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings, size: 24),
                    color: Colors.black,
                  ),
                ],
              ),
              Expanded(
                child: UserProfileContent(
                  data: data,
                  isUpdatingProfile: _isUpdatingProfile,
                  onEditAvatar: () => _editAvatar(data),
                  onEditDisplayName: () => _editNickName(data),
                  onCopyUid: _copyUid,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _originSubtitle(OriginSummary item) {
  final oid = item.oid.trim().isEmpty ? '-' : item.oid.trim();
  final originator = item.originator.trim().isEmpty
      ? '-'
      : item.originator.trim();
  final version = item.versionNum <= 0 ? '-' : 'V${item.versionNum}';
  final updated = formatRelativeTime(item.updatedAt);
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version · $updated';
}

String _worldSubtitle(String wid, String ownerName) {
  final displayWid = wid.trim().isEmpty ? '-' : wid.trim();
  final owner = ownerName.trim().isEmpty ? '-' : ownerName.trim();
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
  final value = map == null ? null : map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
