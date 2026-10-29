import 'auth/login_submission_state.dart';
import 'auth/login_route_completion.dart';
import '../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common/genesis_bottom_sheet_panel.dart';
import 'common/genesis_center_toast.dart';
import 'common/genesis_modal_routes.dart';
import 'login_provider_button.dart';
import 'gems/pro_membership_badge.dart';
import '../app/telemetry/genesis_telemetry.dart';
import '../platform/auth/auth_cancelled_exception.dart';
import '../platform/auth/auth_session.dart';
import '../ui/tokens/genesis_colors.dart';
import '../ui/components/genesis_dark_close_button.dart';
import '../ui/components/genesis_safe_area.dart';
import '../utils/api_error_message.dart';
import '../ui/theme/genesis_dark_theme.dart';

class LoginSheet extends StatefulWidget {
  const LoginSheet({
    super.key,
    required this.onLogin,
    this.isDismissible = true,
    this.linkPurchasedMembership = false,
    this.useSharedLoginSubmission = true,
  });

  final Future<bool> Function(IdentityProvider provider) onLogin;
  final bool isDismissible;
  final bool linkPurchasedMembership;

  /// Developer simulations must not publish a real app login result.
  final bool useSharedLoginSubmission;

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet>
    with LoginSubmissionState<LoginSheet> {
  IdentityProvider? get _submittingProvider => loginSubmittingProvider;
  @override
  bool get usesSharedLoginSubmission => widget.useSharedLoginSubmission;
  bool _completionScheduled = false;

  @override
  void onLoginSubmissionChanged() {
    if (!loginSubmissionSucceeded || _completionScheduled) return;
    _completionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _completionScheduled = false;
      if (loginSubmissionSucceeded) completeLoginRoute(context, true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _submit(IdentityProvider provider) => submitLogin(provider, (
    submission,
  ) async {
    debugPrint('[Auth][LoginSheet] submit start');
    try {
      debugPrint('[Auth][LoginSheet] requesting sign-in');
      final ok = await widget.onLogin(provider);
      debugPrint('[Auth][LoginSheet] login result: $ok');
      if (!submission.isActive) return;
      if (ok) {
        debugPrint('[Auth][LoginSheet] login success, closing sheet');
        submission.markSucceeded();
      } else if (mounted) {
        debugPrint('[Auth][LoginSheet] login failed: onLogin returned false');
        showGenesisToast(
          context,
          GenesisL10n.current.meSignInFailed,
          brightness: Brightness.dark,
        );
      }
    } on AuthCancelledException {
      debugPrint('[Auth][LoginSheet] login cancelled');
      GenesisTelemetry.event(
        'login_cancel',
        category: 'auth',
        data: <String, Object?>{'provider': provider.name},
      );
    } catch (e, st) {
      debugPrint('[Auth][LoginSheet] login exception: $e');
      debugPrint('[Auth][LoginSheet] stacktrace:\n$st');
      if (!mounted || !submission.isActive) return;
      showGenesisToast(
        context,
        loginErrorMessage(e),
        brightness: Brightness.dark,
      );
    } finally {
      debugPrint('[Auth][LoginSheet] submit end');
    }
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 18;
    final targetHeight = maxHeight < 342 ? maxHeight : 342.0;

    return PopScope(
      canPop: widget.isDismissible,
      child: GenesisDarkTheme(
        child: GenesisBottomSystemBarStyleScope(
          style: const GenesisBottomSystemBarStyle(
            color: GenesisColors.darkRaisedBackground,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: GenesisBottomSheetPanel(
              title: widget.linkPurchasedMembership
                  ? GenesisL10n.current.meSignUpClaimPremium
                  : GenesisL10n.current.meSignUpContinue,
              height: targetHeight,
              header: widget.linkPurchasedMembership
                  ? GenesisActionSheetHeader(
                      title: GenesisL10n.current.meSignUpClaimPremium,
                      leading: ProMembershipBadge.beside(fontSize: 18),
                    )
                  : null,
              trailing: widget.isDismissible
                  ? GenesisDarkCloseButton(
                      onPressed: _submittingProvider != null
                          ? null
                          : () {
                              GenesisTelemetry.event(
                                'login_cancel',
                                category: 'auth',
                                data: const <String, Object?>{
                                  'source': 'close_button',
                                },
                              );
                              Navigator.of(context).pop(false);
                            },
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.linkPurchasedMembership) ...[
                    const LoginSignupRewardText(),
                    const SizedBox(height: 12),
                  ],
                  LoginProviderButtons(
                    loggingInProvider: _submittingProvider,
                    onLogin: _submit,
                    spacing: 12,
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: LoginLegalText(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showLoginSheet({
  required BuildContext context,
  required Future<bool> Function(IdentityProvider provider) onLogin,
  bool isDismissible = true,
  bool linkPurchasedMembership = false,
}) async {
  // Forget the field's focus before pushing the route so closing login cannot
  // restore it and briefly reopen the keyboard.
  FocusManager.instance.primaryFocus?.unfocus();
  final loggedIn = await showGenesisModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useRootNavigator: !isDismissible,
    builder: (_) => LoginSheet(
      onLogin: onLogin,
      isDismissible: isDismissible,
      linkPurchasedMembership: linkPurchasedMembership,
    ),
  );
  return loggedIn == true;
}
