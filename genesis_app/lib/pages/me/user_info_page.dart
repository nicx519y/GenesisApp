import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../components/me/user_profile_content.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/relative_time_formatter.dart';

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
    final services = AppServicesScope.read(context);
    final api = services.api;
    final uid = widget.uid.trim();
    final localUid = (await services.sessionStore.readUid())?.trim() ?? '';
    final userInfo = await api.v1.user.info(uid: uid);
    final user = userInfo['user'] is Map
        ? userInfo['user'] as Map
        : const <String, dynamic>{};
    final relation = userInfo['relation'] is Map
        ? userInfo['relation'] as Map
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
      isSelf:
          _mapBool(relation, 'is_self') ||
          (localUid.isNotEmpty && localUid == profileUid),
      isFollowed:
          _mapBool(relation, 'is_followed') || _mapBool(relation, 'i_followed'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: ''),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<UserProfileData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _UserInfoLoadingSkeleton();
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
            return UserProfileContent(data: data);
          },
        ),
      ),
    );
  }
}

class _UserInfoLoadingSkeleton extends StatelessWidget {
  const _UserInfoLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _UserInfoSkeletonShimmer(
      child: Column(
        key: ValueKey<String>('user-info-loading-skeleton'),
        children: [
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserInfoSkeletonBone(width: 80, height: 80, borderRadius: 8),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 2),
                      _UserInfoSkeletonBone(
                        widthFactor: 0.58,
                        height: 20,
                        borderRadius: 4,
                      ),
                      SizedBox(height: 10),
                      _UserInfoSkeletonBone(
                        width: 128,
                        height: 16,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _UserInfoSkeletonBone(width: 84, height: 20, borderRadius: 4),
                SizedBox(width: 16),
                _UserInfoSkeletonBone(width: 86, height: 20, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _UserInfoSkeletonBone(height: 38, borderRadius: 8),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _UserInfoSkeletonBone(height: 38, borderRadius: 8),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UserInfoSkeletonBone(width: 54, height: 20, borderRadius: 4),
                  SizedBox(width: 20),
                  _UserInfoSkeletonBone(width: 48, height: 20, borderRadius: 4),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _UserInfoCollectionSkeletonList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoCollectionSkeletonList extends StatelessWidget {
  const _UserInfoCollectionSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 17, bottom: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) => const _UserInfoCollectionSkeletonItem(),
    );
  }
}

class _UserInfoCollectionSkeletonItem extends StatelessWidget {
  const _UserInfoCollectionSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserInfoSkeletonBone(width: 52, height: 52, borderRadius: 0),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserInfoSkeletonBone(
                widthFactor: 0.48,
                height: 15,
                borderRadius: 4,
              ),
              SizedBox(height: 7),
              _UserInfoSkeletonBone(
                widthFactor: 0.92,
                height: 10,
                borderRadius: 4,
              ),
              SizedBox(height: 6),
              _UserInfoSkeletonBone(
                widthFactor: 0.68,
                height: 10,
                borderRadius: 4,
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _UserInfoSkeletonBone(width: 34, height: 14, borderRadius: 3),
                  SizedBox(width: 10),
                  _UserInfoSkeletonBone(width: 42, height: 14, borderRadius: 3),
                  SizedBox(width: 10),
                  _UserInfoSkeletonBone(width: 36, height: 14, borderRadius: 3),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserInfoSkeletonShimmer extends StatefulWidget {
  const _UserInfoSkeletonShimmer({required this.child});

  final Widget child;

  @override
  State<_UserInfoSkeletonShimmer> createState() =>
      _UserInfoSkeletonShimmerState();
}

class _UserInfoSkeletonShimmerState extends State<_UserInfoSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UserInfoSkeletonAnimation(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _UserInfoSkeletonAnimation extends InheritedWidget {
  const _UserInfoSkeletonAnimation({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_UserInfoSkeletonAnimation>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(covariant _UserInfoSkeletonAnimation oldWidget) {
    return animation != oldWidget.animation;
  }
}

class _UserInfoSkeletonBone extends StatelessWidget {
  const _UserInfoSkeletonBone({
    this.width,
    this.widthFactor,
    this.height,
    this.borderRadius = 4,
  }) : assert(width == null || widthFactor == null);

  final double? width;
  final double? widthFactor;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = _UserInfoSkeletonAnimation.maybeOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    Widget child = SizedBox(
      width: width,
      height: height,
      child: animation == null || disableAnimations
          ? _decoratedBox(0)
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) => _decoratedBox(animation.value),
            ),
    );

    if (widthFactor case final factor?) {
      child = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: child,
      );
    }
    return child;
  }

  Widget _decoratedBox(double animationValue) {
    final offset = -1.4 + (animationValue * 2.8);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(offset - 0.8, 0),
          end: Alignment(offset + 0.8, 0),
          colors: const [
            Color(0xFFE8EBF0),
            Color(0xFFF6F7F9),
            Color(0xFFE8EBF0),
          ],
          stops: const [0.25, 0.5, 0.75],
        ),
      ),
    );
  }
}

String _originSubtitle(OriginSummary item) {
  final oid = item.oid.trim().isEmpty ? '-' : item.oid.trim();
  final originator = item.originator.trim().isEmpty
      ? '-'
      : formatUidForDisplay(item.originator);
  final version = item.versionNum <= 0 ? '-' : 'V${item.versionNum}';
  final updated = formatRelativeTime(item.updatedAt);
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version · $updated';
}

String _worldSubtitle(String wid, String ownerName) {
  final displayWid = wid.trim().isEmpty ? '-' : wid.trim();
  final owner = formatUidForDisplay(ownerName, fallback: '-');
  return 'WID: $displayWid  Owner: $owner';
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

bool _mapBool(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
