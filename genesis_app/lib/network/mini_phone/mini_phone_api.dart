import '../api_client.dart';
import '../api_exception.dart';
import '../v1/v1_api_resource.dart';
import 'mini_phone_models.dart';
export 'mini_phone_models.dart';

class MiniPhoneApi {
  MiniPhoneApi(this.client);
  final ApiClient client;
  static const prefix = 'aitown-chat/api/v1/phone';
  Future<Object?> _request(
    String path,
    Map<String, dynamic> values, {
    bool post = false,
  }) async {
    for (final entry in values.entries) {
      if ({
            'world_id',
            'char_id',
            'client_request_id',
            'content',
          }.contains(entry.key) &&
          (entry.value is! String || (entry.value as String).trim().isEmpty)) {
        throw ArgumentError.value(entry.value, entry.key, 'Must not be empty');
      }
      if ({
        'dm_session_id',
        'post_id',
        'reply_to_comment_id',
        'pn',
        'rn',
      }.contains(entry.key)) {
        phoneId(entry.value);
      }
    }
    final Object? raw = post
        ? await client.post<Object?>('$prefix/$path', body: values)
        : await client.get<Object?>('$prefix/$path', query: v1Query(values));
    if (raw is! Map || raw['err_no'] is! int) {
      throw ApiException(
        message: 'Invalid MiniPhone response',
        kind: ApiExceptionKind.response,
      );
    }
    return handleV1ResponseErrNo(raw);
  }

  Future<PhonePage<T>> _page<T>(
    String path,
    Map<String, dynamic> query,
    T Function(Map<String, dynamic>) parse,
    int pn,
    int rn,
  ) async => PhonePage.fromJson(
    await _request(path, {...query, 'pn': pn, 'rn': rn}),
    parse,
  );
  Future<void> _write(String path, Map<String, dynamic> body) async {
    await _request(path, body, post: true);
  }

  Future<PhoneHome> home(String worldId) async =>
      PhoneHome.fromJson(await _request('home', {'world_id': worldId}));
  Future<PhoneUnread> unread(String worldId) async =>
      PhoneUnread.fromJson(await _request('unread', {'world_id': worldId}));
  Future<PhonePage<PhoneSession>> sessions(
    String worldId, {
    int pn = 1,
    int rn = 10,
    bool unreadOnly = false,
  }) => _page(
    'dm_sessions',
    {'world_id': worldId, 'unread_only': unreadOnly},
    PhoneSession.fromJson,
    pn,
    rn,
  );
  Future<PhonePage<PhoneMessage>> messages(
    String worldId,
    int sessionId, {
    int pn = 1,
    int rn = 10,
  }) => _page(
    'messages',
    {'world_id': worldId, 'dm_session_id': sessionId},
    PhoneMessage.fromJson,
    pn,
    rn,
  );
  Future<void> send(
    String worldId,
    String charId,
    String requestId,
    String content,
  ) => _write('dm/send', {
    'world_id': worldId,
    'char_id': charId,
    'client_request_id': requestId,
    'content': content,
  });
  Future<void> readSession(int sessionId) =>
      _write('dm_session/read', {'dm_session_id': sessionId});
  Future<PhonePage<PhoneNotification>> notifications(
    String worldId, {
    int pn = 1,
    int rn = 10,
    bool unreadOnly = true,
  }) => _page(
    'post/notifications',
    {'world_id': worldId, 'unread_only': unreadOnly},
    PhoneNotification.fromJson,
    pn,
    rn,
  );
  Future<void> readPosts(String worldId) =>
      _write('post/notifications/read', {'world_id': worldId});
  Future<PhonePage<PhonePost>> posts(
    String worldId, {
    int pn = 1,
    int rn = 10,
    PhonePerson? author,
  }) => _page(
    'posts',
    {
      'world_id': worldId,
      if (author != null) ...{
        'author_type': author.type,
        'author_id': author.id,
      },
    },
    PhonePost.fromJson,
    pn,
    rn,
  );
  Future<PhonePostDetail> detail(String worldId, int postId) async =>
      PhonePostDetail.fromJson(
        phoneMap(
          await _request('post/detail', {
            'world_id': worldId,
            'post_id': postId,
          }),
        ),
      );
  Future<void> createPost(
    String worldId,
    String requestId,
    String content, {
    String? image,
  }) => _write('post/create', {
    'world_id': worldId,
    'client_request_id': requestId,
    'content': content,
    if (image != null && image.isNotEmpty) 'image': image,
  });
  Future<void> like(String worldId, int postId) =>
      _write('post/like', {'world_id': worldId, 'post_id': postId});
  Future<void> unlike(String worldId, int postId) =>
      _write('post/unlike', {'world_id': worldId, 'post_id': postId});
  Future<PhonePage<PhoneComment>> comments(
    String worldId,
    int postId, {
    int pn = 1,
    int rn = 10,
  }) => _page(
    'comments',
    {'world_id': worldId, 'post_id': postId},
    PhoneComment.fromJson,
    pn,
    rn,
  );
  Future<void> comment(
    String worldId,
    int postId,
    String requestId,
    String content, {
    int? replyToCommentId,
  }) => _write('comment/create', {
    'world_id': worldId,
    'post_id': postId,
    'client_request_id': requestId,
    'content': content,
    if (replyToCommentId != null) 'reply_to_comment_id': replyToCommentId,
  });
  Future<PhonePage<PhoneAlbumAsset>> album(
    String worldId, {
    int pn = 1,
    int rn = 10,
  }) => _page('album', {'world_id': worldId}, PhoneAlbumAsset.fromJson, pn, rn);
}
