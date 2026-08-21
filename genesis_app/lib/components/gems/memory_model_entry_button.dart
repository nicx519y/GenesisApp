import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
import 'package:genesis_flutter_android/components/genesis_feature_themes.dart';

import '../chat/shared/chat_ui_theme.dart';

const double kMemoryModelEntryMinWidth = 82;
const double kMemoryModelEntryMaxWidth = 96;
const double kMemoryModelRoomHeaderMinWidth = 62;

enum MemoryModelEntryButtonVariant { standard, roomHeader }

class MemoryModelEntryButton extends StatelessWidget {
  const MemoryModelEntryButton({
    super.key,
    required this.modelLabel,
    required this.onTap,
    this.darkHeader = false,
    this.compact = false,
    this.variant = MemoryModelEntryButtonVariant.standard,
  });

  final String modelLabel;
  final VoidCallback onTap;
  final bool darkHeader;
  final bool compact;
  final MemoryModelEntryButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == MemoryModelEntryButtonVariant.roomHeader) {
      return _buildRoomHeaderButton(context);
    }

    final colors = context.genesisColors;
    final foreground = darkHeader
        ? colors.textInverse
        : colors.foregroundStrong;
    final background = darkHeader
        ? Colors.transparent
        : colors.surface.withValues(alpha: 0.9);
    final borderRadius = compact ? 11.5 : 19.0;
    final iconSize = compact ? 16.0 : 18.0;
    final labelStyle = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
      color: foreground,
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: modelLabel, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final buttonWidth = (20 + iconSize + 5 + labelPainter.width)
        .clamp(kMemoryModelEntryMinWidth, kMemoryModelEntryMaxWidth)
        .toDouble();
    return Material(
      key: const ValueKey('memory-model-entry'),
      color: background,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: SizedBox(
          width: buttonWidth,
          height: compact ? 23 : 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/custom-icons/svg/arrow-change-svgrepo-com.svg',
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    modelLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomHeaderButton(BuildContext context) {
    final colors = context.genesisColors;
    final foreground =
        context.genesisChatTheme.locationChat.headerTitleTextStyle.color ??
        colors.textPrimary;
    final labelStyle = TextStyle(
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w600,
      color: foreground,
    );
    const borderRadius = BorderRadius.all(Radius.circular(9));

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          key: const ValueKey('memory-model-entry'),
          color: foreground.withValues(alpha: 0.13),
          shape: const RoundedRectangleBorder(borderRadius: borderRadius)
              .copyWith(
                side: BorderSide(color: foreground.withValues(alpha: 0.18)),
              ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStatePropertyAll<Color>(
              foreground.withValues(alpha: 0.08),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: kMemoryModelRoomHeaderMinWidth,
                minHeight: 28,
                maxHeight: 28,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      modelLabel,
                      maxLines: 1,
                      softWrap: false,
                      style: labelStyle,
                    ),
                    const SizedBox(width: 6),
                    CustomPaint(
                      key: const ValueKey('memory-model-entry-chevron'),
                      size: const Size(9, 6),
                      painter: _MemoryModelChevronPainter(
                        color: foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryModelChevronPainter extends CustomPainter {
  const _MemoryModelChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.5, 0.8)
      ..lineTo(size.width / 2, size.height - 0.8)
      ..lineTo(size.width - 0.5, 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MemoryModelChevronPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
