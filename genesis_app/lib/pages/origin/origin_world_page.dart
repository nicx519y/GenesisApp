import 'package:flutter/material.dart';
import '../../components/origin/characters_list.dart';
import '../../components/origin/stat_item.dart';
import '../../components/origin/world_description_card.dart';
import '../../components/origin/world_header_card.dart';
import '../../components/world_map.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../routers/app_router.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../app/bootstrap/app_services_scope.dart';

const double _stickyBottomBarHeight = 58;

class OriginWorldPage extends StatefulWidget {
  const OriginWorldPage({super.key, required this.oid, required this.originId});

  final String oid;
  final int originId;

  @override
  State<OriginWorldPage> createState() => _OriginWorldPageState();
}

class _OriginWorldPageState extends State<OriginWorldPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Future<OriginDetail>? _future;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppServicesScope.read(context).api.getOrigin(widget.oid);
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _future = AppServicesScope.read(context).api.getOrigin(widget.oid);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return FutureBuilder<OriginDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Load failed'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => setState(() {
                      _future = AppServicesScope.of(
                        context,
                      ).api.getOrigin(widget.oid);
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final origin = snapshot.data;
        if (origin == null) {
          return const Scaffold(body: Center(child: Text('No data')));
        }

        final mapImageUrl = _resolveAssetUrl(
          origin.worldMap.isEmpty ? origin.mapImage : origin.worldMap,
        );
        final points = _pointsFromLocations(
          origin.locations,
          origin.characters,
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
                contentBuilder: (scrollController) => _WorldDetailsContent(
                  scrollController: scrollController,
                  origin: origin,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFF6F6F6)),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: _BottomStatsBar(
                        copyCount: origin.copyCount,
                        interactionCount: origin.interactCount,
                        characterCount: origin.characters.length,
                        launching: _launching,
                        onLaunch: () async {
                          if (_launching) return;
                          setState(() => _launching = true);
                          try {
                            final world = await AppServicesScope.read(context)
                                .api
                                .launchWorld(
                                  originId: widget.originId,
                                  worldviewId: origin.oid,
                                  worldName: origin.name,
                                );
                            if (!context.mounted) return;
                            Navigator.of(
                              context,
                            ).pushNamed(RouteNames.world, arguments: world.wid);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Launch failed')),
                            );
                          } finally {
                            if (mounted) setState(() => _launching = false);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorldDetailsContent extends StatelessWidget {
  const _WorldDetailsContent({
    required this.scrollController,
    required this.origin,
  });

  final ScrollController scrollController;
  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final headerOid = origin.oid;
    final headerTitle = '#${origin.name}';
    final headerUpdatedText = origin.updatedAt == null
        ? ''
        : origin.updatedAt!.toIso8601String().split('T').first;
    final headerOriginator = '';

    final descriptionTitle = 'World View';
    final descriptionBody = origin.worldView;

    final characters = origin.characters
        .map(
          (c) => <String, dynamic>{
            'name': c.name,
            'subtitle': c.description,
            'tags': _splitTags(c.tags),
            'image': _resolveAssetUrl(c.avatar),
            'powerText': '',
          },
        )
        .toList(growable: false);

    final children = <Widget>[
      WorldHeaderCard(
        oid: headerOid,
        title: headerTitle,
        updatedText: headerUpdatedText,
        originator: headerOriginator,
      ),
      const SizedBox(height: 12),
      const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
      const SizedBox(height: 12),
      WorldDescriptionCard(title: descriptionTitle, body: descriptionBody),
      const SizedBox(height: 12),
      CharactersList(characters: characters),
    ];

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(
        bottom: 24 + bottomPadding + _stickyBottomBarHeight + 16,
        top: 0,
        right: 0,
        left: 0,
      ),
      children: children,
    );
  }
}

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const [];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _resolveAssetUrl(String raw) {
  return resolveAssetUrl(raw);
}

List<WorldPoint> _pointsFromLocations(
  List<OriginLocation> locations,
  List<OriginCharacter> characters,
) {
  if (locations.isEmpty) return const <WorldPoint>[];

  final avatarsByLocation = <int, List<UserAvatar>>{};
  for (final c in characters) {
    final locationId = c.currentLocationId > 0
        ? c.currentLocationId
        : c.initialLocationId;
    if (locationId <= 0) continue;
    (avatarsByLocation[locationId] ??= <UserAvatar>[]).add(
      UserAvatar(
        _initials(c.name),
        name: c.name,
        avatarUrl: _resolveAssetUrl(c.avatar),
      ),
    );
  }

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final rawDx = l.xPercent > 0 ? (l.xPercent / 100) : null;
    final rawDy = l.yPercent > 0 ? (l.yPercent / 100) : null;
    final col = i % 3;
    final row = i ~/ 3;
    final dx = rawDx ?? (0.18 + col * 0.30);
    final dy = rawDy ?? (0.22 + row * 0.22);
    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };
    return WorldPoint(
      id: '${l.id}',
      name: l.name,
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: (avatarsByLocation[l.id] ?? const <UserAvatar>[]),
      iconUrl: _resolveAssetUrl(l.icon),
      description: l.description,
    );
  });
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

class _BottomStatsBar extends StatelessWidget {
  const _BottomStatsBar({
    required this.copyCount,
    required this.interactionCount,
    required this.characterCount,
    required this.launching,
    required this.onLaunch,
  });

  final int copyCount;
  final int interactionCount;
  final int characterCount;
  final bool launching;
  final Future<void> Function() onLaunch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatItem(icon: MyFlutterApp.save, text: '$copyCount'),
        const SizedBox(width: 14),
        StatItem(icon: MyFlutterApp.copy, text: '$interactionCount'),
        const SizedBox(width: 14),
        StatItem(icon: MyFlutterApp.userStar, text: '$characterCount'),
        const Spacer(),
        SizedBox(
          height: 30,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: launching ? null : onLaunch,
            child: launching
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Launch',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
          ),
        ),
      ],
    );
  }
}
