import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/common/genesis_center_toast.dart';
import '../platform/app/app_task_controller.dart';

/// Confirms Android back at the main route before moving its task to the back.
class AppShellBackGuard extends StatefulWidget {
  const AppShellBackGuard({
    super.key,
    required this.activeTabIndex,
    required this.child,
  });

  final int activeTabIndex;
  final Widget child;

  @override
  State<AppShellBackGuard> createState() => _AppShellBackGuardState();
}

class _AppShellBackGuardState extends State<AppShellBackGuard>
    with WidgetsBindingObserver {
  static const _confirmationDuration = Duration(seconds: 2);
  Timer? _confirmationTimer;
  bool _isRootAndroidRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isFirst = ModalRoute.isFirstOf(context) ?? false;
    final isCurrent = ModalRoute.isCurrentOf(context) ?? false;
    _isRootAndroidRoute =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android && isFirst;
    if (!_isRootAndroidRoute || !isCurrent) _resetConfirmation();
  }

  @override
  void didUpdateWidget(AppShellBackGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTabIndex != widget.activeTabIndex) {
      _resetConfirmation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _resetConfirmation();
  }

  void _resetConfirmation() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
  }

  void _onPopInvoked(bool didPop, void result) {
    if (didPop ||
        !_isRootAndroidRoute ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (_confirmationTimer?.isActive ?? false) {
      _resetConfirmation();
      // Keep the Activity, Flutter engine and navigation state alive.
      unawaited(moveAppToBackground());
      return;
    }
    _confirmationTimer = Timer(_confirmationDuration, _resetConfirmation);
    showGenesisToast(
      context,
      'Press back again to exit.',
      duration: _confirmationDuration,
      brightness: Brightness.dark,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetConfirmation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalHistory =
        ModalRoute.of(context)?.willHandlePopInternally ?? false;
    return PopScope<void>(
      canPop: !_isRootAndroidRoute || hasLocalHistory,
      onPopInvokedWithResult: _onPopInvoked,
      child: widget.child,
    );
  }
}
