/// All user-facing camera copy is supplied by the parent's localized strings.
/// Template prompts are editable user input, so they are localized too.
class MiniPhoneCameraStrings {
  const MiniPhoneCameraStrings({
    required this.inThePhoto,
    required this.selectedCount,
    required this.castHint,
    required this.you,
    required this.describeMoment,
    required this.promptHint,
    required this.tryTemplate,
    required this.templateHint,
    required this.povSelfie,
    required this.mirrorSelfie,
    required this.byFriend,
    required this.povSelfiePrompt,
    required this.mirrorSelfiePrompt,
    required this.byFriendPrompt,
    required this.takePhoto,
    required this.tryAgain,
    required this.pricePerPhoto,
    required this.comingSoon,
    required this.creatingPhoto,
    required this.creatingTitle,
    required this.creatingBody,
    required this.cancel,
    required this.generationFailed,
    required this.draftPreserved,
    required this.takeAnother,
    required this.useInPost,
    required this.openPhoto,
    required this.imageUnavailable,
    required this.savedToPhotos,
    required this.syncingPhotos,
    required this.photoSyncFailed,
  });

  final String inThePhoto, castHint, you, describeMoment, promptHint;
  final String tryTemplate, templateHint, povSelfie, mirrorSelfie, byFriend;
  final String povSelfiePrompt, mirrorSelfiePrompt, byFriendPrompt;
  final String takePhoto, tryAgain, comingSoon;
  final String creatingPhoto, creatingTitle, creatingBody, cancel;
  final String generationFailed, draftPreserved, takeAnother, useInPost;
  final String openPhoto, imageUnavailable;
  final String savedToPhotos, syncingPhotos, photoSyncFailed;
  final String Function(int count) selectedCount;
  final String Function(double price) pricePerPhoto;
}

typedef CameraStrings = MiniPhoneCameraStrings;
