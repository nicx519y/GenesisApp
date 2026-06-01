import 'package:flutter/material.dart';

import '../platform/auth/auth_session.dart';

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
                    fontSize: 18,
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
      IdentityProvider.google => const Icon(
        Icons.g_mobiledata,
        size: 38,
        color: Color(0xFF4285F4),
      ),
      IdentityProvider.apple => const Icon(
        Icons.apple,
        size: 32,
        color: Colors.black,
      ),
    };
  }
}
