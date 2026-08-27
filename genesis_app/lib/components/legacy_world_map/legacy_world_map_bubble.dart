import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../world_map_contract.dart';
import 'legacy_world_map_background.dart';

const Duration legacyWorldMapBubbleDisplayDuration = Duration(seconds: 4);
const Duration legacyWorldMapBubbleGapDuration = Duration(milliseconds: 500);

@visibleForTesting
List<String> worldMapMessageBubblePagesForTesting(String content) {
  return legacyWorldMapMessageBubblePages(content);
}

List<String> legacyWorldMapMessageBubblePages(
  String content, {
  TextDirection textDirection = TextDirection.ltr,
  TextScaler? textScaler,
  TextStyle? textStyle,
}) {
  return splitWorldMapMessageBubblePages(
    content,
    textDirection: textDirection,
    textScaler: textScaler,
    textStyle: textStyle,
  );
}

class LegacyWorldMapPositionedMessageBubble extends StatelessWidget {
  const LegacyWorldMapPositionedMessageBubble({
    super.key,
    required this.text,
    this.preservePageWidth = false,
    required this.markerLeft,
    required this.markerTop,
    required this.avatarLeft,
    required this.avatarTop,
    required this.markerWidth,
    required this.onPointerDown,
    required this.onTap,
  });

  final String text;
  final bool preservePageWidth;
  final double markerLeft;
  final double markerTop;
  final double avatarLeft;
  final double avatarTop;
  final double markerWidth;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;

  static const double _avatarSize = legacyWorldMapAvatarImageLogicalSize;
  static const double _bubbleGap = 8;
  static const double _pointerWidth = worldMapMessageBubblePointerWidth;
  static const double _pointerHeight = 10;

  @override
  Widget build(BuildContext context) {
    final bubbleWidth = resolveWorldMapMessageBubbleWidth(
      context,
      text,
      preservePageWidth: preservePageWidth,
    );
    final centeredLeft = avatarLeft + _avatarSize / 2 - bubbleWidth / 2;
    final left = centeredLeft.clamp(
      -bubbleWidth / 2,
      math.max(markerWidth - bubbleWidth / 2, -bubbleWidth / 2),
    );

    return Positioned(
      left: markerLeft + left.toDouble(),
      top: markerTop + avatarTop + _avatarSize + _bubbleGap - _pointerHeight,
      width: bubbleWidth,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _MapMessageBubble(
            text: text,
            pointerLeft: (avatarLeft + _avatarSize / 2 - left.toDouble())
                .clamp(_pointerWidth * 1.5, bubbleWidth - _pointerWidth * 1.5)
                .toDouble(),
          ),
        ),
      ),
    );
  }
}

class _MapMessageBubble extends StatelessWidget {
  const _MapMessageBubble({required this.text, required this.pointerLeft});

  final String text;
  final double pointerLeft;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: pointerLeft - 6,
          top: 0,
          width: 12,
          height: 10,
          child: CustomPaint(
            painter: const _MapMessageBubblePointerPainter(
              color: worldMapMessageBubbleBackgroundColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            key: const ValueKey<String>('world-map-message-bubble-body'),
            width: double.infinity,
            child: WorldMapMessageBubbleSurface(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: worldMapMessageBubbleHorizontalPadding,
                  vertical: worldMapMessageBubbleVerticalPadding,
                ),
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.clip,
                  style: worldMapMessageBubbleTextStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapMessageBubblePointerPainter extends CustomPainter {
  const _MapMessageBubblePointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MapMessageBubblePointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
