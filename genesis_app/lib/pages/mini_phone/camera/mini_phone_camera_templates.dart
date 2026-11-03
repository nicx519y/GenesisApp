import 'mini_phone_camera_strings.dart';

/// Style illustrations; Debug may reuse them only as labelled preview results.
enum MiniPhoneCameraTemplate {
  povSelfie('selfie'),
  mirrorSelfie('mirror'),
  byFriend('friend'),
  candid('candid'),
  livePhoto('live');

  const MiniPhoneCameraTemplate(this.assetName);
  final String assetName;
  String get assetPath => 'assets/mini_phone/camera-templates/$assetName.jpg';

  String label(MiniPhoneCameraStrings strings) => switch (this) {
    povSelfie => strings.povSelfie,
    mirrorSelfie => strings.mirrorSelfie,
    byFriend => strings.byFriend,
    candid => strings.candid,
    livePhoto => strings.livePhoto,
  };

  String prompt(MiniPhoneCameraStrings strings) => switch (this) {
    povSelfie => strings.povSelfiePrompt,
    mirrorSelfie => strings.mirrorSelfiePrompt,
    byFriend => strings.byFriendPrompt,
    candid => strings.candidPrompt,
    livePhoto => strings.livePhotoPrompt,
  };
}
