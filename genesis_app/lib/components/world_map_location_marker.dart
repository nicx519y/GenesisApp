import 'dart:async';
import '../ui/tokens/genesis_typography.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/config/genesis_image_config.dart';
import '../ui/components/genesis_character_avatar.dart';
import 'world_map_avatar_logic.dart';
import 'world_point.dart';

const double worldMapLocationMarkerAvatarSize = 26;
const int worldMapLocationMarkerMaxAvatarCount = 3;
const double worldMapLocationMarkerAvatarOverlap = 6;
const double worldMapLocationMarkerStemHeight = 11;
const double worldMapLocationMarkerDotSize = 7;
const double worldMapLocationMarkerMaxNameWidth = 135;
// 8-22 spec: ink glass is rgba(21,21,23,.6).
const Color worldMapLocationMarkerBackground = Color(0x99151517);
const Color worldMapLocationMarkerEventColor = Color(0xFFF82B3C);

/// 药丸描边的白。设计稿是 `rgba(255,255,255,.2)`。
const Color worldMapLocationMarkerHairline = Color(0x33FFFFFF);

/// 头像环:设计稿的 `box-shadow:0 0 0 1.5px #151517`。实机上 1.5px 显粗,
/// 收到 1px。
const Color worldMapLocationMarkerAvatarRing = Color(0xFF151517);
const double worldMapLocationMarkerAvatarRingWidth = 1;

/// 设计稿 +N 小块:`width:22px;height:22px;border-radius:7px;`
/// `background:rgba(255,255,255,.13)`,字 600 9.5px,色 73% 白 ——
/// 也就是和头像同一个方形圆角规格,不是一颗圆药丸。
const Color worldMapLocationMarkerOverflowFill = Color(0x21FFFFFF);

/// +N 小块的字号与左右内边距。字号按设计稿的字/框比回算(22:9.5 -> 26:11);
/// 字重按实机观感提到 800(设计稿是 600),这个块小又压着 72% 透明度。
const double worldMapLocationMarkerOverflowFontSize = 11;
const double worldMapLocationMarkerOverflowPadding = 5;

// 8-22 spec: soft white #F4F3F6 for occupied pills, 73% white for empty ones.
const TextStyle worldMapLocationMarkerNameStyle = TextStyle(
  inherit: false,
  fontFamily: GenesisTypography.fontFamily,
  fontFamilyFallback: GenesisTypography.fontFamilyFallback,
  color: Color(0xFFF4F3F6),
  fontSize: 12,
  height: 1,
  fontWeight: FontWeight.w600,
);

const TextStyle worldMapLocationMarkerEmptyNameStyle = TextStyle(
  inherit: false,
  fontFamily: GenesisTypography.fontFamily,
  fontFamilyFallback: GenesisTypography.fontFamilyFallback,
  color: Color(0xBAFFFFFF),
  fontSize: 12,
  height: 1,
  fontWeight: FontWeight.w400,
);

@immutable
class WorldMapLocationMarkerMetrics {
  const WorldMapLocationMarkerMetrics({
    required this.pillWidth,
    required this.pillHeight,
  });

  final double pillWidth;
  final double pillHeight;

  double get anchorCenterY =>
      pillHeight +
      worldMapLocationMarkerStemHeight +
      worldMapLocationMarkerDotSize / 2;

  double get totalHeight => anchorCenterY + worldMapLocationMarkerDotSize / 2;
}

WorldMapLocationMarkerMetrics resolveWorldMapLocationMarkerMetrics(
  BuildContext context, {
  required String name,
  required int avatarCount,
}) {
  final visibleAvatarCount = avatarCount
      .clamp(0, worldMapLocationMarkerMaxAvatarCount)
      .toInt();
  final hiddenAvatarCount = math.max(0, avatarCount - visibleAvatarCount);
  final namePainter = TextPainter(
    text: TextSpan(text: name, style: worldMapLocationMarkerNameStyle),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: worldMapLocationMarkerMaxNameWidth);
  final nameWidth = namePainter.width.ceilToDouble().clamp(
    1,
    worldMapLocationMarkerMaxNameWidth,
  );
  final avatarWidth = visibleAvatarCount == 0
      ? 0.0
      : worldMapLocationMarkerAvatarSize +
            (visibleAvatarCount - 1) *
                (worldMapLocationMarkerAvatarSize -
                    worldMapLocationMarkerAvatarOverlap);
  final overflowWidth = hiddenAvatarCount == 0
      ? 0.0
      : _overflowChipWidth(context, hiddenAvatarCount);
  final leadingWidth =
      avatarWidth +
      (avatarWidth > 0 && overflowWidth > 0 ? 5 : 0) +
      overflowWidth;
  final pillWidth =
      6 + leadingWidth + (leadingWidth > 0 ? 8 : 5) + nameWidth + 11;
  return WorldMapLocationMarkerMetrics(
    pillWidth: pillWidth,
    pillHeight: visibleAvatarCount > 0 ? 36 : 25,
  );
}

