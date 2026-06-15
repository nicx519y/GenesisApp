import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/genesis_app.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  final services = await AppBootstrap.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFFFFFF),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(GenesisApp(services: services));
}
