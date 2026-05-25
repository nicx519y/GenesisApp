import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/world_map.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../app/bootstrap/app_services_scope.dart';

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
        final locationNodes = flattenLocationTree(origin.locationTree);
        final points = locationNodes.isNotEmpty
            ? _pointsFromLocations(
                locationNodes.map((node) => node.value).toList(growable: false),
                origin.characters,
                depths: locationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
              )
            : _pointsFromLocations(origin.locations, origin.characters);

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
        bottom: 32 + bottomPadding,
        top: 18,
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
        _DiscussSection(count: origin.discussCount),
        const SizedBox(height: 28),
        _OriginCharactersSection(characters: origin.characters),
      ],
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
    final age = _relativeAge(origin.updatedAt);

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
        _PreviewImage(url: origin.mapImage),
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
        _TickPreviewHeader(startTime: origin.startTime),
        const SizedBox(height: 12),
        _GlobalPreviewCard(body: globalBody),
        const SizedBox(height: 18),
        for (int i = 0; i < previewEvents.length; i++) ...[
          _PreviewEventRow(event: previewEvents[i], index: i),
          if (i != previewEvents.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _TickPreviewHeader extends StatelessWidget {
  const _TickPreviewHeader({required this.startTime});

  final String startTime;

  @override
  Widget build(BuildContext context) {
    final time = startTime.trim().isEmpty ? 'Day 1, 18:00' : startTime.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Tick 1 · $time',
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: Color(0xFF151515),
        ),
      ),
    );
  }
}

class _GlobalPreviewCard extends StatelessWidget {
  const _GlobalPreviewCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _TwoColumnText(label: 'Global', body: body, highlighted: true),
    );
  }
}

class _PreviewEventRow extends StatelessWidget {
  const _PreviewEventRow({required this.event, required this.index});

  final OriginEvent event;
  final int index;

  @override
  Widget build(BuildContext context) {
    final timestamp = event.timestamp.trim().isEmpty
        ? _fallbackEventTime(index)
        : event.timestamp.trim();

    return _TwoColumnText(
      label: event.label.trim().isEmpty ? 'Scene' : event.label.trim(),
      timestamp: timestamp,
      body: event.content,
    );
  }
}

class _TwoColumnText extends StatelessWidget {
  const _TwoColumnText({
    required this.label,
    required this.body,
    this.timestamp = '',
    this.highlighted = false,
  });

  final String label;
  final String timestamp;
  final String body;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: Color(0xFF171717),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timestamp.isNotEmpty) ...[
                Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(body, style: highlighted ? _bodyTextStyle : _eventTextStyle),
            ],
          ),
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
          icon: MyFlutterApp.skipNext,
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

class _DiscussSection extends StatelessWidget {
  const _DiscussSection({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: MyFlutterApp.discuss,
          iconColor: const Color(0xFF111111),
          title: 'Discuss ($count)',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Write a post',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9A9A9A),
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
    final avatar = character.avatar.trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.person_outline, color: Color(0xFF8D8D8D)),
    );
    final tags = _splitTags(character.tags);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 86,
            height: 86,
            child: avatar.isEmpty
                ? fallback
                : Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return fallback;
                    },
                  ),
          ),
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
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF171717),
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  tags.join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF5148),
                  ),
                ),
              ],
              const SizedBox(height: 9),
              Text(character.description, style: _bodyTextStyle),
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
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w800,
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

const _eventTextStyle = TextStyle(
  fontSize: 12,
  height: 1.5,
  fontWeight: FontWeight.w500,
  color: Color(0xFF4C4C4C),
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

String _relativeAge(DateTime? dateTime) {
  if (dateTime == null) return '';
  final now = DateTime.now();
  final local = dateTime.toLocal();
  final diff = now.difference(local);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}年前';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}月前';
  if (diff.inDays >= 1) return '${diff.inDays}天前';
  if (diff.inHours >= 1) return '${diff.inHours}小时前';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}分钟前';
  return '刚刚';
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

String _fallbackEventTime(int index) {
  const times = ['Day 1, 17:55', 'Day 1, 18:00', 'Day 1, 18:02'];
  return times[index.clamp(0, times.length - 1)];
}

List<WorldPoint> _pointsFromLocations(
  List<OriginLocation> locations,
  List<OriginCharacter> characters, {
  List<int>? depths,
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
      depth: depths == null || i >= depths.length ? 0 : depths[i],
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
