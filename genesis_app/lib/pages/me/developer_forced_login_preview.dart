import 'package:flutter/material.dart';

import '../../components/common/genesis_modal_routes.dart';
import '../../components/login_sheet.dart';
import '../../platform/auth/auth_cancelled_exception.dart';
import '../../ui/theme/genesis_dark_theme.dart';

/// Shows the actual mandatory-login UI without creating an order, invoking
/// OAuth, changing the current session or enabling the production login gate.
Future<bool?> showDeveloperForcedLoginPreview(BuildContext context) =>
    showGenesisModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox.expand(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            LoginSheet(
              isDismissible: false,
              onLogin: (_) async {
                await Future<void>.delayed(const Duration(milliseconds: 450));
                // The sheet may still be mounted during its exit animation.
                // Do not let a late fake success pop the underlying page.
                if (!context.mounted ||
                    ModalRoute.of(context)?.isCurrent != true) {
                  throw const AuthCancelledException();
                }
                return true;
              },
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              right: 16,
              child: GenesisDarkTheme(
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.tonal(
                        key: const ValueKey('forced-login-preview-close'),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Close preview'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Preview only. Tap Google / Apple to simulate sign-in.',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
