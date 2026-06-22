import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/genesis_app.dart';
import 'components/common/genesis_modal_routes.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  final services = AppBootstrap.createInitialServices();
  GenesisSystemUiChrome.applyDefault();
  runApp(GenesisApp(services: services));
  unawaited(AppBootstrap.warmUp(services));
}
