import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/config/app_global_config.dart';
import '../../app/debug/membership_guest_login_debug_settings.dart';
import '../../app/gems/daily_check_in_coordinator.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/onboarding/personalization_store.dart';
import '../../platform/auth/auth_session.dart';
import '../../routers/app_router.dart';
import '../auth/login_guard.dart';
import '../common/genesis_modal_routes.dart';
import '../gems/pro_subscription_content.dart';
import 'personalization_sheet.dart';

/// Resolves paid guest login before loading the current identity's profile.
class PersonalizationGate extends StatefulWidget {
  const PersonalizationGate({
    super.key,
    required this.store,
    required this.appConfig,
    required this.navigatorKey,
    required this.child,
    this.loginPending,
    this.checkGuestPurchases,
    this.requestRequiredLogin,
    this.membershipAccess,
    this.signIn,
    this.subscriptionBuilder,
  });
  final PersonalizationStore store;
  final ValueListenable<AppGlobalConfig> appConfig;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final ValueListenable<String?>? loginPending;
  final Future<void> Function()? checkGuestPurchases;
  final Future<bool> Function(BuildContext)? requestRequiredLogin;
  final MembershipAccessStore? membershipAccess;
  final Future<void> Function(BuildContext, IdentityProvider)? signIn;
  final WidgetBuilder? subscriptionBuilder;

  @override
  State<PersonalizationGate> createState() => _PersonalizationGateState();
}

