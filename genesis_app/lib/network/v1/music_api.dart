import '../models/music.dart';
import 'v1_api_resource.dart';

class MusicV1Api extends V1ApiResource {
  const MusicV1Api(super.client);

  /// Guest-accessible, unpaginated catalogue with like_cnt/is_liked per track.
  /// GET /api/v1/music/list has no parameters.
  Future<MusicCatalog> list() async =>
      MusicCatalog.fromJson(await getMap('music/list'));

  /// Authenticated, idempotent POST /api/v1/music/like.
  Future<void> like({required String file}) =>
      postVoid('music/like', {'file': file});

  /// Authenticated, idempotent POST /api/v1/music/unlike.
  Future<void> unlike({required String file}) =>
      postVoid('music/unlike', {'file': file});

  /// The exact catalogue file name is sent without normalization.
  Future<MusicLikeStatus> likeStatus({required String file}) async =>
      MusicLikeStatus.fromJson(
        await getMap('music/like_status', {'file': file}),
      );
}
