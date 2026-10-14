/// Phone IDs are JSON integers, never converted through double or int32.
int phoneId(Object? value) {
  if (value is! int || value <= 0) {
    throw const FormatException('Expected a positive int64 phone ID');
  }
  return value;
}

Map<String, dynamic> phoneMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected phone object');
  return Map<String, dynamic>.from(value);
}

String phoneText(Object? value) => value is String ? value : '';
int phoneCount(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Expected non-negative phone count');
  }
  return value;
}

int phoneActorType(Object? value) {
  if (value is! int || (value != 1 && value != 2)) {
    throw const FormatException('Unsupported phone actor type');
  }
  return value;
}

List<T> phoneList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) throw const FormatException('Expected phone list');
  return value.map((v) => parse(phoneMap(v))).toList(growable: false);
}

class PhonePage<T> {
  const PhonePage(this.list, this.total, this.pn, this.rn);
  factory PhonePage.fromJson(
    Object? value,
    T Function(Map<String, dynamic>) parse,
  ) {
    final j = phoneMap(value);
    return PhonePage(
      phoneList(j['list'], parse),
      phoneCount(j['total']),
      phoneId(j['pn']),
      phoneId(j['rn']),
    );
  }
  final List<T> list;
  final int total, pn, rn;
  bool get hasMore => pn * rn < total;
}

class PhoneMessage {
  PhoneMessage.fromJson(Map<String, dynamic> j)
    : id = phoneId(j['message_id']),
      sessionId = phoneId(j['dm_session_id']),
      worldId = phoneText(j['world_id']),
      senderType = phoneText(j['sender_type']),
      senderId = phoneText(j['sender_id']),
      content = phoneText(j['content']),
      currentTime = phoneText(j['current_time']),
      deliveredAt = phoneText(j['delivered_at']),
      requestId = j['client_request_id'] as String? {
    if (!{'user', 'char'}.contains(senderType) || j['type'] != 'text') {
      throw const FormatException('Unsupported phone message');
    }
  }
  final int id, sessionId;
  final String worldId, senderType, senderId, content, currentTime, deliveredAt;
  final String? requestId;
}

class PhonePerson {
  const PhonePerson(this.id, this.name, this.avatar, {this.type = 2});
  final String id, name, avatar;
  final int type;
  String get key => '$type:$id';
}

class PhoneSession {
  PhoneSession.fromJson(Map<String, dynamic> j)
    : id = phoneId(j['dm_session_id']),
      worldId = phoneText(j['world_id']),
      person = PhonePerson(
        phoneText(j['char_id']),
        phoneText(j['char_name']),
        phoneText(j['char_avatar_url']),
      ),
      unreadCount = phoneCount(j['unread_count']),
      updatedAt = phoneText(j['updated_at']),
      lastMessage = j['last_message'] == null
          ? null
          : PhoneMessage.fromJson(phoneMap(j['last_message']));
  final int id, unreadCount;
  final String worldId, updatedAt;
  final PhonePerson person;
  final PhoneMessage? lastMessage;
}

class PhoneComment {
  PhoneComment.fromJson(Map<String, dynamic> j)
    : id = phoneId(j['comment_id']),
      postId = phoneId(j['post_id']),
      author = PhonePerson(
        phoneText(j['author_id']),
        phoneText(j['author_name']),
        phoneText(j['author_avatar_url']),
        type: phoneActorType(j['author_type']),
      ),
      type = phoneActorType(j['comment_type']),
      text = phoneText(j['text']),
      currentTime = phoneText(j['current_time']),
      publishedAt = phoneText(j['published_at']),
      replyToCommentId = j['reply_to_comment_id'] == null
          ? null
          : phoneId(j['reply_to_comment_id']),
      replyToCharId = j['reply_to_char_id'] as String?;
  final int id, postId, type;
  final int? replyToCommentId;
  final String? replyToCharId;
  final PhonePerson author;
  final String text, currentTime, publishedAt;
}

