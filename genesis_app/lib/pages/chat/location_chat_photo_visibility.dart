import '../../network/chatroom/chat_photo.dart';

/// View-only policy. Never removes the stored message, ID, or pagination cursor.
class LocationChatPhotoVisibility {
  LocationChatPhotoVisibility({required this.liveBaseline});
  final int liveBaseline;
  bool calibrated = false;
  final _visibleTasks = <String>{};

  bool includes(
    ChatPhoto? photo, {
    required int liveRevision,
    required bool confirmedGenerating,
  }) {
    if (photo == null) return true;
    if (liveRevision > liveBaseline ||
        calibrated &&
            confirmedGenerating &&
            photo.status == ChatPhotoStatus.generating) {
      _visibleTasks.add(photo.taskId);
    }
    return photo.status != ChatPhotoStatus.failed ||
        _visibleTasks.contains(photo.taskId);
  }
}
