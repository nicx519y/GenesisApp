import 'dart:async';

import 'package:flutter/material.dart';

import '../components/bottom_tabs.dart';
import '../components/google_login_sheet.dart';
import '../network/genesis_api.dart';
import 'create/create_origin_page.dart';
import 'home/home_page.dart';
import 'me/me_page.dart';
import 'origin/origin_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  late int _selectedIndex;
  final GenesisApi _api = GenesisApi();

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
    debugPrint('[Auth][AppShell] checking session before entering Me');
    final authed = await _api.hasAuthenticatedSession();
    debugPrint('[Auth][AppShell] hasAuthenticatedSession=$authed');
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
        return GoogleLoginSheet(
          onLogin: (idToken) async {
            debugPrint('[Auth][AppShell] onLogin start');
            try {
              final user = await _api.loginWithGoogle(idToken: idToken);
              debugPrint(
                '[Auth][AppShell] onLogin success uid=${user.uid} nickname=${user.nickname}',
              );
              return true;
            } catch (e, st) {
              debugPrint('[Auth][AppShell] onLogin failed: $e');
              debugPrint('[Auth][AppShell] onLogin stacktrace:\n$st');
              rethrow;
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
        return const _MessagesPlaceholderPage();
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

class _MessagesPlaceholderPage extends StatelessWidget {
  const _MessagesPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Messages',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
