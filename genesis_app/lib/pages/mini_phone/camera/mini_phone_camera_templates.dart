import 'mini_phone_camera_strings.dart';

/// These assets illustrate viewpoint only; they never stand in for a result.
enum MiniPhoneCameraTemplate {
  povSelfie('selfie'),
  mirrorSelfie('mirror'),
  byFriend('friend');

  const MiniPhoneCameraTemplate(this.assetName);
  final String assetName;
  String get assetPath => 'assets/mini_phone/camera-templates/$assetName.webp';

  String label(MiniPhoneCameraStrings strings) => switch (this) {
    povSelfie => strings.povSelfie,
    mirrorSelfie => strings.mirrorSelfie,
    byFriend => strings.byFriend,
  };

  String prompt(MiniPhoneCameraStrings strings) => switch (this) {
    povSelfie => strings.povSelfiePrompt,
    mirrorSelfie => strings.mirrorSelfiePrompt,
    byFriend => strings.byFriendPrompt,
  };
}
