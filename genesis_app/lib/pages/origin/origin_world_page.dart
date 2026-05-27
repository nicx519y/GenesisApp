import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_preview_list.dart';
import '../../components/origin/stat_item.dart';
import '../../components/world_map.dart';
import '../../components/world_map_stage.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../utils/relative_time_formatter.dart';
import '../../utils/stat_count_formatter.dart';

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

  void _showMapTab() {
    if (_tabController.index == 0) return;
    _tabController.animateTo(
      0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _launchOrigin(OriginDetail origin) async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final result = await AppServicesScope.of(
        context,
      ).api.v1.origin.launch(oid: origin.oid);
      if (!mounted) return;
      final wid = '${result['wid'] ?? ''}'.trim();
      if (wid.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Launch failed')));
        return;
      }
      Navigator.of(
        context,
      ).pushNamed(RouteNames.world, arguments: {'wid': wid});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Launch failed')));
    } finally {
      if (mounted) setState(() => _launching = false);
    }
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
        final rootLocationNodes = origin.locationTree;
        final allLocationNodes = flattenLocationTree(rootLocationNodes);
        final locationNodes = _originMapLocationNodes(
          rootLocationNodes,
          origin.characters,
        );
        final points = rootLocationNodes.isNotEmpty
            ? _pointsFromLocations(
                rootLocationNodes
                    .map((node) => node.value)
                    .toList(growable: false),
                origin.characters,
                depths: rootLocationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
                isLeafLocations: rootLocationNodes
                    .map((node) => node.children.isEmpty)
                    .toList(growable: false),
              )
            : _pointsFromLocations(
                _rootOriginLocations(origin.locations),
                origin.characters,
              );
        final listPoints = allLocationNodes.isNotEmpty
            ? _pointsFromLocations(
                allLocationNodes
                    .map((node) => node.value)
                    .toList(growable: false),
                origin.characters,
                depths: allLocationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
                isLeafLocations: allLocationNodes
                    .map((node) => node.children.isEmpty)
                    .toList(growable: false),
              )
            : origin.locations.isNotEmpty
            ? _pointsFromLocations(origin.locations, origin.characters)
            : points;

        return Scaffold(
          body: Stack(
            children: [
              WorldMapStage(
                controller: _tabController,
                pointsCount: listPoints.length,
                top: topPadding + 8,
                mapBuilder: (context, pointMode) => WorldMap(
                  points: points,
                  listPoints: listPoints,
                  locationNodes: locationNodes,
                  mapImageUrl: mapImageUrl,
                  dimmed: pointMode,
                  showPointsList: pointMode,
                  overlayTop: topPadding + 8 + 48,
                  drillExitTop: topPadding + 68,
                  onDrillIntoLocation: _showMapTab,
                ),
              ),
              WorldDetailsShell(
                topGap: 0,
                minChildSize: 0.31,
                initialChildSize: 0.31,
                collapsedHeightOffset: 15,
                contentBuilder: (scrollController) => _WorldDetailsContent(
                  scrollController: scrollController,
                  origin: origin,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _OriginBottomLaunchBar(
                  origin: origin,
                  launching: _launching,
                  onLaunch: () => _launchOrigin(origin),
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

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(
        bottom: 126 + bottomPadding,
        top: 12,
        right: 0,
        left: 0,
      ),
      children: [
        _OriginHeader(origin: origin),
        const SizedBox(height: 22),
        _WorldViewSection(origin: origin),
        const SizedBox(height: 26),
        _LaunchPreviewSection(origin: origin),
        const SizedBox(height: 28),
        const _CopyWorldProgressSection(),
        const SizedBox(height: 18),
        _DiscussSection(origin: origin),
        const SizedBox(height: 24),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
        const SizedBox(height: 24),
        _OriginCharactersSection(characters: origin.characters),
      ],
    );
  }
}

class _OriginBottomLaunchBar extends StatelessWidget {
  const _OriginBottomLaunchBar({
    required this.origin,
    required this.launching,
    required this.onLaunch,
  });

  final OriginDetail origin;
  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = (constraints.maxWidth * 0.38)
                .clamp(132.0, 168.0)
                .toDouble();
            return SizedBox(
              height: 56,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _LaunchBarStat(
                          icon: MyFlutterApp.save,
                          value: origin.copyCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          icon: MyFlutterApp.copy,
                          value: origin.interactCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          icon: MyFlutterApp.userStar,
                          value: origin.characterCount,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: buttonWidth,
                    height: 30,
                    child: FilledButton(
                      onPressed: launching ? null : onLaunch,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF238861),
                        disabledBackgroundColor: const Color(
                          0xFF238861,
                        ).withValues(alpha: 0.62),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: launching
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Launch'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LaunchBarStat extends StatelessWidget {
  const _LaunchBarStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      icon: icon,
      iconSize: 10,
      iconColor: const Color(0xFF171717),
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w400,
        color: Color(0xFF171717),
      ),
    );
  }
}

class _OriginHeader extends StatelessWidget {
  const _OriginHeader({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final originator = origin.originator.trim().isEmpty
        ? '-'
        : origin.originator.trim();
    final version = origin.versionNum <= 0 ? 1 : origin.versionNum;
    final age = formatRelativeTime(origin.updatedAt, fallback: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            '#${origin.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF53699E),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _OidMetaText(oid: origin.oid)),
            const SizedBox(width: 12),
            Text(
              'Originator: $originator  >',
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8C8C8C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Latest Version: V$version${age.isEmpty ? '' : ' · $age'}',
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8C8C8C),
          ),
        ),
        const SizedBox(height: 12),
        GenesisPrimaryButton(
          label: 'Edit Origin',
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(RouteNames.edit, arguments: {'origin_id': origin.oid}),
          backgroundColor: const Color(0xFF3B2468),
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}

class _OidMetaText extends StatelessWidget {
  const _OidMetaText({required this.oid});

  final String oid;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'OID: $oid',
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8C8C8C),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        InkResponse(
          onTap: () => _copyOid(context, oid),
          radius: 18,
          child: const Icon(
            Icons.copy_outlined,
            size: 15,
            color: Color(0xFF8C8C8C),
          ),
        ),
      ],
    );
  }
}

class _WorldViewSection extends StatelessWidget {
  const _WorldViewSection({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final body = origin.worldView.trim().isEmpty
        ? origin.description.trim()
        : origin.worldView.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: Color(0xFFFF2344),
          title: 'World View',
        ),
        const SizedBox(height: 12),
        Text(body, style: _bodyTextStyle),
        const SizedBox(height: 12),
        _PreviewImage(url: _resolveAssetUrl(origin.mapImage)),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9A9A9A)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: AspectRatio(
        aspectRatio: 2.1,
        child: imageUrl.isEmpty
            ? fallback
            : imageUrl.startsWith('assets/')
            ? Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return fallback;
                },
              ),
      ),
    );
  }
}

