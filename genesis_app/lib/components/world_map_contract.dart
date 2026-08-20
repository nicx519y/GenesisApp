import 'dart:async';

import 'package:flutter/material.dart';

import 'world_point.dart';

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

const double worldMapMessageBubbleMaxWidth = 220;
const double worldMapMessageBubbleHorizontalPadding = 12;
const double worldMapMessageBubblePointerWidth = 12;
const TextStyle worldMapMessageBubbleTextStyle = TextStyle(
  color: Color(0xFF1F1F1F),
  fontSize: 11,
  height: 1.25,
  fontWeight: FontWeight.w400,
);

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
      text: text.trim(),
      style: resolveWorldMapMessageBubbleTextStyle(context),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  const horizontalInsets = worldMapMessageBubbleHorizontalPadding * 2;
  const minimumWidth = worldMapMessageBubblePointerWidth * 3;
  const layoutSafetyWidth = 2.0;
  return (painter.width.ceilToDouble() + layoutSafetyWidth + horizontalInsets)
      .clamp(minimumWidth, worldMapMessageBubbleMaxWidth)
      .toDouble();
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
  final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
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

    var low = 1;
    var high = remaining.length;
    var bestFit = 1;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final candidate = remaining.substring(0, middle).trimRight();
      if (candidate.isNotEmpty &&
          _worldMapMessageBubbleTextFitsPage(
            candidate,
            textDirection: textDirection,
            textScaler: resolvedTextScaler,
            textStyle: resolvedTextStyle,
          )) {
        bestFit = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    var split = remaining.lastIndexOf(' ', bestFit);
    if (split <= 0) split = _safeWorldMapMessageBubbleSplit(remaining, bestFit);
    final page = remaining.substring(0, split).trim();
    if (page.isEmpty) {
      split = _safeWorldMapMessageBubbleSplit(remaining, bestFit);
      pages.add(remaining.substring(0, split).trim());
    } else {
      pages.add(page);
    }
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
  )..layout(maxWidth: textMaxWidth);
  return !painter.didExceedMaxLines;
}

int _safeWorldMapMessageBubbleSplit(String text, int split) {
  if (text.length <= 1) return text.length;
  var safeSplit = split.clamp(1, text.length - 1).toInt();
  if (safeSplit < text.length &&
      _isHighSurrogate(text.codeUnitAt(safeSplit - 1)) &&
      _isLowSurrogate(text.codeUnitAt(safeSplit))) {
    safeSplit -= 1;
  }
  return safeSplit;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

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
    this.drillExitTop = 68,
    this.foregroundOverlay,
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
  });

  final List<WorldMapLocationNode> locationNodes;
  final double drillExitTop;
  final Widget? foregroundOverlay;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final WorldPointTapCallback? onPointTap;
}
