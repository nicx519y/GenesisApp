import 'package:flutter/material.dart';

import 'common/genesis_bottom_sheet_panel.dart';
import 'common/genesis_center_toast.dart';
import 'login_provider_button.dart';
import '../platform/auth/auth_cancelled_exception.dart';
import '../platform/auth/auth_session.dart';

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key, required this.onLogin});

  final Future<bool> Function(IdentityProvider provider) onLogin;

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  IdentityProvider? _submittingProvider;

  Future<void> _submit(IdentityProvider provider) async {
    if (_submittingProvider != null) return;
    setState(() => _submittingProvider = provider);
    debugPrint('[Auth][LoginSheet] submit start');
    try {
      debugPrint('[Auth][LoginSheet] requesting sign-in');
      final ok = await widget.onLogin(provider);
      debugPrint('[Auth][LoginSheet] login result: $ok');
      if (!mounted) return;
      if (ok) {
        debugPrint('[Auth][LoginSheet] login success, closing sheet');
        Navigator.of(context).pop(true);
      } else {
        debugPrint('[Auth][LoginSheet] login failed: onLogin returned false');
        showGenesisToast(context, 'Sign-in failed');
      }
    } on AuthCancelledException {
      debugPrint('[Auth][LoginSheet] login cancelled');
    } catch (e, st) {
      debugPrint('[Auth][LoginSheet] login exception: $e');
      debugPrint('[Auth][LoginSheet] stacktrace:\n$st');
      if (!mounted) return;
      final message = e.toString().trim();
      showGenesisToast(context, message.isEmpty ? 'Sign-in failed' : message);
    } finally {
      debugPrint('[Auth][LoginSheet] submit end');
      if (mounted) setState(() => _submittingProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 18;
    final targetHeight = maxHeight < 360 ? maxHeight : 360.0;

    return GenesisBottomSheetPanel(
      title: 'Sign in to continue',
      height: targetHeight,
      titleBottomSpacing: 14,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
      ),
      trailing: IconButton(
        onPressed: _submittingProvider != null
            ? null
            : () => Navigator.of(context).pop(false),
        icon: const Icon(Icons.close),
        iconSize: 22,
        color: Colors.black,
        tooltip: 'Close',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Use your Google or Apple account to continue.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          LoginProviderButtons(
            loggingInProvider: _submittingProvider,
            onLogin: _submit,
          ),
          const SizedBox(height: 18),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: LoginLegalText(),
            ),
          ),
        ],
      ),
    );
  }
}
