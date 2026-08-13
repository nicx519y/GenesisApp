import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

typedef FirebaseInitializer = Future<void> Function();

/// Owns the single Firebase Core initialization shared by all telemetry SDKs.
class FirebaseRuntime {
  const FirebaseRuntime._();

  static Future<void>? _initialization;
  static FirebaseInitializer _initializer = _initializeFirebase;

  static Future<void> ensureInitialized() {
    final inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final future = _runInitialization();
    _initialization = future;
    return future;
  }

  static Future<void> _runInitialization() async {
    try {
      await _initializer();
    } catch (_) {
      // A transient initialization failure must not permanently disable all
      // Firebase telemetry for the rest of the process lifetime.
      _initialization = null;
      rethrow;
    }
  }

  static Future<void> _initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  @visibleForTesting
  static void setInitializerForTesting(FirebaseInitializer value) {
    _initialization = null;
    _initializer = value;
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialization = null;
    _initializer = _initializeFirebase;
  }
}
