import 'package:flutter/widgets.dart';

import '../../l10n/genesis_localizations.dart';
import 'camera/mini_phone_camera_strings.dart';

/// Resolves camera copy for the current locale whenever the parent builds.
MiniPhoneCameraStrings miniPhoneCameraStrings(BuildContext context) {
  final l10n = context.l10n;
  return MiniPhoneCameraStrings(
    inThePhoto: l10n.miniPhoneCameraInThePhoto,
    selectedCount: (count) => l10n.miniPhoneCameraSelectedCount(count: count),
    castHint: l10n.miniPhoneCameraCastHint,
    you: l10n.miniPhoneYou,
    describeMoment: l10n.miniPhoneCameraDescribeMoment,
    promptHint: l10n.miniPhoneCameraPromptHint,
    tryTemplate: l10n.miniPhoneCameraTryTemplate,
    templateHint: l10n.miniPhoneCameraTemplateHint,
    povSelfie: l10n.miniPhoneCameraPovSelfie,
    mirrorSelfie: l10n.miniPhoneCameraMirrorSelfie,
    byFriend: l10n.miniPhoneCameraByFriend,
    povSelfiePrompt: l10n.miniPhoneCameraPovSelfiePrompt,
    mirrorSelfiePrompt: l10n.miniPhoneCameraMirrorSelfiePrompt,
    byFriendPrompt: l10n.miniPhoneCameraByFriendPrompt,
    takePhoto: l10n.miniPhoneCameraTakePhoto,
    tryAgain: l10n.miniPhoneCameraTryAgain,
    pricePerPhoto: (price) => l10n.miniPhoneCameraPricePerPhoto(price: price),
    comingSoon: l10n.miniPhoneComingSoon,
    creatingPhoto: l10n.miniPhoneCameraCreatingPhoto,
    creatingTitle: l10n.miniPhoneCameraCreatingTitle,
    creatingBody: l10n.miniPhoneCameraCreatingBody,
    cancel: l10n.cancelAction,
    generationFailed: l10n.miniPhoneCameraGenerationFailed,
    draftPreserved: l10n.miniPhoneCameraDraftPreserved,
    takeAnother: l10n.miniPhoneCameraTakeAnother,
    useInPost: l10n.miniPhoneCameraUseInPost,
    openPhoto: l10n.miniPhoneCameraOpenPhoto,
    imageUnavailable: l10n.miniPhoneCameraImageUnavailable,
    savedToPhotos: l10n.miniPhoneCameraSavedToPhotos,
    syncingPhotos: l10n.miniPhoneCameraSyncingPhotos,
    photoSyncFailed: l10n.miniPhoneCameraPhotoSyncFailed,
  );
}
