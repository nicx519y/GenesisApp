import 'package:flutter/material.dart';

import '../../../ui/tokens/genesis_typography.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_camera_models.dart';

class CameraRatioPicker extends StatefulWidget {
  const CameraRatioPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final CameraPhotoRatio value;
  final ValueChanged<CameraPhotoRatio> onChanged;
  @override
  State<CameraRatioPicker> createState() => _CameraRatioPickerState();
}

class _CameraRatioPickerState extends State<CameraRatioPicker> {
  late final _pages = PageController(
    initialPage: widget.value.index,
    viewportFraction: 1 / 5,
  );
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant CameraRatioPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        !_dragging &&
        _pages.hasClients &&
        (_pages.page! - widget.value.index).abs() > .01) {
      _pages.animateToPage(
        widget.value.index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('camera-ratio-picker'),
    width: 260,
    height: 44,
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _dragging = notification.dragDetails != null;
        }
        if (notification is ScrollEndNotification) {
          _dragging = false;
          widget.onChanged(CameraPhotoRatio.values[_pages.page!.round()]);
        }
        return false;
      },
      child: PageView(
        controller: _pages,
        children: [
          for (final ratio in CameraPhotoRatio.values)
            AnimatedBuilder(
              animation: _pages,
              builder: (context, _) {
                final page =
                    _pages.hasClients && _pages.position.hasContentDimensions
                    ? _pages.page ?? widget.value.index.toDouble()
                    : widget.value.index.toDouble();
                // Follow scroll position rather than waiting for ScrollEnd.
                final emphasis = (1 - (page - ratio.index).abs()).clamp(
                  0.0,
                  1.0,
                );
                return Semantics(
                  selected: ratio == widget.value,
                  button: true,
                  label: ratio.label,
                  child: InkWell(
                    key: ValueKey('camera-ratio-${ratio.label}'),
                    onTap: () => _pages.animateToPage(
                      ratio.index,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                    ),
                    child: Center(
                      child: SizedBox(
                        key: ValueKey('camera-ratio-frame-${ratio.label}'),
                        height: ratio.aspectRatio >= 1 ? 24 : 36,
                        width: ratio.aspectRatio >= 1
                            ? 24 * ratio.aspectRatio
                            : 36 * ratio.aspectRatio,
                        child: CustomPaint(
                          painter: _RatioCorners(emphasis),
                          child: Center(
                            child: Text(
                              ratio.label,
                              style: GenesisTypography.supporting.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.lerp(
                                  FontWeight.w400,
                                  FontWeight.w600,
                                  emphasis,
                                ),
                                color: Color.lerp(
                                  miniTertiary,
                                  miniWhite,
                                  emphasis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _RatioCorners extends CustomPainter {
  const _RatioCorners(this.emphasis);
  final double emphasis;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.lerp(
        miniTertiary.withValues(alpha: .4),
        miniWhite,
        emphasis,
      )!
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final x in [1.0, size.width - 1]) {
      for (final y in [1.0, size.height - 1]) {
        final sx = x == 1 ? 1.0 : -1.0;
        final sy = y == 1 ? 1.0 : -1.0;
        canvas.drawPath(
          Path()
            ..moveTo(x + sx * 8, y)
            ..lineTo(x + sx * 3, y)
            ..quadraticBezierTo(x, y, x, y + sy * 3)
            ..lineTo(x, y + sy * 8),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RatioCorners oldDelegate) =>
      emphasis != oldDelegate.emphasis;
}
