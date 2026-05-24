import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../components/me/profile_collection_list.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import 'settings_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_MeDataVm> _future;
  bool _isUpdatingProfile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_MeDataVm> _loadData() async {
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

    try {
      final userInfo = await api.v1.user.info();
      final user = userInfo['user'] is Map ? userInfo['user'] as Map : null;
      final backendName = _mapString(user, 'name');
      final backendAvatar = _mapString(user, 'avatar');
      if (backendName.isNotEmpty) resolvedDisplayName = backendName;
      if (backendAvatar.isNotEmpty) {
        resolvedAvatarUrl = resolveAssetUrl(backendAvatar);
      }
    } catch (_) {}

    List<_OriginListItemVm> origins = const [];
    try {
      final originPage = await api.getMyLaunchedOrigins(limit: 30, offset: 0);
      origins = originPage.data
          .map(
            (item) => _OriginListItemVm(
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

    List<_WorldListItemVm> worldItems = const [];
    try {
      final worlds = await api.getMyWorlds(limit: 30, offset: 0);
      worldItems = worlds
          .map(
            (item) => _WorldListItemVm(
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

    return _MeDataVm(
      avatarUrl: resolvedAvatarUrl,
      displayName: resolvedDisplayName,
      uid: uid.isEmpty ? 'Unknown' : uid,
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

  Future<void> _editAvatar(_MeDataVm data) async {
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
            final uploaded = await services.api.v1.common.uploadFile(
              bytes: result.bytes,
              bizType: 'avatar',
              filename: result.filename,
              contentType: result.contentType,
            );
            return _mapString(uploaded, 'file_url');
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

  Future<void> _editNickName(_MeDataVm data) async {
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
    required _MeDataVm Function(Map<dynamic, dynamic> updatedUser) apply,
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
        _future = Future<_MeDataVm>.value(updatedData);
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
    return FutureBuilder<_MeDataVm>(
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
                            onEdit: _isUpdatingProfile
                                ? null
                                : () => _editAvatar(data),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      data.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        height: 1,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _isUpdatingProfile
                                          ? null
                                          : () => _editNickName(data),
                                      child: const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Icon(Icons.edit, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'UID: ${data.uid}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6F6F6F),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _copyUid(data.uid),
                                      child: const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: Icon(Icons.copy, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SecendTabs(
                        controller: _tabController,
                        labels: const ['Origin', 'World'],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            ProfileCollectionList(
                              items: data.origins
                                  .map(
                                    (item) => GenesisProfileCollectionItemData(
                                      imageUrl: item.imageUrl,
                                      title: item.title,
                                      subtitle: item.subtitle,
                                      stats: [
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.save,
                                          value: item.copyCount,
                                        ),
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.copy,
                                          value: item.interactCount,
                                        ),
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.userStar,
                                          value: item.characterCount,
                                        ),
                                      ],
                                      onTap: () =>
                                          Navigator.of(context).pushNamed(
                                            RouteNames.originWorld,
                                            arguments: {
                                              'originId': item.originId,
                                              'oid': item.oid,
                                            },
                                          ),
                                    ),
                                  )
                                  .toList(growable: false),
                              emptyText: 'No Origins you created yet.',
                            ),
                            ProfileCollectionList(
                              items: data.worlds
                                  .map(
                                    (item) => GenesisProfileCollectionItemData(
                                      imageUrl: item.imageUrl,
                                      title: item.title,
                                      subtitle: item.subtitle,
                                      stats: [
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.pregress,
                                          value: item.progressCount,
                                        ),
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.copy,
                                          value: item.interactCount,
                                        ),
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.userStar,
                                          value: item.characterCount,
                                        ),
                                        GenesisProfileCollectionStat(
                                          icon: MyFlutterApp.user,
                                          value: item.playerCount,
                                        ),
                                      ],
                                      onTap: () =>
                                          Navigator.of(context).pushNamed(
                                            RouteNames.world,
                                            arguments: {'wid': item.wid},
                                          ),
                                    ),
                                  )
                                  .toList(growable: false),
                              emptyText: 'No Worlds you created yet.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
  final updated = _relativeTime(item.updatedAt);
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version · $updated';
}

String _worldSubtitle(String wid, String ownerName) {
  final displayWid = wid.trim().isEmpty ? '-' : wid.trim();
  final owner = ownerName.trim().isEmpty ? '-' : ownerName.trim();
  return 'WID: $displayWid  Owner: $owner';
}

String _relativeTime(DateTime? time) {
  if (time == null) return '-';
  final diff = DateTime.now().difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return _plural(diff.inMinutes, 'minute');
  if (diff.inDays < 1) return _plural(diff.inHours, 'hour');
  if (diff.inDays < 7) return _plural(diff.inDays, 'day');
  if (diff.inDays < 30) return _plural(diff.inDays ~/ 7, 'week');
  if (diff.inDays < 365) {
    final months = diff.inDays ~/ 30;
    if (months == 6) return 'half a year ago';
    return _plural(months, 'month');
  }
  return _plural(diff.inDays ~/ 365, 'year');
}

String _plural(int value, String unit) {
  return '$value $unit${value == 1 ? '' : 's'} ago';
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.onEdit});

  static const double _size = 80;
  static const double _radius = 8;

  final String url;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: _AvatarImage(url: url, size: _size),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_document,
                    size: 12,
                    color: onEdit == null ? Colors.white54 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE6E6E6),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.45,
        color: const Color(0xFF9C9C9C),
      ),
    );
  }
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

class _MeDataVm {
  const _MeDataVm({
    required this.avatarUrl,
    required this.displayName,
    required this.uid,
    required this.origins,
    required this.worlds,
  });

  final String avatarUrl;
  final String displayName;
  final String uid;
  final List<_OriginListItemVm> origins;
  final List<_WorldListItemVm> worlds;

  _MeDataVm copyWith({String? avatarUrl, String? displayName}) {
    return _MeDataVm(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      uid: uid,
      origins: origins,
      worlds: worlds,
    );
  }
}

class _OriginListItemVm {
  const _OriginListItemVm({
    required this.originId,
    required this.oid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.copyCount,
    required this.interactCount,
    required this.characterCount,
  });

  final int originId;
  final String oid;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int copyCount;
  final int interactCount;
  final int characterCount;
}

class _WorldListItemVm {
  const _WorldListItemVm({
    required this.wid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.progressCount,
    required this.interactCount,
    required this.characterCount,
    required this.playerCount,
    required this.ownerName,
  });

  final String wid;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int progressCount;
  final int interactCount;
  final int characterCount;
  final int playerCount;
  final String ownerName;
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
