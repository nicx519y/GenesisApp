import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/gems/gem_balance_prompt_controller.dart';
import '../../network/gem_balance_alert.dart';
import 'gem_balance_prompt.dart';

/// Mounted once above the root Navigator, including all nested chat routes.
class GemBalancePromptHost extends StatefulWidget {
  const GemBalancePromptHost({
    super.key,
    required this.controller,
    required this.navigatorKey,
    required this.child,
    this.present,
  });
  final GemBalancePromptController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final Future<void> Function(BuildContext, GemBalanceAlert)? present;
  @override
  State<GemBalancePromptHost> createState() => _GemBalancePromptHostState();
}

class _GemBalancePromptHostState extends State<GemBalancePromptHost>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(GemBalancePromptHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_schedule);
      widget.controller.addListener(_schedule);
      _schedule();
    }
  }

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    if (!mounted ||
        _scheduled ||
        !_foreground ||
        widget.controller.pending == null) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_foreground) return;
      final context = widget.navigatorKey.currentState?.overlay?.context;
      if (context == null || !context.mounted) return;
      final controller = widget.controller;
      final alert = controller.beginPresentation();
      if (alert == null) return;
      unawaited(_present(context, alert, controller));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _present(
    BuildContext context,
    GemBalanceAlert alert,
    GemBalancePromptController controller,
  ) async {
    try {
      await (widget.present ?? showGemBalancePrompt)(context, alert);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'gem balance prompt',
        ),
      );
    } finally {
      controller.endPresentation();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
