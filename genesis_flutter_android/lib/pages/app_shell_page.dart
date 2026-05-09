import 'package:flutter/material.dart';

import '../components/bottom_tabs.dart';
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
  }

  void _onTapNav(int index) {
    if (index != 1) return;
    if (_selectedIndex == 1) return;
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const OriginPage(),
      bottomNavigationBar: BottomTabs(
        currentIndex: _selectedIndex,
        onTap: _onTapNav,
      ),
    );
  }
}
