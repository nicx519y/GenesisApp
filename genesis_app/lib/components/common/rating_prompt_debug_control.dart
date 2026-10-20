import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../platform/session/user_session_store.dart';
import '../../ui/genesis_ui.dart';
import 'genesis_center_toast.dart';
import 'worldo_rating_dialog.dart';

/// The developer entry is always visible; the rating flow still requires login.
class RatingPromptDebugSection extends StatefulWidget {
  const RatingPromptDebugSection({super.key, this.spacing = 12});
  final double spacing;

  @override
  State<RatingPromptDebugSection> createState() =>
      _RatingPromptDebugSectionState();
}

class _RatingPromptDebugSectionState extends State<RatingPromptDebugSection> {
  bool _openingRateDialog = false;

  Future<void> _showRateDialog() async {
    if (_openingRateDialog) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final services = AppServicesScope.read(context);
    final revision = services.sessionRevision.value;
    final loginUid = await services.sessionStore.readLoginUid();
    if (!mounted || services.sessionRevision.value != revision) return;
    if (loginUid == null) {
      showGenesisToast(
        context,
        'Available after signing in',
        brightness: Brightness.dark,
      );
      return;
    }
    final routeNavigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final target = rootNavigator.overlay?.context ?? rootNavigator.context;
    setState(() => _openingRateDialog = true);
    try {
      if (route != null && routeNavigator.canPop()) {
        final dismissed = await routeNavigator.maybePop();
        if (!dismissed || route.isCurrent) return;
        // maybePop finishes before the sheet/page's reverse transition does.
        // Keep the preview off the developer UI and its soon-disposed context.
        await route.completed;
      }
      if (!target.mounted || services.sessionRevision.value != revision) return;
      await showWorldoRatingDialog(target);
    } finally {
      if (mounted) setState(() => _openingRateDialog = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GenesisPrimaryButton(
        key: const ValueKey('developer-rate-button'),
        label: 'Rate Dialog',
        onPressed: _openingRateDialog ? null : _showRateDialog,
        backgroundColor: GenesisColors.darkFaintFill,
        foregroundColor: GenesisColors.darkTextPrimary,
      ),
      SizedBox(height: widget.spacing),
    ],
  );
}
