import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/auth/auth_session.dart';

const String _googleOauthIconAsset = 'assets/custom-icons/png/google_oauth.png';

class LoginProviderButtons extends StatelessWidget {
  const LoginProviderButtons({
    super.key,
    required this.loggingInProvider,
    required this.onLogin,
    this.spacing = 18,
  });

  final IdentityProvider? loggingInProvider;
  final FutureOr<void> Function(IdentityProvider provider) onLogin;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LoginProviderButton(
          provider: IdentityProvider.google,
          label: 'Continue with Google',
          onPressed: loggingInProvider == null
              ? () => onLogin(IdentityProvider.google)
              : null,
          isLoading: loggingInProvider == IdentityProvider.google,
        ),
        SizedBox(height: spacing),
        LoginProviderButton(
          provider: IdentityProvider.apple,
          label: 'Continue with Apple',
          onPressed: loggingInProvider == null
              ? () => onLogin(IdentityProvider.apple)
              : null,
          isLoading: loggingInProvider == IdentityProvider.apple,
        ),
      ],
    );
  }
}

class LoginLegalText extends StatelessWidget {
  const LoginLegalText({super.key});

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: Color(0xFF8A8A8A),
    );
    const linkStyle = TextStyle(
      fontSize: 12,
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

class LoginProviderButton extends StatelessWidget {
  const LoginProviderButton({
    super.key,
    required this.provider,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 62,
    this.borderRadius = 32,
    this.backgroundColor = const Color(0xFFF0F0F0),
    this.foregroundColor = Colors.black,
  });

  final IdentityProvider provider;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.55),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          alignment: Alignment.center,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: foregroundColor.withValues(alpha: 0.75),
                      ),
                    )
                  : _LoginProviderIcon(provider: provider),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginProviderIcon extends StatelessWidget {
  const _LoginProviderIcon({required this.provider});

  final IdentityProvider provider;

  @override
  Widget build(BuildContext context) {
    return switch (provider) {
      IdentityProvider.google => Image.asset(
        _googleOauthIconAsset,
        width: 38,
        height: 38,
        fit: BoxFit.contain,
      ),
      IdentityProvider.apple => const Icon(
        Icons.apple,
        size: 32,
        color: Colors.black,
      ),
    };
  }
}
