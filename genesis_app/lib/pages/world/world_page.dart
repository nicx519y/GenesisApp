import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

import '../../components/origin/stat_item.dart';
import '../../components/secend_tabs.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../network/genesis_api.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../utils/stat_count_formatter.dart';

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
      final world = await AppServicesScope.read(
        context,
      ).api.getWorld(widget.wid);
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
      final message = await AppServicesScope.of(
        context,
      ).api.progressWorld(widget.wid);
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
      await AppServicesScope.of(
        context,
      ).api.updateUserPosition(wid: widget.wid, locationId: point.sceneId);
    } catch (_) {}

    if (!mounted) return;
    final locationId = point.sceneId.trim().isNotEmpty
        ? point.sceneId.trim()
        : pointId;
    Navigator.of(context).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': widget.wid,
        'location_id': locationId,
        'pointId': pointId,
        'location_name': point.name,
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
    final locationNodes = flattenLocationTree(world.worldLocationTree);
    final points = locationNodes.isNotEmpty
        ? _pointsFromWorldLocations(
            locationNodes.map((node) => node.value).toList(growable: false),
            avatarsByLocation,
            depths: locationNodes
                .map((node) => node.depth)
                .toList(growable: false),
          )
        : world.worldLocations.isNotEmpty
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
            top: topPadding + 20,
            child: WorldTopOverlayBar(
              pointsCount: points.length,
              controller: _tabController,
            ),
          ),
          WorldDetailsShell(
            topGap: 0,
            minChildSize: 0.2,
            initialChildSize: 0.2,
            collapsedHeightOffset: 15,
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

class _WorldFeedContent extends StatefulWidget {
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
  State<_WorldFeedContent> createState() => _WorldFeedContentState();
}

class _WorldFeedContentState extends State<_WorldFeedContent>
    with SingleTickerProviderStateMixin {
  late final TabController _sectionController;
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _sectionController = TabController(length: 3, vsync: this)
      ..addListener(_handleSectionChange);
  }

  @override
  void dispose() {
    _sectionController
      ..removeListener(_handleSectionChange)
      ..dispose();
    super.dispose();
  }

  void _handleSectionChange() {
    if (_selectedSection == _sectionController.index) return;
    setState(() => _selectedSection = _sectionController.index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _WorldInfoHeader(
                  world: widget.world,
                  progressing: widget.progressing,
                  onProgress: widget.onProgress,
                ),
                const SizedBox(height: 4),
                SecendTabs(
                  controller: _sectionController,
                  labels: const ['Events', 'Status', 'Characters'],
                  horizontalPadding: 0,
                  labelPadding: EdgeInsets.zero,
                  expanded: true,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        switch (_selectedSection) {
          0 => _WorldEventsSection(world: widget.world),
          1 => SliverToBoxAdapter(
            child: _WorldStatusSection(world: widget.world),
          ),
          _ => SliverToBoxAdapter(
            child: _WorldCharactersSection(world: widget.world),
          ),
        },
        SliverToBoxAdapter(child: SizedBox(height: 20 + bottomPadding)),
      ],
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
    final title = world.origin.name.isEmpty ? world.name : world.origin.name;
    final wid = world.wid;
    final owner = world.origin.originator.trim().isNotEmpty
        ? world.origin.originator.trim()
        : world.ownerUid;
    final ownerUid = world.ownerUid.trim();
    final counters = <Map<String, dynamic>>[
      {'icon': 'tick', 'value': world.progressCount},
      {'icon': 'connect', 'value': world.interactCount},
      {'icon': 'character', 'value': world.characterCount},
      {'icon': 'player', 'value': world.playerCount},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B6192),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(
              width: 38,
              child: Icon(
                Icons.more_horiz_sharp,
                size: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Flexible(
              child: _WidMetaText(
                wid: wid,
                onCopy: () => _copyWid(context, wid),
              ),
            ),
            const Spacer(),
            Flexible(
              child: _OwnerMetaLink(
                owner: owner,
                onTap: ownerUid.isEmpty
                    ? null
                    : () => Navigator.of(context).pushNamed(
                        RouteNames.userInfo,
                        arguments: {'uid': ownerUid},
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final data in counters)
                    StatItem(
                      icon: _counterIcon(data['icon'] as String? ?? ''),
                      iconSize: 11,
                      iconColor: Colors.black,
                      text: formatStatCount(
                        data['value'] is num ? data['value'] as num : 0,
                      ),
                      gap: 4,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
            // const Spacer(),
            SizedBox(
              width: 120,
              height: 28,
              child: FilledButton(
                onPressed: progressing ? null : onProgress,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F9663),
                  disabledBackgroundColor: const Color(
                    0xFF2F9663,
                  ).withValues(alpha: 0.62),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: progressing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Progress',
                          strutStyle: StrutStyle(
                            fontSize: 14,
                            height: 1,
                            forceStrutHeight: true,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WidMetaText extends StatelessWidget {
  const _WidMetaText({required this.wid, required this.onCopy});

  final String wid;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'WID: $wid',
            style: const TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A8A8A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        InkResponse(
          onTap: onCopy,
          radius: 18,
          child: const Icon(
            Icons.copy_outlined,
            size: 16,
            color: Color(0xFF8A8A8A),
          ),
        ),
      ],
    );
  }
}

class _OwnerMetaLink extends StatelessWidget {
  const _OwnerMetaLink({required this.owner, required this.onTap});

  final String owner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                'Owner: $owner',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A8A8A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF8A8A8A)),
          ],
        ),
      ),
    );
  }
}

