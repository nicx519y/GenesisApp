import '../../../network/models/photo_task.dart';

class PhoneWrite {
  PhoneWrite(
    this.id,
    this.kind,
    this.target,
    this.content, {
    this.image,
    this.replyTo,
    this.retryRootId,
  });
  factory PhoneWrite.fromJson(Map<String, dynamic> j) =>
      PhoneWrite(
          j['id'] as String,
          j['kind'] as String,
          j['target'] as String,
          j['content'] as String,
          image: j['image'] as String?,
          replyTo: j['replyTo'] as int?,
          retryRootId: j['retryRootId'] as String?,
        )
        ..cameraInAlbum = j['cameraInAlbum'] == true
        ..cameraConflict = j['cameraConflict'] == true
        ..cameraPhoto = j['cameraPhoto'] == null
            ? null
            : PhotoTask.fromJson(j['cameraPhoto'], requireChatMessageId: false)
        ..accepted = j['accepted'] == true
        ..rejected = j['rejected'] == true
        ..sendReleased = j['sendReleased'] == true
        ..uncertain = true;
  final String id, kind, target, content;
  final String? image, retryRootId;
  final int? replyTo;
  PhotoTask? cameraPhoto;
  bool cameraConflict = false;
  bool cameraInAlbum = false;
  bool accepted = false, uncertain = false, rejected = false;
  // Local unlock is independent of server acceptance and final outcome.
  bool sendReleased = false;
  String get key => '$kind:$target';
  String get recoveryKey => 'dm-recovery:$id';
  String get storageKey => kind == 'dm' && sendReleased ? recoveryKey : key;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'target': target,
    'content': content,
    'image': image,
    'replyTo': replyTo,
    if (retryRootId != null) 'retryRootId': retryRootId,
    'accepted': accepted,
    if (cameraConflict) 'cameraConflict': true,
    if (cameraInAlbum) 'cameraInAlbum': true,
    if (cameraPhoto != null) 'cameraPhoto': cameraPhoto!.toJson(),
    'rejected': rejected,
    if (sendReleased) 'sendReleased': true,
  };
}
