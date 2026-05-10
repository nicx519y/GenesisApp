import 'package:flutter/material.dart';

import '../platform/google_sign_in_service.dart';

class GoogleLoginSheet extends StatefulWidget {
  const GoogleLoginSheet({super.key, required this.onLogin});

  final Future<bool> Function(String idToken) onLogin;

  @override
  State<GoogleLoginSheet> createState() => _GoogleLoginSheetState();
}

class _GoogleLoginSheetState extends State<GoogleLoginSheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    debugPrint('[Auth][GoogleLoginSheet] submit start');
    try {
      debugPrint('[Auth][GoogleLoginSheet] requesting idToken from Google');
      final token = await GoogleSignInService.signInAndGetIdToken();
      debugPrint(
        '[Auth][GoogleLoginSheet] idToken received, length=${token.length}',
      );
      debugPrint('[Auth][GoogleLoginSheet] calling backend login');
      final ok = await widget.onLogin(token);
      debugPrint('[Auth][GoogleLoginSheet] backend login result: $ok');
      if (!mounted) return;
      if (ok) {
        debugPrint('[Auth][GoogleLoginSheet] login success, closing sheet');
        Navigator.of(context).pop(true);
      } else {
        debugPrint('[Auth][GoogleLoginSheet] login failed: onLogin returned false');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Google 登录失败')));
      }
    } catch (e, st) {
      debugPrint('[Auth][GoogleLoginSheet] login exception: $e');
      debugPrint('[Auth][GoogleLoginSheet] stacktrace:\n$st');
      if (!mounted) return;
      final message = e.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Google 登录失败' : message)),
      );
    } finally {
      debugPrint('[Auth][GoogleLoginSheet] submit end');
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
              '登录后可使用该功能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '请使用 Google 登录继续。点击按钮会拉起 Google 账号选择。',
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
                    : const Icon(Icons.g_mobiledata, size: 22),
                label: const Text('Sign In With Google'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