class _LaunchPreviewSection extends StatelessWidget {
  const _LaunchPreviewSection({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final previewEvents = _previewEvents(origin);
    final globalBody = origin.description.trim().isEmpty
        ? (previewEvents.isEmpty
              ? origin.worldView
              : previewEvents.first.content)
        : origin.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.auto_awesome,
          iconColor: Color(0xFF6554FF),
          title: 'Launch Preview',
        ),
        const SizedBox(height: 16),
        WorldTickEventItem(
          tick: _originPreviewTick(
            origin: origin,
            globalBody: globalBody,
            events: previewEvents,
          ),
          tickNumber: 1,
          fallbackBody: globalBody,
          dateLabel: origin.startTime.trim().isEmpty
              ? 'Day 1, 18:00'
              : origin.startTime.trim(),
          timeAgoLabel: '',
        ),
      ],
    );
  }
}

class _CopyWorldProgressSection extends StatelessWidget {
  const _CopyWorldProgressSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: MyFlutterApp.pregress,
          iconColor: Color(0xFFFF3347),
          title: 'Copy World Progress',
        ),
        SizedBox(height: 10),
        Text(
          'No launched world',
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }
}

class _DiscussSection extends StatefulWidget {
  const _DiscussSection({required this.origin});

  final OriginDetail origin;

  @override
  State<_DiscussSection> createState() => _DiscussSectionState();
}

class _DiscussSectionState extends State<_DiscussSection> {
  int _reloadSerial = 0;

  void _refreshDiscussPreview() {
    setState(() => _reloadSerial += 1);
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.origin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: MyFlutterApp.discuss,
          iconColor: const Color(0xFF111111),
          title: 'Discuss (${origin.discussCount})',
        ),
        const SizedBox(height: 14),
        DiscussPostInput(
          bizId: origin.oid,
          onSubmitted: _refreshDiscussPreview,
        ),
        const SizedBox(height: 14),
        OriginDiscussPreviewList(
          key: ValueKey('origin-discuss-preview-${origin.oid}-$_reloadSerial'),
          oid: origin.oid,
          count: origin.discussCount,
          showHeader: false,
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.center,
          child: Text(
            'View More >',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: Color(0xFF888888),
            ),
          ),
        ),
      ],
    );
  }
}

class _OriginCharactersSection extends StatelessWidget {
  const _OriginCharactersSection({required this.characters});

