import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'genesis_telemetry.dart';

enum NativeAppLifecycleEvent { background, foreground }

class NativeAppLifecycleEvents {
  const NativeAppLifecycleEvents._();

  static const channelName = 'com.worldo.ai/app_lifecycle';
  static const EventChannel _channel = EventChannel(channelName);

  static final Stream<NativeAppLifecycleEvent> _events = _channel
      .receiveBroadcastStream()
      .map(tryParse)
      .where((event) => event != null)
      .cast<NativeAppLifecycleEvent>();

  static Stream<NativeAppLifecycleEvent> get events => _events;

  @visibleForTesting
  static NativeAppLifecycleEvent? tryParse(Object? value) {
    return switch (value) {
      'background' => NativeAppLifecycleEvent.background,
      'foreground' => NativeAppLifecycleEvent.foreground,
      _ => null,
    };
  }
}

class GenesisTelemetryAppLifecycleReporter {
  bool _isBackgrounded = false;

  void handle(NativeAppLifecycleEvent event) {
    switch (event) {
      case NativeAppLifecycleEvent.background:
        if (_isBackgrounded) return;
        _isBackgrounded = true;
        GenesisTelemetry.event(
          'app_background',
          category: 'app.lifecycle',
          collectPayload: const <String, Object?>{
            'action_type': 'event',
            'action': 'app_background',
          },
        );
        GenesisTelemetry.handleAppBackgrounded();
      case NativeAppLifecycleEvent.foreground:
        // Native platforms can replay their current foreground state when the
        // Dart listener attaches. It is a cold-start baseline, not a return
        // from the background, so only report foreground after a background.
        if (!_isBackgrounded) return;
        _isBackgrounded = false;
        GenesisTelemetry.event(
          'app_foreground',
          category: 'app.lifecycle',
          collectPayload: const <String, Object?>{
            'action_type': 'event',
            'action': 'app_foreground',
          },
        );
        GenesisTelemetry.handleAppResumed();
    }
  }
}
