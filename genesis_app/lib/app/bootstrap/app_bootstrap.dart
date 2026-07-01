import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import '../telemetry/genesis_telemetry.dart';
import '../telemetry/firebase_crash_reporting.dart';
import '../telemetry/firebase_performance_monitoring.dart';
import 'service_registry.dart';

class AppBootstrap {
  const AppBootstrap._();

  static const _firebaseInitializeTimeout = Duration(seconds: 4);
  static const _gatewayPrepareTimeout = Duration(seconds: 8);
  static const _networkPermissionPrimeTimeout = Duration(seconds: 15);
  static const _sessionReadTimeout = Duration(seconds: 2);
  static const _guestBindTimeout = Duration(seconds: 8);
  static Future<void>? _firebasePerformanceInitialization;

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

  static Future<void> primeNetworkPermission(AppServices services) async {
    try {
      await services.api.v1.origin.homeNav().timeout(
        _networkPermissionPrimeTimeout,
      );
    } catch (e, st) {
      debugPrint('[Auth][Bootstrap] network permission prime failed: $e');
      debugPrint('[Auth][Bootstrap] stacktrace:\n$st');
    }
  }

  static Future<void> ensureFirebasePerformanceMonitoring() {
    final inFlight = _firebasePerformanceInitialization;
    if (inFlight != null) return inFlight;
    final future = _initializeFirebasePerformanceMonitoring();
    _firebasePerformanceInitialization = future;
    return future;
  }

  static Future<void> _initializeFirebasePerformanceMonitoring() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(_firebaseInitializeTimeout);
      }
      await FirebasePerformanceMonitoring.enable();
    } catch (e, st) {
      _firebasePerformanceInitialization = null;
      debugPrint('[Auth][Firebase] initialize failed: $e');
      debugPrint('[Auth][Firebase] stacktrace:\n$st');
    }
  }

  static Future<void> warmUp(AppServices services) async {
    await ensureFirebasePerformanceMonitoring();
    await FirebaseCrashReporting.enable();

    try {
      await services.gatewayAuth?.prepare().timeout(_gatewayPrepareTimeout);
    } catch (e, st) {
      debugPrint('[GatewayAuth] warm-up prepare failed: $e');
      debugPrint('[GatewayAuth] stacktrace:\n$st');
    }

    String? uid;
    try {
      uid = await services.sessionStore.readUid().timeout(_sessionReadTimeout);
    } catch (e, st) {
      debugPrint('[Auth][Bootstrap] session read failed: $e');
      debugPrint('[Auth][Bootstrap] stacktrace:\n$st');
    }
    final normalizedUid = uid?.trim() ?? '';
    if (normalizedUid.isNotEmpty && !normalizedUid.startsWith('guest_')) {
      GenesisTelemetry.setUserId(normalizedUid);
    } else {
      if (normalizedUid.startsWith('guest_')) {
        await services.sessionStore.clearUid();
      }
      try {
        await services.api.bindDevice().timeout(_guestBindTimeout);
      } catch (e, st) {
        debugPrint('[Auth][Bootstrap] guest bind failed: $e');
        debugPrint('[Auth][Bootstrap] stacktrace:\n$st');
      }
    }
  }
}
