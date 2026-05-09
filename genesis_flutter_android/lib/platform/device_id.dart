import 'dart:io';

import 'package:flutter/services.dart';

class DeviceId {
  static const MethodChannel _channel = MethodChannel('com.genesis.ai/device');

  static Future<String> androidId() async {
    if (!Platform.isAndroid) return 'unknown';
    final id = await _channel.invokeMethod<String>('getAndroidId');
    final value = (id ?? '').trim();
    return value.isEmpty ? 'unknown' : value;
  }
}
