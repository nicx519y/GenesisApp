// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../../components/origin/stat_item.dart';
import '../../components/world_details_shell.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/models/world.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/stat_count_formatter.dart';
import 'world_constants.dart';
import 'world_models.dart';

class WorldMapBackButton extends StatelessWidget {
  const WorldMapBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: worldMapTabsHeight,
      height: worldMapTabsHeight,
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        iconSize: 18,
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class WorldMapIdentityPill extends StatelessWidget {
  const WorldMapIdentityPill({
    required this.title,
    required this.timeText,
    required this.maxWidth,
  });

  final String title;
  final String timeText;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: worldTimePillMinWidth,
        maxWidth: maxWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            worldTimePillHorizontalPadding,
            title.isEmpty ? 0 : 7,
            worldTimePillHorizontalPadding,
            7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4B6192),
                    fontSize: 16,
                    height: 1.1,
                    leadingDistribution: TextLeadingDistribution.even,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (title.isNotEmpty && timeText.isNotEmpty)
                const SizedBox(height: 3),
              if (timeText.isNotEmpty) _WorldMapTimeLabel(text: timeText),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldMapTimeLabel extends StatelessWidget {
  const _WorldMapTimeLabel({required this.text});

  static const _textStyle = TextStyle(
    color: Color(0xFF111111),
    fontSize: 12,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
  );
  static const _strutStyle = StrutStyle(
    fontSize: 12,
    height: 1,
    forceStrutHeight: true,
  );
  static const _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = _splitWorldMapTimeLabel(text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (parts.tick.isNotEmpty) ...[
          Text(
            parts.tick,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _textStyle,
            strutStyle: _strutStyle,
            textHeightBehavior: _textHeightBehavior,
          ),
          if (parts.time.isNotEmpty)
            const Text(' · ', style: _textStyle, strutStyle: _strutStyle),
        ],
        if (parts.time.isNotEmpty) ...[
          const Icon(Icons.schedule, size: 12, color: Color(0xFF111111)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              parts.time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _textStyle,
              strutStyle: _strutStyle,
              textHeightBehavior: _textHeightBehavior,
            ),
          ),
        ],
      ],
    );
  }
}

({String tick, String time}) _splitWorldMapTimeLabel(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return (tick: '', time: '');
  final separatorIndex = trimmed.indexOf(' · ');
  if (separatorIndex <= 0) {
    return trimmed.startsWith('Tick ')
        ? (tick: trimmed, time: '')
        : (tick: '', time: trimmed);
  }
  final tick = trimmed.substring(0, separatorIndex).trim();
  final time = trimmed.substring(separatorIndex + 3).trim();
  if (!tick.startsWith('Tick ')) return (tick: '', time: trimmed);
  return (tick: tick, time: time);
}

String worldTimeLabel({required int tickIndex, required String worldTime}) {
  final parts = <String>[];
  if (tickIndex >= 0) {
    parts.add('Tick $tickIndex');
  }
  final resolvedWorldTime = worldTime.trim();
  if (resolvedWorldTime.isNotEmpty) {
    parts.add(resolvedWorldTime);
  }
  return parts.join(' · ');
}

