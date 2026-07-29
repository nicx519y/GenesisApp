part of 'origin_discuss_library.dart';

Future<bool> showOriginDiscussReplyComposer({
  required BuildContext context,
  required OriginDiscussListController controller,
  required OriginDiscussListItem item,
  String? parentDiscussId,
  String? replyToUid,
  String? replyToUsername,
  String? placeholder,
}) async {
  final discussId = item.discussId.trim();
  final bizId = item.bizId.trim();
  if (discussId.isEmpty || bizId.isEmpty) return false;

  return showDiscussPostComposer(
    context: context,
    title: 'Reply',
    placeholder: placeholder ?? 'Write a reply',
    submitter: (content, images) => submitOriginDiscussReply(
      context: context,
      controller: controller,
      item: item,
      content: content,
      images: images,
      parentDiscussId: parentDiscussId,
      replyToUid: replyToUid,
      replyToUsername: replyToUsername,
    ),
  );
}

Future<void> submitOriginDiscussReply({
  required BuildContext context,
  required OriginDiscussListController controller,
  required OriginDiscussListItem item,
  required String content,
  required List<String> images,
  String? parentDiscussId,
  String? replyToUid,
  String? replyToUsername,
}) async {
  final discussId = item.discussId.trim();
  final rootDiscussId = item.replyRootDiscussId.trim();
  final bizId = item.bizId.trim();
  final resolvedParentDiscussId = parentDiscussId?.trim().isNotEmpty == true
      ? parentDiscussId!.trim()
      : rootDiscussId;
  final resolvedReplyToUid = replyToUid?.trim().isNotEmpty == true
      ? replyToUid!.trim()
      : item.authorUid;
  final resolvedReplyToUsername = replyToUsername?.trim().isNotEmpty == true
      ? replyToUsername!.trim()
      : item.authorName;
  if (discussId.isEmpty || rootDiscussId.isEmpty || bizId.isEmpty) return;

  final services = AppServicesScope.read(context);
  final created = await services.api.v1.discuss.post(
    bizId: bizId,
    content: content,
    images: images,
    rootDiscussId: rootDiscussId,
    parentDiscussId: resolvedParentDiscussId,
  );
  final userInfo = await services.sessionStore.readUserInfo();
  controller.insertReply(
    discussId,
    _localReplyJson(
      created: created,
      content: content,
      images: images,
      bizId: bizId,
      rootDiscussId: rootDiscussId,
      parentDiscussId: resolvedParentDiscussId,
      replyToUid: resolvedReplyToUid,
      replyToUsername: resolvedReplyToUsername,
      userInfo: userInfo,
    ),
  );
}

Map<String, dynamic> _localReplyJson({
  required Map<String, dynamic> created,
  required String content,
  required List<String> images,
  required String bizId,
  required String rootDiscussId,
  required String parentDiscussId,
  required String replyToUid,
  required String replyToUsername,
  required Map<String, dynamic>? userInfo,
}) {
  final user = userInfo == null
      ? const <String, dynamic>{}
      : asJsonMap(userInfo);
  final userMap = user['user'] is Map ? asJsonMap(user['user']) : user;
  final uid = asString(userMap['uid']);
  final name = asString(
    userMap['name'] ??
        userMap['user_name'] ??
        userMap['nickname'] ??
        userMap['display_name'],
    fallback: 'User',
  );
  return {
    'discuss_id': asString(created['discuss_id']),
    'biz_type': 1,
    'biz_id': bizId,
    'author': {
      'uid': uid,
      'name': name,
      'avatar': asImageUrl(userMap['avatar'] ?? userMap['avatar_url']),
    },
    'content': decodeGenesisUgcTextForDisplay(content),
    'images': images,
    'root_discuss_id': rootDiscussId,
    'parent_discuss_id': parentDiscussId,
    'reply_to_uid': replyToUid,
    'reply_to_username': replyToUsername,
    'level': asInt(created['level'], fallback: 2),
    'reply_cnt': 0,
    'like_cnt': 0,
    'is_liked': false,
    'created_at': DateTime.now().toIso8601String(),
  };
}
