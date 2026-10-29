import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../components/common/genesis_bottom_sheet_panel.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../../../ui/tokens/genesis_radii.dart';
import '../../../ui/tokens/genesis_blur.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_camera_strings.dart';
import 'mini_phone_camera_templates.dart';

class MiniPhoneCameraSectionHeading extends StatelessWidget {
  const MiniPhoneCameraSectionHeading({
    super.key,
    required this.label,
    this.detail,
  });

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: miniStyle(14, FontWeight.w600).copyWith(height: 1.4),
        ),
      ),
      if (detail != null) ...[
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            detail!,
            textAlign: TextAlign.end,
            style: miniStyle(
              12,
              FontWeight.w400,
              miniTertiary,
            ).copyWith(height: 1.4),
          ),
        ),
      ],
    ],
  );
}

/// A decorative composition surface only. It never opens a device camera or
/// displays a sample image as a live preview.
class MiniPhoneCameraViewfinder extends StatelessWidget {
  const MiniPhoneCameraViewfinder({
    super.key,
    required this.child,
    this.imageUrl = '',
    this.footer,
  });
  final Widget child;
  final String imageUrl;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const ValueKey('mini-phone-camera-viewfinder'),
    borderRadius: BorderRadius.circular(14),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: miniRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: miniLine),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty) ...[
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: GenesisBlur.strong,
                sigmaY: GenesisBlur.strong,
                tileMode: TileMode.clamp,
              ),
              child: GenesisStaticNetworkImage(
                key: ValueKey(imageUrl),
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_) => const ColoredBox(color: miniRaised),
                errorWidget: (_, _) => const ColoredBox(color: miniRaised),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .32, .64, 1],
                  colors: [
                    miniBackground.withValues(alpha: .8),
                    miniBackground.withValues(alpha: .5),
                    miniBackground.withValues(alpha: .5),
                    miniBackground.withValues(alpha: .8),
                  ],
                ),
              ),
            ),
          ],
          const IgnorePointer(
            child: CustomPaint(
              key: ValueKey('mini-phone-camera-guide-area'),
              painter: _ViewfinderGuides(),
            ),
          ),
          Column(
            children: [
              Expanded(child: child),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: footer,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ViewfinderGuides extends CustomPainter {
  const _ViewfinderGuides();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = miniWhite.withValues(alpha: .04)
      ..strokeWidth = .5;
    for (final fraction in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        grid,
      );
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        grid,
      );
    }
    final corners = Paint()
      ..color = miniWhite.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.25;
    const inset = 14.0, arm = 18.0;
    for (final x in [inset, size.width - inset]) {
      for (final y in [inset, size.height - inset]) {
        final sx = x == inset ? 1.0 : -1.0;
        final sy = y == inset ? 1.0 : -1.0;
        const radius = 6.0;
        canvas.drawPath(
          Path()
            ..moveTo(x + sx * arm, y)
            ..lineTo(x + sx * radius, y)
            ..quadraticBezierTo(x, y, x, y + sy * radius)
            ..lineTo(x, y + sy * arm),
          corners,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ViewfinderGuides oldDelegate) => false;
}

class MiniPhoneCameraShutter extends StatelessWidget {
  const MiniPhoneCameraShutter({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('mini-phone-camera-shutter-semantics'),
    label: label,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: IconButton(
      key: const ValueKey('mini-phone-camera-shutter'),
      tooltip: label,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(78),
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        side: const BorderSide(color: Colors.white, width: 4),
      ),
      icon: Container(
        key: const ValueKey('mini-phone-camera-shutter-core'),
        width: 62,
        height: 62,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// Actual template art or caller-supplied album art; an absent album stays empty.
class MiniPhoneCameraThumbnail extends StatelessWidget {
  const MiniPhoneCameraThumbnail({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.showSwitch = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget child;
  final bool showSwitch;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    excludeSemantics: true,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 13),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: const ValueKey('mini-phone-camera-thumbnail-image'),
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                ),
                if (showSwitch)
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: miniBackground, width: 2),
                      ),
                      child: const Icon(
                        Icons.sync,
                        size: 12,
                        color: miniBackground,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: miniStyle(11, FontWeight.w400, miniSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

class MiniPhoneCameraAddPerson extends StatelessWidget {
  const MiniPhoneCameraAddPerson({super.key});
  @override
  Widget build(BuildContext context) => const CustomPaint(
    painter: _DashedFocusBox(),
    child: SizedBox.square(
      dimension: 64,
      child: Icon(Icons.add, size: 24, color: miniWhite),
    ),
  );
}

class _DashedFocusBox extends CustomPainter {
  const _DashedFocusBox();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(12),
        ),
      );
    final paint = Paint()
      ..color = miniSecondary
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 8) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 4).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFocusBox oldDelegate) => false;
}

class MiniPhoneCameraTemplateSheet extends StatelessWidget {
  const MiniPhoneCameraTemplateSheet({
    super.key,
    required this.strings,
    required this.prompt,
    required this.onSelected,
  });
  final MiniPhoneCameraStrings strings;
  final String prompt;
  final ValueChanged<MiniPhoneCameraTemplate> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: strings.tryTemplate,
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    child: ClipRRect(
      borderRadius: GenesisRadii.sheet,
      child: ColoredBox(
        color: miniRaised,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GenesisActionSheetHeader(
                  title: strings.tryTemplate,
                  showClose: true,
                  onClose: () => Navigator.of(context).pop(),
                ),
                SingleChildScrollView(
                  key: const ValueKey('mini-phone-camera-template-scroll'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: miniPageInset,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final template
                          in MiniPhoneCameraTemplate.values) ...[
                        if (template != MiniPhoneCameraTemplate.values.first)
                          const SizedBox(width: 12),
                        SizedBox(
                          width: 128,
                          child: MiniPhoneCameraTemplateChoice(
                            template: template,
                            strings: strings,
                            selected: prompt == template.prompt(strings),
                            onTap: () => onSelected(template),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MiniPhoneCameraPersonChoice extends StatelessWidget {
  const MiniPhoneCameraPersonChoice({
    super.key,
    required this.person,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PhonePerson person;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label == person.name ? label : '$label · ${person.name}',
    excludeSemantics: true,
    child: SizedBox(
      width: 76,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected ? miniWhite : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Opacity(
                      opacity: selected ? 1 : .65,
                      child: miniPhonePersonAvatar(person, 62, radius: 10),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      right: -2,
                      bottom: -2,
                      child: _CameraCheck(size: 19),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: miniStyle(
                  12,
                  FontWeight.w400,
                  selected ? miniWhite : miniSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MiniPhoneCameraTemplateChoice extends StatelessWidget {
  const MiniPhoneCameraTemplateChoice({
    super.key,
    required this.template,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final MiniPhoneCameraTemplate template;
  final MiniPhoneCameraStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: template.label(strings),
    excludeSemantics: true,
    child: Material(
      color: selected ? miniLine : miniRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? miniRed : miniLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Image.asset(
                    template.assetPath,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: miniRaised),
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: 5,
                    top: 5,
                    child: _CameraCheck(size: 17),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                template.label(strings),
                textAlign: TextAlign.center,
                style: miniStyle(
                  12,
                  FontWeight.w500,
                  selected ? miniWhite : miniSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CameraCheck extends StatelessWidget {
  const _CameraCheck({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: miniBackground, width: 2),
    ),
    child: const Icon(Icons.check, size: 11, color: miniBackground),
  );
}
