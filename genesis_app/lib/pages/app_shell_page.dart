import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/bootstrap/app_services_scope.dart';
import '../app/bootstrap/polling_scheduler.dart';
import '../app/gems/daily_check_in_coordinator.dart';
import '../app/startup/app_startup_coordinator.dart';
import '../app/telemetry/genesis_telemetry.dart';
import '../components/bottom_tabs.dart';
import '../components/login_sheet.dart';
import '../network/models/unread_summary.dart';
import '../platform/auth/auth_session.dart';
import '../platform/billing/billing_models.dart';
import 'create/create_origin_page.dart';
import 'home/home_feed_cache_store.dart';
import 'home/home_page.dart';
import 'me/me_page.dart';
import 'messages/messages_page.dart';
import 'origin/origin_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.initialIndex,
    this.homeInitialTabIndex,
  });

  final int initialIndex;
  final int? homeInitialTabIndex;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  late final Set<int> _visitedTabIndexes;
  late final ValueNotifier<bool> _messagesTabActiveNotifier;
  late final ValueNotifier<bool> _meTabActiveNotifier;
  late final ValueNotifier<bool> _homeTabActiveNotifier;
  late final ValueNotifier<int> _homeTabActivationNotifier;
  late final ValueNotifier<int> _meTabActivationNotifier;
  int? _homeInitialTabIndexOverride;
  late final bool _shouldResolveColdStartHomeTarget;
  var _coldStartHomeTargetResolved = true;
  var _hasRecordedInitialTabPageView = false;
  Future<void>? _coldStartHomeTargetResolution;
  ValueListenable<int>? _sessionRevisionListenable;
  final Map<int, Widget> _tabPageCache = <int, Widget>{};
  final ValueNotifier<UnreadSummary> _unreadSummaryNotifier =
      ValueNotifier<UnreadSummary>(UnreadSummary.zero);
  static const _messagesPollInterval = Duration(seconds: 30);
  late final GenesisPollingScheduler _messagesPoller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppStartupCoordinator.postLaunchWorkAllowedListenable.addListener(
      _handlePostLaunchWorkAllowed,
    );
    _selectedIndex = _normalTabIndex(widget.initialIndex);
    _messagesTabActiveNotifier = ValueNotifier<bool>(_selectedIndex == 3);
    _meTabActiveNotifier = ValueNotifier<bool>(_selectedIndex == 4);
    _homeTabActiveNotifier = ValueNotifier<bool>(_selectedIndex == 0);
    _homeTabActivationNotifier = ValueNotifier<int>(0);
    _meTabActivationNotifier = ValueNotifier<int>(0);
    _homeInitialTabIndexOverride = widget.homeInitialTabIndex;
    _shouldResolveColdStartHomeTarget =
        widget.initialIndex == 0 && widget.homeInitialTabIndex == null;
    _coldStartHomeTargetResolved = !_shouldResolveColdStartHomeTarget;
    _visitedTabIndexes = _coldStartHomeTargetResolved
        ? <int>{_selectedIndex}
        : <int>{};
    _messagesPoller = GenesisPollingScheduler(
      interval: _messagesPollInterval,
      onTick: _refreshMessagesData,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAppRuntime();
      _startColdStartHomeTargetResolutionIfNeeded();
      _startPostLaunchWorkIfAllowed();
    });
  }

  @override
  void dispose() {
    _sessionRevisionListenable?.removeListener(_handleSessionChanged);
    AppStartupCoordinator.postLaunchWorkAllowedListenable.removeListener(
      _handlePostLaunchWorkAllowed,
    );
    WidgetsBinding.instance.removeObserver(this);
    _stopMessagesPolling();
    _messagesTabActiveNotifier.dispose();
    _meTabActiveNotifier.dispose();
    _homeTabActiveNotifier.dispose();
    _homeTabActivationNotifier.dispose();
    _unreadSummaryNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (AppStartupCoordinator.isPostLaunchWorkAllowed) {
        _startColdStartHomeTargetResolutionIfNeeded();
        if (!_coldStartHomeTargetResolved) return;
        _startMessagesPolling();
        _notifyActiveTabActivated();
        unawaited(
          AppServicesScope.read(
            context,
          ).billing?.recover(BillingRecoverySource.foreground),
        );
      }
    } else {
      _stopMessagesPolling();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionRevision = AppServicesScope.of(context).sessionRevision;
    if (identical(_sessionRevisionListenable, sessionRevision)) return;
    _sessionRevisionListenable?.removeListener(_handleSessionChanged);
    _sessionRevisionListenable = sessionRevision;
    sessionRevision.addListener(_handleSessionChanged);
  }

  void _startMessagesPolling() {
    if (!mounted) return;
    _messagesPoller.start();
  }

  void _stopMessagesPolling() {
    _messagesPoller.stop();
  }

  void _handlePostLaunchWorkAllowed() {
    _startColdStartHomeTargetResolutionIfNeeded();
    _startPostLaunchWorkIfAllowed();
  }

  void _startPostLaunchWorkIfAllowed() {
    if (!AppStartupCoordinator.isPostLaunchWorkAllowed) return;
    if (!_coldStartHomeTargetResolved) return;
    if (!_hasRecordedInitialTabPageView) {
      _hasRecordedInitialTabPageView = true;
      _recordSelectedTabPageView();
    }
    _startMessagesPolling();
    if (_selectedIndex == 4 && _meTabActivationNotifier.value == 0) {
      _notifyActiveTabActivated();
    }
  }

  void _startAppRuntime() {
    if (!mounted) return;
    final services = AppServicesScope.read(context);
    AppStartupCoordinator.startFirebasePerformance();
    AppStartupCoordinator.startWarmUp(services);
    unawaited(AppStartupCoordinator.initializeTelemetry(services: services));
  }

  void _startColdStartHomeTargetResolutionIfNeeded() {
    if (!_shouldResolveColdStartHomeTarget) return;
    if (_coldStartHomeTargetResolved) return;
    if (_coldStartHomeTargetResolution != null) return;
    _coldStartHomeTargetResolution = _resolveColdStartHomeTarget();
  }

  Future<void> _resolveColdStartHomeTarget() async {
    final hasSession = await _hasLocalLoginSession();
    final hasMyWorldsCache = hasSession
        ? await _hasMyWorldsCacheForLocalSession()
        : false;
    if (!mounted) return;
    final openHome = hasSession && hasMyWorldsCache;
    setState(() {
      _selectedIndex = openHome ? 0 : 1;
      _homeInitialTabIndexOverride = openHome
          ? HomePage.myWorldsTabIndex
          : HomePage.popularTabIndex;
      _visitedTabIndexes
        ..clear()
        ..add(_selectedIndex);
      _coldStartHomeTargetResolved = true;
    });
    _messagesTabActiveNotifier.value = _selectedIndex == 3;
    _meTabActiveNotifier.value = _selectedIndex == 4;
    _homeTabActiveNotifier.value = _selectedIndex == 0;
    _startPostLaunchWorkIfAllowed();
  }

  Future<bool> _hasMyWorldsCacheForLocalSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    if (authToken.isEmpty) return false;
    final cached = await HomeFeedCacheStore(
      ownerUid: uid,
    ).load(HomeFeedCacheKind.myWorlds);
    if (cached == null) return false;
    final list = cached['list'];
    if (list is List && list.isNotEmpty) return true;
    final total = cached['total'];
    if (total is num) return total > 0;
    return (int.tryParse(total?.toString() ?? '') ?? 0) > 0;
  }

  Future<void> _refreshMessagesData() async {
    try {
      if (!await _hasLocalLoginSession()) {
        if (mounted && _unreadSummaryNotifier.value != UnreadSummary.zero) {
          _unreadSummaryNotifier.value = UnreadSummary.zero;
        }
        return;
      }
      if (!mounted) return;
      final services = AppServicesScope.read(context);
      final requests = <Future<void>>[
        _refreshUnreadSummary(),
        services.directMessageConversations.syncConversations(),
      ];
      await Future.wait(requests);
    } catch (e, st) {
      debugPrint('[Messages][Poll] refresh failed: $e');
      debugPrint('[Messages][Poll] stacktrace:\n$st');
    }
  }

  Future<void> _refreshUnreadSummary() async {
    try {
      final summary = await AppServicesScope.read(
        context,
      ).api.v1.messages.unreadSummary();
      if (!mounted) return;
      _unreadSummaryNotifier.value = summary;
    } catch (e, st) {
      debugPrint('[Messages][Unread] unreadSummary polling failed: $e');
      debugPrint('[Messages][Unread] stacktrace:\n$st');
    }
  }

  Future<void> _onTapNav(int index) async {
    if (index == 0) {
      if (_selectedIndex == 0) return;
      _selectTab(0);
      return;
    }

    if (index == 1) {
      if (_selectedIndex == 1) return;
      _selectTab(1);
      return;
    }

    if (index == 2) {
      if (!await _ensureMainTabLogin()) return;
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CreateOriginPage()));
      return;
    }

    if (index == 3) {
      if (!await _ensureMainTabLogin()) return;
      if (!mounted) return;
      if (_selectedIndex == 3) return;
      _selectTab(3);
      unawaited(_messagesPoller.runNow());
      return;
    }

    if (index == 4) {
      if (_selectedIndex == 4) return;
      _selectTab(4);
      return;
    }
  }

  Future<bool> _ensureMainTabLogin() async {
    if (await _hasLocalLoginSession()) return true;
    if (!mounted) return false;
    final loggedIn = await showLoginSheet(
      context: context,
      onLogin: _loginWithProvider,
    );
    if (!mounted || !loggedIn) return false;
    await showDailyCheckInAfterLogin(context);
    if (!mounted) return false;
    return _hasLocalLoginSession();
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
  }

  Future<bool> _loginWithProvider(IdentityProvider provider) async {
    debugPrint('[Auth][AppShell] onLogin start provider=$provider');
    final services = AppServicesScope.read(context);
    final session = await services.identityAuth.signIn(provider);
    final user = await services.backendAuth.loginWithIdentity(session);
    if (user.uid.trim().isNotEmpty) {
      await services.sessionStore.saveUid(user.uid);
    }
    final cachedUserInfo = await services.sessionStore.readUserInfo();
    final loginUserInfo = <String, dynamic>{
      if (cachedUserInfo != null) ...cachedUserInfo,
      'uid': user.uid,
      'login_provider': provider.name,
    };
    if (user.nickname.trim().isNotEmpty) {
      loginUserInfo['name'] = user.nickname;
    }
    if (user.avatar.trim().isNotEmpty) {
      loginUserInfo['avatar'] = user.avatar;
    }
    await services.sessionStore.saveUserInfo(loginUserInfo);
    services.notifySessionChanged();
    unawaited(_messagesPoller.runNow());
    debugPrint('[Auth][AppShell] backend login success uid=${user.uid}');
    return true;
  }

  int _normalTabIndex(int index) {
    return switch (index) {
      0 || 1 || 3 || 4 => index,
      _ => 0,
    };
  }

  void _selectTab(int index) {
    if (_selectedIndex == index && _visitedTabIndexes.contains(index)) {
      return;
    }
    final previousIndex = _selectedIndex;
    setState(() {
      _selectedIndex = index;
      _visitedTabIndexes.add(index);
    });
    _messagesTabActiveNotifier.value = _selectedIndex == 3;
    _meTabActiveNotifier.value = _selectedIndex == 4;
    _homeTabActiveNotifier.value = _selectedIndex == 0;
    if (previousIndex != index) {
      _recordSelectedTabPageView();
      _notifyActiveTabActivated();
    }
  }

  void _recordSelectedTabPageView() {
    switch (_selectedIndex) {
      case 1:
        GenesisTelemetry.collectLog(
          actionType: 'pageview',
          action: 'worldo_list_tab',
        );
        return;
      case 3:
        GenesisTelemetry.collectLog(
          actionType: 'pageview',
          action: 'messages_home',
        );
        return;
      case 4:
        GenesisTelemetry.collectLog(actionType: 'pageview', action: 'me');
        return;
    }
  }

  void _notifyActiveTabActivated() {
    if (!mounted) return;
    switch (_selectedIndex) {
      case 0:
        _homeTabActivationNotifier.value += 1;
      case 4:
        _meTabActivationNotifier.value += 1;
        unawaited(AppServicesScope.read(context).gemWallet.refresh());
    }
  }

  void _handleMeLoggedOut() {
    _homeInitialTabIndexOverride = HomePage.popularTabIndex;
    _resetSessionBoundState(selectedIndex: 0);
    unawaited(
      AppServicesScope.read(context).directMessageConversations.loadFromDb(),
    );
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    // Normal navigation into Home starts at Popular. Cold-start routing sets
    // My Worlds explicitly when its local cache exists.
    _homeInitialTabIndexOverride = HomePage.popularTabIndex;
    _resetSessionBoundState(selectedIndex: _selectedIndex);
    final services = AppServicesScope.read(context);
    services.billing?.resetForSession();
    unawaited(services.directMessageConversations.loadFromDb());
    if (_selectedIndex == 3) {
      unawaited(_messagesPoller.runNow());
    }
    if (_selectedIndex == 4) {
      _notifyActiveTabActivated();
    }
  }

  void _resetSessionBoundState({required int selectedIndex}) {
    setState(() {
      _tabPageCache.clear();
      _visitedTabIndexes
        ..clear()
        ..add(selectedIndex);
      _selectedIndex = selectedIndex;
    });
    _unreadSummaryNotifier.value = UnreadSummary.zero;
    _messagesTabActiveNotifier.value = _selectedIndex == 3;
    _meTabActiveNotifier.value = _selectedIndex == 4;
    _homeTabActiveNotifier.value = _selectedIndex == 0;
  }

  Widget _cachedTabPage(int index) {
    return _tabPageCache.putIfAbsent(index, () {
      return switch (index) {
        0 => HomePage(
          initialTabIndex: _homeInitialTabIndexOverride,
          activationListenable: _homeTabActivationNotifier,
          activeListenable: _homeTabActiveNotifier,
        ),
        1 => const OriginPage(),
        3 => ValueListenableBuilder<UnreadSummary>(
          valueListenable: _unreadSummaryNotifier,
          builder: (context, unreadSummary, _) {
            return MessagesPage(
              unreadSummary: unreadSummary,
              onMessagesDataRefresh: _messagesPoller.runNow,
              isActiveListenable: _messagesTabActiveNotifier,
            );
          },
        ),
        4 => MePage(
          onLoggedOut: _handleMeLoggedOut,
          onLogin: _loginWithProvider,
          onLoginCompleted: () => showDailyCheckInAfterLogin(context),
          activationListenable: _meTabActivationNotifier,
          isActiveListenable: _meTabActiveNotifier,
        ),
        _ => const SizedBox.shrink(),
      };
    });
  }

  Widget _buildTabSlot(int index) {
    if (!_visitedTabIndexes.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return _cachedTabPage(index);
      case 3:
        return _cachedTabPage(index);
      case 4:
        return _cachedTabPage(index);
      case 1:
        return _cachedTabPage(index);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBody() {
    if (!_coldStartHomeTargetResolved) return const SizedBox.expand();
    return IndexedStack(
      index: _selectedIndex,
      children: [
        for (var index = 0; index < 5; index += 1) _buildTabSlot(index),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: ValueListenableBuilder<UnreadSummary>(
        valueListenable: _unreadSummaryNotifier,
        builder: (context, unreadSummary, _) {
          return BottomTabs(
            currentIndex: _coldStartHomeTargetResolved ? _selectedIndex : -1,
            messagesUnreadCount: unreadSummary.totalUnread,
            onTap: (index) => unawaited(_onTapNav(index)),
          );
        },
      ),
    );
  }
}
