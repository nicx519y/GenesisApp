import 'package:flutter/material.dart';

import '../pages/app_shell_page.dart';
import '../pages/create/create_origin_page.dart';
import '../pages/discuss/discuss_page.dart';
import '../pages/edit/edit_origin_page.dart';
import '../pages/search/search_page.dart';
import '../pages/origin/origin_world_page.dart';
import '../pages/world/world_page.dart';
import '../pages/chat/chat_page.dart';
import '../pages/chat/location_chat_page.dart';
import '../pages/messages/message_category_list_page.dart';
import '../pages/me/follows_page.dart';
import '../pages/me/user_info_page.dart';
import '../network/chatroom/chatroom_connection_controller.dart';

sealed class RouteNames {
  static const shell = '/';
  static const home = '/home';
  static const origin = '/origin';
  static const originWorld = '/origin_world';
  static const discuss = '/discuss';
  static const world = '/world';
  static const chat = '/chat';
  static const locationChat = '/location_chat';
  static const search = '/search';
  static const create = '/create';
  static const edit = '/edit';
  static const messages = '/messages';
  static const me = '/me';
  static const notifications = '/message/notifications';
  static const newFollowers = '/messages/new_followers';
  static const comments = '/messages/comments';
  static const userInfo = '/user_info';
  static const follows = '/follows';
}

