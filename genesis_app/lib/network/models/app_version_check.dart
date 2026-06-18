import '../json_utils.dart';

class AppVersionCheckResponse {
  const AppVersionCheckResponse({
    required this.needUpgrade,
    required this.forceUpgrade,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minVersionCode,
    required this.upgradeType,
    required this.title,
    required this.content,
    required this.downloadUrl,
    required this.storeUrl,
    required this.packageSize,
    required this.packageMd5,
    required this.canIgnore,
  });

  factory AppVersionCheckResponse.fromJson(Map<String, dynamic> json) {
    return AppVersionCheckResponse(
      needUpgrade: asBool(json['need_upgrade']),
      forceUpgrade: asBool(json['force_upgrade']),
      latestVersionName: asString(json['latest_version_name']).trim(),
      latestVersionCode: asInt(json['latest_version_code']),
      minVersionCode: asInt(json['min_version_code']),
      upgradeType: asInt(json['upgrade_type']),
      title: asString(json['title']).trim(),
      content: asString(json['content']).trim(),
      downloadUrl: asString(json['download_url']).trim(),
      storeUrl: asString(json['store_url']).trim(),
      packageSize: asInt(json['package_size']),
      packageMd5: asString(json['package_md5']).trim(),
      canIgnore: asBool(json['can_ignore']),
    );
  }

  static const none = AppVersionCheckResponse(
    needUpgrade: false,
    forceUpgrade: false,
    latestVersionName: '',
    latestVersionCode: 0,
    minVersionCode: 0,
    upgradeType: 0,
    title: '',
    content: '',
    downloadUrl: '',
    storeUrl: '',
    packageSize: 0,
    packageMd5: '',
    canIgnore: true,
  );

  final bool needUpgrade;
  final bool forceUpgrade;
  final String latestVersionName;
  final int latestVersionCode;
  final int minVersionCode;
  final int upgradeType;
  final String title;
  final String content;
  final String downloadUrl;
  final String storeUrl;
  final int packageSize;
  final String packageMd5;
  final bool canIgnore;

  bool get shouldForceUpgrade => needUpgrade && forceUpgrade;

  String get updateUrl {
    if (storeUrl.isNotEmpty) return storeUrl;
    return downloadUrl;
  }
}
