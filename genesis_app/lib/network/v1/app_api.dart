import '../models/app_version_check.dart';
import '../api_client.dart';
import 'v1_api_resource.dart';

class AppV1Api extends V1ApiResource {
  const AppV1Api(super.client);

  /// GET /api/v1/app/config
  Future<Map<String, dynamic>> config({String? uid}) => getMapWithTracePolicy(
    'app/config',
    query: v1Query({'uid': uid}),
    tracePolicy: ApiRequestTracePolicy.always,
  );

  /// POST /api/v1/app/version/check
  Future<AppVersionCheckResponse> versionCheck({
    required String appId,
    required String platform,
    required String channel,
    required int versionCode,
    String? versionName,
    String? deviceId,
    String? uid,
  }) async {
    final data = await postMap(
      'app/version/check',
      v1Body({
        'app_id': appId,
        'platform': platform,
        'channel': channel,
        'version_name': versionName,
        'version_code': versionCode,
        'device_id': deviceId,
        'uid': uid,
      }),
    );
    return AppVersionCheckResponse.fromJson(data);
  }
}