sealed class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 0),
        );
      case RouteNames.origin:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 1),
        );
      case RouteNames.originWorld:
        final args = settings.arguments;
        var oid = '';
        var originId = 0;
        if (args is String) {
          oid = args;
        } else if (args is Map) {
          final rawOid = args['oid'];
          final rawOriginId = args['originId'];
          if (rawOid != null) oid = rawOid.toString();
          if (rawOriginId is int) {
            originId = rawOriginId;
          } else if (rawOriginId != null) {
            originId = int.tryParse(rawOriginId.toString()) ?? 0;
          }
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => OriginWorldPage(oid: oid, originId: originId),
        );
      case RouteNames.discuss:
        final args = settings.arguments;
        var oid = '';
        var originId = 0;
        if (args is String) {
          oid = args;
        } else if (args is Map) {
          final rawOid = args['oid'] ?? args['origin_id'] ?? args['originId'];
          if (rawOid != null) oid = rawOid.toString();
          final rawOriginId = args['originId'] ?? args['origin_id'];
          if (rawOriginId is int) {
            originId = rawOriginId;
          } else if (rawOriginId != null) {
            originId = int.tryParse(rawOriginId.toString()) ?? 0;
          }
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => DiscussPage(oid: oid, originId: originId),
        );
      case RouteNames.world:
        final args = settings.arguments;
        var wid = '';
        if (args is String) {
          wid = args;
        } else if (args is Map) {
          final rawWid = args['wid'];
          if (rawWid != null) wid = rawWid.toString();
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorldPage(wid: wid),
        );
      case RouteNames.chat:
        final args = settings.arguments;
        var peerUid = '';
        var peerName = '';
        var peerAvatar = '';
        var conversationId = '';
        if (args is Map) {
          final rawPeerUid = args['peer_uid'] ?? args['peerUid'] ?? args['uid'];
          if (rawPeerUid != null) peerUid = rawPeerUid.toString();

          final rawPeerName =
              args['peer_name'] ?? args['peerName'] ?? args['name'];
          if (rawPeerName != null) peerName = rawPeerName.toString();

          final rawPeerAvatar =
              args['peer_avatar'] ?? args['peerAvatar'] ?? args['avatar'];
          if (rawPeerAvatar != null) peerAvatar = rawPeerAvatar.toString();

          final rawConversationId =
              args['conv_id'] ??
              args['conversationId'] ??
              args['conversation_id'];
          if (rawConversationId != null) {
            conversationId = rawConversationId.toString();
          }
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ChatPage(
            peerUid: peerUid,
            peerName: peerName,
            peerAvatar: peerAvatar,
            conversationId: conversationId,
          ),
        );
      case RouteNames.locationChat:
        final args = settings.arguments;
        var worldId = '';
        var locationId = '';
        var worldName = '';
        var locationName = '';
        ChatroomConnectionController? chatroomConnection;
        if (args is Map) {
          final rawWorldId = args['world_id'] ?? args['worldId'] ?? args['wid'];
          if (rawWorldId != null) worldId = rawWorldId.toString();

          final rawWorldName = args['world_name'] ?? args['worldName'];
          if (rawWorldName != null) worldName = rawWorldName.toString();

          final rawLocationId =
              args['location_id'] ??
              args['locationId'] ??
              args['scene_id'] ??
              args['sceneId'] ??
              args['point_id'] ??
              args['pointId'];
          if (rawLocationId != null) locationId = rawLocationId.toString();

          final rawLocationName = args['locationName'] ?? args['location_name'];
          if (rawLocationName != null) {
            locationName = rawLocationName.toString();
          }

          final rawConnection =
              args['chatroom_connection'] ?? args['chatroomConnection'];
          if (rawConnection is ChatroomConnectionController) {
            chatroomConnection = rawConnection;
          }
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LocationChatPage(
            worldId: worldId,
            locationId: locationId,
            worldName: worldName,
            locationName: locationName,
            connection: chatroomConnection,
          ),
        );
      case RouteNames.search:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SearchPage(),
        );
      case RouteNames.create:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CreateOriginPage(),
        );
      case RouteNames.edit:
        final args = settings.arguments;
        var originId = '';
        if (args is String) {
          originId = args;
        } else if (args is Map) {
          final rawOriginId =
              args['origin_id'] ?? args['originId'] ?? args['oid'];
          if (rawOriginId != null) originId = rawOriginId.toString();
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => EditOriginPage(originId: originId),
        );
      case RouteNames.messages:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 3),
        );
      case RouteNames.me:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 4),
        );
      case RouteNames.notifications:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MessageCategoryListPage(
            title: 'Notifications',
            block: 'world_apply',
            emptyText: 'No notifications yet.',
          ),
        );
      case RouteNames.newFollowers:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MessageCategoryListPage(
            title: 'New followers',
            block: 'follow',
            emptyText: 'No new followers yet.',
          ),
        );
      case RouteNames.comments:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MessageCategoryListPage(
            title: 'Comments',
            block: 'interaction',
            emptyText: 'No comments yet.',
          ),
        );
      case RouteNames.userInfo:
        final args = settings.arguments;
        var uid = '';
        if (args is String) {
          uid = args;
        } else if (args is Map) {
          final rawUid = args['uid'] ?? args['userId'] ?? args['id'];
          if (rawUid != null) uid = rawUid.toString();
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => UserInfoPage(uid: uid),
        );
      case RouteNames.follows:
        final args = settings.arguments;
        var uid = '';
        var initialIndex = 0;
        String? title;
        if (args is String) {
          uid = args;
        } else if (args is Map) {
          final rawUid = args['uid'] ?? args['userId'] ?? args['id'];
          if (rawUid != null) uid = rawUid.toString();

          final rawTitle = args['title'] ?? args['name'] ?? args['displayName'];
          if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
            title = rawTitle.toString();
          }

          final rawTab =
              args['initialIndex'] ?? args['tabIndex'] ?? args['tab'];
          if (rawTab is int) {
            initialIndex = rawTab;
          } else if (rawTab != null) {
            final tabText = rawTab.toString().trim().toLowerCase();
            initialIndex =
                int.tryParse(tabText) ??
                (tabText == 'followers' || tabText == 'follower' ? 1 : 0);
          }
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => FollowsPage(
            uid: uid,
            initialIndex: initialIndex,
            initialTitle: title,
          ),
        );
      case RouteNames.shell:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 0),
        );
    }
  }
}
