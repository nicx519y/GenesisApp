import '../../platform/session/user_session_store.dart';
import '../../app/debug/rating_prompt_debug_settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/genesis_navigator.dart';
import '../../app/review/rating_prompt_store.dart';
import '../../routers/app_router.dart';
import 'pending_rating_reward_host.dart';
import 'worldo_rating_dialog.dart';

final ratingPromptRouteObserver = RatingPromptRouteObserver();

/// The embedded chat navigators remain inside World/Worldo routes. Do not
/// interrupt them when closing a chat panel or a detail sheet within that route.
class RatingPromptRouteObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  VoidCallback? onExit;
  static const protectedNames = {
    RouteNames.locationChat,
    RouteNames.world,
    RouteNames.originWorld,
  };
  bool get canPresent =>
      _routes.isNotEmpty &&
      _routes.last is! PopupRoute &&
      !_routes.any((route) => protectedNames.contains(route.settings.name));

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) _routes.clear();
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    if (!protectedNames.contains(route.settings.name)) return;
    if (route is TransitionRoute<dynamic>) {
      route.completed.then((_) => onExit?.call());
    } else {
      onExit?.call();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
  }
}

class RatingPromptHost extends StatefulWidget {
  const RatingPromptHost({super.key, required this.child});
  final Widget child;
  @override
  State<RatingPromptHost> createState() => _RatingPromptHostState();
}

class _RatingPromptHostState extends State<RatingPromptHost> {
  bool _checking = false;
  bool _recheck = false;
  bool _exitObserved = false;
  @override
  void initState() {
    super.initState();
    ratingPromptRouteObserver.onExit = () {
      _exitObserved = true;
      _check();
    };
    RatingPromptStore.instance.changes.addListener(_afterCount);
  }

  @override
  void dispose() {
    ratingPromptRouteObserver.onExit = null;
    RatingPromptStore.instance.changes.removeListener(_afterCount);
    super.dispose();
  }

  bool get _available =>
      mounted &&
      ratingPromptRouteObserver.canPresent &&
      !PendingRatingReward.flowActive &&
      !PendingRatingReward.waitingForStore &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void _afterCount() {
    if (!_exitObserved) return;
    if (_checking) {
      _recheck = true;
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking || !_available) return;
    _checking = true;
    String? reservedOwner;
    bool presented = false;
    try {
      final services = AppServicesScope.read(context);
      final revision = services.sessionRevision.value;
      if (services.personalization.blocksOtherPrompts.value) return;
      final owner = await services.sessionStore.readLoginUid();
      if (owner == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(PendingRatingReward.key(owner))) return;
      final threshold = await RatingPromptDebugSettings.resolve(
        services.appGlobalConfig.value.ratingPromptMessageCount,
      );
      if (!_available || services.sessionRevision.value != revision) return;
      if (!await RatingPromptStore.instance.takePending(owner, threshold)) {
        return;
      }
      reservedOwner = owner;
      final latestThreshold = await RatingPromptDebugSettings.resolve(
        services.appGlobalConfig.value.ratingPromptMessageCount,
      );
      final target = genesisNavigatorKey.currentState?.overlay?.context;
      if (!_available ||
          target == null ||
          !target.mounted ||
          services.sessionRevision.value != revision ||
          latestThreshold <= 0) {
        return;
      }
      presented = true;
      await showWorldoRatingDialog(target);
    } catch (_) {
      // Prompt persistence must never break page navigation or message sending.
    } finally {
      if (!presented && reservedOwner != null) {
        try {
          await RatingPromptStore.instance.restorePending(reservedOwner);
        } catch (_) {}
      }
      _checking = false;
      if (_recheck && mounted) {
        _recheck = false;
        _check();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
