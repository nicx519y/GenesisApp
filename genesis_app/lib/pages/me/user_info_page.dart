import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../components/me/user_profile_content.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key, required this.uid});

  final String uid;

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  late Future<UserProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<UserProfileData> _loadData() async {
    final api = AppServicesScope.read(context).api;
    final uid = widget.uid.trim();
    final userInfo = await api.v1.user.info(uid: uid);
    final user = userInfo['user'] is Map
        ? userInfo['user'] as Map
        : const <String, dynamic>{};
    final resolvedUid = _mapString(user, 'uid', fallback: uid);
    final displayName = _mapString(user, 'name', fallback: 'User');
    final avatarUrl = resolveAssetUrl(_mapString(user, 'avatar'));
    final profileUid = resolvedUid.trim().isNotEmpty ? resolvedUid : uid;

    List<UserProfileOriginItem> origins = const [];
    if (profileUid.trim().isNotEmpty) {
      try {
        final originPage = await api.getMyLaunchedOrigins(
          uid: profileUid,
          limit: 30,
          offset: 0,
        );
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
    }

    List<UserProfileWorldItem> worldItems = const [];
    if (profileUid.trim().isNotEmpty) {
      try {
        final worlds = await api.getMyWorlds(
          uid: profileUid,
          limit: 30,
          offset: 0,
        );
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
    }

    return UserProfileData(
      avatarUrl: avatarUrl,
      displayName: displayName,
      uid: profileUid.trim().isEmpty ? 'Unknown' : profileUid,
      followingCount: _mapInt(user, 'following_cnt'),
      followerCount: _mapInt(user, 'follower_cnt'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const PageTitleText(pageName: 'User Info'),
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<UserProfileData>(
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
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return UserProfileContent(data: data, onCopyUid: _copyUid);
          },
        ),
      ),
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
