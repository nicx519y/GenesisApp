import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/auth/login_guard.dart';
import '../../components/auth/login_route_completion.dart';
import '../../components/auth/login_submission_state.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/me/signed_out_me_view.dart';
import '../../l10n/genesis_l10n.dart';
import '../../platform/auth/auth_cancelled_exception.dart';
import '../../platform/auth/auth_session.dart';
import '../../ui/navigation/genesis_dark_page_route.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../utils/api_error_message.dart';
import 'settings_page.dart';

Route<bool> createForceLoginRoute({
  required RouteSettings settings,
  Future<bool> Function(IdentityProvider)? onLogin,
}) => GenesisDarkPageRoute<bool>(
  settings: settings,
  builder: (_) => ForceLoginPage(onLogin: onLogin),
);

/// The existing signed-out Me content, without the app shell or bottom tabs.
class ForceLoginPage extends StatefulWidget {
  const ForceLoginPage({super.key, this.onLogin});

  final Future<bool> Function(IdentityProvider)? onLogin;

  @override
  State<ForceLoginPage> createState() => _ForceLoginPageState();
}

class _ForceLoginPageState extends State<ForceLoginPage>
    with LoginSubmissionState<ForceLoginPage> {
  Future<void> _login(IdentityProvider provider) => submitLogin(provider, (
    submission,
  ) async {
    try {
      final ok =
          await (widget.onLogin?.call(provider) ??
              loginGenesisWithProvider(
                context,
                provider,
                source: LoginSource.forceLogin,
              ));
      if (!mounted || !submission.isActive) return;
      if (ok) {
        submission.markSucceeded();
        completeLoginRoute(context, true);
      } else if (mounted) {
        showGenesisToast(
          context,
          GenesisL10n.current.meSignInFailed,
          brightness: Brightness.dark,
        );
      }
    } on AuthCancelledException {
      // Provider cancellation leaves the required login page available to retry.
    } catch (error, stack) {
      debugPrint('[Auth][ForceLogin] login failed: $error\n$stack');
      if (!mounted || !submission.isActive) return;
      showGenesisToast(
        context,
        loginErrorMessage(error),
        brightness: Brightness.dark,
      );
    }
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      key: const ValueKey('force-login-page'),
      backgroundColor: GenesisColors.darkBackground,
      body: Stack(
        children: [
          SignedOutMeView(
            loggingInProvider: loginSubmittingProvider,
            onLogin: (provider) => unawaited(_login(provider)),
          ),
          Positioned(
            top: 0,
            right: 4,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                key: const ValueKey('me-settings-button'),
                onPressed: () => Navigator.of(context).push<bool>(
                  GenesisDarkPageRoute<bool>(
                    builder: (_) => const SettingsPage(),
                  ),
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.settings, size: 24),
                color: GenesisColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
