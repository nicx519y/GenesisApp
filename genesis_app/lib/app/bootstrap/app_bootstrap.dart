import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'service_registry.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppServices> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final services = ServiceRegistry.build();
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      debugPrint('[Auth][Firebase] initialize failed: $e');
      debugPrint('[Auth][Firebase] stacktrace:\n$st');
    }

    final uid = await services.sessionStore.readUid();
    if (uid == null) {
      try {
        await services.api.bindDevice().timeout(const Duration(seconds: 8));
      } catch (e, st) {
        debugPrint('[Auth][Bootstrap] guest bind failed: $e');
        debugPrint('[Auth][Bootstrap] stacktrace:\n$st');
      }
    }
    return services;
  }
}
