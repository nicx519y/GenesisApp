import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/config/app_global_config.dart';
import '../../app/startup/startup_prompt_sequence.dart';
import '../../pages/me/force_login_page.dart';
import '../../platform/auth/auth_session.dart';
import '../../platform/session/user_session_store.dart';
import '../../routers/app_router.dart';

/// Reacts to the existing config response without delaying the startup page.
class StartupLoginGate extends StatefulWidget {
  const StartupLoginGate({
    super.key,
    required this.config,
    required this.sessionStore,
    required this.sessionRevision,
    required this.builder,
    this.onLogin,
  });

  final AppGlobalConfigStore config;
  final UserSessionStore sessionStore;
  final ValueListenable<int> sessionRevision;
  final WidgetBuilder builder;
  final Future<bool> Function(IdentityProvider)? onLogin;

  @override
  State<StartupLoginGate> createState() => _StartupLoginGateState();
}

class _StartupLoginGateState extends State<StartupLoginGate> {
  bool _handled = false;
  bool _scheduled = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.config.addListener(_schedule);
    widget.config.requestState.addListener(_schedule);
    widget.sessionRevision.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(StartupLoginGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      oldWidget.config.removeListener(_schedule);
      oldWidget.config.requestState.removeListener(_schedule);
      widget.config.addListener(_schedule);
      widget.config.requestState.addListener(_schedule);
    }
    if (oldWidget.sessionRevision != widget.sessionRevision) {
      oldWidget.sessionRevision.removeListener(_schedule);
      widget.sessionRevision.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (!mounted || _handled || _scheduled || _checking) return;
    final request = widget.config.requestState.value;
    if (request.isLoading || request.error != null) return;
    if (!widget.config.value.forceLogin) {
      // The initial default is not a config response. Keep listening for it.
      if (request.data != null) _handled = true;
      return;
    }
    // Reserve presentation only after true is confirmed, never while waiting
    // for Config. Other automatic prompts must not race required login.
    startupPromptSequence.blockForLogin(this);
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_check());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _check() async {
    if (_handled || _checking) return;
    _checking = true;
    final config = widget.config;
    final session = widget.sessionStore;
    final revision = widget.sessionRevision.value;
    var retry = false;
    try {
      String? uid;
      try {
        uid = await session.readLoginUid().timeout(const Duration(seconds: 2));
      } catch (_) {
        // A failed local read does not establish a signed-in account.
      }
      if (!mounted) return;
      if (!identical(config, widget.config) ||
          !identical(session, widget.sessionStore) ||
          revision != widget.sessionRevision.value) {
        retry = true;
        return;
      }
      if (config.requestState.value.isLoading ||
          config.requestState.value.error != null) {
        return;
      }
      _handled = true;
      if (!config.value.forceLogin || uid != null) return;
      await Navigator.of(context).push<bool>(
        createForceLoginRoute(
          settings: const RouteSettings(name: RouteNames.forceLogin),
          onLogin: widget.onLogin,
        ),
      );
    } finally {
      _checking = false;
      startupPromptSequence.releaseLogin(this);
      if (retry && mounted) _schedule();
    }
  }

  @override
  void dispose() {
    widget.config.removeListener(_schedule);
    widget.config.requestState.removeListener(_schedule);
    widget.sessionRevision.removeListener(_schedule);
    startupPromptSequence.releaseLogin(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
