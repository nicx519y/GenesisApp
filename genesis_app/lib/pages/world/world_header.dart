// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/models/world.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_control_icons.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_palette.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import 'world_constants.dart';
import 'world_models.dart';
import 'world_value_helpers.dart';

class WorldMapBackButton extends StatelessWidget {
  const WorldMapBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GenesisBackButton(
      key: const ValueKey<String>('world-map-back-button'),
      onPressed: onPressed,
      dimension: worldMapHeaderButtonSize,
      backgroundColor: GenesisPalette.redesignInkGlass50,
    );
  }
}

class WorldMapIdentityPill extends StatelessWidget {
  const WorldMapIdentityPill({
    required this.title,
    required this.statusText,
    required this.maxWidth,
  });

  final String title;
  final String statusText;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                key: const ValueKey<String>('world-map-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GenesisTypography.immersiveTitle.copyWith(
                  color: context.genesisColors.immersiveForeground,
                  shadows: [
                    Shadow(
                      color: context.genesisColors.scrim.withValues(alpha: 0.6),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            if (title.isNotEmpty && statusText.isNotEmpty)
              const SizedBox(height: 5),
            if (statusText.isNotEmpty)
              Text(
                statusText,
                key: const ValueKey<String>('world-map-status'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.genesisColors.immersiveForeground.withValues(
                    alpha: 0.73,
                  ),
                  fontSize: 9.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: context.genesisColors.scrim.withValues(alpha: 0.7),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String worldMapStatusLabel({
  required String relationStatus,
  required String timeText,
}) {
  if (!shouldConnectWorldChatroom(relationStatus)) return 'Not started';
  final resolvedTimeText = timeText.trim();
  return resolvedTimeText.isEmpty ? 'Started' : resolvedTimeText;
}

String worldTimeLabel({
  required int tickIndex,
  int subTickNo = 0,
  required String worldTime,
}) {
  final parts = <String>[];
  if (tickIndex >= 0) {
    parts.add('Tick $tickIndex${subTickNo > 0 ? '-$subTickNo' : ''}');
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
    required this.currentUid,
    required this.worldActionRunning,
    required this.onWorldAction,
    required this.onPullUp,
  });

  final WorldDetail world;
  final String currentUid;
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
            child: SizedBox(
              key: const ValueKey<String>('world-panel-info-row'),
              height: worldInfoHeaderHeight,
              child: WorldInfoHeader(
                world: world,
                currentUid: currentUid,
                worldActionRunning: worldActionRunning,
                onWorldAction: onWorldAction,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: worldMainTabsHeight)),
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
    required this.currentUid,
    required this.worldActionRunning,
    required this.onWorldAction,
  });

  final WorldDetail world;
  final String currentUid;
  final bool worldActionRunning;
  final Future<void> Function(WorldHeaderActionKind action) onWorldAction;

  @override
  Widget build(BuildContext context) {
    final action = worldHeaderActionFor(world.relationStatus);
    final canTapRunningProgress =
        action.kind == WorldHeaderActionKind.progress &&
        worldActionRunning &&
        action.isClickable &&
        !world.deleted;
    final actionEnabled =
        !world.deleted && !worldActionRunning && action.isClickable;
    final currentCharacter = _currentPlayerCharacter(world, currentUid);
    final characterName = worldMapString(
      currentCharacter ?? const <String, dynamic>{},
      const ['name'],
      fallback: 'Your role',
    );
    final avatarUrl = worldMapString(
      currentCharacter ?? const <String, dynamic>{},
      const ['avatar'],
    );
    // connect_cnt 就是这条世界线累计的消息数,world 详情接口本来就返回它
    // (world_api.dart:51 的 stats),Home 的世界卡片用的是同一个字段。
    final messageCount = world.connectCount;
    final tickLabel = world.tickCount < 0
        ? ''
        : 'Tick ${world.tickCount}'
              '${world.subTickNo > 0 ? '-${world.subTickNo}' : ''}'
              '${messageCount > 0 ? ' · $messageCount Messages' : ''}';
    final actionLabel = action.kind == WorldHeaderActionKind.progress
        ? 'Tick now'
        : action.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: worldInfoHeaderHeight - 1,
          child: Padding(
            // 设计稿 `padding:0 20px 13px` 是相对浮窗边缘量的;这里外层容器
            // 已经带了 12px,内层只补 8 —— 8+12=20 才是头像盒的左边,2px 红环
            // 再外扩到 18,与下方 Detail 药丸的左边缘对齐。
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 13),
            child: Row(
              children: [
                Container(
                  key: const ValueKey<String>('world-playing-avatar'),
                  // 设计稿原文:头像 `width:40px;height:40px;border-radius:12px`
                  // 外加 `box-shadow:0 0 0 2px #F82B3C` 的 2px 红环 = 外框 44。
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: context.genesisColors.danger,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: GenesisAvatar(
                    name: characterName,
                    url: avatarUrl,
                    size: 40,
                    borderRadius: 12,
                    alignment: Alignment.topCenter,
                    showFallbackWhileLoading: false,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Playing $characterName',
                        key: const ValueKey<String>('world-playing-label'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.genesisColors.foregroundStrong,
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tickLabel.isNotEmpty) ...[
                        // Playing 行与 Tick 行之间留 6 显得挤,拉到 8。
                        const SizedBox(height: 8),
                        Text(
                          tickLabel,
                          key: const ValueKey<String>('world-playing-tick'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.genesisColors.textMuted,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canTapRunningProgress
                      ? () => onWorldAction(action.kind)
                      : null,
                  child: AbsorbPointer(
                    absorbing: canTapRunningProgress,
                    child: GenesisPrimaryButton(
                      key: const ValueKey<String>('world-action-button'),
                      label: actionLabel,
                      onPressed: actionEnabled
                          ? () => onWorldAction(action.kind)
                          : null,
                      height: worldInfoHeaderContentHeight,
                      width: 92,
                      borderRadius: BorderRadius.circular(11),
                      leadingIcon: action.kind == WorldHeaderActionKind.progress
                          ? SvgPicture.asset(
                              tickStatIconAsset,
                              // 对齐大写字高:12px Inter 的 capHeight = 0.7275em
                              // ≈ 8.7px。图标做 11px 会比字母高出一整圈,三角形的
                              // 尖端把视线往上带,几何中心对齐了也仍然显得偏高。
                              width: 9,
                              height: 9,
                              colorFilter: ColorFilter.mode(
                                context.genesisColors.onDanger,
                                BlendMode.srcIn,
                              ),
                            )
                          : null,
                      iconGap: 6,
                      backgroundColor: context.genesisColors.danger,
                      disabledBackgroundColor: context.genesisColors.danger
                          .withValues(alpha: 0.62),
                      foregroundColor: context.genesisColors.onDanger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      isLoading: worldActionRunning,
                      loadingSize: 18,
                      loadingStrokeWidth: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 原先这里有一条带 6px 水平内边距的 Divider,左右都不顶满 —— 它就是与
        // tab 容器顶边那条通栏线重叠的"原来那条"。通栏线现在由 WorldBottomTags
        // 画在自己的顶边上(容器无圆角,天然贯通),这里不再重复画。
      ],
    );
  }
}

Map<String, dynamic>? _currentPlayerCharacter(
  WorldDetail world,
  String currentUid,
) {
  final resolvedUid = currentUid.trim();
  if (resolvedUid.isEmpty) return null;
  for (final character in world.characters) {
    if (worldMapString(character, const ['player_uid']).trim() == resolvedUid) {
      return character;
    }
  }
  return null;
}

double worldCollapsedPanelHeightFor(BuildContext context) {
  final bottomSafeArea = worldBottomSafeAreaOf(context);
  return worldCollapsedPanelBaseHeight + bottomSafeArea;
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
  return GenesisSafeAreaInsets.bottom(context, minimum: 24);
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
