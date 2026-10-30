import 'package:adjust_sdk/adjust.dart';

import 'android_advertising_id_service.dart';

typedef GaidReader = Future<String?> Function();

class GaidResult {
  const GaidResult(this.id, this.source, this.adjustId, this.nativeId);

  final String id;
  final String? source;
  final String adjustId;
  final String nativeId;
}

Future<String?> readSystemGaid() => readGoogleAdvertisingIdFromPlatform();

/// Shared selection policy; optional native capture is diagnostic only.
Future<GaidResult> readGaid({
  GaidReader adjustReader = Adjust.getGoogleAdId,
  GaidReader systemReader = readSystemGaid,
  Duration timeout = const Duration(seconds: 3),
  bool captureNative = false,
}) async {
  Future<String> read(GaidReader reader) async {
    try {
      return (await reader().timeout(timeout))?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool usable(String id) =>
      id.isNotEmpty && id != '00000000-0000-0000-0000-000000000000';

  final adjustId = await read(adjustReader);
  final nativeId = !usable(adjustId) || captureNative
      ? await read(systemReader)
      : '';
  if (usable(adjustId)) {
    return GaidResult(adjustId, 'adjust', adjustId, nativeId);
  }
  if (usable(nativeId)) {
    return GaidResult(nativeId, 'system_api', adjustId, nativeId);
  }
  return GaidResult('', null, adjustId, nativeId);
}
