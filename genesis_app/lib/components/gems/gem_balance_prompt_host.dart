import '../common/genesis_center_toast.dart';
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
      final presentation = (widget.present ?? showGemBalancePrompt)(
        context,
        alert,
      );
      if (alert.kind == GemBalanceAlertKind.insufficient &&
          alert.message.trim().isNotEmpty) {
        // Insert after the purchase route so the same server error stays visible
        // above it, regardless of which chat received the failure.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !identical(controller, widget.controller)) return;
          final overlay = widget.navigatorKey.currentState?.overlay;
          if (overlay != null) {
            showGenesisToastInOverlay(
              overlay,
              alert.message,
              brightness: Brightness.dark,
            );
          }
        });
      }
      await presentation;
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
