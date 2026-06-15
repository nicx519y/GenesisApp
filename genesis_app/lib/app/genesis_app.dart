import 'package:flutter/material.dart';

import '../routers/app_router.dart';
import '../ui/genesis_ui.dart';
import 'bootstrap/app_services_scope.dart';
import 'bootstrap/service_registry.dart';

class GenesisApp extends StatelessWidget {
  const GenesisApp({super.key, this.services});

  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: services ?? ServiceRegistry.build(),
      child: MaterialApp(
        title: 'worldo',
        debugShowCheckedModeBanner: false,
        theme: GenesisTheme.light(),
        initialRoute: RouteNames.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
