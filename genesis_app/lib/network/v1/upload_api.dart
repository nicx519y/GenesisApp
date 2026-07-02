import 'package:flutter/foundation.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../http_transport.dart';
import '../multipart_body.dart';
import '../json_utils.dart';
import 'v1_api_resource.dart';

class UploadV1Api extends V1ApiResource {
  const UploadV1Api(super.client);

  static const int imageUploadTimeoutMs = 120000;

  /// POST /api/v1/upload/image
  ///
  /// 提交参数:
  /// multipart/form-data，字段名 `file`。
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"url":"https://cdn.example.com/uploads/20260526/1234567890.jpg","object_key":"uploads/20260526/1234567890.jpg"}}
  /// ```
  Future<Map<String, dynamic>> image({
    required List<int> bytes,
    String filename = 'upload.jpg',
    String contentType = 'image/jpeg',
    NetworkProgressCallback? onSendProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final prepareStopwatch = Stopwatch()..start();
    GenesisTelemetry.event(
      'image_upload_start',
      category: 'upload.image',
      data: <String, Object?>{
        'file_count': 1,
        'bytes': bytes.length,
        'content_type': contentType,
      },
    );
    final body = MultipartBody.singleFile(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    final bodyBytes = body.toBytes();
    prepareStopwatch.stop();
    final uploadStopwatch = Stopwatch()..start();
    try {
      final json = await client
          .copyWith(timeoutMs: imageUploadTimeoutMs)
          .post<Object?>(
            'v1/upload/image',
            body: bodyBytes,
            headers: {'content-type': body.contentType},
            onSendProgress: onSendProgress,
          );
      final data = handleV1ResponseErrNo(json);
      final result = data == null ? <String, dynamic>{} : asJsonMap(data);
      uploadStopwatch.stop();
      stopwatch.stop();
      GenesisTelemetry.event(
        'image_upload_success',
        category: 'upload.image',
        data: <String, Object?>{
          'file_count': 1,
          'bytes': bytes.length,
          'content_type': contentType,
          'request_bytes': bodyBytes.length,
          'prepare_duration_ms': prepareStopwatch.elapsedMilliseconds,
          'network_duration_ms': uploadStopwatch.elapsedMilliseconds,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );
      _debugPrintImageUploadMetric(
        outcome: 'success',
        bytes: bytes.length,
        requestBytes: bodyBytes.length,
        prepareDuration: prepareStopwatch.elapsed,
        networkDuration: uploadStopwatch.elapsed,
        totalDuration: stopwatch.elapsed,
        errorType: null,
      );
      return result;
    } catch (error) {
      uploadStopwatch.stop();
      stopwatch.stop();
      GenesisTelemetry.event(
        'image_upload_failure',
        category: 'upload.image',
        data: <String, Object?>{
          'file_count': 1,
          'bytes': bytes.length,
          'content_type': contentType,
          'request_bytes': bodyBytes.length,
          'prepare_duration_ms': prepareStopwatch.elapsedMilliseconds,
          'network_duration_ms': uploadStopwatch.elapsedMilliseconds,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType.toString(),
        },
        level: GenesisTelemetryLevel.warning,
      );
      _debugPrintImageUploadMetric(
        outcome: 'failure',
        bytes: bytes.length,
        requestBytes: bodyBytes.length,
        prepareDuration: prepareStopwatch.elapsed,
        networkDuration: uploadStopwatch.elapsed,
        totalDuration: stopwatch.elapsed,
        errorType: error.runtimeType.toString(),
      );
      rethrow;
    }
  }
}

void _debugPrintImageUploadMetric({
  required String outcome,
  required int bytes,
  required int requestBytes,
  required Duration prepareDuration,
  required Duration networkDuration,
  required Duration totalDuration,
  required String? errorType,
}) {
  if (const bool.fromEnvironment('dart.vm.product')) return;
  debugPrint(
    '[Upload][image] outcome=$outcome bytes=$bytes '
    'request_bytes=$requestBytes prepare_ms=${prepareDuration.inMilliseconds} '
    'network_ms=${networkDuration.inMilliseconds} '
    'total_ms=${totalDuration.inMilliseconds}'
    '${errorType == null ? '' : ' error_type=$errorType'}',
  );
}
