part of 'tilemap_renderer_library.dart';

class _TilemapLocationLabelData {
  const _TilemapLocationLabelData({
    required this.tile,
    required this.name,
    required this.avatars,
    required this.showRecentChat,
    required this.showEvent,
  });

  final TilemapCell tile;
  final String name;
  final List<UserAvatar> avatars;
  final bool showRecentChat;
  final bool showEvent;
}

const double _tilemapLocationLabelMaxWidth = 141;
const double _tilemapLocationLabelHorizontalPadding = 3;
const double _tilemapLocationLabelVerticalPadding = 4;
const double _tilemapLocationActivityIconGap = 3;
const double _tilemapLocationActivityIconExtraWidth =
    _tilemapLocationActivityIconGap + kRecentChatMapBadgeSize;
const TextStyle _tilemapLocationLabelTextStyle = TextStyle(
  inherit: false,
  color: Colors.white,
  fontSize: 12,
  height: 1.2,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.w600,
);
const TextStyle _tilemapEmptyLocationLabelTextStyle = TextStyle(
  inherit: false,
  color: Color(0xBAFFFFFF),
  fontSize: 12,
  height: 1.2,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.w600,
);

class _TilemapLocationLabelLayout {
  const _TilemapLocationLabelLayout({
    required this.bubbleWidth,
    required this.height,
    required this.lineCount,
  });

  final double bubbleWidth;
  final double height;
  final int lineCount;
}

_TilemapLocationLabelLayout _tilemapLocationLabelLayout(
  BuildContext context,
  String name, {
  required bool occupied,
}) {
  final style = occupied
      ? _tilemapLocationLabelTextStyle
      : _tilemapEmptyLocationLabelTextStyle;
  final painter =
      TextPainter(
        text: TextSpan(text: name, style: style),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth:
            _tilemapLocationLabelMaxWidth -
            _tilemapLocationLabelHorizontalPadding * 2,
      );
  final lines = painter.computeLineMetrics();
  final longestLine = lines.fold<double>(
    0,
    (width, line) => math.max(width, line.width),
  );
  final lineCount = math.max(1, lines.length);
  final paddedLongestLine =
      longestLine.ceilToDouble() + _tilemapLocationLabelHorizontalPadding * 2;
  return _TilemapLocationLabelLayout(
    bubbleWidth: paddedLongestLine.clamp(
      _tilemapLocationLabelHorizontalPadding * 2,
      _tilemapLocationLabelMaxWidth,
    ),
    height: painter.height + _tilemapLocationLabelVerticalPadding * 2,
    lineCount: lineCount,
  );
}

class _TilemapInfiniteGridPainter extends CustomPainter {
  const _TilemapInfiniteGridPainter({
    required this.projection,
    required this.scale,
    required this.translation,
    required this.lineColor,
  });

  final TilemapProjection projection;
  final double scale;
  final Offset translation;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!scale.isFinite || scale <= 0 || size.isEmpty) return;

    final spacing = projection.tileExtent * scale / 2;
    if (!spacing.isFinite || spacing <= 0) return;

    final positiveSlopeBase =
        translation.dy - translation.dx / 2 - projection.originX * scale / 2;
    final negativeSlopeBase =
        translation.dy + translation.dx / 2 + projection.originX * scale / 2;
    final path = Path();

    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: -size.width / 2,
      maxIntercept: size.height,
      baseIntercept: positiveSlopeBase,
      spacing: spacing,
      slope: 0.5,
    );
    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: 0,
      maxIntercept: size.height + size.width / 2,
      baseIntercept: negativeSlopeBase,
      spacing: spacing,
      slope: -0.5,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapInfiniteGridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.translation != translation ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.projection.mapWidth != projection.mapWidth ||
        oldDelegate.projection.mapHeight != projection.mapHeight ||
        oldDelegate.projection.tileExtent != projection.tileExtent ||
        oldDelegate.projection.originX != projection.originX;
  }
}

