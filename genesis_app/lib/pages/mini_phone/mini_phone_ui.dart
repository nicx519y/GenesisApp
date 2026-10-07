import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../ui/tokens/genesis_blur.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../ui/tokens/genesis_spacing.dart';
import '../../ui/tokens/genesis_radii.dart';
import '../../ui/components/genesis_dark_close_button.dart';
import 'mini_phone_demo_store.dart';

const miniBackground = GenesisColors.darkBackground;
const miniRaised = GenesisColors.darkRaisedBackground;
const miniPink = GenesisColors.redSecondary;
const miniRed = GenesisColors.redPrimary;
const miniWhite = GenesisColors.darkTextPrimary;
const miniSecondary = GenesisColors.darkTextSecondary;
const miniTertiary = GenesisColors.darkTextTertiary;
const miniPlaceholder = GenesisColors.darkInputPlaceholder;
const miniLine = GenesisColors.darkFaintFill;
const miniDivider = Color(0x0DFFFFFF);
const miniPageInset = GenesisSpacing.page;
const miniInputRadius = GenesisRadii.input;
const miniButtonRadius = GenesisRadii.button;
final miniPageTitle = GenesisTypography.pageTitle.copyWith(color: miniWhite);
final miniSectionTitle = GenesisTypography.bodyStrong.copyWith(
  fontSize: 16,
  color: miniWhite,
);

TextStyle miniStyle([
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = miniWhite,
]) => (size <= 12 ? GenesisTypography.supporting : GenesisTypography.body)
    .copyWith(fontSize: size, fontWeight: weight, color: color);

class MiniIcon extends StatelessWidget {
  const MiniIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = miniWhite,
  });
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    '${miniPhoneAssets}icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class MiniAvatar extends StatelessWidget {
  const MiniAvatar(this.person, {super.key, this.size = 40});
  final MiniDemoPerson person;
  final double size;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset(
      '$miniPhoneAssets${person.image}',
      width: size,
      height: size,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -.6),
      semanticLabel: person.name,
    ),
  );
}

class MiniGlass extends StatelessWidget {
  const MiniGlass({
    super.key,
    required this.child,
    this.radius = 21,
    this.opacity = .42,
    this.light = false,
    this.outlined = true,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius, opacity;
  final bool light, outlined;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: GenesisBlur.strong,
        sigmaY: GenesisBlur.strong,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: (light ? Colors.white : miniRaised).withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
          border: outlined
              ? Border.all(
                  color: light
                      ? const Color(0x40FFFFFF)
                      : const Color(0x33F4F3F6),
                )
              : null,
          gradient: light
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .1),
                    Colors.white.withValues(alpha: .02),
                  ],
                ),
        ),
        child: child,
      ),
    ),
  );
}

class MiniBadge extends StatelessWidget {
  const MiniBadge(this.count, {super.key});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: miniRed,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: GenesisTypography.supporting.copyWith(
        color: miniWhite,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class MiniIconButton extends StatelessWidget {
  const MiniIconButton(
    this.icon,
    this.label,
    this.onPressed, {
    super.key,
    this.glass = false,
  });
  final String icon, label;
  final VoidCallback? onPressed;
  final bool glass;
  @override
  Widget build(BuildContext context) {
    if (icon == 'close' && !glass) {
      return GenesisDarkCloseButton(onPressed: onPressed);
    }
    final button = IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      icon: MiniIcon(icon, size: 18),
    );
    return glass
        ? MiniGlass(radius: 13, child: button)
        : Container(
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: button,
          );
  }
}

class MiniPhoneDemoEntry extends StatefulWidget {
  const MiniPhoneDemoEntry({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<MiniPhoneDemoEntry> createState() => _MiniPhoneDemoEntryState();
}

class _MiniPhoneDemoEntryState extends State<MiniPhoneDemoEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival;
  int _unread = 0;
  @override
  void initState() {
    super.initState();
    _arrival = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _unread = miniPhoneDemoStore.totalUnread;
    miniPhoneDemoStore.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _unread > 0 && !MediaQuery.disableAnimationsOf(context)) {
        _arrival.forward();
      }
    });
  }

  void _changed() {
    final unread = miniPhoneDemoStore.totalUnread;
    if (unread > _unread && !MediaQuery.disableAnimationsOf(context)) {
      _arrival.forward(from: 0);
    }
    if (unread == 0) _arrival.stop();
    setState(() => _unread = unread);
  }

  @override
  void dispose() {
    miniPhoneDemoStore.removeListener(_changed);
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Open Mini phone, $_unread unread messages',
    button: true,
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _arrival,
        builder: (context, child) {
          final seconds = _arrival.value * 3;
          final vibrating = _arrival.isAnimating && seconds < .76;
          final wave = vibrating
              ? math.sin(seconds / .76 * math.pi * 8) * (1 - seconds / .76)
              : 0.0;
          final visible = _unread > 0 && _arrival.isAnimating;
          final alpha = visible
              ? (_arrival.value < .1
                    ? _arrival.value / .1
                    : _arrival.value > .85
                    ? (1 - _arrival.value) / .15
                    : 1.0)
              : 0.0;
          final reveal = (_arrival.isAnimating ? seconds / .9 : 1.0).clamp(
            0.0,
            1.0,
          );
          return SizedBox(
            width: 34,
            height: 57,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: Offset(wave * 1.2, 0),
                  child: Transform.rotate(
                    angle: wave * math.pi / 22,
                    child: child,
                  ),
                ),
                if (_unread > 0)
                  Positioned(
                    right: -5,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: miniRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$_unread',
                          style: miniStyle(
                            9,
                            FontWeight.w600,
                          ).copyWith(height: 1),
                        ),
                      ),
                    ),
                  ),
                if (visible)
                  Positioned(
                    left: -1,
                    top: -48,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: alpha.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, (1 - alpha) * 8),
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 14,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: MiniAvatar(
                                  miniDemoPeople.first,
                                  size: 32,
                                ),
                              ),
                              CustomPaint(
                                size: const Size(12, 6),
                                painter: _MiniPhonePointer(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_unread > 0)
                  Positioned(
                    top: 28,
                    left: 5,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: reveal,
                        child: Transform.translate(
                          offset: Offset(0, (1 - reveal) * 7),
                          child: Container(
                            width: 24,
                            height: 12,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0x1CFFFFFF),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF929294),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 1.5,
                                      color: const Color(0xFFC9C9CB),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 7,
                                      height: 1.5,
                                      color: const Color(0xFF8D8D90),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        child: Container(
          width: 34,
          height: 57,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF454647), Color(0xFF151718), Color(0xFF303435)],
              stops: [0, .55, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(width: 11, height: 2, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                '01:04',
                style: miniStyle(
                  7,
                  FontWeight.w900,
                ).copyWith(height: 1, letterSpacing: -.175),
              ),
              const Spacer(),
              Container(width: 12, height: 2, color: Colors.white),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MiniPhonePointer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = Colors.white,
  );
  @override
  bool shouldRepaint(_MiniPhonePointer oldDelegate) => false;
}
