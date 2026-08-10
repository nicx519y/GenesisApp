import 'v1_api_resource.dart';

class FeedbackV1Api extends V1ApiResource {
  const FeedbackV1Api(super.client);

  /// POST /api/v1/feedback/create
  ///
  /// Request parameters:
  /// ```json
  /// {"content":"Please add dark mode"}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_msg":"succ","data":{"feedback_id":"fbk_X9KQ4M2A1B2C"}}
  /// ```
  Future<Map<String, dynamic>> create({required String content}) {
    return postMap('feedback/create', v1Body({'content': content}));
  }
}
