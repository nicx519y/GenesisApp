import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ui/tokens/genesis_blur.dart';
import '../utils/genesis_ugc_text.dart';
import '../ui/tokens/genesis_typography.dart';

import 'world_point.dart';

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

const double worldMapMessageBubbleMaxWidth = 220;
const double worldMapMessageBubbleHorizontalPadding = 11;
const double worldMapMessageBubbleVerticalPadding = 8;
const double worldMapMessageBubblePointerWidth = 12;
const double worldMapMessageBubblePointerHeight = 10;
const double worldMapMessageBubbleBorderWidth = 1;
const Color worldMapMessageBubbleBorderColor = Color(0x2EFFFFFF);
// Centers the 30px drill-up control against the 68px zoom control whose
// bottom inset is 30px: 30 + (68 - 30) / 2.
const double worldMapDrillExitBottom = 49;
const Color worldMapMessageBubbleBackgroundColor = Color(0xCC3A3942);
const BorderRadius worldMapMessageBubbleBorderRadius = BorderRadius.all(
  Radius.circular(8),
);
const TextStyle worldMapMessageBubbleTextStyle = TextStyle(
  fontFamily: GenesisTypography.fontFamily,
  fontFamilyFallback: GenesisTypography.fontFamilyFallback,
  color: Color(0xFFF4F3F6),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

class WorldMapMessageBubbleSurface extends StatelessWidget {
  const WorldMapMessageBubbleSurface({
    super.key,
    required this.pointerLeft,
    required this.child,
  });

  final double pointerLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clipper = _WorldMapMessageBubbleClipper(pointerLeft);
    return ClipPath(
      clipper: clipper,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: GenesisBlur.light,
          sigmaY: GenesisBlur.light,
        ),
        child: CustomPaint(
          foregroundPainter: _WorldMapMessageBubbleBorderPainter(clipper),
          child: ColoredBox(
            color: worldMapMessageBubbleBackgroundColor,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _WorldMapMessageBubbleClipper extends CustomClipper<Path> {
  const _WorldMapMessageBubbleClipper(this.pointerLeft);

  final double pointerLeft;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(
        worldMapMessageBubbleBorderRadius.toRRect(
          Rect.fromLTWH(
            0,
            worldMapMessageBubblePointerHeight,
            size.width,
            size.height - worldMapMessageBubblePointerHeight,
          ),
        ),
      );
    final pointer = Path()
      ..moveTo(pointerLeft, 0)
      ..lineTo(
        pointerLeft + worldMapMessageBubblePointerWidth / 2,
        worldMapMessageBubblePointerHeight,
      )
      ..lineTo(
        pointerLeft - worldMapMessageBubblePointerWidth / 2,
        worldMapMessageBubblePointerHeight,
      )
      ..close();
    // One silhouette keeps the fill, blur and border seamless at the tail.
    return Path.combine(PathOperation.union, body, pointer);
  }

  @override
  bool shouldReclip(_WorldMapMessageBubbleClipper oldClipper) =>
      pointerLeft != oldClipper.pointerLeft;
}

class _WorldMapMessageBubbleBorderPainter extends CustomPainter {
  const _WorldMapMessageBubbleBorderPainter(this.clipper);

  final _WorldMapMessageBubbleClipper clipper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.getClip(size),
      Paint()
        ..color = worldMapMessageBubbleBorderColor
        ..style = PaintingStyle.stroke
        // ClipPath removes the outside half, leaving a 1px inner border.
        ..strokeWidth = worldMapMessageBubbleBorderWidth * 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WorldMapMessageBubbleBorderPainter oldDelegate) =>
      clipper.pointerLeft != oldDelegate.clipper.pointerLeft;
}

TextStyle resolveWorldMapMessageBubbleTextStyle(BuildContext context) {
  return DefaultTextStyle.of(
    context,
  ).style.merge(worldMapMessageBubbleTextStyle);
}

double resolveWorldMapMessageBubbleWidth(
  BuildContext context,
  String text, {
  bool preservePageWidth = false,
}) {
  if (preservePageWidth) return worldMapMessageBubbleMaxWidth;
  final painter = TextPainter(
    text: TextSpan(
      text: normalizeGenesisUgcTextForDisplay(text).trim(),
      style: resolveWorldMapMessageBubbleTextStyle(context),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  );
  try {
    painter.layout();
    const horizontalInsets = worldMapMessageBubbleHorizontalPadding * 2;
    const minimumWidth = worldMapMessageBubblePointerWidth * 3;
    const layoutSafetyWidth = 2.0;
    return (painter.width.ceilToDouble() + layoutSafetyWidth + horizontalInsets)
        .clamp(minimumWidth, worldMapMessageBubbleMaxWidth)
        .toDouble();
  } finally {
    painter.dispose();
  }
}

List<String> resolveWorldMapMessageBubblePages(
  BuildContext context,
  String content,
) {
  return splitWorldMapMessageBubblePages(
    content,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    textStyle: resolveWorldMapMessageBubbleTextStyle(context),
  );
}

List<String> splitWorldMapMessageBubblePages(
  String content, {
  TextDirection textDirection = TextDirection.ltr,
  TextScaler? textScaler,
  TextStyle? textStyle,
}) {
  final normalized = normalizeGenesisUgcTextForDisplay(
    content,
  ).trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return const <String>[];
  final resolvedTextScaler = textScaler ?? TextScaler.noScaling;
  final resolvedTextStyle = textStyle ?? worldMapMessageBubbleTextStyle;
  final pages = <String>[];
  var remaining = normalized;
  while (remaining.isNotEmpty) {
    if (_worldMapMessageBubbleTextFitsPage(
      remaining,
      textDirection: textDirection,
      textScaler: resolvedTextScaler,
      textStyle: resolvedTextStyle,
    )) {
      pages.add(remaining);
      break;
    }

    // Every measurement must end on a grapheme boundary, not only the final page.
    final boundaries = <int>[];
    var offset = 0;
    for (final character in remaining.characters) {
      offset += character.length;
      boundaries.add(offset);
    }
    var low = 0;
    var high = boundaries.length - 1;
    var bestFit = boundaries.first;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final candidate = remaining.substring(0, boundaries[middle]).trimRight();
      if (candidate.isNotEmpty &&
          _worldMapMessageBubbleTextFitsPage(
            candidate,
            textDirection: textDirection,
            textScaler: resolvedTextScaler,
            textStyle: resolvedTextStyle,
          )) {
        bestFit = boundaries[middle];
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    var split = remaining.lastIndexOf(' ', bestFit);
    // A space can itself belong to a combining sequence. Never cut inside it.
    if (split <= 0 || !boundaries.contains(split)) split = bestFit;
    pages.add(remaining.substring(0, split).trim());
    remaining = remaining.substring(split).trim();
  }
  return List<String>.unmodifiable(pages);
}

bool _worldMapMessageBubbleTextFitsPage(
  String text, {
  required TextDirection textDirection,
  required TextScaler textScaler,
  required TextStyle textStyle,
}) {
  const textMaxWidth =
      worldMapMessageBubbleMaxWidth -
      worldMapMessageBubbleHorizontalPadding * 2;
  final painter = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    maxLines: 3,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  try {
    painter.layout(maxWidth: textMaxWidth);
    return !painter.didExceedMaxLines;
  } finally {
    painter.dispose();
  }
}

@immutable
class WorldMapHorizontalPanState {
  const WorldMapHorizontalPanState({
    required this.canScrollLeft,
    required this.canScrollRight,
  });

  final bool canScrollLeft;
  final bool canScrollRight;
}

@immutable
class WorldMapMessageBubble {
  const WorldMapMessageBubble({
    required this.characterId,
    required this.content,
    this.preservePageWidth = false,
  });

  final String characterId;
  final String content;
  final bool preservePageWidth;
}

@immutable
class WorldMapCommonConfig {
  const WorldMapCommonConfig({
    this.locationNodes = const <WorldMapLocationNode>[],
    this.drillExitBottom = worldMapDrillExitBottom,
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
  });

  final List<WorldMapLocationNode> locationNodes;
  final double drillExitBottom;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final WorldPointTapCallback? onPointTap;
}
