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
                              fontSize: 12,
                              height: 1.35,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        LoginProviderButtons(
                          loggingInProvider: loggingInProvider,
                          onLogin: onLogin,
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