IconData _counterIcon(String key) {
  switch (key) {
    case 'tick':
      return MyFlutterApp.pregress;
    case 'connect':
      return MyFlutterApp.copy;
    case 'character':
      return MyFlutterApp.userStar;
    case 'player':
      return MyFlutterApp.user;
    default:
      return Icons.circle_outlined;
  }
}

Future<void> _copyWid(BuildContext context, String wid) async {
  await Clipboard.setData(ClipboardData(text: wid));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('WID copied')));
}

class _WorldEventsSection extends StatelessWidget {
  const _WorldEventsSection({required this.world});

  final WorldDetail world;

  @override
  Widget build(BuildContext context) {
    final ticks = world.ticks;
    if (ticks.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptySection(text: 'No events yet.'),
      );
    }

    final locationsById = <String, Map<String, dynamic>>{
      for (final location in world.worldLocations)
        _mapString(location, const ['location_id', 'id']): location,
    }..remove('');
    final fallbackBody = _eventBody(world);

    return SliverList.builder(
      itemCount: ticks.length,
      itemBuilder: (context, index) {
        return _TickEventItem(
          tick: ticks[index],
          tickNumber: _mapInt(ticks[index], const [
            'tick_index',
          ], fallback: index + 1),
          fallbackBody: fallbackBody,
          locationsById: locationsById,
          isLast: index == ticks.length - 1,
        );
      },
    );
  }
}

class _TickEventItem extends StatelessWidget {
  const _TickEventItem({
    required this.tick,
    required this.tickNumber,
    required this.fallbackBody,
    required this.locationsById,
    required this.isLast,
  });

