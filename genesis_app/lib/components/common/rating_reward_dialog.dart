import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/review/rating_prompt_store.dart';
import '../../l10n/genesis_localizations.dart';
import '../../network/v1/gem_api.dart';
import '../../platform/session/user_session_store.dart';
import '../../utils/api_error_message.dart';
import '../gems/gem_task_reward.dart';
import '../auth/login_guard.dart';
import 'genesis_action_box.dart';
import 'genesis_center_toast.dart';

// Published rating-task contract: 30 Gems per UID for a lifetime, not per review.
const ratingRewardGemsCent = 3000;
String _claimedKey(String uid) => RatingPromptStore.rewardClaimedKey(uid);

class RatingRewardDialog extends StatefulWidget {
  const RatingRewardDialog({super.key, required this.rating});
  final int rating;
  @override
  State<RatingRewardDialog> createState() => _RatingRewardDialogState();
}

class _RatingRewardDialogState extends State<RatingRewardDialog> {
  bool _claiming = false;
  bool _checking = true;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = await AppServicesScope.read(
        context,
      ).sessionStore.readLoginUid();
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(
          () => _claimed =
              uid != null && (prefs.getBool(_claimedKey(uid)) ?? false),
        );
        if (_claimed) Navigator.of(context).pop();
      }
    } catch (_) {
      // This is display-only deduplication; the server remains authoritative.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _claim() async {
    if (_claiming || _checking || _claimed) return;
    setState(() => _claiming = true);
    try {
      if (!await ensureGenesisLogin(context)) return;
      if (!mounted) return;
      final services = AppServicesScope.read(context);
      final revision = services.sessionRevision.value;
      final uid = await services.sessionStore.readLoginUid();
      if (uid == null ||
          !mounted ||
          services.sessionRevision.value != revision) {
        return;
      }
      final result = await services.api.v1.gem.claimTask(
        GemV1Api.ratingTaskCode,
      );
      if (!mounted ||
          services.sessionRevision.value != revision ||
          await services.sessionStore.readLoginUid() != uid) {
        return;
      }
      if (result.status != 'claimed') {
        throw StateError('Rating reward was not claimed');
      }
      // A storage failure must not turn a successful server grant into a failed grant.
      try {
        await (await SharedPreferences.getInstance()).setBool(
          _claimedKey(uid),
          true,
        );
      } catch (_) {}
      if (!mounted || services.sessionRevision.value != revision) return;
      // An older wallet request may have started before the grant. Wait for it
      // before fetching again rather than coalescing into the pre-grant result.
      await services.gemWallet.pendingRefresh;
      if (!mounted || services.sessionRevision.value != revision) return;
      await services.gemWallet.refresh();
      if (!mounted || services.sessionRevision.value != revision) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      final message = context.l10n.gemsClaimSuccessful;
      Navigator.of(context).pop();
      if (overlay != null) {
        showGenesisToastInOverlay(
          overlay,
          message,
          brightness: Brightness.dark,
        );
      }
    } catch (error) {
      if (mounted) {
        showGenesisToast(
          context,
          apiErrorMessage(error, fallback: context.l10n.gemsClaimFailed),
          brightness: Brightness.dark,
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: _checking || _claimed
          ? const SizedBox.shrink()
          : GenesisActionBox<void>(
              title: context.l10n.rateWorldoThanks,
              titleContent: const GemTaskReward(
                rewardGemsCent: ratingRewardGemsCent,
                showWholeReward: true,
              ),
              titleContentSpacing: 10,
              actions: [
                if (!_claimed)
                  GenesisActionBoxAction<void>(
                    label: context.l10n.gemsClaim,
                    value: null,
                    enabled: !_checking && !_claiming,
                  ),
              ],
              onActionSelected: (_) => _claim(),
              onCancel: () {
                if (!_claiming) Navigator.of(context).pop();
              },
            ),
    );
  }
}
