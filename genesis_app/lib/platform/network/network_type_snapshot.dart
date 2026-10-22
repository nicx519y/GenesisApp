import 'package:flutter/services.dart';

/// Diagnostic transport types only; never a reachability check.
class NetworkTypeSnapshot {
  static const _channel = MethodChannel('com.worldo.ai/device');
  static const _order = [
    'wifi',
    'mobile',
    'ethernet',
    'bluetooth',
    'vpn',
    'satellite',
  ];

  static Future<String> read() async {
    try {
      final values = await _channel.invokeListMethod<String>('getNetworkTypes');
      return normalize(values ?? const []);
    } catch (_) {
      return 'unknown';
    }
  }

  static String normalize(List<String> values) {
    final types = _order.where(values.contains).toList();
    if (types.isNotEmpty) return types.join(',');
    return values.contains('none') ? 'none' : 'unknown';
  }
}
