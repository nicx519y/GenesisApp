import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/debug_floating_button_unlock.dart';
import '../../platform/auth/auth_session.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_radii.dart';
import '../login_provider_button.dart';

const double _logoWidth = 168;

/// Sign-up incentive, shown only on the full signed-out page — the login sheet
/// interrupts a task and stays free of promos.
const String _signUpBonusCopy = 'Sign up and get 200 gems!';
const double _bonusBubbleHeight = 28;
const double _bonusTailWidth = 14;
const double _bonusTailHeight = 7;
const double _bonusTailToButtonGap = 12;
const double _lockupTopFraction = 0.27;

class SignedOutMeView extends StatefulWidget {
  const SignedOutMeView({
    super.key,
    required this.loggingInProvider,
    required this.onLogin,
  });

  final IdentityProvider? loggingInProvider;
  final ValueChanged<IdentityProvider> onLogin;

  @override
  State<SignedOutMeView> createState() => _SignedOutMeViewState();
}

class _SignedOutMeViewState extends State<SignedOutMeView> {
  static const int _debugButtonUnlockTapCount = 10;

  int _topTapCount = 0;

  void _handleTopTap() {
    final nextCount = _topTapCount + 1;
    if (nextCount < _debugButtonUnlockTapCount) {
      _topTapCount = nextCount;
      return;
    }
    _topTapCount = 0;
    unawaited(requestGenesisDebugFloatingButtonUnlock(context));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: signedOutHorizontalInset,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight * _lockupTopFraction,
                          ),
                          GestureDetector(
                            key: const ValueKey<String>(
                              'signed-out-debug-button-restore',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleTopTap,
                            child: SvgPicture.asset(
                              'assets/svg/worldo-logo.svg',
                              key: const Key('signed_out_worldo_logo'),
                              width: _logoWidth,
                              fit: BoxFit.contain,
                              // Brand lockup on the 95% soft-white tier, the
                              // same value the splash wordmark is baked at.
                              colorFilter: ColorFilter.mode(
                                context.genesisColors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            'YOUR LIVING AI WORLDS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              // Tracking drops from 9 to 5 because the line
                              // grew by six characters; the tagline keeps its
                              // ~239 optical width and stays 1.4x the logo.
                              letterSpacing: 5,
                              color: context.genesisColors.textTagline,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            signedOutSupportingCopy,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: context.genesisColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const _SignUpBonusBubble(),
                        const SizedBox(height: _bonusTailToButtonGap),
                        LoginProviderButtons(
                          loggingInProvider: widget.loggingInProvider,
                          onLogin: widget.onLogin,
                        ),
                        const SizedBox(height: 38),
                        const LoginLegalText(),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Reference-style promo bubble: a chip with a tail aimed at the first
/// provider button. It rides [textPrimary]/[textInverse], so it is a white
/// pill with dark text on the dark skin and flips to an ink pill on the light
/// one, where a white pill would vanish into the paper ground.
class _SignUpBonusBubble extends StatelessWidget {
  const _SignUpBonusBubble();

  @override
  Widget build(BuildContext context) {
    final background = context.genesisColors.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey<String>('signed-out-signup-bonus'),
          height: _bonusBubbleHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(GenesisRadii.compactControl),
          ),
          // Center rather than Container.alignment: an aligned Container grows
          // to the widest constraint, which would stretch the chip full width.
          child: Center(
            widthFactor: 1,
            child: Text(
              _signUpBonusCopy,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w400,
                color: context.genesisColors.textInverse,
              ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(_bonusTailWidth, _bonusTailHeight),
          painter: _BonusTailPainter(color: background),
        ),
      ],
    );
  }
}

class _BonusTailPainter extends CustomPainter {
  const _BonusTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BonusTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
