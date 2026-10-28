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
        ..accepted = j['accepted'] == true
        ..rejected = j['rejected'] == true
        ..uncertain = true;
  final String id, kind, target, content;
  final String? image, retryRootId;
  final int? replyTo;
  bool accepted = false, uncertain = false, rejected = false;
  String get key => '$kind:$target';
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'target': target,
    'content': content,
    'image': image,
    'replyTo': replyTo,
    if (retryRootId != null) 'retryRootId': retryRootId,
    'accepted': accepted,
    'rejected': rejected,
  };
}
