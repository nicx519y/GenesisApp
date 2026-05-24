import '../api_client.dart';
import 'common_api.dart';
import 'discuss_api.dart';
import 'dm_api.dart';
import 'follow_api.dart';
import 'home_api.dart';
import 'messages_api.dart';
import 'origin_api.dart';
import 'search_api.dart';
import 'user_api.dart';
import 'world_api.dart';

class GenesisV1Api {
  GenesisV1Api(ApiClient client)
    : user = UserV1Api(client),
      origin = OriginV1Api(client),
      world = WorldV1Api(client),
      messages = MessagesV1Api(client),
      dm = DmV1Api(client),
      follow = FollowV1Api(client),
      discuss = DiscussV1Api(client),
      search = SearchV1Api(client),
      home = HomeV1Api(client),
      common = CommonV1Api(client);

  final UserV1Api user;
  final OriginV1Api origin;
  final WorldV1Api world;
  final MessagesV1Api messages;
  final DmV1Api dm;
  final FollowV1Api follow;
  final DiscussV1Api discuss;
  final SearchV1Api search;
  final HomeV1Api home;
  final CommonV1Api common;
}
