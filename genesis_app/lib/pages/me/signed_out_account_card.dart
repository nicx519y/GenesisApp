import 'package:flutter/material.dart';

import '../../l10n/genesis_localizations.dart';
import '../../ui/genesis_ui.dart';

/// Account status and an explicit sign-in action; privacy remains independent.
class SignedOutAccountCard extends StatelessWidget {
  const SignedOutAccountCard({
    super.key,
    required this.onSignIn,
    this.openingLogin = false,
  });

  final VoidCallback onSignIn;
  final bool openingLogin;

  @override
  Widget build(BuildContext context) {
    final button = GenesisPrimaryButton(
      key: const ValueKey('account-sign-in'),
      label: context.l10n.settingsAccountSignIn,
      onPressed: onSignIn,
      fullWidth: false,
      height: (MediaQuery.textScalerOf(context).scale(14) * 1.4 + 12)
          .clamp(36.0, double.infinity)
          .toDouble(),
      fontSize: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      isLoading: openingLogin,
      showLoadingIndicator: false,
    );
    final status = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.settingsNotSignedIn,
                style: const TextStyle(
                  color: GenesisColors.darkTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.settingsAccountSignInDescription,
                style: const TextStyle(
                  color: GenesisColors.darkTextSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return DecoratedBox(
      key: const ValueKey('signed-out-account-card'),
      decoration: BoxDecoration(
        color: GenesisColors.darkFaintFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(child: status),
            const SizedBox(width: 12),
            button,
          ],
        ),
      ),
    );
  }
}
