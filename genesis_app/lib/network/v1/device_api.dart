import '../models/personalization.dart';
import '../../l10n/app_language_controller.dart';
import 'v1_api_resource.dart';

class DeviceV1Api extends V1ApiResource {
  const DeviceV1Api(super.client);

  /// POST /api/v1/device/setlanguage. Preserve exact backend language codes.
  Future<void> setLanguage({
    required String deviceId,
    required String language,
  }) async {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    if (!AppLanguageController.languageCodes.contains(language)) {
      throw ArgumentError.value(language, 'language');
    }
    await postData(
      'device/setlanguage',
      {'language': language},
      {'X-Device-ID': deviceId.trim()},
    );
  }

  /// Registers the Adjust device identifier and the platform-specific
  /// advertising identifiers and Firebase Analytics app instance ID for the
  /// current Gateway device identity.
  ///
  /// An empty ADID means it is not available yet; the server preserves any
  /// previously registered ADID and creates a new device with an empty one.
  /// Unavailable optional identifiers are omitted to preserve server values.
  /// Privacy choices are reported independently and never clear identifiers.
  Future<void> registerAttribution({
    required String adid,
    required String environment,
    String? gpsAdid,
    String? idfa,
    String? idfv,
    String? appInstanceId,
    String? privacyConsent,
  }) async {
    final normalizedAdid = adid.trim();
    final normalizedEnvironment = environment.trim().toLowerCase();
    if (normalizedEnvironment != 'sandbox' &&
        normalizedEnvironment != 'production') {
      throw ArgumentError.value(
        environment,
        'environment',
        'must be sandbox or production',
      );
    }
    String? available(String? value) {
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    }

    await postData(
      'device/register',
      v1Body({
        'adid': normalizedAdid,
        'gps_adid': available(gpsAdid),
        'idfa': available(idfa),
        'idfv': available(idfv),
        'app_instance_id': available(appInstanceId),
        'privacy_consent': privacyConsent,
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