double _overflowChipWidth(BuildContext context, int count) {
  final painter = TextPainter(
    text: TextSpan(
      // 必须与 _WorldMapLocationOverflowChip 真正渲染的样式一致,
      // 否则量出来的宽度对不上。
      text: '+$count',
      style: const TextStyle(
        inherit: false,
        fontFamily: GenesisTypography.fontFamily,
        fontFamilyFallback: GenesisTypography.fontFamilyFallback,
        color: Colors.white,
        fontSize: worldMapLocationMarkerOverflowFontSize,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  // +N 现在是与头像同尺寸的方块,宽度不再随文字变化;
  // painter 仍保留,便于将来数字变宽时收紧。
  // 默认与头像同宽的方块;但 "+99" 这类更宽的数字必须撑开,否则文字会溢出。
  return math.max(
    worldMapLocationMarkerAvatarSize,
    painter.width.ceilToDouble() + worldMapLocationMarkerOverflowPadding * 2,
  );
}

class WorldMapLocationMarker extends StatelessWidget {
  const WorldMapLocationMarker({
    super.key,
    required this.name,
    required this.avatars,
    required this.eventCount,
    required this.highlighted,
    required this.metrics,
    this.enableAvatarScaleReboundHint = false,
    this.onLabelTap,
    this.onAvatarTap,
  });

  final String name;
  final List<UserAvatar> avatars;
  final int eventCount;
  final bool highlighted;
  final WorldMapLocationMarkerMetrics metrics;
  final bool enableAvatarScaleReboundHint;
  final VoidCallback? onLabelTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final visibleAvatars = avatars
        .take(worldMapLocationMarkerMaxAvatarCount)
        .toList(growable: false);
    final hiddenAvatarCount = math.max(
      0,
      avatars.length - visibleAvatars.length,
    );
    // 设计稿:有人的药丸 border-radius:24px,空位的是 20px。
    final pillRadius = visibleAvatars.isNotEmpty ? 24.0 : 20.0;
    return Semantics(
      label: name,
      button: onLabelTap != null || onAvatarTap != null,
      child: SizedBox(
        key: const ValueKey<String>('world-map-location-marker'),
        width: metrics.pillWidth,
        height: metrics.totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: metrics.pillWidth,
              height: metrics.pillHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onLabelTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(pillRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      key: const ValueKey<String>(
                        'world-map-location-marker-pill',
                      ),
                      decoration: BoxDecoration(
                        color: worldMapLocationMarkerBackground,
                        borderRadius: BorderRadius.circular(pillRadius),
                        // 设计稿三种变体:有人 .2 / 高亮(有新对话).62 / 空位 .18。
                        // 深浅不一是状态区分,不是配错色。
                        border: Border.all(
                          color: highlighted
                              ? Colors.white.withValues(alpha: 0.62)
                              : visibleAvatars.isNotEmpty
                              ? worldMapLocationMarkerHairline
                              : Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (visibleAvatars.isNotEmpty)
                              _WorldMapLocationAvatarStack(
                                avatars: visibleAvatars,
                                enableScaleReboundHint:
                                    enableAvatarScaleReboundHint,
                                onTap: onAvatarTap,
                              ),
                            if (hiddenAvatarCount > 0) ...[
                              const SizedBox(width: 5),
                              _WorldMapLocationOverflowChip(
                                count: hiddenAvatarCount,
                              ),
                            ],
                            SizedBox(
                              width:
                                  visibleAvatars.isNotEmpty ||
                                      hiddenAvatarCount > 0
                                  ? 8
                                  : 5,
                            ),
                            Flexible(
                              child: Text(
                                name,
                                key: const ValueKey<String>(
                                  'world-map-location-marker-name',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: avatars.isEmpty
                                    ? worldMapLocationMarkerEmptyNameStyle
                                    : worldMapLocationMarkerNameStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: metrics.pillHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onLabelTap,
                child: const SizedBox(
                  width: 16,
                  height:
                      worldMapLocationMarkerStemHeight +
                      worldMapLocationMarkerDotSize,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      SizedBox(
                        width: 1.5,
                        height: worldMapLocationMarkerStemHeight,
                        child: ColoredBox(color: Color(0x66FFFFFF)),
                      ),
                      Positioned(
                        top: worldMapLocationMarkerStemHeight,
                        child: DecoratedBox(
                          key: ValueKey<String>('world-map-location-dot'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xD9FFFFFF),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x59000000),
                                blurRadius: 0,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: SizedBox.square(
                            dimension: worldMapLocationMarkerDotSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (eventCount > 0)
              Positioned(
                right: -3,
                top: -4,
                child: _WorldMapLocationEventBadge(count: eventCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorldMapLocationAvatarStack extends StatelessWidget {
  const _WorldMapLocationAvatarStack({
    required this.avatars,
    required this.enableScaleReboundHint,
    required this.onTap,
  });

  final List<UserAvatar> avatars;
  final bool enableScaleReboundHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width =
        worldMapLocationMarkerAvatarSize +
        (avatars.length - 1) *
            (worldMapLocationMarkerAvatarSize -
                worldMapLocationMarkerAvatarOverlap);
    return SizedBox(
      key: const ValueKey<String>('world-map-location-marker-avatars'),
      width: width,
      height: worldMapLocationMarkerAvatarSize,
      child: Stack(
        children: [
          for (final (index, avatar) in avatars.indexed)
            Positioned(
              left:
                  index *
                  (worldMapLocationMarkerAvatarSize -
                      worldMapLocationMarkerAvatarOverlap),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: _WorldMapLocationAvatarRebound(
                  enabled: enableScaleReboundHint,
                  child: GenesisCharacterAvatar(
                    key: ValueKey<String>(
                      'world-map-location-marker-avatar-'
                      '${worldMapAvatarStableId(avatar)}',
                    ),
                    url: avatar.avatarUrl,
                    name: (avatar.name ?? avatar.initials).trim(),
                    size: worldMapLocationMarkerAvatarSize,
                    borderRadius: 7,
                    showStar: false,
                    showFallbackWhileLoading: false,
                    showFallbackWhenUnavailable: true,
                    maxDevicePixelRatio:
                        GenesisImageConfig.tilemapAvatarMaxDevicePixelRatio,
                    border: Border.all(
                      color: avatar.isPlayerControlledRole
                          ? worldMapLocationMarkerEventColor
                          // 非玩家头像的环:纯白不透明。
                          : worldMapLocationMarkerAvatarRing,
                      width: avatar.isPlayerControlledRole
                          ? 2
                          : worldMapLocationMarkerAvatarRingWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorldMapLocationOverflowChip extends StatelessWidget {
  const _WorldMapLocationOverflowChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('world-map-location-marker-overflow'),
      // 与头像同规格的方形圆角,不是圆药丸。圆角比头像的 7 再放大一档,
      // 且不描边 —— 它是个计数块,不需要和头像一样被环出来。
      // 用 minWidth 而不是固定 width:多位数(+99)时能撑开,不会溢出。
      constraints: const BoxConstraints(
        minWidth: worldMapLocationMarkerAvatarSize,
      ),
      height: worldMapLocationMarkerAvatarSize,
      padding: const EdgeInsets.symmetric(
        horizontal: worldMapLocationMarkerOverflowPadding,
      ),
      decoration: BoxDecoration(
        color: worldMapLocationMarkerOverflowFill,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          inherit: false,
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          color: Colors.white.withValues(alpha: 0.72),
          // 设计稿是 22px 方块配 9.5px 字(字/框比 0.43)。头像放大到 26 之后
          // 方块跟着变大而字号没动,比例掉到 0.365,字在框里就显得又小又轻。
          // 按原比例回算 26 x 0.43 ≈ 11。
          // 字重按实机观感提到 800(设计稿是 600)—— 这个数字块尺寸小、又压着
          // 72% 透明度,600 在设备上读起来偏轻。
          fontSize: worldMapLocationMarkerOverflowFontSize,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WorldMapLocationEventBadge extends StatelessWidget {
  const _WorldMapLocationEventBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      key: const ValueKey<String>('world-map-location-event-count'),
      // 圆角长方形,不是圆形:半径 6 < 高度的一半,并去掉描边 ——
      // 设计稿 9a 的 #F82B3C 徽标本来就没有描边。
      constraints: const BoxConstraints(minWidth: 20),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: worldMapLocationMarkerEventColor,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          inherit: false,
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          color: Colors.white,
          fontSize: 9.5,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WorldMapLocationAvatarRebound extends StatefulWidget {
  const _WorldMapLocationAvatarRebound({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_WorldMapLocationAvatarRebound> createState() =>
      _WorldMapLocationAvatarReboundState();
}

class _WorldMapLocationAvatarReboundState
    extends State<_WorldMapLocationAvatarRebound>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleNext());
    }
  }

  @override
  void didUpdateWidget(covariant _WorldMapLocationAvatarRebound oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _scheduleNext();
    } else {
      _timer?.cancel();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleNext() {
    if (!mounted || !widget.enabled) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !widget.enabled) return;
      _controller.forward(from: 0).whenComplete(_scheduleNext);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        final rebound =
            math.sin(math.pi * 2.2 * progress) * math.pow(1 - progress, 1.4);
        return Transform.scale(scale: 1 + 0.08 * rebound, child: child);
      },
    );
  }
}