class _PersonalizationGateState extends State<PersonalizationGate>
    with WidgetsBindingObserver {
  bool _showing = false;
  bool _scheduled = false;
  bool _saved = false;
  bool _authenticating = false;
  bool _preparing = false;
  bool _startupReady = false;
  bool _completedRequiredLogin = false;
  String? _preparedUid;
  int _startupRevision = 0;
  final _requiresSignIn = ValueNotifier(false);
  Timer? _retry;
  int _failures = 0;
  ModalRoute<PersonalizationProfile>? _route;

  @override
  void initState() {
    super.initState();
    widget.store.setEnabled(widget.appConfig.value.showPersonalizationForm);
    WidgetsBinding.instance.addObserver(this);
    widget.appConfig.addListener(_configChanged);
    widget.store.state.addListener(_schedule);
    widget.loginPending?.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(PersonalizationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.store, widget.store)) {
      widget.store.setEnabled(widget.appConfig.value.showPersonalizationForm);
      final route = _route;
      if (route != null && route.isActive) route.navigator?.removeRoute(route);
      oldWidget.store.state.removeListener(_schedule);
      widget.store.state.addListener(_schedule);
      _retry?.cancel();
      _retry = null;
      _startupRevision++;
      _preparing = false;
      _startupReady = false;
      _completedRequiredLogin = false;
      _preparedUid = null;
    }
    if (!identical(oldWidget.loginPending, widget.loginPending)) {
      oldWidget.loginPending?.removeListener(_schedule);
      widget.loginPending?.addListener(_schedule);
    }
    if (!identical(oldWidget.appConfig, widget.appConfig)) {
      oldWidget.appConfig.removeListener(_configChanged);
      widget.appConfig.addListener(_configChanged);
      _configChanged();
    }
    _schedule();
  }

  void _configChanged() {
    // The flag controls entry. Let an already-open form/login/purchase finish.
    if (_showing) return;
    final enabled = widget.appConfig.value.showPersonalizationForm;
    if (widget.store.isEnabled != enabled) {
      widget.store.setEnabled(enabled);
      _retry?.cancel();
      _retry = null;
      _failures = 0;
      _startupReady = false;
      if (!_preparing) _completedRequiredLogin = false;
    }
    _schedule();
  }

  bool get _foreground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_startupReady &&
          !_preparing &&
          widget.store.state.value.error != null) {
        unawaited(widget.store.refresh());
      }
      _schedule();
    }
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_update());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _update() async {
    if (!_foreground || _preparing) return;
    final store = widget.store;
    final snapshot = store.state.value;
    if (!_showing && snapshot.data != null && snapshot.uid != _preparedUid) {
      _startupReady = false;
      _completedRequiredLogin = false;
    }
    if (!_startupReady) {
      if (_retry == null) await _prepareStartup();
      return;
    }
    if (!store.isEnabled) return;
    if (!_showing &&
        snapshot.data != null &&
        snapshot.uid == null &&
        widget.loginPending?.value != null &&
        membershipGuestLoginDebugSettings.forceLogin) {
      _startupReady = false;
      await _prepareStartup();
      return;
    }
    if (snapshot.error != null && _retry == null) {
      // Failed reads never mean completed. Retry without a fabricated form.
      _retry = Timer(Duration(seconds: 2 << math.min(_failures++, 4)), () {
        _retry = null;
        if (mounted && _foreground) unawaited(store.refresh());
      });
    } else if (snapshot.error == null) {
      _retry?.cancel();
      _retry = null;
      if (snapshot.data != null) _failures = 0;
    }
    if (_showing) {
      // Login may have succeeded while the first profile read failed. A later
      // successful read can finish the form without requiring another login.
      if (!_saved &&
          !_authenticating &&
          snapshot.data?.profile.completed == true &&
          _route?.isCurrent == true) {
        _route!.navigator?.pop(snapshot.data!.profile);
        return;
      }
      // A background retry can discover an order after the initial check. Keep its
      // route open so the separate guest login gate cannot stack another sheet.
      if (snapshot.uid == null &&
          widget.loginPending?.value != null &&
          membershipGuestLoginDebugSettings.forceLogin &&
          _route?.isCurrent == true) {
        _requiresSignIn.value = true;
      }
      return;
    }
    final data = snapshot.data;
    final navigator = widget.navigatorKey.currentState;
    final context = navigator?.overlay?.context;
    if (data == null ||
        data.profile.completed ||
        context == null ||
        !context.mounted) {
      return;
    }
    _showing = true;
    _saved = false;
    _requiresSignIn.value = _completedRequiredLogin;
    store.beginPresentation();
    try {
      await showGenesisModalBottomSheet<PersonalizationProfile>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          _route = ModalRoute.of<PersonalizationProfile>(sheetContext);
          return AnimatedBuilder(
            animation: Listenable.merge([store.state, _requiresSignIn]),
            builder: (_, _) {
              final current = store.state.value;
              return PersonalizationSheet(
                form: (current.data ?? data).form,
                initialProfile: data.profile,
                initiallySignedIn: current.uid != null || snapshot.uid != null,
                requiresSignIn: _requiresSignIn.value,
                onSignIn: (provider) async {
                  _authenticating = true;
                  try {
                    final login = widget.signIn;
                    if (login != null) {
                      await login(sheetContext, provider);
                    } else {
                      await loginGenesisWithProvider(sheetContext, provider);
                    }
                    if (!mounted || !sheetContext.mounted) return null;
                    // Cancellation must not reuse the completed guest profile
                    // as proof of a successful account login.
                    if (await store.readLoginUid() == null) return null;
                    _saved = false;
                    final updated = await store.refresh();
                    if (updated == null) {
                      throw StateError('Profile lookup failed after login');
                    }
                    if (sheetContext.mounted &&
                        AppServicesScope.maybeRead(sheetContext) != null) {
                      await scheduleDailyCheckInAfterLogin(sheetContext);
                    }
                    return updated.profile;
                  } finally {
                    _authenticating = false;
                    _schedule();
                  }
                },
                onSubmit: (profile) async {
                  await store.submit(profile);
                  if (!mounted ||
                      !sheetContext.mounted ||
                      !identical(store, widget.store)) {
                    return PersonalizationNextStep.close;
                  }
                  _saved = true;
                  // Startup already resolved paid guest login. Continue only
                  // saves this identity's profile and chooses its next page.
                  if (_requiresSignIn.value) {
                    return store.state.value.uid == null
                        ? PersonalizationNextStep.requiredSignIn
                        : PersonalizationNextStep.close;
                  }
                  final membership =
                      widget.membershipAccess ??
                      AppServicesScope.maybeRead(sheetContext)?.membership;
                  if (membership != null) {
                    final savedUid = store.state.value.uid;
                    final result = Completer<bool?>();
                    membership.checkVip(result.complete);
                    final isVip = await result.future;
                    // Saving already succeeded. Only confirmed non-members
                    // should proceed to the subscription offer.
                    if (!mounted ||
                        !sheetContext.mounted ||
                        !identical(store, widget.store) ||
                        store.state.value.uid != savedUid ||
                        isVip != false) {
                      return PersonalizationNextStep.close;
                    }
                  }
                  return PersonalizationNextStep.subscription;
                },
                subscriptionBuilder:
                    widget.subscriptionBuilder ??
                    (_) => const ProSubscriptionContent(
                      topSpacing: 0,
                      horizontalInset: 0,
                      closeOnPurchaseSuccess: true,
                    ),
              );
            },
          );
        },
      );
      if (mounted &&
          identical(store, widget.store) &&
          _requiresSignIn.value &&
          !_completedRequiredLogin &&
          store.state.value.data?.profile.completed == true &&
          await store.readLoginUid() != null &&
          mounted) {
        // Preserve the original guest checkout destination. Session login
        // already starts claim/retry in MembershipPurchaseService.
        unawaited(
          widget.navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
            RouteNames.me,
            (_) => false,
          ),
        );
      }
    } finally {
      _route = null;
      _showing = false;
      store.endPresentation();
      if (mounted) _configChanged();
    }
  }

  Future<void> _prepareStartup() async {
    final store = widget.store;
    final revision = _startupRevision;
    bool current() =>
        mounted &&
        identical(store, widget.store) &&
        revision == _startupRevision;
    _preparing = true;
    // Keep the independent login/check-in gates from stacking another modal.
    store.beginPresentation();
    try {
      var uid = await store.readLoginUid();
      if (!current()) return;
      if (uid == null) {
        if (widget.loginPending?.value == null) {
          await widget.checkGuestPurchases?.call();
        }
        if (!current()) return;
        final forceLogin = await membershipGuestLoginDebugSettings.load();
        if (!current()) return;
        uid = await store.readLoginUid();
        if (!current()) return;
        if (uid == null && widget.loginPending?.value != null && forceLogin) {
          if (!_foreground) return;
          final context = widget.navigatorKey.currentState?.overlay?.context;
          if (context == null || !context.mounted) return;
          final login = widget.requestRequiredLogin;
          final loggedIn = login != null
              ? await login(context)
              : await ensureGenesisLogin(
                  context,
                  continueAfterLogin: true,
                  isDismissible: false,
                  forceLoginRequired: kDebugMode
                      ? membershipGuestLoginDebugSettings.listenable
                      : null,
                );
          if (!current()) return;
          uid = await store.readLoginUid();
          if (!current()) return;
          if (!loggedIn || uid == null) return;
          _completedRequiredLogin = true;
          // Session login starts claim/retry independently of onboarding.
          unawaited(
            widget.navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
              RouteNames.me,
              (_) => false,
            ),
          );
        }
      }
      _preparedUid = uid;
      _startupReady = true;
      if (store.isEnabled) await store.start();
    } catch (error) {
      if (!current()) return;
      debugPrint('[Personalization] startup check failed: $error');
      _retry = Timer(Duration(seconds: 2 << math.min(_failures++, 4)), () {
        _retry = null;
        if (current()) _schedule();
      });
    } finally {
      store.endPresentation();
      if (current()) {
        _preparing = false;
        _schedule();
      }
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    widget.store.state.removeListener(_schedule);
    widget.loginPending?.removeListener(_schedule);
    widget.appConfig.removeListener(_configChanged);
    _requiresSignIn.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
