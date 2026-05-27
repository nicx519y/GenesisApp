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
  }) {
    final boundary = '----genesis-${DateTime.now().microsecondsSinceEpoch}';
    final body = multipartBody(
      boundary: boundary,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      fields: {'biz_type': bizType},
    );
    return postMap('common/upload', body, {
      'content-type': 'multipart/form-data; boundary=$boundary',
    });
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
