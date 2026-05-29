import '../json_utils.dart';

class UnreadSummary {
  const UnreadSummary({
    required this.systemUnread,
    required this.followerUnread,
    required this.commentUnread,
    required this.dmUnread,
    required this.totalUnread,
  });

  factory UnreadSummary.fromJson(Map<String, dynamic> json) {
    return UnreadSummary(
      systemUnread: asInt(
        json['world_apply_unread'],
        fallback: asInt(json['system_unread']),
      ),
      followerUnread: asInt(
        json['follow_unread'],
        fallback: asInt(json['follower_unread']),
      ),
      commentUnread: asInt(
        json['interaction_unread'],
        fallback: asInt(json['comment_unread']),
      ),
      dmUnread: asInt(
        json['direct_message_unread'],
        fallback: asInt(json['dm_unread']),
      ),
      totalUnread: asInt(json['total_unread']),
    );
  }

  static const zero = UnreadSummary(
    systemUnread: 0,
    followerUnread: 0,
    commentUnread: 0,
    dmUnread: 0,
    totalUnread: 0,
  );

  final int systemUnread;
  final int followerUnread;
  final int commentUnread;
  final int dmUnread;
  final int totalUnread;
}
