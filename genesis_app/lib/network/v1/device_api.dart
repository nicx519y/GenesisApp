import '../models/personalization.dart';
import 'v1_api_resource.dart';

class DeviceV1Api extends V1ApiResource {
  const DeviceV1Api(super.client);

  /// Registers the Adjust device identifier and the platform-specific
  /// advertising identifiers for the current Gateway device identity.
  ///
  /// `null` optional identifiers are omitted so the server preserves their
  /// current values. Empty strings are sent intentionally and clear the
  /// corresponding value according to the API contract.
  Future<void> registerAttribution({
    required String adid,
    String? gpsAdid,
    String? idfa,
    String? idfv,
  }) async {
    final normalizedAdid = adid.trim();
    if (normalizedAdid.isEmpty) {
      throw ArgumentError.value(adid, 'adid', 'must not be empty');
    }
    await postData(
      'device/register',
      v1Body({
        'adid': normalizedAdid,
        'gps_adid': gpsAdid?.trim(),
        'idfa': idfa?.trim(),
        'idfv': idfv?.trim(),
      }),
    );
  }

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