class WorldFeedContent extends StatelessWidget {
  const WorldFeedContent({
    required this.world,
    required this.worldActionRunning,
    required this.onWorldAction,
    required this.onPullUp,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final Future<void> Function(WorldHeaderActionKind action) onWorldAction;
  final VoidCallback onPullUp;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: WorldSectionSheetPullGesture(
            onPullUp: onPullUp,
            child: Column(
              children: [
                WorldInfoHeader(
                  world: world,
                  worldActionRunning: worldActionRunning,
                  onWorldAction: onWorldAction,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WorldSectionSheetPullGesture extends StatefulWidget {
  const WorldSectionSheetPullGesture({
    required this.child,
    required this.onPullUp,
  });

  final Widget child;
  final VoidCallback onPullUp;

  @override
  State<WorldSectionSheetPullGesture> createState() =>
      WorldSectionSheetPullGestureState();
}

class WorldSectionSheetPullGestureState
    extends State<WorldSectionSheetPullGesture> {
  static const double _triggerDistance = 56;
  static const double _triggerVelocity = 520;

  var _dragDy = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) {
        _dragDy = 0;
      },
      onVerticalDragUpdate: (details) {
        _dragDy += details.delta.dy;
      },
      onVerticalDragEnd: (details) {
        final upwardVelocity = -(details.primaryVelocity ?? 0);
        if (_dragDy <= -_triggerDistance ||
            upwardVelocity >= _triggerVelocity) {
          widget.onPullUp();
        }
        _dragDy = 0;
      },
      onVerticalDragCancel: () {
        _dragDy = 0;
      },
      child: widget.child,
    );
  }
}

class WorldKeepAlivePage extends StatefulWidget {
  const WorldKeepAlivePage({required this.child});

  final Widget child;

  @override
  State<WorldKeepAlivePage> createState() => WorldKeepAlivePageState();
}

class WorldKeepAlivePageState extends State<WorldKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class WorldInfoHeader extends StatelessWidget {
  const WorldInfoHeader({
    required this.world,
    required this.worldActionRunning,
    required this.onWorldAction,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final Future<void> Function(WorldHeaderActionKind action) onWorldAction;

  @override
  Widget build(BuildContext context) {
    final action = worldHeaderActionFor(world.relationStatus);
    final actionEnabled =
        !world.deleted && !worldActionRunning && action.isClickable;
    final counters = <Map<String, dynamic>>[
      {'icon': 'tick', 'value': world.tickCount},
      {'icon': 'connect', 'value': world.connectCount},
      {'icon': 'character', 'value': world.characterCount},
      {'icon': 'player', 'value': world.playerCount},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: worldInfoHeaderHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: worldInfoHeaderContentHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final data in counters)
                          StatItem(
                            icon: worldCounterIcon(
                              data['icon'] as String? ?? '',
                            ),
                            iconAsset: worldCounterIconAsset(
                              data['icon'] as String? ?? '',
                            ),
                            preserveIconAssetColor:
                                worldCounterIconAssetPreservesColor(
                                  data['icon'] as String? ?? '',
                                ),
                            iconSize: 14,
                            iconColor: Colors.black,
                            text: formatStatCount(
                              data['value'] is num ? data['value'] as num : 0,
                            ),
                            gap: 4,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              height: 1,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  GenesisPrimaryButton(
                    label: action.label,
                    onPressed: actionEnabled
                        ? () => onWorldAction(action.kind)
                        : null,
                    height: 35,
                    width: 140,
                    backgroundColor: const Color(0xFF2F9663),
                    disabledBackgroundColor: const Color(
                      0xFF2F9663,
                    ).withValues(alpha: 0.62),
                    foregroundColor: Colors.white,
                    fontSize: 16,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    isLoading: worldActionRunning,
                    loadingSize: 18,
                    loadingStrokeWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

double worldCollapsedPanelHeightFor(BuildContext context) {
  final bottomSafeArea = worldBottomSafeAreaOf(context);
  final collapsedPanelHeight =
      WorldDetailsPageScaffold.inlineContentTopPadding +
      worldStatsTopSpacerHeight +
      worldInfoHeaderHeight +
      bottomSafeArea;
  return collapsedPanelHeight;
}

String worldOwnerDisplayName(WorldDetail world) {
  if (world.ownerDeleted) return deletedEntityDisplayText;
  final ownerName = world.ownerName.trim();
  if (ownerName.isNotEmpty) return ownerName;
  final originator = world.origin.originator.trim();
  if (originator.isNotEmpty) return originator;
  return formatUidForDisplay(world.ownerUid);
}

double worldBottomSafeAreaOf(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final paddingBottom = mediaQuery.padding.bottom;
  final viewPaddingBottom = mediaQuery.viewPadding.bottom;
  return paddingBottom > viewPaddingBottom ? paddingBottom : viewPaddingBottom;
}

IconData? worldCounterIcon(String key) {
  switch (key) {
    case 'tick':
      return null;
    case 'connect':
      return null;
    case 'character':
      return null;
    case 'player':
      return null;
    default:
      return Icons.circle_outlined;
  }
}

String? worldCounterIconAsset(String key) {
  return switch (key) {
    'tick' => tickStatIconAsset,
    'connect' => connectStatIconAsset,
    'character' => characterStatIconAsset,
    'player' => userStatIconAsset,
    _ => null,
  };
}

bool worldCounterIconAssetPreservesColor(String key) {
  return key == 'character';
}
