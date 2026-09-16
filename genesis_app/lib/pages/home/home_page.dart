import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/startup/app_startup_coordinator.dart';
import '../../app/startup/startup_request_diagnostics.dart';
import '../../app/telemetry/firebase_performance_operation.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/home/world_item_card.dart';
import '../../components/me/signed_out_me_view.dart';
import '../../components/page_header.dart';
import '../../components/search_bar.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/api_exception.dart';
import '../../network/json_utils.dart';
import '../../platform/auth/auth_cancelled_exception.dart';
import '../../platform/auth/auth_session.dart';
import '../../platform/session/user_session_store.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_deleted_list_item_transition.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_refresh_indicator.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/theme/genesis_dark_theme.dart';
import 'home_feed_cache_store.dart';
import '../world/world_deletion_events.dart';
import '../world/world_page_result.dart';

part 'home_page_chrome.dart';
part 'home_my_world_feed.dart';
part 'home_world_feed_widgets.dart';

void _ignoreHomeFeedCacheWrite(Future<void> write) {
  unawaited(write.catchError((_) {}));
}

Future<void> _waitHomeInitialRequestMetricWindow(Duration delay) async {
  if (delay <= Duration.zero) return;
  await Future<void>.delayed(delay);
}

const Duration _homeInitialNetworkRetryDelay = Duration(seconds: 2);
const Duration _homeLocalRestoreTimeout = Duration(milliseconds: 500);

typedef HomeMyWorldsCacheLoader =
    Future<Map<String, dynamic>?> Function(String ownerUid);

bool _isNetworkLikeHomeError(Object error) {
  if (error is ApiException) {
    return error.kind == ApiExceptionKind.timeout ||
        error.kind == ApiExceptionKind.transport ||
        error.transportErrorKind == TransportErrorKind.timeout ||
        error.transportErrorKind == TransportErrorKind.connection;
  }
  if (error is TimeoutException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('timeout') ||
      text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('host lookup');
}

_WorldListPage _parseHomeWorldListPage(
  Map<String, dynamic> data, {
  Set<String> locallyDeletedWorldIds = const <String>{},
}) {
  final list = data['list'];
  final items = list is List
      ? list
            .whereType<Map>()
            .map((raw) => WorldListItem.fromJson(asJsonMap(raw)))
            .where((item) => !locallyDeletedWorldIds.contains(item.wid.trim()))
            .toList(growable: false)
      : const <WorldListItem>[];
  return _WorldListPage(items: items, total: asInt(data['total']));
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialMyWorldsData,
    this.activationListenable,
    this.reselectionListenable,
    this.isActiveListenable,
    this.isFirstPageViewReported,
    this.onFirstPageViewReady,
    this.onOpenWorldo,
    this.onLogin,
    this.onLoginCompleted,
    this.initialRequestMetricWindow = Duration.zero,
    this.localRestoreTimeout = _homeLocalRestoreTimeout,
    this.myWorldsCacheLoader,
  });

  final Map<String, dynamic>? initialMyWorldsData;
  final ValueListenable<int>? activationListenable;
  final ValueListenable<int>? reselectionListenable;
  final ValueListenable<bool>? isActiveListenable;
  final bool Function(String action)? isFirstPageViewReported;
  final void Function(String action)? onFirstPageViewReady;
  final VoidCallback? onOpenWorldo;
  final Future<bool> Function(IdentityProvider provider)? onLogin;
  final Future<void> Function()? onLoginCompleted;
  final Duration initialRequestMetricWindow;
  final Duration localRestoreTimeout;
  final HomeMyWorldsCacheLoader? myWorldsCacheLoader;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Feed widgets still observe this notifier for their own loading lifecycle;
  // startup permissions never change it.
  late final ValueNotifier<bool> _homeNetworkRequestsAllowed;
  IdentityProvider? _loggingInProvider;

  Future<void> _login(IdentityProvider provider) async {
    if (_loggingInProvider != null) return;
    final login = widget.onLogin;
    if (login == null) {
      showGenesisToast(
        context,
        'Sign-in unavailable',
        brightness: Brightness.dark,
      );
      return;
    }
    final onLoginCompleted = widget.onLoginCompleted;
    setState(() => _loggingInProvider = provider);
    try {
      final ok = await login(provider);
      if (ok) {
        await onLoginCompleted?.call();
      } else if (mounted) {
        showGenesisToast(
          context,
          'Sign-in failed',
          brightness: Brightness.dark,
        );
      }
    } on AuthCancelledException {
      // The user closed the provider sign-in flow.
    } catch (error) {
      if (mounted) {
        showGenesisToast(
          context,
          error.toString(),
          brightness: Brightness.dark,
        );
      }
    } finally {
      if (mounted) setState(() => _loggingInProvider = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _homeNetworkRequestsAllowed = ValueNotifier<bool>(true);
    widget.isActiveListenable?.addListener(_scheduleGuestPurchaseCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppServicesScope.maybeOf(context);
    _scheduleGuestPurchaseCheck();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveListenable != widget.isActiveListenable) {
      oldWidget.isActiveListenable?.removeListener(_scheduleGuestPurchaseCheck);
      widget.isActiveListenable?.addListener(_scheduleGuestPurchaseCheck);
      _scheduleGuestPurchaseCheck();
    }
  }

  void _scheduleGuestPurchaseCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isActiveListenable?.value == false) return;
      final membership = AppServicesScope.maybeRead(
        context,
      )?.membershipPurchases;
      if (membership != null) unawaited(membership.checkGuestPurchasesOnHome());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.isActiveListenable?.removeListener(_scheduleGuestPurchaseCheck);
    _homeNetworkRequestsAllowed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GenesisDarkTheme(
      child: ColoredBox(
        color: GenesisColors.darkBackground,
        child: _HomeScaffold(
          signedOutView: SignedOutMeView(
            loggingInProvider: _loggingInProvider,
            onLogin: _login,
            reselectionListenable: widget.reselectionListenable,
            isActiveListenable: widget.isActiveListenable,
            topSafeArea: false,
            showLogo: false,
            title: 'Your worlds, all in one place',
            description: 'Sign in to create worlds and continue your stories.',
            titleFontSize: 20,
            descriptionFontSize: 14,
            titleLetterSpacing: 0,
          ),
          activationListenable: widget.activationListenable,
          reselectionListenable: widget.reselectionListenable,
          isActiveListenable: widget.isActiveListenable,
          isFirstPageViewReported: widget.isFirstPageViewReported,
          onFirstPageViewReady: widget.onFirstPageViewReady,
          onOpenWorldo: widget.onOpenWorldo,
          networkRequestsAllowed: _homeNetworkRequestsAllowed,
          keepInitialNetworkFailureLoading: false,
          initialRequestMetricWindow: widget.initialRequestMetricWindow,
          localRestoreTimeout: widget.localRestoreTimeout,
          myWorldsCacheLoader: widget.myWorldsCacheLoader,
          initialMyWorldsData: widget.initialMyWorldsData,
          initialMyWorldsRenderOperation: null,
          initialMyWorldsRequestAttempt: 0,
        ),
      ),
    );
  }
}
