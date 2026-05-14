import 'dart:async';

import 'package:flutter/material.dart';

import '../app/bootstrap/app_services_scope.dart';
import '../components/bottom_tabs.dart';
import '../components/login_sheet.dart';
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

class _AppShellPageState extends State<AppShellPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    if (_selectedIndex == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_ensureMeTabWithAuth());
      });
    }
  }

  Future<void> _onTapNav(int index) async {
    if (index == 0) {
      if (_selectedIndex == 0) return;
      setState(() => _selectedIndex = 0);
      return;
    }

    if (index == 1) {
      if (_selectedIndex == 1) return;
      setState(() => _selectedIndex = 1);
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
      setState(() => _selectedIndex = 3);
      return;
    }

    if (index == 4) {
      await _ensureMeTabWithAuth();
      return;
    }
  }

  Future<void> _ensureMeTabWithAuth() async {
    debugPrint('[Auth][AppShell] checking auth before entering Me');
    final services = AppServicesScope.read(context);
    final identityAuthed = services.identityAuth.hasLocalIdentitySession();
    final backendAuthed = identityAuthed
        ? false
        : await services.backendAuth.hasAuthenticatedBackendSession(
            tryAutoRefresh: false,
          );
    final authed = identityAuthed || backendAuthed;
    debugPrint(
      '[Auth][AppShell] identityAuthed=$identityAuthed backendAuthed=$backendAuthed',
    );
    if (!mounted) return;
    if (authed) {
      setState(() => _selectedIndex = 4);
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
            try {
              final user = await services.backendAuth.loginWithIdentity(
                session,
              );
              debugPrint(
                '[Auth][AppShell] backend login success uid=${user.uid}',
              );
              return true;
            } catch (e, st) {
              debugPrint('[Auth][AppShell] backend login skipped: $e');
              debugPrint('[Auth][AppShell] backend login stacktrace:\n$st');
              await services.sessionStore.saveUid(session.identityUid);
              return true;
            }
          },
        );
      },
    );
    debugPrint('[Auth][AppShell] login sheet closed result=$loginOk');
    if (!mounted) return;
    if (loginOk == true) {
      setState(() => _selectedIndex = 4);
    } else if (_selectedIndex == 4) {
      setState(() => _selectedIndex = 1);
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const HomePage();
      case 3:
        return const MessagesPage();
      case 4:
        return MePage(
          onLoggedOut: () {
            setState(() => _selectedIndex = 1);
          },
        );
      case 1:
      default:
        return const OriginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomTabs(
        currentIndex: _selectedIndex,
        onTap: (index) => unawaited(_onTapNav(index)),
      ),
    );
  }
}
