import 'package:flutter/material.dart';

import '../ui/theme/genesis_semantic_colors.dart';

const String kAiContentDisclaimerText =
    'All content is AI-generated and fictional. Any resemblance to real people, events, or places is coincidental.';

const TextStyle kAiContentDisclaimerTextStyle = TextStyle(
  fontSize: 11,
  height: 1.4,
  fontWeight: FontWeight.w400,
);

class AiContentDisclaimer extends StatelessWidget {
  const AiContentDisclaimer({
    super.key,
    this.text = kAiContentDisclaimerText,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.textAlign = TextAlign.center,
  });

  /// Fixed like the other small glyphs in the app (12/13/14), sized so its
  /// stroke weight sits level with the 11px w400 text beside it.
  static const double _iconSize = 12;

  final String text;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final color = context.genesisColors.textFaint;
    return Padding(
      padding: padding,
      child: Text.rich(
        TextSpan(
          children: [
            // Inline, so the glyph centres with the paragraph instead of
            // hanging off its left edge.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox.square(
                  key: const ValueKey<String>(
                    'ai-content-disclaimer-hint-icon',
                  ),
                  dimension: _iconSize,
                  child: CustomPaint(
                    painter: _AiDisclaimerHintIconPainter(color: color),
                  ),
                ),
              ),
            ),
            TextSpan(text: text),
          ],
        ),
        textAlign: textAlign,
        style: kAiContentDisclaimerTextStyle.copyWith(color: color),
        semanticsLabel: text,
      ),
    );
  }
}

/// The spec's Field hint glyph flipped into an exclamation mark: the 16-unit
/// circle keeps its stroke, the stem runs the top half, the dot sits below.
/// The dot is the round-line-icon standard (Feather/Lucide alert-circle): a
/// zero-length round-capped stroke, so its diameter equals the stroke width
/// and it stays as thin as the stem. Drawn rather than loaded because scaling
/// an asset this far down thins the stroke.
class _AiDisclaimerHintIconPainter extends CustomPainter {
  const _AiDisclaimerHintIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final dot = Offset(8 * scale, 11.3 * scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.49 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawCircle(Offset(8 * scale, 8 * scale), 6.4 * scale, paint)
      ..drawLine(
        Offset(8 * scale, 4.6 * scale),
        Offset(8 * scale, 8.6 * scale),
        paint,
      )
      ..drawLine(dot, dot, paint);
  }

  @override
  bool shouldRepaint(_AiDisclaimerHintIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
