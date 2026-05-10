import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

import '../../components/origin/stat_item.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../network/genesis_api.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';

class WorldPage extends StatefulWidget {
  const WorldPage({super.key, required this.wid});

  final String wid;

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  WorldDetail? _world;
  Object? _initialLoadError;
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _progressing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_fetchWorld(isInitial: true));
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_fetchWorld());
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(_fetchWorld());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorld({bool isInitial = false}) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final world = await GenesisApi().getWorld(widget.wid);
      if (!mounted) return;
      setState(() {
        _world = world;
        if (isInitial) _initialLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (isInitial) {
        setState(() {
          _initialLoadError = e;
        });
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _progress() async {
    if (_progressing) return;
    setState(() => _progressing = true);
    try {
      final message = await GenesisApi().progressWorld(widget.wid);
      if (!mounted) return;
      if (message.trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      await _fetchWorld();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Progress failed')));
    } finally {
      if (mounted) setState(() => _progressing = false);
    }
  }

  Future<void> _openChatForPoint(WorldPoint point) async {
    final pointId = point.pointId.trim().isNotEmpty
        ? point.pointId.trim()
        : point.id.trim();
    if (pointId.isEmpty) {
      Navigator.of(context).pushNamed(RouteNames.chat);
      return;
    }

    try {
      await GenesisApi().updateUserPosition(
        wid: widget.wid,
        locationId: point.sceneId,
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushNamed(
      RouteNames.chat,
      arguments: {
        'wid': widget.wid,
        'pointId': pointId,
        'sceneId': point.sceneId,
        'locationName': point.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final world = _world;
    if (world == null) {
      if (_initialLoadError != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _fetchWorld(isInitial: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mapImageUrl = _resolveAssetUrl(
      world.origin.worldMap.isEmpty
          ? world.origin.mapImage
          : world.origin.worldMap,
    );
    final avatarsByLocation = _avatarsByLocationFromCharacterPositions(
      world.characterPositions,
    );
    final points = world.worldLocations.isNotEmpty
        ? _pointsFromWorldLocations(world.worldLocations, avatarsByLocation)
        : _pointsFromLocationIds(
            world.characterPositions
                .map((e) => e['location_id'])
                .followedBy(world.userPositions.map((e) => e['location_id']))
                .toList(growable: false),
            avatarsByLocation,
          );
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final pointMode = _tabController.index == 1;
                return WorldMap(
                  points: points,
                  mapImageUrl: mapImageUrl,
                  dimmed: pointMode,
                  showPointsList: pointMode,
                  overlayTop: topPadding + 8 + 48,
                  onPointTap: (p) => unawaited(_openChatForPoint(p)),
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: topPadding + 8,
            child: WorldTopOverlayBar(
              pointsCount: points.length,
              controller: _tabController,
            ),
          ),
          WorldDetailsShell(
            topGap: 60,
            contentBuilder: (scrollController) => _WorldFeedContent(
              scrollController: scrollController,
              world: world,
              progressing: _progressing,
              onProgress: _progress,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldFeedContent extends StatelessWidget {
  const _WorldFeedContent({
    required this.scrollController,
    required this.world,
    required this.progressing,
    required this.onProgress,
  });

  final ScrollController scrollController;
  final WorldDetail world;
  final bool progressing;
  final Future<void> Function() onProgress;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final children = <Widget>[
      _WorldInfoHeader(
        world: world,
        progressing: progressing,
        onProgress: onProgress,
      ),
      const SizedBox(height: 12),
      const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
      const SizedBox(height: 12),
      _LastProgressCard(data: world),
      const SizedBox(height: 12),
    ];

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(top: 0, bottom: 24 + bottomPadding + 16),
      children: children,
    );
  }
}

class _WorldInfoHeader extends StatelessWidget {
  const _WorldInfoHeader({
    required this.world,
    required this.progressing,
    required this.onProgress,
  });

  final WorldDetail world;
  final bool progressing;
  final Future<void> Function() onProgress;

  @override
  Widget build(BuildContext context) {
    final title =
        '#${world.origin.name.isEmpty ? world.name : world.origin.name}';
    final wid = world.wid;
    final lastProgress = world.lastProgressAt == null
        ? ''
        : world.lastProgressAt!.toIso8601String().split('T').first;
    final owner = world.ownerUid;
    final counters = <Map<String, dynamic>>[
      {'icon': 'play', 'value': world.progressCount},
      {'icon': 'eye', 'value': world.interactCount},
      {'icon': 'group', 'value': world.userPositions.length},
      {'icon': 'spark', 'value': world.characterPositions.length},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: progressing ? null : onProgress,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: progressing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B6192),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(MyFlutterApp.gas, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${world.origin.interactCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.more_horiz, size: 18),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MetaText('WID: $wid'),
            const SizedBox(width: 14),
            _MetaText('Last Progress: $lastProgress'),
            const Spacer(),
            Text(
              'Owner: $owner >',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < counters.length; i++) ...[
              Builder(
                builder: (context) {
                  final data = counters[i];
                  final iconKey = data['icon'] as String? ?? '';
                  final value = data['value'];
                  return StatItem(
                    icon: _counterIcon(iconKey),
                    text: '$value',
                    gap: 8,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  );
                },
              ),
              if (i != counters.length - 1) const SizedBox(width: 12),
            ],
            const Spacer(),

            Text(
              'Invite / Request',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A8A8A),
      ),
    );
  }
}

IconData _counterIcon(String key) {
  switch (key) {
    case 'play':
      return MyFlutterApp.skipNext;
    case 'eye':
      return MyFlutterApp.eye;
    case 'group':
      return MyFlutterApp.userStar;
    case 'spark':
      return MyFlutterApp.user;
    default:
      return Icons.circle_outlined;
  }
}

class _LastProgressCard extends StatelessWidget {
  const _LastProgressCard({required this.data});

  final WorldDetail data;

  @override
  Widget build(BuildContext context) {
    final title = 'Last Progress';
    final timeAgo = data.lastProgressAt == null
        ? ''
        : data.lastProgressAt!.toIso8601String().split('T').first;
    final action = 'View history >';
    final body = data.origin.worldView;
    final images = const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timeAgo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF999999),
              ),
            ),
            const Spacer(),
            Text(
              action,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8A8A8A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 10),
        if (images.isNotEmpty)
          Row(
            children: [
              for (int i = 0; i < images.length && i < 2; i++) ...[
                SizedBox(
                  width: 100,
                  height: 100,
                  child: _DemoImageBox(seed: images[i]),
                ),
                if (i == 0) const SizedBox(width: 10),
              ],
            ],
          ),
      ],
    );
  }
}

class _DemoImageBox extends StatelessWidget {
  const _DemoImageBox({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: _seedGradient(seed),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 28,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

LinearGradient _seedGradient(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (a, b) => a * 31 + b);
  final c1 = Color(0xFF000000 + (hash & 0x00FFFFFF)).withValues(alpha: 0.9);
  final c2 = Color(
    0xFF000000 + ((hash * 7) & 0x00FFFFFF),
  ).withValues(alpha: 0.9);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [c1, c2],
  );
}

String _resolveAssetUrl(String raw) {
  return resolveAssetUrl(raw);
}

Map<String, List<UserAvatar>> _avatarsByLocationFromCharacterPositions(
  List<Map<String, dynamic>> characterPositions,
) {
  final map = <String, List<UserAvatar>>{};
  for (final cp in characterPositions) {
    final rawLocationId = cp['location_id'] ?? cp['current_location_id'];
    final locationId = '$rawLocationId'.trim();
    if (locationId.isEmpty) continue;
    final character = cp['character'];
    if (character is! Map) continue;
    final c = character;
    final name = (c['name'] ?? '').toString();
    final avatar = _resolveAssetUrl((c['avatar'] ?? '').toString());
    (map[locationId] ??= <UserAvatar>[]).add(
      UserAvatar(_initials(name), name: name, avatarUrl: avatar),
    );
  }
  return map;
}

String _initials(String name) {
  final cleaned = name.trim();
  if (cleaned.isEmpty) return '?';
  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}

List<WorldPoint> _pointsFromWorldLocations(
  List<Map<String, dynamic>> locations,
  Map<String, List<UserAvatar>> avatarsByLocation,
) {
  if (locations.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final locationId = '${l['location_id'] ?? l['id'] ?? ''}'.trim();
    final pointId = '${l['point_id'] ?? l['id'] ?? locationId}'.trim();
    final id = pointId.isNotEmpty
        ? pointId
        : (locationId.isNotEmpty ? locationId : '$i');
    final name = (l['name'] ?? '').toString();
    final description = (l['description'] ?? '').toString();
    final icon = _resolveAssetUrl((l['icon'] ?? '').toString());

    final rawXP = l['x_percent'] ?? l['xPercent'];
    final rawYP = l['y_percent'] ?? l['yPercent'];
    final xPercent = rawXP is num
        ? rawXP.toDouble()
        : double.tryParse('$rawXP') ?? 0;
    final yPercent = rawYP is num
        ? rawYP.toDouble()
        : double.tryParse('$rawYP') ?? 0;

    double? dx;
    double? dy;
    if (xPercent > 0 && yPercent > 0) {
      dx = xPercent / 100;
      dy = yPercent / 100;
    } else {
      final posX = l['x'] ?? l['pos_x'] ?? l['position_x'];
      final posY = l['y'] ?? l['pos_y'] ?? l['position_y'];
      dx = posX is num ? posX.toDouble() : double.tryParse('$posX');
      dy = posY is num ? posY.toDouble() : double.tryParse('$posY');
    }

    if (dx == null || dy == null) {
      final positionRaw = l['position'];
      final position = positionRaw is int
          ? positionRaw
          : int.tryParse('$positionRaw');
      final index = (position == null || position <= 0) ? i : (position - 1);
      final col = index % 3;
      final row = index ~/ 3;
      dx = 0.18 + col * 0.30;
      dy = 0.22 + row * 0.22;
    }

    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };

    return WorldPoint(
      id: id,
      name: name,
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: (avatarsByLocation[locationId] ?? const <UserAvatar>[]),
      sceneId: locationId,
      pointId: pointId,
      iconUrl: icon,
      description: description,
    );
  });
}

List<WorldPoint> _pointsFromLocationIds(
  List<dynamic> locationIds,
  Map<String, List<UserAvatar>> avatarsByLocation,
) {
  final ids =
      locationIds
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort((a, b) => a.compareTo(b));

  if (ids.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(ids.length, (i) {
    final id = ids[i];
    final col = i % 3;
    final row = i ~/ 3;
    final dx = 0.18 + col * 0.30;
    final dy = 0.22 + row * 0.22;
    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };

    return WorldPoint(
      id: id,
      name: 'Location $id',
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: (avatarsByLocation[id] ?? const <UserAvatar>[]),
      sceneId: id,
      pointId: id,
      description: '',
    );
  });
}
