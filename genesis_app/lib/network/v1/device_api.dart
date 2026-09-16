import '../models/personalization.dart';
import 'v1_api_resource.dart';

class DeviceV1Api extends V1ApiResource {
  const DeviceV1Api(super.client);

  Future<PersonalizationData> personalization({
    required String deviceId,
  }) async => PersonalizationData.fromJson(
    await getMapWithHeaders(
      'device/personalization',
      headers: {'X-Device-ID': deviceId, 'Cache-Control': 'no-store'},
    ),
  );

  Future<PersonalizationProfile> savePersonalization({
    required String deviceId,
    required PersonalizationProfile profile,
  }) async => PersonalizationProfile.fromJson(
    await postMap('device/personalization', profile.toJson(), {
      'X-Device-ID': deviceId,
    }),
  );

  Future<PersonalizationProfile> updateOriginFeedGender({
    required String deviceId,
    required String gender,
  }) async {
    if (!const {'Male', 'Female', 'Non_binary', 'All'}.contains(gender)) {
      throw ArgumentError.value(gender, 'gender');
    }
    return PersonalizationProfile.fromJson(
      await postMap(
        'device/personalization/update_origin_feed_gender',
        {'origin_feed_gender': gender},
        {'X-Device-ID': deviceId},
      ),
    );
  }
}
