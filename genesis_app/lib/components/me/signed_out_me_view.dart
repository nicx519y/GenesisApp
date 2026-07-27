import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/components/genesis_svg_asset.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_color_token.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';

import '../../app/debug_floating_button_unlock.dart';
import '../../platform/auth/auth_session.dart';
import '../login_provider_button.dart';

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
    final colors = GenesisSemanticColors.of(context);
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 38),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.15),
                          GestureDetector(
                            key: const ValueKey<String>(
                              'signed-out-debug-button-restore',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleTopTap,
                            child: GenesisSvgAsset.asset(
                              'assets/svg/worldo-logo.svg',
                              key: const Key('signed_out_worldo_logo'),
                              width: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'LIVE YOUR WORLD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 9,
                              color: colors.color(
                                GenesisColorToken.textEmptyState,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Launch world, create worldo, invite\n'
                            'friends, and continue them anywhere.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: colors.color(
                                GenesisColorToken.textSecondaryStrong,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
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
