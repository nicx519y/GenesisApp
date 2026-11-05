import 'mini_phone_camera_strings.dart';

/// Legacy composition presets for adapter previews, without bundled artwork.
enum MiniPhoneCameraTemplate {
  povSelfie,
  mirrorSelfie,
  byFriend,
  candid,
  livePhoto;

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
