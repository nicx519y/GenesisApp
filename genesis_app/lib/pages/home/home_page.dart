import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/firebase_performance_operation.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/discuss/origin_discuss_preview_list.dart';
import '../../components/genesis_logo.dart';
import '../../components/home/popular_origin_list.dart';
import '../../components/home/world_item_card.dart';
import '../../components/origin/origin_item_card.dart';
import '../../network/api_exception.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_deleted_list_item_transition.dart';
import '../../ui/components/genesis_page_header.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_search_field.dart';
import '../../ui/components/genesis_tab_bar.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import 'home_feed_cache_store.dart';
import '../world/world_deletion_events.dart';
import '../world/world_page_result.dart';

part 'home_page_chrome.dart';
part 'home_my_world_feed.dart';
part 'home_world_feed_widgets.dart';
part 'home_popular_origin_feed.dart';

void _ignoreHomeFeedCacheWrite(Future<void> write) {
  unawaited(write.catchError((_) {}));
}

Future<void> _waitHomeInitialRequestMetricWindow(Duration delay) async {
  if (delay <= Duration.zero) return;
  await Future<void>.delayed(delay);
}

const Duration _homeInitialNetworkRetryDelay = Duration(seconds: 2);

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
    this.initialTabIndex,
    this.initialMyWorldsData,
    this.activationListenable,
    this.initialRequestMetricWindow = Duration.zero,
  });

  static const List<String> tabs = ['My Worlds', 'Popular'];
  static const int myWorldsTabIndex = 0;
  static const int popularTabIndex = 1;

  final int? initialTabIndex;
  final Map<String, dynamic>? initialMyWorldsData;
  final ValueListenable<int>? activationListenable;
  final Duration initialRequestMetricWindow;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _initialTabIndex;
  Future<int>? _initialTabIndexFuture;
  Map<String, dynamic>? _resolvedInitialMyWorldsData;
  FirebasePerformanceOperation? _initialMyWorldsRequestOperation;
  FirebasePerformanceOperation? _resolvedInitialMyWorldsRenderOperation;
  var _initialMyWorldsRequestAttempt = 0;
  // Feed widgets still observe this notifier for their own loading lifecycle;
  // startup permissions never change it.
  late final ValueNotifier<bool> _homeNetworkRequestsAllowed;

  @override
  void initState() {
    super.initState();
    _homeNetworkRequestsAllowed = ValueNotifier<bool>(true);
    _resolveInitialTabIndex();
  }

  @override
  void dispose() {
    unawaited(_initialMyWorldsRequestOperation?.cancel());
    unawaited(_resolvedInitialMyWorldsRenderOperation?.cancel());
    _homeNetworkRequestsAllowed.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _resolveInitialTabIndex();
    }
  }

  void _resolveInitialTabIndex() {
    unawaited(_initialMyWorldsRequestOperation?.cancel());
    unawaited(_resolvedInitialMyWorldsRenderOperation?.cancel());
    _initialMyWorldsRequestOperation = null;
    _resolvedInitialMyWorldsRenderOperation = null;
    _initialMyWorldsRequestAttempt = 0;
    final requestedIndex = widget.initialTabIndex;
    _resolvedInitialMyWorldsData = null;
    if (requestedIndex != null) {
      _initialTabIndex = requestedIndex.clamp(0, HomePage.tabs.length - 1);
      _initialTabIndexFuture = null;
      return;
    }
    _initialTabIndex = null;
    _initialTabIndexFuture = _initialTabIndexFromSession();
  }

  Future<int> _initialTabIndexFromSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) {
      return HomePage.popularTabIndex;
    }
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    if (authToken.isEmpty) return HomePage.popularTabIndex;

    final cacheStore = HomeFeedCacheStore(ownerUid: uid);
    final cached = await cacheStore.load(HomeFeedCacheKind.myWorlds);
    if (_hasMyWorldsData(cached)) {
      _resolvedInitialMyWorldsData = cached;
      return HomePage.myWorldsTabIndex;
    }

    final attempt = ++_initialMyWorldsRequestAttempt;
    final requestOperation = await FirebasePerformanceOperation.start(
      surface: FirebasePerformanceSurface.myWorlds,
      phase: FirebasePerformancePhase.request,
      attempt: attempt,
    );
    if (!mounted) {
      unawaited(requestOperation.cancel());
      return HomePage.popularTabIndex;
    }
    _initialMyWorldsRequestOperation = requestOperation;
    try {
      final data = await services.api.v1.world.list(
        scene: 'mine',
        pn: 1,
        rn: 10,
      );
      if (!mounted ||
          !identical(_initialMyWorldsRequestOperation, requestOperation)) {
        unawaited(requestOperation.cancel());
        return HomePage.popularTabIndex;
      }
      _initialMyWorldsRequestOperation = null;
      unawaited(requestOperation.succeed());
      _resolvedInitialMyWorldsData = data;
      _ignoreHomeFeedCacheWrite(
        cacheStore.save(HomeFeedCacheKind.myWorlds, data),
      );
      if (!_hasMyWorldsData(data)) return HomePage.popularTabIndex;
      final renderOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.myWorlds,
        phase: FirebasePerformancePhase.render,
        attempt: attempt,
        timeout: FirebasePerformanceOperation.renderTimeout,
      );
      if (!mounted) {
        unawaited(renderOperation.cancel());
        return HomePage.popularTabIndex;
      }
      _resolvedInitialMyWorldsRenderOperation = renderOperation;
      return HomePage.myWorldsTabIndex;
    } catch (error) {
      if (identical(_initialMyWorldsRequestOperation, requestOperation)) {
        _initialMyWorldsRequestOperation = null;
      }
      unawaited(
        requestOperation.fail(errorType: firebasePerformanceErrorType(error)),
      );
      return HomePage.popularTabIndex;
    }
  }

  bool _hasMyWorldsData(Map<String, dynamic>? data) {
    if (data == null) return false;
    final list = data['list'];
    if (list is List && list.isNotEmpty) return true;
    return asInt(data['total']) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final initialTabIndex = _initialTabIndex;
    if (initialTabIndex != null) {
      return _HomeTabScaffold(
        initialIndex: initialTabIndex,
        activationListenable: widget.activationListenable,
        networkRequestsAllowed: _homeNetworkRequestsAllowed,
        keepInitialNetworkFailureLoading: false,
        initialRequestMetricWindow: widget.initialRequestMetricWindow,
        initialMyWorldsData: widget.initialMyWorldsData,
        initialMyWorldsRenderOperation: null,
        initialMyWorldsRequestAttempt: 0,
      );
    }

    return FutureBuilder<int>(
      future: _initialTabIndexFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _HomeInitialLoadingScaffold();
        }

        return _HomeTabScaffold(
          initialIndex: snapshot.data ?? HomePage.myWorldsTabIndex,
          activationListenable: widget.activationListenable,
          networkRequestsAllowed: _homeNetworkRequestsAllowed,
          keepInitialNetworkFailureLoading: false,
          initialRequestMetricWindow: widget.initialRequestMetricWindow,
          initialMyWorldsData:
              widget.initialMyWorldsData ?? _resolvedInitialMyWorldsData,
          initialMyWorldsRenderOperation: widget.initialMyWorldsData == null
              ? _resolvedInitialMyWorldsRenderOperation
              : null,
          initialMyWorldsRequestAttempt: widget.initialMyWorldsData == null
              ? _initialMyWorldsRequestAttempt
              : 0,
        );
      },
    );
  }
}
