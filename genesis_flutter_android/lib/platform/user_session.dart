import 'dart:io';

import 'package:flutter/services.dart';

class UserSession {
  static const MethodChannel _channel = MethodChannel('com.genesis.ai/device');
  static String? _memoryUid;

  static Future<void> saveUid(String uid) async {
    final value = uid.trim();
    if (value.isEmpty) return;
    _memoryUid = value;
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setUid', {'uid': value});
  }

  static Future<String?> readUid() async {
    if (!Platform.isAndroid) return _memoryUid;
    final uid = await _channel.invokeMethod<String>('getUid');
    final value = (uid ?? '').trim();
    return value.isEmpty ? null : value;
  }

  static Future<void> clearUid() async {
    _memoryUid = null;
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearUid');
  }
}
