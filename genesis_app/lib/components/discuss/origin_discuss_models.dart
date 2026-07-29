part of 'origin_discuss_library.dart';

class OriginDiscussRepliesPage {
  const OriginDiscussRepliesPage({
    required this.comment,
    required this.items,
    required this.total,
    required this.pn,
    required this.rn,
  });

  factory OriginDiscussRepliesPage.fromJson(Map<String, dynamic> json) {
    final comment = json['comment'] is Map
        ? OriginDiscussListItem.fromJson(asJsonMap(json['comment']))
        : null;
    final rawList = json['list'];
    final items = rawList is List
        ? rawList
              .whereType<Map>()
              .map((raw) => asJsonMap(raw))
              .map(_decodeDiscussContentForDisplay)
              .where((item) {
                final content = asString(item['content']).trim();
                final images = _imageUrlsFrom(item['images']);
                return content.isNotEmpty || images.isNotEmpty;
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return OriginDiscussRepliesPage(
      comment: comment,
      items: items,
      total: asInt(json['total'], fallback: items.length),
      pn: asInt(json['pn'], fallback: 1),
      rn: asInt(json['rn'], fallback: originDiscussRepliesPageSize),
    );
  }

  final OriginDiscussListItem? comment;
  final List<Map<String, dynamic>> items;
  final int total;
  final int pn;
  final int rn;
}

class OriginDiscussPage {
  const OriginDiscussPage({
    required this.items,
    required this.topTotal,
    required this.totalAll,
    required this.pn,
    required this.rn,
  });

  factory OriginDiscussPage.empty({
    int pn = 1,
    int rn = originDiscussPageSize,
  }) {
    return OriginDiscussPage(
      items: const <OriginDiscussListItem>[],
      topTotal: 0,
      totalAll: 0,
      pn: pn,
      rn: rn,
    );
  }

  factory OriginDiscussPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'];
    final items = rawList is List
        ? rawList
              .whereType<Map>()
              .map((raw) => asJsonMap(raw))
              .map(OriginDiscussListItem.fromEnvelopeJson)
              .where((item) => item.level <= 1)
              .where((item) => item.content.trim().isNotEmpty)
              .toList(growable: false)
        : const <OriginDiscussListItem>[];
    return OriginDiscussPage(
      items: items,
      topTotal: asInt(json['top_total'], fallback: items.length),
      totalAll: asInt(json['total_all'], fallback: items.length),
      pn: asInt(json['pn'], fallback: 1),
      rn: asInt(json['rn'], fallback: originDiscussPageSize),
    );
  }

  final List<OriginDiscussListItem> items;
  final int topTotal;
  final int totalAll;
  final int pn;
  final int rn;
}

class OriginDiscussListItem {
  const OriginDiscussListItem({
    required this.discussId,
    this.rootDiscussId = '',
    this.bizId = '',
    this.worldId = '',
    this.authorUid = '',
    this.authorDeleted = false,
    required this.authorName,
    required this.avatar,
    required this.content,
    this.imageUrls = const <String>[],
    this.storyCount = 0,
    required this.replyCount,
    this.likeCount = 0,
    this.isLiked = false,
    this.level = 1,
    required this.createdAt,
    required this.seed,
    required this.latestReplies,
  });

  factory OriginDiscussListItem.fromEnvelopeJson(Map<String, dynamic> json) {
    final comment = json['comment'] is Map ? asJsonMap(json['comment']) : json;
    final latestReplies = json['latest_replies'] is List
        ? asJsonList(json['latest_replies'])
              .whereType<Map>()
              .map((raw) => asJsonMap(raw))
              .map(_decodeDiscussContentForDisplay)
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return OriginDiscussListItem.fromJson(
      comment,
      latestReplies: latestReplies,
    );
  }

  factory OriginDiscussListItem.fromJson(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>> latestReplies = const <Map<String, dynamic>>[],
  }) {
    final author = json['author'] is Map ? asJsonMap(json['author']) : null;
    final uid = asString(author?['uid'], fallback: asString(json['uid']));
    final name = asString(
      author?['name'] ??
          author?['user_name'] ??
          author?['nickname'] ??
          author?['display_name'] ??
          json['author_name'] ??
          json['user_name'],
      fallback: formatUidForDisplay(uid, fallback: 'User'),
    );
    return OriginDiscussListItem(
      discussId: asString(json['discuss_id']),
      rootDiscussId: asString(json['root_discuss_id']),
      bizId: asString(json['biz_id']),
      worldId: asString(
        json['world_id'],
        fallback: asString(
          json['wid'],
          fallback: asString(json['display_wid_str']),
        ),
      ),
      authorUid: uid,
      authorDeleted: entityDeleted(author?['deleted']),
      authorName: formatUidForDisplay(name, fallback: 'User'),
      avatar: asImageUrl(author?['avatar'] ?? author?['avatar_url']),
      content: decodeGenesisUgcTextForDisplay(asString(json['content'])),
      imageUrls: _imageUrlsFrom(json['images'] ?? json['image_urls']),
      storyCount: asInt(
        json['story_cnt'],
        fallback: asInt(json['tick_cnt'], fallback: asInt(json['connect_cnt'])),
      ),
      replyCount: asInt(json['reply_cnt']),
      likeCount: asInt(json['like_cnt'], fallback: asInt(json['like_count'])),
      isLiked: asBool(json['is_liked']),
      level: asInt(json['level'], fallback: 1),
      createdAt: _parseDateTime(json['created_at']),
      seed: uid.isEmpty ? name : uid,
      latestReplies: latestReplies,
    );
  }

  final String discussId;
  final String rootDiscussId;
  final String bizId;
  final String worldId;
  final String authorUid;
  final bool authorDeleted;
  final String authorName;
  final String avatar;
  final String content;
  final List<String> imageUrls;
  final int storyCount;
  final int replyCount;
  final int likeCount;
  final bool isLiked;
  final int level;
  final DateTime? createdAt;
  final String seed;
  final List<Map<String, dynamic>> latestReplies;

  String get replyRootDiscussId {
    final rootId = rootDiscussId.trim();
    return rootId.isEmpty ? discussId : rootId;
  }

  OriginDiscussListItem copyWith({
    String? rootDiscussId,
    String? worldId,
    int? storyCount,
    int? replyCount,
    int? likeCount,
    bool? isLiked,
    List<Map<String, dynamic>>? latestReplies,
  }) {
    return OriginDiscussListItem(
      discussId: discussId,
      rootDiscussId: rootDiscussId ?? this.rootDiscussId,
      bizId: bizId,
      worldId: worldId ?? this.worldId,
      authorUid: authorUid,
      authorDeleted: authorDeleted,
      authorName: authorName,
      avatar: avatar,
      content: content,
      imageUrls: imageUrls,
      storyCount: storyCount ?? this.storyCount,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      level: level,
      createdAt: createdAt,
      seed: seed,
      latestReplies: latestReplies ?? this.latestReplies,
    );
  }
}

Map<String, dynamic> _decodeDiscussContentForDisplay(
  Map<String, dynamic> json,
) {
  final content = json['content'];
  if (content is! String || content.isEmpty) return json;
  return <String, dynamic>{
    ...json,
    'content': decodeGenesisUgcTextForDisplay(content),
  };
}
