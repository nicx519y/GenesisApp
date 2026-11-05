import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chat_photo.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_photo_visibility.dart';

void main() {
  const pending = ChatPhoto(
    taskId: 't',
    requestId: '',
    status: ChatPhotoStatus.generating,
  );
  const failed = ChatPhoto(
    taskId: 't',
    requestId: '',
    status: ChatPhotoStatus.failed,
  );
  bool visible(
    LocationChatPhotoVisibility visit,
    ChatPhoto photo, {
    int revision = 5,
    bool confirmed = false,
  }) => visit.includes(
    photo,
    liveRevision: revision,
    confirmedGenerating: confirmed,
  );
  test(
    'cached pending corrected to failed during initial calibration stays hidden',
    () {
      final visit = LocationChatPhotoVisibility(liveBaseline: 5);
      expect(visible(visit, pending), isTrue);
      expect(visible(visit, failed), isFalse);
      visit.calibrated = true;
      expect(visible(visit, failed), isFalse);
    },
  );
  test(
    'new live failures persist through rebuild and reconnect but not reentry',
    () {
      final visit = LocationChatPhotoVisibility(liveBaseline: 5);
      expect(visible(visit, failed, revision: 6), isTrue);
      visit.calibrated = true;
      expect(visible(visit, failed), isTrue);
      expect(
        visible(
          LocationChatPhotoVisibility(liveBaseline: 6),
          failed,
          revision: 6,
        ),
        isFalse,
      );
    },
  );
  test(
    'confirmed ongoing task may fail during this visit; unconfirmed cache may not',
    () {
      final visit = LocationChatPhotoVisibility(liveBaseline: 5)
        ..calibrated = true;
      expect(visible(visit, pending, confirmed: true), isTrue);
      expect(visible(visit, failed), isTrue);
      final offlineVisit = LocationChatPhotoVisibility(liveBaseline: 5)
        ..calibrated = true;
      expect(visible(offlineVisit, pending), isTrue);
      expect(visible(offlineVisit, failed), isFalse);
    },
  );
}
