import 'package:flutter/foundation.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../http_transport.dart';
import '../json_utils.dart';
import '../multipart_body.dart';
import 'v1_api_resource.dart';

class CommonV1Api extends V1ApiResource {
  const CommonV1Api(super.client);

  /// POST /api/v1/common/upload
  ///
  /// 提交参数:
  /// ```json
  /// {"file":"binary","biz_type":"avatar"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"file_id":"string","biz_type":"avatar","file_url":"string","width":0,"height":0,"file_size":0}}
  /// ```
  Future<Map<String, dynamic>> uploadFile({
    required List<int> bytes,
    required String bizType,
    String filename = 'upload.bin',
    String contentType = 'application/octet-stream',
    NetworkProgressCallback? onSendProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final prepareStopwatch = Stopwatch()..start();
    GenesisTelemetry.event(
      'file_upload_start',
      category: 'upload.file',
      data: <String, Object?>{
        'file_count': 1,
        'bytes': bytes.length,
        'content_type': contentType,
        'biz_type': bizType,
      },
    );
    final body = MultipartBody.singleFile(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      fields: {'biz_type': bizType},
    );
    final bodyBytes = body.toBytes();
    prepareStopwatch.stop();
    final uploadStopwatch = Stopwatch()..start();
    try {
      final json = await client.post<Object?>(
        'v1/common/upload',
        body: bodyBytes,
        headers: {'content-type': body.contentType},
        onSendProgress: onSendProgress,
      );
      final data = handleV1ResponseErrNo(json);
      final result = data == null ? <String, dynamic>{} : asJsonMap(data);
      uploadStopwatch.stop();
      stopwatch.stop();
      GenesisTelemetry.event(
        'file_upload_success',
        category: 'upload.file',
        data: <String, Object?>{
          'file_count': 1,
          'bytes': bytes.length,
          'content_type': contentType,
          'biz_type': bizType,
          'request_bytes': bodyBytes.length,
          'prepare_duration_ms': prepareStopwatch.elapsedMilliseconds,
          'network_duration_ms': uploadStopwatch.elapsedMilliseconds,
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );
      _debugPrintFileUploadMetric(
        outcome: 'success',
        bytes: bytes.length,
        requestBytes: bodyBytes.length,
        prepareDuration: prepareStopwatch.elapsed,
        networkDuration: uploadStopwatch.elapsed,
        totalDuration: stopwatch.elapsed,
        bizType: bizType,
        errorType: null,
      );
      return result;
    } catch (error) {
      uploadStopwatch.stop();
      stopwatch.stop();
      GenesisTelemetry.event(
        'file_upload_failure',
        category: 'upload.file',
        data: <String, Object?>{
          'file_count': 1,
          'bytes': bytes.length,
          'content_type': contentType,
          'biz_type': bizType,
          'request_bytes': bodyBytes.length,
          'prepare_duration_ms': prepareStopwatch.elapsedMilliseconds,
          'network_duration_ms': uploadStopwatch.elapsedMilliseconds,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType.toString(),
        },
        level: GenesisTelemetryLevel.warning,
      );
      _debugPrintFileUploadMetric(
        outcome: 'failure',
        bytes: bytes.length,
        requestBytes: bodyBytes.length,
        prepareDuration: prepareStopwatch.elapsed,
        networkDuration: uploadStopwatch.elapsed,
        totalDuration: stopwatch.elapsed,
        bizType: bizType,
        errorType: error.runtimeType.toString(),
      );
      rethrow;
    }
  }

  /// POST /api/v1/common/drafts
  ///
  /// 提交参数:
  /// ```json
  /// {"draft_type":"origin_create","draft_id":"string","draft_data":{}}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"draft_id":"string","draft_type":"origin_create","draft_data":{},"update_time":"string","expire_time":"string"}}
  /// ```
  Future<Map<String, dynamic>> saveDraft({
    required String draftType,
    String? draftId,
    required Map<String, dynamic> draftData,
  }) {
    return postMap(
      'common/drafts',
      v1Body({
        'draft_type': draftType,
        'draft_id': draftId,
        'draft_data': draftData,
      }),
    );
  }

  /// GET /api/v1/common/drafts
  ///
  /// 提交参数:
  /// ```json
  /// {"draft_type":"origin_create"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"draft_id":"string","draft_type":"origin_create","draft_data":{},"update_time":"string","expire_time":"string"}}
  /// ```
  Future<Object?> readDraft({required String draftType}) {
    return getData('common/drafts', {'draft_type': draftType});
  }

  /// POST /api/v1/common/drafts/del
  ///
  /// 提交参数:
  /// ```json
  /// {"draft_id":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> deleteDraft({required String draftId}) {
    return postVoid('common/drafts/del', {'draft_id': draftId});
  }

  /// POST /api/v1/common/devices/register
  ///
  /// 提交参数:
  /// ```json
  /// {"device_id":"d_xxx","platform":"android","package_name":"string","app_version":"string"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{}}
  /// ```
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    String? packageName,
    String? appVersion,
  }) {
    return postVoid(
      'common/devices/register',
      v1Body({
        'device_id': deviceId,
        'platform': platform,
        'package_name': packageName,
        'app_version': appVersion,
      }),
    );
  }
}

void _debugPrintFileUploadMetric({
  required String outcome,
  required int bytes,
  required int requestBytes,
  required Duration prepareDuration,
  required Duration networkDuration,
  required Duration totalDuration,
  required String bizType,
  required String? errorType,
}) {
  if (const bool.fromEnvironment('dart.vm.product')) return;
  debugPrint(
    '[Upload][file] outcome=$outcome biz_type=$bizType bytes=$bytes '
    'request_bytes=$requestBytes prepare_ms=${prepareDuration.inMilliseconds} '
    'network_ms=${networkDuration.inMilliseconds} '
    'total_ms=${totalDuration.inMilliseconds}'
    '${errorType == null ? '' : ' error_type=$errorType'}',
  );
}
