import 'package:flutter/material.dart';

import '../../l10n/genesis_l10n.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../chat/shared/chat_ui.dart';

/// One tick of the recap on a timeline. A rail on the left strings the ticks
/// into one story, read downward in the order it happened; each tick is named
/// as the Events tab names it, beside its node, and only the latest node takes
/// the accent, so the red marks where the story now stands.
class WorldMemoryTickTile extends StatelessWidget {
  const WorldMemoryTickTile({
    super.key,
    required this.tickNo,
    required this.bodies,
    required this.isFirst,
    required this.isLast,
  });

  final int tickNo;
  final List<String> bodies;
  final bool isFirst;
  final bool isLast;

  static const double _railWidth = 16;
  static const double _railGap = 10;
  static const double _gapAfterTick = 22;

  static final TextStyle _body = GenesisTypography.body.copyWith(
    color: GenesisColors.darkTextSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final hasLabel = tickNo > 0;
    // The node centres on the first line beside it, measured at the reader's
    // own text scale so it stays level whatever size they read at.
    final firstLine = TextPainter(
      text: TextSpan(text: 'M', style: hasLabel ? chatTickLabelStyle : _body),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    final nodeCentre = firstLine.height / 2;
    firstLine.dispose();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: CustomPaint(
              painter: _TickRailPainter(
                nodeCentre: nodeCentre,
                lineAbove: !isFirst,
                lineBelow: !isLast,
                latest: isLast,
              ),
            ),
          ),
          const SizedBox(width: _railGap),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : _gapAfterTick),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasLabel) ...[
                    // Named as the Events tab names a tick.
                    Text(
                      GenesisL10n.current.tickNumber(
                        tick: tickNo.toString(),
                        suffix: '',
                      ),
                      style: chatTickLabelStyle,
                    ),
                    const SizedBox(height: 8),
                  ],
                  for (final (index, body) in bodies.indexed) ...[
                    if (index > 0) const SizedBox(height: 10),
                    Text(body, style: _body),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickRailPainter extends CustomPainter {
  const _TickRailPainter({
    required this.nodeCentre,
    required this.lineAbove,
    required this.lineBelow,
    required this.latest,
  });

  final double nodeCentre;
  final bool lineAbove;
  final bool lineBelow;
  final bool latest;

  static const Color _line = Color(0x1FFFFFFF);
  static const double _nodeRadius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final line = Paint()
      ..color = _line
      ..strokeWidth = 1;
    if (lineAbove) {
      canvas.drawLine(Offset(x, 0), Offset(x, nodeCentre), line);
    }
    if (lineBelow) {
      canvas.drawLine(Offset(x, nodeCentre), Offset(x, size.height), line);
    }
    canvas.drawCircle(
      Offset(x, nodeCentre),
      _nodeRadius,
      Paint()
        ..color = latest
            ? GenesisColors.redPrimary
            : GenesisColors.darkTextTertiary,
    );
  }

  @override
  bool shouldRepaint(_TickRailPainter old) =>
      old.nodeCentre != nodeCentre ||
      old.lineAbove != lineAbove ||
      old.lineBelow != lineBelow ||
      old.latest != latest;
}
