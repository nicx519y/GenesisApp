import 'package:flutter/material.dart';

import '../../platform/auth/auth_session.dart';
import '../login_provider_button.dart';

class SignedOutMeView extends StatelessWidget {
  const SignedOutMeView({
    super.key,
    required this.loggingInProvider,
    required this.onLogin,
  });

  final IdentityProvider? loggingInProvider;
  final ValueChanged<IdentityProvider> onLogin;

  @override
  Widget build(BuildContext context) {
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
                          Image.asset(
                            'assets/images/worldo_logo.png',
                            width: 200,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'LIVE YOUR WORLD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 9,
                              color: Color(0xFF7A7A7A),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Launch world, create origin, invite\n'
                            'friends, and continue them anywhere.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        LoginProviderButton(
                          provider: IdentityProvider.google,
                          label: 'Continue with Google',
                          onPressed: loggingInProvider == null
                              ? () => onLogin(IdentityProvider.google)
                              : null,
                          isLoading:
                              loggingInProvider == IdentityProvider.google,
                        ),
                        const SizedBox(height: 18),
                        LoginProviderButton(
                          provider: IdentityProvider.apple,
                          label: 'Continue with Apple',
                          onPressed: loggingInProvider == null
                              ? () => onLogin(IdentityProvider.apple)
                              : null,
                          isLoading:
                              loggingInProvider == IdentityProvider.apple,
                        ),
                        const SizedBox(height: 38),
                        const _LegalText(),
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

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: Color(0xFF8A8A8A),
    );
    const linkStyle = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: Color(0xFF3E5B8A),
    );
    return const Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms', style: linkStyle),
          TextSpan(text: '\nand acknowledge our '),
          TextSpan(text: 'Privacy Policy', style: linkStyle),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
