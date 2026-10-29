import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../network/mini_phone/mini_phone_models.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_ui.dart';

const _cameraAvatarSize = 48.0;

/// The filmstrip and the focused portraits share the app's avatar renderer.
class MiniPhoneCameraCastChoice extends StatelessWidget {
  const MiniPhoneCameraCastChoice({
    super.key,
    required this.person,
    required this.label,
    required this.order,
    required this.onTap,
  });
  final PhonePerson person;
  final String label;
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: order > 0,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 68,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: order > 0 ? miniRed : const Color(0x33FFFFFF),
                      ),
                    ),
                    child: miniPhonePersonAvatar(
                      person,
                      _cameraAvatarSize,
                      radius: _cameraAvatarSize / 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: miniStyle(
                  11,
                  FontWeight.w500,
                  order > 0 ? miniWhite : miniSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MiniPhoneCameraFocusedPerson extends StatelessWidget {
  const MiniPhoneCameraFocusedPerson({
    super.key,
    required this.person,
    required this.label,
  });
  final PhonePerson person;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    excludeSemantics: true,
    child: Center(
      child: CustomPaint(
        painter: _FocusCorners(),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: miniPhonePersonAvatar(
            person,
            _cameraAvatarSize,
            radius: _cameraAvatarSize / 2,
          ),
        ),
      ),
    ),
  );
}

class _FocusCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = miniWhite
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final x in [0.0, size.width]) {
      for (final y in [0.0, size.height]) {
        canvas.drawPath(
          Path()
            ..moveTo(x + (x == 0 ? 11 : -11), y)
            ..lineTo(x, y)
            ..lineTo(x, y + (y == 0 ? 11 : -11)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FocusCorners oldDelegate) => false;
}

/// Fit every selected character in the frame; rows never overflow or require
/// horizontal scrolling. Larger casts scale down together after wrapping.
class MiniPhoneCameraFocusedCast extends StatelessWidget {
  const MiniPhoneCameraFocusedCast({
    super.key,
    required this.people,
    required this.label,
  });
  final List<PhonePerson> people;
  final String Function(PhonePerson) label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (people.isEmpty) return const SizedBox.shrink();
      const cellHeight = 72.0;
      var columns = 1;
      var bestScale = 0.0;
      for (var count = 1; count <= people.length; count++) {
        final rows = (people.length / count).ceil();
        final scale = math.min(
          1.0,
          math.min(
            bounds.maxWidth / (count * cellHeight + (count - 1) * 12),
            bounds.maxHeight / (rows * cellHeight + (rows - 1) * 12),
          ),
        );
        if (scale > bestScale || (scale == bestScale && count <= 3)) {
          columns = count;
          bestScale = scale;
        }
      }
      final rows = (people.length / columns).ceil();
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: columns * cellHeight + (columns - 1) * 12,
            height: rows * cellHeight + (rows - 1) * 12,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final person in people)
                  SizedBox(
                    width: cellHeight,
                    height: cellHeight,
                    child: MiniPhoneCameraFocusedPerson(
                      person: person,
                      label: label(person),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
