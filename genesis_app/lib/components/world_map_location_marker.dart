import 'dart:async';
import '../ui/tokens/genesis_typography.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/config/genesis_image_config.dart';
import '../ui/components/genesis_character_avatar.dart';
import 'world_map_avatar_logic.dart';
import 'world_point.dart';

const double worldMapLocationMarkerAvatarSize = 22;
const int worldMapLocationMarkerMaxAvatarCount = 3;
const double worldMapLocationMarkerAvatarOverlap = 6;
const double worldMapLocationMarkerStemHeight = 11;
const double worldMapLocationMarkerDotSize = 7;
const double worldMapLocationMarkerMaxNameWidth = 135;
// 8-22 spec: ink glass is rgba(21,21,23,.6).
const Color worldMapLocationMarkerBackground = Color(0x99151517);
const Color worldMapLocationMarkerEventColor = Color(0xFFF82B3C);

const TextStyle worldMapLocationMarkerNameStyle = TextStyle(
  inherit: false,
  fontFamily: GenesisTypography.fontFamily,
  fontFamilyFallback: GenesisTypography.fontFamilyFallback,
  color: Colors.white,
  fontSize: 11,
  height: 1,
  fontWeight: FontWeight.w600,
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
    pillHeight: visibleAvatarCount > 0 ? 32 : 24,
  );
}

double _overflowChipWidth(BuildContext context, int count) {
  final painter = TextPainter(
    text: TextSpan(
      text: '+$count',
      style: const TextStyle(
        inherit: false,
        fontFamily: GenesisTypography.fontFamily,
        fontFamilyFallback: GenesisTypography.fontFamilyFallback,
        color: Colors.white,
        fontSize: 9.5,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width.ceilToDouble() + 12;
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
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      key: const ValueKey<String>(
                        'world-map-location-marker-pill',
                      ),
                      decoration: BoxDecoration(
                        color: worldMapLocationMarkerBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: highlighted ? 0.62 : 0.20,
                          ),
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
                                style: worldMapLocationMarkerNameStyle,
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
                          : const Color(0xFF151517),
                      width: avatar.isPlayerControlledRole ? 2 : 1.5,
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
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: TextStyle(
          inherit: false,
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 9.5,
          height: 1,
          fontWeight: FontWeight.w600,
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
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: worldMapLocationMarkerEventColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF151517), width: 1.5),
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
          fontWeight: FontWeight.w700,
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
