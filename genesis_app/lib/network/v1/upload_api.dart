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
  }) async {
    final boundary = '----genesis-${DateTime.now().microsecondsSinceEpoch}';
    final body = multipartBody(
      boundary: boundary,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    final json = await client
        .copyWith(timeoutMs: imageUploadTimeoutMs)
        .post<Object?>(
          'v1/upload/image',
          body: body,
          headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        );
    final data = handleV1ResponseErrNo(json);
    return data == null ? <String, dynamic>{} : asJsonMap(data);
  }
}
