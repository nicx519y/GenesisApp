import 'v1_api_resource.dart';

class ReportV1Api extends V1ApiResource {
  const ReportV1Api(super.client);

  /// POST /api/v1/report/create
  ///
  /// 提交参数:
  /// ```json
  /// {"target_type":"origin","target_id":"o_A1B2C3","content":"内容疑似违规"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"report_id":"rpt_X9KQ4M2A1B2C"}}
  /// ```
  Future<Map<String, dynamic>> create({
    required String targetType,
    required String targetId,
    required String content,
  }) {
    return postMap(
      'report/create',
      v1Body({
        'target_type': targetType,
        'target_id': targetId,
        'content': content,
      }),
    );
  }
}