  final Map<String, dynamic> tick;
  final int tickNumber;
  final String fallbackBody;
  final Map<String, Map<String, dynamic>> locationsById;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final createdAt = _tickDateTime(tick['created_at']);
    final date = _formatShortDate(createdAt);
    final body = _mapString(tick, const [
      'narrator',
      'content',
      'summary',
    ], fallback: fallbackBody);
    final paragraphs = _tickParagraphs(tick);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TickHeader(
            tickNumber: tickNumber,
            date: date,
            timeAgo: _relativeTime(createdAt),
          ),
          const SizedBox(height: 6),
          _GlobalEventCard(body: body),
          const SizedBox(height: 6),
          for (final paragraph in paragraphs) ...[
            _TickParagraphRow(
              paragraph: paragraph,
              fallbackDate: date,
              locationsById: locationsById,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _TickHeader extends StatelessWidget {
  const _TickHeader({
    required this.tickNumber,
    required this.date,
    required this.timeAgo,
  });

  final int tickNumber;
  final String date;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tick $tickNumber · $date',
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeAgo,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8F8F8F),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalEventCard extends StatelessWidget {
  const _GlobalEventCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 82,
            child: Text(
              'Global',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w300,
                color: Color(0xFF3B3B3B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickParagraphRow extends StatelessWidget {
  const _TickParagraphRow({
    required this.paragraph,
    required this.fallbackDate,
    required this.locationsById,
  });

  final Map<String, dynamic> paragraph;
  final String fallbackDate;
  final Map<String, Map<String, dynamic>> locationsById;

  @override
  Widget build(BuildContext context) {
    final locationId = _mapString(paragraph, const ['location_id']);
    final location = locationsById[locationId];
    final name = location == null
        ? locationId
        : _mapString(location, const ['location_name', 'name']);
    final date = _formatShortDate(
      _tickDateTime(paragraph['timestamp'] ?? paragraph['created_at']),
    );
    final body = _mapString(paragraph, const [
      'text',
      'content',
      'summary',
      'description',
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              name.isEmpty ? 'Location' : name,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((date.isEmpty ? fallbackDate : date).isNotEmpty) ...[
                  Text(
                    date.isEmpty ? fallbackDate : date,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF9A9A9A),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF3B3B3B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldStatusSection extends StatelessWidget {
  const _WorldStatusSection({required this.world});

  final WorldDetail world;

  @override
  Widget build(BuildContext context) {
    return _CharacterList(
      characters: world.characters,
      emptyText: 'No character status yet.',
      subtitleBuilder: _metricPercentText,
    );
  }
}

class _WorldCharactersSection extends StatelessWidget {
  const _WorldCharactersSection({required this.world});

  final WorldDetail world;

  @override
  Widget build(BuildContext context) {
    return _CharacterList(
      characters: world.characters,
      emptyText: 'No characters yet.',
      subtitleBuilder: _characterDescriptionText,
    );
  }
}

class _CharacterList extends StatelessWidget {
  const _CharacterList({
    required this.characters,
    required this.emptyText,
    required this.subtitleBuilder,
  });

  final List<Map<String, dynamic>> characters;
  final String emptyText;
  final String Function(Map<String, dynamic> character) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return _EmptySection(text: emptyText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < characters.length; i++) ...[
          _CharacterRow(
            character: characters[i],
            subtitle: subtitleBuilder(characters[i]),
          ),
          if (i != characters.length - 1) const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _CharacterRow extends StatelessWidget {
  const _CharacterRow({required this.character, required this.subtitle});

  final Map<String, dynamic> character;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final name = _mapString(character, const ['name'], fallback: 'Character');
    final type = _mapString(character, const ['type']).toLowerCase();
    final isAi = type == 'ai';
    final roleLabel = isAi
        ? 'Character'
        : _mapString(character, const [
            'player_name',
            'player_uid',
          ], fallback: 'Player');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenesisCharacterAvatar(
          url: _mapString(character, const ['avatar']),
          name: name,
          showStar: isAi,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      roleLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8F8F8F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6F6F6F),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}

String _eventBody(WorldDetail world) {
  final candidates = [
    world.lastProgressUpdate,
    world.origin.worldView,
    world.origin.description,
    world.name,
  ];
  for (final item in candidates) {
    final value = item.trim();
    if (value.isNotEmpty) return value;
  }
  return 'No world events yet.';
}

String _formatShortDate(DateTime? value) {
  if (value == null) return '';
  return value.toLocal().toIso8601String().split('T').first;
}

String _relativeTime(DateTime? value) {
  if (value == null) return '';
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return '1 day ago';
  return '${diff.inDays} days ago';
}

DateTime? _tickDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}

List<Map<String, dynamic>> _tickParagraphs(Map<String, dynamic> tick) {
  final raw = tick['paragraphs'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}

String _characterDescriptionText(Map<String, dynamic> character) {
  return _mapString(character, const [
    'brief',
    'description',
    'identity',
  ], fallback: 'No character details yet.');
}

String _metricPercentText(Map<String, dynamic> character) {
  final value = character['metric_value'];
  if (value is num) {
    final text = value % 1 == 0 ? value.toInt().toString() : value.toString();
    return '$text%';
  }

  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '0%';
  return text.endsWith('%') ? text : '$text%';
}

int _mapInt(Map<String, dynamic> map, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

String _mapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
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
    final isAi = '${c['type'] ?? ''}'.trim().toLowerCase() == 'ai';
    (map[locationId] ??= <UserAvatar>[]).add(
      UserAvatar(
        _initials(name),
        name: name,
        avatarUrl: avatar,
        showStar: isAi,
      ),
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
  Map<String, List<UserAvatar>> avatarsByLocation, {
  List<int>? depths,
}) {
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
      depth: depths == null || i >= depths.length ? 0 : depths[i],
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
