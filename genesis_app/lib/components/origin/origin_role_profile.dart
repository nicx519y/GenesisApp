import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../l10n/genesis_localizations.dart';
import '../../network/json_utils.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../auth/login_guard.dart';
import '../common/genesis_center_toast.dart';
import 'origin_role_draft.dart';

Future<OriginCustomRoleDraft?> loadOriginRoleProfile(
  BuildContext context, {
  required LoginSource source,
  required String Function(Map<String, dynamic>) resolveAvatar,
}) async {
  if (!await ensureGenesisLogin(context, source: source) || !context.mounted) {
    return null;
  }
  final services = AppServicesScope.read(context);
  final revision = services.sessionRevision.value;
  Map<String, dynamic>? user;
  try {
    user = await services.sessionStore.readUserInfo();
  } catch (_) {
    // An unreadable profile follows the same path as a missing cached profile.
  }
  if (!context.mounted ||
      !identical(services, AppServicesScope.maybeRead(context)) ||
      revision != services.sessionRevision.value) {
    return null;
  }
  if (user == null || user.isEmpty) {
    showGenesisToast(
      context,
      context.l10n.worldDetailNoSavedProfileFound,
      brightness: Brightness.dark,
    );
    return null;
  }

  return OriginCustomRoleDraft(
    avatarUrl: resolveAvatar(user),
    name: _profileText(user, const [
      'name',
      'nickname',
      'user_name',
      'displayName',
      'display_name',
    ]),
    identity: _profileText(user, const ['identity']),
    bio: _profileText(user, const ['bio', 'description']),
  );
}

String _profileText(Map<String, dynamic> user, List<String> keys) {
  for (final key in keys) {
    final value = asString(user[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

class OriginRoleProfileFillAction extends StatelessWidget {
  const OriginRoleProfileFillAction({
    super.key,
    required this.filling,
    required this.onPressed,
  });

  final bool filling;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: filling ? null : onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            filling
                ? context.l10n.worldoLaunchFilling
                : context.l10n.worldoLaunchFillMyProfile,
            style: GenesisTypography.bodyStrong.copyWith(
              height: 1.1,
              color: GenesisColors.redSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
