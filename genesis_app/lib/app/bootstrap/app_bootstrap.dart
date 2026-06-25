import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'service_registry.dart';

class AppBootstrap {
  const AppBootstrap._();

  static const _firebaseInitializeTimeout = Duration(seconds: 4);
  static const _sessionReadTimeout = Duration(seconds: 2);
  static const _guestBindTimeout = Duration(seconds: 8);

  static AppServices createInitialServices({
    AppConfig config = const AppConfig(),
  }) {
    WidgetsFlutterBinding.ensureInitialized();
    return ServiceRegistry.build(config: config);
  }

  static Future<AppServices> initialize() async {
    final services = createInitialServices();
    await warmUp(services);
    return services;
  }

  static Future<void> warmUp(AppServices services) async {
    try {
      await Firebase.initializeApp().timeout(_firebaseInitializeTimeout);
    } catch (e, st) {
      debugPrint('[Auth][Firebase] initialize failed: $e');
      debugPrint('[Auth][Firebase] stacktrace:\n$st');
    }

    String? uid;
    try {
      uid = await services.sessionStore.readUid().timeout(_sessionReadTimeout);
    } catch (e, st) {
      debugPrint('[Auth][Bootstrap] session read failed: $e');
      debugPrint('[Auth][Bootstrap] stacktrace:\n$st');
    }
    if (uid == null) {
      try {
        await services.api.bindDevice().timeout(_guestBindTimeout);
      } catch (e, st) {
        debugPrint('[Auth][Bootstrap] guest bind failed: $e');
        debugPrint('[Auth][Bootstrap] stacktrace:\n$st');
      }
    }
  }
}
