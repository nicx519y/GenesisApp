import 'package:flutter/material.dart';
import '../../../l10n/genesis_localizations.dart';
import '../../../network/models/photo_task.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../shared/mini_phone_ui.dart';
import '../state/mini_phone_write.dart';

class CameraTaskAlbumTile extends StatelessWidget {
  const CameraTaskAlbumTile({super.key, required this.write});
  final PhoneWrite write;
  @override
  Widget build(BuildContext context) {
    final photo = write.cameraPhoto;
    final failed = photo?.status == PhotoTaskStatus.failed;
    final text = photo == null
        ? context.l10n.cameraSubmissionUnconfirmed
        : failed
        ? (photo.failureMessage.isNotEmpty
              ? photo.failureMessage
              : context.l10n.chatPhotoFailed)
        : context.l10n.miniPhoneCameraCreatingPhoto;
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: miniRaised,
          border: Border.all(
            color: failed ? miniRed.withValues(alpha: .25) : miniLine,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (photo?.status == PhotoTaskStatus.generating)
              const SizedBox.square(
                dimension: 22,
                child: GenesisLoadingIndicator(
                  strokeWidth: 1.5,
                  color: miniWhite,
                ),
              )
            else
              Icon(
                failed ? Icons.broken_image_outlined : Icons.help_outline,
                size: 22,
                color: miniSecondary,
              ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: miniStyle(11, FontWeight.w400, miniSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
