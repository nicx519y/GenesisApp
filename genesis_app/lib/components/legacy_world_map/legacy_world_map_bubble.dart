import 'dart:math' as math;

import 'package:flutter/material.dart';

const int legacyWorldMapBubblePageMaxCharacters = 144;
const Duration legacyWorldMapBubbleDisplayDuration = Duration(seconds: 4);
const Duration legacyWorldMapBubbleGapDuration = Duration(milliseconds: 500);

@visibleForTesting
List<String> worldMapMessageBubblePagesForTesting(String content) {
  return legacyWorldMapMessageBubblePages(content);
}

List<String> legacyWorldMapMessageBubblePages(String content) {
  final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return const <String>[];
  final pages = <String>[];
  var remaining = normalized;
  while (remaining.length > legacyWorldMapBubblePageMaxCharacters) {
    var split = remaining.lastIndexOf(
      ' ',
      legacyWorldMapBubblePageMaxCharacters,
    );
    if (split <= 0) split = legacyWorldMapBubblePageMaxCharacters;
    pages.add(remaining.substring(0, split).trim());
    remaining = remaining.substring(split).trim();
  }
  if (remaining.isNotEmpty) pages.add(remaining);
  return List<String>.unmodifiable(pages);
}

class LegacyWorldMapPositionedMessageBubble extends StatelessWidget {
  const LegacyWorldMapPositionedMessageBubble({
    super.key,
    required this.text,
    required this.markerLeft,
    required this.markerTop,
    required this.avatarLeft,
    required this.avatarTop,
    required this.markerWidth,
    required this.onPointerDown,
    required this.onTap,
  });

  final String text;
  final double markerLeft;
  final double markerTop;
  final double avatarLeft;
  final double avatarTop;
  final double markerWidth;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;

  static const double _avatarSize = 42;
  static const double _bubbleGap = 8;
  static const double _bubbleWidth = 220;
  static const double _pointerWidth = 12;
  static const double _pointerHeight = 10;

  @override
  Widget build(BuildContext context) {
    final centeredLeft = avatarLeft + _avatarSize / 2 - _bubbleWidth / 2;
    final left = centeredLeft.clamp(
      -_bubbleWidth / 2,
      math.max(markerWidth - _bubbleWidth / 2, -_bubbleWidth / 2),
    );

    return Positioned(
      left: markerLeft + left.toDouble(),
      top: markerTop + avatarTop + _avatarSize + _bubbleGap - _pointerHeight,
      width: _bubbleWidth,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _MapMessageBubble(
            text: text,
            pointerLeft: (avatarLeft + _avatarSize / 2 - left.toDouble())
                .clamp(_pointerWidth * 1.5, _bubbleWidth - _pointerWidth * 1.5)
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
            painter: const _MapMessageBubblePointerPainter(color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            key: const ValueKey<String>('world-map-message-bubble-body'),
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                  ),
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
