import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/app_endpoint_overrides.dart';

Future<AppConfig> loadStartupEndpointConfig({
  Future<AppConfig> Function()? load,
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    return await Future<AppConfig>.sync(
      load ?? AppEndpointOverrideStore.loadConfig,
    ).timeout(timeout);
  } catch (error) {
    debugPrint(
      '[Startup] endpoint config unavailable (${error.runtimeType}); using defaults',
    );
    return const AppConfig();
  }
}
