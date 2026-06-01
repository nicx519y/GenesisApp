import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
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
  late final OriginDiscussListController _discussController;
  Future<OriginDetail>? _future;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _discussController = OriginDiscussListController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _loadOriginDetail();
  }

  @override
  void didUpdateWidget(covariant OriginWorldPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid) {
      _future = _loadOriginDetail();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _future = _loadOriginDetail();
    });
  }

  @override
  void dispose() {
    _discussController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<OriginDetail> _loadOriginDetail() {
    final api = AppServicesScope.read(context).api;
    final future = api.getOrigin(widget.oid);
    future.then((origin) {
      if (!mounted) return;
      _configureDiscuss(origin.oid);
      unawaited(_discussController.loadInitialIfNeeded());
    }, onError: (_) {});
    return future;
  }

  void _configureDiscuss(String oid) {
    _discussController.configure(
      oid: oid,
      loader: ({required String oid, required int pn, required int rn}) async {
        return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
      },
    );
  }

  void _showMapTab() {
    if (_tabController.index == 0) return;
    _tabController.animateTo(
      0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showLaunchRoleSheet(OriginDetail origin) async {
    if (_launching) return;
    final selection = await showOriginRoleLaunchSheet(
      context: context,
      characters: origin.characters,
      resolveAvatarUrl: _resolveAssetUrl,
      onFillFromProfile: _customRoleFromProfile,
    );
    if (!mounted || selection == null) return;
    await _launchOrigin(origin, selection);
  }

  Future<void> _launchOrigin(
    OriginDetail origin,
    OriginRoleLaunchSelection roleSelection,
  ) async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final result = await AppServicesScope.of(context).api.v1.origin.launch(
        oid: origin.oid,
        presetCharacterId: roleSelection.presetCharacterId,
        customRole: roleSelection.customRole?.toPayload(),
      );
      if (!mounted) return;
      final wid = '${result['world_id'] ?? result['wid'] ?? ''}'.trim();
      if (wid.isEmpty) {
        showGenesisToast(context, 'Launch failed');
        return;
      }
      Navigator.of(
        context,
      ).pushNamed(RouteNames.world, arguments: {'wid': wid});
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Launch failed');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<OriginCustomRoleDraft?> _customRoleFromProfile() async {
    final services = AppServicesScope.read(context);
    final userInfo = await services.sessionStore.readUserInfo();
    final profile = services.identityAuth.currentProfile();
    if ((userInfo == null || userInfo.isEmpty) && profile == null) {
      if (mounted) {
        showGenesisToast(context, 'No saved profile found');
      }
      return null;
    }
    final cachedUser = userInfo ?? const <String, dynamic>{};
    final cachedAvatar = _mapString(cachedUser, const [
      'avatar',
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]);
    final profileAvatar = profile?.photoUrl.trim() ?? '';
    final cachedName = _mapString(cachedUser, const [
      'name',
      'nickname',
      'user_name',
      'displayName',
      'display_name',
    ]);
    final profileName = (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : (profile?.email.trim() ?? '');
    final resolvedAvatar = _resolveAssetUrl(
      cachedAvatar.isNotEmpty ? cachedAvatar : profileAvatar,
    );
    debugPrint(
      '[OriginRoleLaunch] Fill from profile avatar: '
      'cached="$cachedAvatar", '
      'identity="$profileAvatar", '
      'resolved="$resolvedAvatar"',
    );

    return OriginCustomRoleDraft(
      avatarUrl: resolvedAvatar,
      name: cachedName.isNotEmpty ? cachedName : profileName,
      identity: _mapString(cachedUser, const ['identity']),
      bio: _mapString(cachedUser, const ['bio', 'description']),
    );
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
                      _future = _loadOriginDetail();
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
        final processedLocationTree = origin.processedLocationTree;
        final rootLocationNodes = processedLocationTree.mapRoots;
        final renderLocationNodes = processedLocationTree.renderRoots;
        final allLocationNodes = processedLocationTree.flattened;
        final avatarsByLocation = _originAvatarsByLocation(
          origin.characters,
          origin.locations,
        );
        final locationNodes = _originMapLocationNodes(
          rootLocationNodes,
          avatarsByLocation,
          processedLocationTree,
        );
        final points = renderLocationNodes.isNotEmpty
            ? _pointsFromLocations(
                renderLocationNodes
                    .map((node) => node.value)
                    .toList(growable: false),
                avatarsByLocation,
                depths: renderLocationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
                isLeafLocations: renderLocationNodes
                    .map((node) => node.children.isEmpty)
                    .toList(growable: false),
                usersByIndex: renderLocationNodes
                    .map(
                      (node) =>
                          processedLocationTree.aggregateValues<UserAvatar>(
                            node.id,
                            avatarsByLocation,
                            idOf: _userAvatarStableId,
                          ),
                    )
                    .toList(growable: false),
              )
            : _pointsFromLocations(
                _rootOriginLocations(origin.locations),
                avatarsByLocation,
              );
        final listPoints = allLocationNodes.isNotEmpty
            ? _pointsFromLocations(
                allLocationNodes
                    .map((node) => node.value)
                    .toList(growable: false),
                avatarsByLocation,
                depths: allLocationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
                isLeafLocations: allLocationNodes
                    .map((node) => node.children.isEmpty)
                    .toList(growable: false),
                usersByIndex: allLocationNodes
                    .map(
                      (node) =>
                          processedLocationTree.aggregateValues<UserAvatar>(
                            node.id,
                            avatarsByLocation,
                            idOf: _userAvatarStableId,
                          ),
                    )
                    .toList(growable: false),
              )
            : origin.locations.isNotEmpty
            ? _pointsFromLocations(origin.locations, avatarsByLocation)
            : points;

        return WorldDetailsPageScaffold(
          panelTopGap: 50,
          panelCollapsedHeightOffset: 45,
          map: WorldMapStage(
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
          slivers: [
            _WorldDetailsContent(
              origin: origin,
              discussController: _discussController,
            ),
          ],
          bottomBar: _OriginBottomLaunchBar(
            origin: origin,
            launching: _launching,
            onLaunch: () => _showLaunchRoleSheet(origin),
          ),
        );
      },
    );
  }
}

class _WorldDetailsContent extends StatelessWidget {
  const _WorldDetailsContent({
    required this.origin,
    required this.discussController,
  });

  final OriginDetail origin;
  final OriginDiscussListController discussController;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        _OriginHeader(origin: origin),
        const SizedBox(height: 22),
        _WorldViewSection(origin: origin),
        const SizedBox(height: 26),
        _LaunchPreviewSection(origin: origin),
        const SizedBox(height: 28),
        const _CopyWorldProgressSection(),
        const SizedBox(height: 18),
        _DiscussSection(origin: origin, controller: discussController),
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
        minimum: const EdgeInsets.fromLTRB(13, 0, 13, 0),
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
              color: Color(0xFF4B6192),
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

class _DiscussSection extends StatelessWidget {
  const _DiscussSection({required this.origin, required this.controller});

  final OriginDetail origin;
  final OriginDiscussListController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pushNamed(
            RouteNames.discuss,
            arguments: {'oid': origin.oid, 'originId': origin.id},
          ),
          child: Row(
            children: [
              _SectionTitle(
                icon: MyFlutterApp.discuss,
                iconColor: const Color(0xFF111111),
                title: 'Discuss (${origin.discussCount})',
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF8B8B8B),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OriginDiscussList(
          controller: controller,
          count: origin.discussCount,
          showHeader: false,
          onViewMoreTap: () async {
            await Navigator.of(context).pushNamed(
              RouteNames.discuss,
              arguments: {'oid': origin.oid, 'originId': origin.id},
            );
          },
        ),
        const SizedBox(height: 14),
        DiscussPostInput(
          bizId: origin.oid,
          onSubmitted: () => unawaited(controller.refreshFirstPage()),
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
  fontWeight: FontWeight.w400,
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

String _mapString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Future<void> _copyOid(BuildContext context, String oid) async {
  await Clipboard.setData(ClipboardData(text: oid));
  if (!context.mounted) return;
  showGenesisToast(context, 'OID copied');
}

List<OriginEvent> _previewEvents(OriginDetail origin) {
  if (origin.events.isNotEmpty) {
    return origin.events.take(3).toList(growable: false);
  }

  final renderLocations = origin.processedLocationTree.flattenedRenderNodes
      .map((node) => node.value)
      .toList(growable: false);
  if (renderLocations.isNotEmpty) {
    return renderLocations
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
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<OriginLocation> processedLocationTree,
) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot: node.id == processedLocationTree.root?.id,
          point: _pointsFromLocations(
            [node.value],
            avatarsByLocation,
            depths: [node.depth],
            isLeafLocations: [node.children.isEmpty],
            usersByIndex: [
              processedLocationTree.aggregateValues<UserAvatar>(
                node.id,
                avatarsByLocation,
                idOf: _userAvatarStableId,
              ),
            ],
          ).first,
          mapImageUrl: _resolveAssetUrl(node.value.mapUrl),
          children: _originMapLocationNodes(
            node.children,
            avatarsByLocation,
            processedLocationTree,
          ),
        );
      })
      .toList(growable: false);
}

List<WorldPoint> _pointsFromLocations(
  List<OriginLocation> locations,
  Map<String, List<UserAvatar>> avatarsByLocation, {
  List<int>? depths,
  List<bool>? isLeafLocations,
  List<List<UserAvatar>>? usersByIndex,
}) {
  if (locations.isEmpty) return const <WorldPoint>[];

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
      users: usersByIndex == null || i >= usersByIndex.length
          ? (avatarsByLocation[locationId] ??
                avatarsByLocation['${l.id}'] ??
                const <UserAvatar>[])
          : usersByIndex[i],
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

Map<String, List<UserAvatar>> _originAvatarsByLocation(
  List<OriginCharacter> characters,
  List<OriginLocation> locations,
) {
  final map = <String, List<UserAvatar>>{};
  final locationIdsByStableId = <int, List<String>>{};
  for (final location in locations) {
    locationIdsByStableId
        .putIfAbsent(location.id, () => <String>[])
        .add(location.locationId.trim());
  }

  for (final c in characters) {
    final locationId = c.currentLocationId > 0
        ? c.currentLocationId
        : c.initialLocationId;
    if (locationId <= 0) continue;
    final avatar = UserAvatar(
      _initials(c.name),
      id: '${c.id}',
      name: c.name,
      avatarUrl: _resolveAssetUrl(c.avatar),
      showStar: true,
    );
    final keys = <String>{'$locationId', ...?locationIdsByStableId[locationId]}
      ..remove('');
    for (final key in keys) {
      (map[key] ??= <UserAvatar>[]).add(avatar);
    }
  }
  return map;
}

String _userAvatarStableId(UserAvatar avatar) {
  final id = avatar.id.trim();
  if (id.isNotEmpty) return id;
  return '${avatar.name ?? ''}|${avatar.avatarUrl}|${avatar.initials}';
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