class PhonePost {
  PhonePost.fromJson(Map<String, dynamic> j)
    : id = phoneId(j['post_id']),
      worldId = phoneText(j['world_id']),
      author = PhonePerson(
        phoneText(j['author_id']),
        phoneText(j['author_name']),
        phoneText(j['author_avatar_url']),
        type: phoneActorType(j['author_type']),
      ),
      text = phoneText(j['text']),
      image = phoneText(j['image']),
      currentTime = phoneText(j['current_time']),
      publishedAt = phoneText(j['published_at']),
      likeCount = phoneCount(j['like_count']),
      commentCount = phoneCount(j['comment_count']),
      isLiked = j['is_liked'] == true,
      // Optional extension: absence must not trigger per-post detail requests.
      commentsPreview = phoneList(
        j['comments_preview'] ?? [],
        PhoneComment.fromJson,
      );
  final int id, likeCount, commentCount;
  final String worldId, text, image, currentTime, publishedAt;
  final PhonePerson author;
  final bool isLiked;
  final List<PhoneComment> commentsPreview;
}

class PhoneDetailComment {
  PhoneDetailComment.fromJson(Map<String, dynamic> j)
    : charId = phoneText(j['char_id']),
      name = phoneText(j['char_name']),
      content = phoneText(j['content']);
  final String charId, name, content;
}

class PhonePostDetail {
  PhonePostDetail.fromJson(Map<String, dynamic> j)
    : charId = phoneText(j['char_id']),
      name = phoneText(j['char_name']),
      content = phoneText(j['content']),
      image = phoneText(j['image']),
      publishedAt = phoneText(j['published_at']),
      likeCount = phoneCount(j['like_count']),
      commentCount = phoneCount(j['comment_count']),
      isLiked = j['is_liked'] == true,
      comments = phoneList(j['comments'], PhoneDetailComment.fromJson);
  final String charId, name, content, image, publishedAt;
  final int likeCount, commentCount;
  final bool isLiked;
  final List<PhoneDetailComment> comments;
}

class PhoneAlbumAsset {
  PhoneAlbumAsset.fromJson(Map<String, dynamic> j)
    : id = phoneId(j['asset_id']),
      worldId = phoneText(j['world_id']),
      image = phoneText(j['image_url']),
      thumbnail = phoneText(j['thumbnail_url']),
      description = phoneText(j['desc']),
      createdAt = phoneText(j['created_at']);
  final int id;
  final String worldId, image, thumbnail, description, createdAt;
}

class PhoneNotification {
  PhoneNotification.fromJson(Map<String, dynamic> j)
    : worldId = phoneText(j['world_id']),
      postId = phoneId(j['post_id']),
      eventType = phoneText(j['event_type']),
      actorType = phoneActorType(j['actor_type']),
      actorId = phoneText(j['actor_id']),
      currentTime = phoneText(j['current_time']),
      publishedAt = phoneText(j['published_at']),
      readAt = j['read_at'] as String?;
  final int postId, actorType;
  final String worldId, eventType, actorId, currentTime, publishedAt;
  final String? readAt;
}

class PhoneHome {
  const PhoneHome({
    this.dmUnread = 0,
    this.postUnread = 0,
    this.messages = const [],
    this.notifications = const [],
  });
  factory PhoneHome.fromJson(Object? value) {
    final j = phoneMap(value),
        dms = phoneMap(j['dms']),
        posts = phoneMap(j['posts']);
    return PhoneHome(
      dmUnread: phoneCount(dms['unread_count']),
      postUnread: phoneCount(posts['unread_count']),
      messages: phoneList(dms['list'], PhoneMessage.fromJson),
      notifications: phoneList(posts['list'], PhoneNotification.fromJson),
    );
  }
  final int dmUnread, postUnread;
  final List<PhoneMessage> messages;
  final List<PhoneNotification> notifications;
}

class PhoneUnread {
  const PhoneUnread(this.count, this.charId);
  factory PhoneUnread.fromJson(Object? value) {
    final j = phoneMap(value);
    return PhoneUnread(phoneCount(j['unread_count']), j['char_id'] as String?);
  }
  final int count;
  final String? charId;
}
