import '../../app/startup/startup_prompt_sequence.dart';
import '../../platform/session/user_session_store.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/genesis_navigator.dart';
import '../../app/review/rating_prompt_store.dart';
import 'genesis_modal_routes.dart';
import 'rating_reward_dialog.dart';

/// Only the rating is persisted; server-side claim idempotency remains authoritative.
class PendingRatingReward {
  static bool flowActive = false;
  static String key(String owner) => 'rating_pending_reward_v1:$owner';

  static Future<String> owner(BuildContext context) async {
    final services = AppServicesScope.read(context);
    final uid = await services.sessionStore.readUid();
    return uid?.trim().isNotEmpty == true
        ? uid!
        : await services.deviceId.getDeviceId();
  }

  static Future<void> save(String owner, int rating) async {
    if (!await (await SharedPreferences.getInstance()).setInt(
      key(owner),
      rating,
    )) {
      throw StateError('Pending rating reward could not be saved');
    }
  }

  static Future<void> show(
    BuildContext context,
    String owner,
    int rating,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(RatingPromptStore.rewardClaimedKey(owner)) ?? false) {
      await prefs.remove(key(owner));
      return;
    }
    if (!context.mounted) return;
    TransitionRoute<dynamic>? route;
    await showGenesisDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        route = ModalRoute.of(context) as TransitionRoute<dynamic>?;
        return RatingRewardDialog(rating: rating);
      },
    );
    await route?.completed;
    await (await SharedPreferences.getInstance()).remove(key(owner));
  }
}

/// Deferred iOS rewards use the next app interaction, never a guessed delay.
class PendingRatingRewardHost extends StatefulWidget {
  const PendingRatingRewardHost({super.key, required this.child});
  final Widget child;
  @override
  State<PendingRatingRewardHost> createState() =>
      _PendingRatingRewardHostState();
}

class _PendingRatingRewardHostState extends State<PendingRatingRewardHost> {
  bool _opening = false;

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShow());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _tryShow() async {
    if (!mounted ||
        _opening ||
        PendingRatingReward.flowActive ||
        startupPromptSequence.blocksOtherPrompts) {
      return;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    final navigator = genesisNavigatorKey.currentState;
    final target = navigator?.overlay?.context;
    if (target == null) return;
    _opening = true;
    try {
      final services = AppServicesScope.read(context);
      final revision = services.sessionRevision.value;
      final owner = await services.sessionStore.readLoginUid();
      if (owner == null) return;
      final rating = (await SharedPreferences.getInstance()).getInt(
        PendingRatingReward.key(owner),
      );
      if (!mounted ||
          !target.mounted ||
          rating == null ||
          startupPromptSequence.blocksOtherPrompts ||
          services.sessionRevision.value != revision ||
          PendingRatingReward.flowActive) {
        return;
      }
      await PendingRatingReward.show(target, owner, rating);
    } catch (_) {
      // Keep the record for a later interaction if storage/navigation fails.
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerUp: (_) => _schedule(),
    child: widget.child,
  );
}
