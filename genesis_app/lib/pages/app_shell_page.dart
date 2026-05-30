import 'dart:async';

import 'package:flutter/material.dart';

import '../app/bootstrap/app_services_scope.dart';
import '../components/bottom_tabs.dart';
import '../components/login_sheet.dart';
import '../network/models/unread_summary.dart';
import 'create/create_origin_page.dart';
import 'home/home_page.dart';
import 'me/me_page.dart';
import 'messages/messages_page.dart';
import 'origin/origin_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  late final Set<int> _visitedTabIndexes;
  final Map<int, Widget> _tabPageCache = <int, Widget>{};
  final ValueNotifier<UnreadSummary> _unreadSummaryNotifier =
      ValueNotifier<UnreadSummary>(UnreadSummary.zero);
  Timer? _unreadPollTimer;
  bool _unreadPollInFlight = false;
  bool _unreadPollingActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = _normalTabIndex(widget.initialIndex);
    _visitedTabIndexes = <int>{_selectedIndex};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startUnreadPolling();
    });
    if (_selectedIndex == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureMeTabWithAuth());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopUnreadPolling();
    _unreadSummaryNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startUnreadPolling();
    } else {
      _stopUnreadPolling();
    }
  }

  void _startUnreadPolling() {
    if (!mounted || _unreadPollingActive) return;
    _unreadPollingActive = true;
    unawaited(_refreshUnreadSummary());
    _unreadPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_refreshUnreadSummary());
    });
  }

  void _stopUnreadPolling() {
    _unreadPollingActive = false;
    _unreadPollTimer?.cancel();
    _unreadPollTimer = null;
  }

  Future<void> _refreshUnreadSummary({bool force = false}) async {
    if (_unreadPollInFlight && !force) return;
    _unreadPollInFlight = true;
    try {
      final summary = await AppServicesScope.read(
        context,
      ).api.v1.messages.unreadSummary();
      if (!mounted) return;
      _unreadSummaryNotifier.value = summary;
    } catch (e, st) {
      debugPrint('[Messages][Unread] unreadSummary polling failed: $e');
      debugPrint('[Messages][Unread] stacktrace:\n$st');
    } finally {
      _unreadPollInFlight = false;
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
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CreateOriginPage()));
      return;
    }

    if (index == 3) {
      if (_selectedIndex == 3) return;
      _selectTab(3);
      return;
    }

    if (index == 4) {
      await _ensureMeTabWithAuth();
      return;
    }
  }

  Future<void> _ensureMeTabWithAuth() async {
    debugPrint('[Auth][AppShell] checking auth before entering Me');
    final locallyAuthed = await _hasLocalLoginSession();
    debugPrint('[Auth][AppShell] locallyAuthed=$locallyAuthed');
    if (!mounted) return;
    if (locallyAuthed) {
      _selectTab(4);
      return;
    }

    final loginOk = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return LoginSheet(
          onLogin: () async {
            debugPrint('[Auth][AppShell] onLogin start');
            final services = AppServicesScope.read(context);
            final session = await services.identityAuth.signIn();
            final user = await services.backendAuth.loginWithIdentity(session);
            if (user.uid.trim().isNotEmpty) {
              await services.sessionStore.saveUid(user.uid);
            }
            final cachedUserInfo = await services.sessionStore.readUserInfo();
            final loginUserInfo = <String, dynamic>{
              if (cachedUserInfo != null) ...cachedUserInfo,
              'uid': user.uid,
            };
            if (user.nickname.trim().isNotEmpty) {
              loginUserInfo['name'] = user.nickname;
            }
            if (user.avatar.trim().isNotEmpty) {
              loginUserInfo['avatar'] = user.avatar;
            }
            await services.sessionStore.saveUserInfo(loginUserInfo);
            debugPrint(
              '[Auth][AppShell] backend login success uid=${user.uid}',
            );
            return true;
          },
        );
      },
    );
    debugPrint('[Auth][AppShell] login sheet closed result=$loginOk');
    if (!mounted) return;
    if (loginOk == true) {
      _selectTab(4);
    } else if (_selectedIndex == 4) {
      _selectTab(1);
    }
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
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
    setState(() {
      _selectedIndex = index;
      _visitedTabIndexes.add(index);
    });
  }

  void _handleMeLoggedOut() {
    _selectTab(1);
  }

  Widget _cachedTabPage(int index) {
    return _tabPageCache.putIfAbsent(index, () {
      return switch (index) {
        0 => const HomePage(),
        1 => const OriginPage(),
        3 => ValueListenableBuilder<UnreadSummary>(
          valueListenable: _unreadSummaryNotifier,
          builder: (context, unreadSummary, _) {
            return MessagesPage(
              unreadSummary: unreadSummary,
              onUnreadSummaryRefresh: () => _refreshUnreadSummary(force: true),
            );
          },
        ),
        4 => MePage(onLoggedOut: _handleMeLoggedOut),
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
            currentIndex: _selectedIndex,
            messagesUnreadCount: unreadSummary.totalUnread,
            onTap: (index) => unawaited(_onTapNav(index)),
          );
        },
      ),
    );
  }
}
