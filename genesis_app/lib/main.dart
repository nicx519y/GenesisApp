import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/genesis_app.dart';
import 'components/common/genesis_modal_routes.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  final services = await AppBootstrap.initialize();
  GenesisSystemUiChrome.applyDefault();
  runApp(GenesisApp(services: services));
}
