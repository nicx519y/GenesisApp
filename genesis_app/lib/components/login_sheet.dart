import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/auth/auth_cancelled_exception.dart';

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key, required this.onLogin});

  final Future<bool> Function() onLogin;

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  bool _submitting = false;

  bool get _usesApple => !kIsWeb && Platform.isIOS;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    debugPrint('[Auth][LoginSheet] submit start');
    try {
      debugPrint('[Auth][LoginSheet] requesting sign-in');
      final ok = await widget.onLogin();
      debugPrint('[Auth][LoginSheet] login result: $ok');
      if (!mounted) return;
      if (ok) {
        debugPrint('[Auth][LoginSheet] login success, closing sheet');
        Navigator.of(context).pop(true);
      } else {
        debugPrint('[Auth][LoginSheet] login failed: onLogin returned false');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sign-in failed')));
      }
    } on AuthCancelledException {
      debugPrint('[Auth][LoginSheet] login cancelled');
    } catch (e, st) {
      debugPrint('[Auth][LoginSheet] login exception: $e');
      debugPrint('[Auth][LoginSheet] stacktrace:\n$st');
      if (!mounted) return;
      final message = e.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Sign-in failed' : message)),
      );
    } finally {
      debugPrint('[Auth][LoginSheet] submit end');
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign in to continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _usesApple
                  ? 'Use your Apple account to continue.'
                  : 'Use your Google account to continue. Tapping the button will open account selection.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _usesApple ? Icons.apple : Icons.g_mobiledata,
                        size: 22,
                      ),
                label: Text(
                  _usesApple ? 'Sign In With Apple' : 'Sign In With Google',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