  final List<OriginCharacter> characters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: MyFlutterApp.userStar,
          iconColor: const Color(0xFFFF2344),
          title: 'Characters (${characters.length})',
        ),
        const SizedBox(height: 14),
        if (characters.isEmpty)
          const Text('No characters', style: _mutedBodyTextStyle)
        else
          for (int i = 0; i < characters.length; i++) ...[
            _OriginCharacterRow(character: characters[i]),
            if (i != characters.length - 1) const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _OriginCharacterRow extends StatelessWidget {
  const _OriginCharacterRow({required this.character});

  final OriginCharacter character;

  @override
  Widget build(BuildContext context) {
    final identity = _splitTags(character.tags).join(' · ');
    final tagline = character.tagline.trim();
    final description = character.description.trim();
    final goal = character.goal.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenesisCharacterAvatar(
          url: _resolveAssetUrl(character.avatar),
          name: character.name,
          showStar: true,
          size: 86,
          borderRadius: 6,
          starSize: 22,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF171717),
                ),
              ),
              if (identity.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  identity,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF202020),
                  ),
                ),
              ],
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  tagline,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFFF5148),
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(description, style: _bodyTextStyle),
              ],
              if (goal.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text('Goal: $goal', style: _bodyTextStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  final IconData icon;
  final Color iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF151515),
          ),
        ),
      ],
    );
  }
}

const _bodyTextStyle = TextStyle(
  fontSize: 12,
  height: 1.45,
  fontWeight: FontWeight.w500,
  color: Color(0xFF3C3C3C),
);

const _mutedBodyTextStyle = TextStyle(
  fontSize: 12,
  height: 1.3,
  fontWeight: FontWeight.w500,
  color: Color(0xFF999999),
);

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

Future<void> _copyOid(BuildContext context, String oid) async {
  await Clipboard.setData(ClipboardData(text: oid));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('OID copied')));
}

List<OriginEvent> _previewEvents(OriginDetail origin) {
  if (origin.events.isNotEmpty) {
    return origin.events.take(3).toList(growable: false);
  }

  if (origin.locations.isNotEmpty) {
    return origin.locations
        .take(3)
        .map(
          (location) => OriginEvent(
            label: location.name.trim().isEmpty ? 'Scene' : location.name,
            timestamp: '',
            content: location.description.trim().isEmpty
                ? origin.description
                : location.description,
          ),
        )
        .where((event) => event.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  final fallback = origin.description.trim().isEmpty
      ? origin.worldView.trim()
      : origin.description.trim();
  if (fallback.isEmpty) return const <OriginEvent>[];
  return [OriginEvent(label: 'Scene', timestamp: '', content: fallback)];
}

Map<String, dynamic> _originPreviewTick({
  required OriginDetail origin,
  required String globalBody,
  required List<OriginEvent> events,
}) {
  return <String, dynamic>{
    'created_at': origin.updatedAt,
    'narrator': globalBody,
    'paragraphs': [
      for (int i = 0; i < events.length; i++)
        <String, dynamic>{
          'label': events[i].label.trim().isEmpty
              ? 'Scene'
              : events[i].label.trim(),
          'timestamp': events[i].timestamp.trim().isEmpty
              ? _fallbackEventTime(i)
              : events[i].timestamp.trim(),
          'content': events[i].content,
        },
    ],
  };
}

String _fallbackEventTime(int index) {
  const times = ['Day 1, 17:55', 'Day 1, 18:00', 'Day 1, 18:02'];
  return times[index.clamp(0, times.length - 1)];
}

List<OriginLocation> _rootOriginLocations(List<OriginLocation> locations) {
  return locations
      .where((location) => location.parentLocationId.trim().isEmpty)
      .toList(growable: false);
}

List<WorldMapLocationNode> _originMapLocationNodes(
  List<LocationTreeNode<OriginLocation>> nodes,
  List<OriginCharacter> characters,
) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          point: _pointsFromLocations(
            [node.value],
            characters,
            depths: [node.depth],
            isLeafLocations: [node.children.isEmpty],
          ).first,
          mapImageUrl: _resolveAssetUrl(node.value.mapUrl),
          children: _originMapLocationNodes(node.children, characters),
        );
      })
      .toList(growable: false);
}

List<WorldPoint> _pointsFromLocations(
  List<OriginLocation> locations,
  List<OriginCharacter> characters, {
  List<int>? depths,
  List<bool>? isLeafLocations,
}) {
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
        showStar: true,
      ),
    );
  }

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final locationId = l.locationId.trim().isEmpty
        ? '${l.id}'
        : l.locationId.trim();
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
      sceneId: locationId,
      pointId: locationId,
      iconUrl: _resolveAssetUrl(l.icon),
      description: l.description,
      depth: depths == null || i >= depths.length ? 0 : depths[i],
      isLeafLocation: isLeafLocations == null || i >= isLeafLocations.length
          ? true
          : isLeafLocations[i],
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
