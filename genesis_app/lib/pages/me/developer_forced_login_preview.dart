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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: GenesisDarkTheme(
                  child: FilledButton.tonal(
                    key: const ValueKey('forced-login-preview-close'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Close preview'),
                  ),
                ),
              ),
            ),
            LoginSheet(
              isDismissible: false,
              linkPurchasedMembership: true,
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
          ],
        ),
      ),
    );