void _appendParallelGridLines({
  required Path path,
  required double width,
  required double minIntercept,
  required double maxIntercept,
  required double baseIntercept,
  required double spacing,
  required double slope,
}) {
  final firstIndex = ((minIntercept - baseIntercept) / spacing).floor() - 1;
  final lastIndex = ((maxIntercept - baseIntercept) / spacing).ceil() + 1;
  for (var index = firstIndex; index <= lastIndex; index += 1) {
    final intercept = baseIntercept + index * spacing;
    path
      ..moveTo(0, intercept)
      ..lineTo(width, slope * width + intercept);
  }
}

class _TilemapLocationBubble extends StatelessWidget {
  const _TilemapLocationBubble({
    super.key,
    required this.name,
    required this.avatars,
    required this.showRecentChat,
    required this.showEvent,
    required this.onLabelTap,
    required this.onAvatarTap,
    required this.anchor,
  });

  final String name;
  final List<UserAvatar> avatars;
  final bool showRecentChat;
  final bool showEvent;
  final VoidCallback? onLabelTap;
  final VoidCallback? onAvatarTap;
  final Offset anchor;

  @override
  Widget build(BuildContext context) {
    final occupied = avatars.isNotEmpty;
    final labelStyle = occupied
        ? _tilemapLocationLabelTextStyle
        : _tilemapEmptyLocationLabelTextStyle;
    final labelLayout = _tilemapLocationLabelLayout(
      context,
      name,
      occupied: occupied,
    );
    final activityIconCount = showRecentChat ? 1 : 0;
    final activityIconsWidth =
        activityIconCount * _tilemapLocationActivityIconExtraWidth;
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Transform.translate(
          // Match the reference marker: the white dot's center, rather than
          // the label's lower edge, is fixed to the tile anchor. Measuring the
          // rendered label also keeps the point fixed when the name wraps.
          offset: Offset(
            0,
            -labelLayout.height -
                tilemapLocationLabelToDotSpacing -
                tilemapLocationDotSize / 2,
          ),
          child: Semantics(
            label: name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (activityIconCount > 0)
                      SizedBox(width: activityIconsWidth),
                    SizedBox(
                      width: labelLayout.bubbleWidth,
                      height: labelLayout.height,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Keep text layout at the canonical max width while
                          // keeping the row footprint at the measured bubble
                          // width. Shrinking the text box itself can trigger a
                          // second wrap; keeping a 141px row footprint pushes
                          // the recent-chat badge too far away.
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onLabelTap,
                              child: Container(
                                key: ValueKey<String>(
                                  'tile-location-bubble-body-$name',
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: OverflowBox(
                                alignment: Alignment.center,
                                minWidth: _tilemapLocationLabelMaxWidth,
                                maxWidth: _tilemapLocationLabelMaxWidth,
                                minHeight: labelLayout.height,
                                maxHeight: labelLayout.height,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal:
                                        _tilemapLocationLabelHorizontalPadding,
                                    vertical:
                                        _tilemapLocationLabelVerticalPadding,
                                  ),
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    maxLines: labelLayout.lineCount,
                                    overflow: TextOverflow.visible,
                                    style: labelStyle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showEvent)
                            const Positioned(
                              right: worldMapLocationEventBadgeRight,
                              top: worldMapLocationEventBadgeTop,
                              child: WorldEventCountBadge(
                                key: ValueKey<String>(
                                  'world-map-location-event-count',
                                ),
                                count: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (activityIconCount > 0)
                      SizedBox(
                        width: activityIconsWidth,
                        child: Row(
                          children: [
                            if (showRecentChat)
                              const SizedBox(
                                width: _tilemapLocationActivityIconExtraWidth,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: RecentChatMapBadge(
                                    badgeKey: ValueKey<String>(
                                      'tilemap-recent-chat-icon',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: tilemapLocationLabelToDotSpacing),
                DecoratedBox(
                  key: ValueKey<String>('tile-location-dot-$name'),
                  decoration: const BoxDecoration(
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
                  child: const SizedBox.square(
                    dimension: tilemapLocationDotSize,
                  ),
                ),
                if (avatars.isNotEmpty) ...[
                  const SizedBox(height: tilemapLocationDotToAvatarSpacing),
                  TilemapLocationAvatars(
                    avatars: avatars,
                    onAvatarTap: onAvatarTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
