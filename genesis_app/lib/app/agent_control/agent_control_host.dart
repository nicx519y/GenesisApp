import 'dart:async';

import 'package:flutter/widgets.dart';

import '../bootstrap/app_services_scope.dart';
import '../bootstrap/service_registry.dart';
import 'agent_control_server.dart';

class AgentControlHost extends StatefulWidget {
  const AgentControlHost({required this.child, super.key});

  final Widget child;

  @override
  State<AgentControlHost> createState() => _AgentControlHostState();
}

class _AgentControlHostState extends State<AgentControlHost> {
  final AgentControlServer _server = AgentControlServer();
  AppServices? _activeServices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.of(context);
    if (!identical(_activeServices, services)) {
      _activeServices = services;
      unawaited(_server.start(services));
    }
  }

  @override
  void dispose() {
    unawaited(_server.stop(force: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
