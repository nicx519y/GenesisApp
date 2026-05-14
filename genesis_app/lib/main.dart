import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/genesis_app.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  final services = await AppBootstrap.initialize();
  runApp(GenesisApp(services: services));
}
