import 'package:flutter/material.dart';

import '../pages/app_shell_page.dart';
import '../pages/create/create_origin_page.dart';
import '../pages/discuss/discuss_page.dart';
import '../pages/discuss/post_detail_page.dart';
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
import '../network/chatroom/world_chatroom_service.dart';
import '../components/discuss/origin_discuss_list.dart';

sealed class RouteNames {
  static const shell = '/';
  static const home = '/home';
  static const origin = '/origin';
  static const originWorld = '/origin_world';
  static const discuss = '/discuss';
  static const postDetail = '/post_detail';
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

class _RouteArgs {
  const _RouteArgs(this.raw);

  final Object? raw;

  String directString() {
    final value = raw;
    return value is String ? value : '';
  }

  String string(List<String> keys, {String fallback = ''}) {
    final rawValue = _first(keys);
    return rawValue == null ? fallback : rawValue.toString();
  }

  int integer(List<String> keys, {int fallback = 0}) {
    final rawValue = _first(keys);
    if (rawValue is int) return rawValue;
    if (rawValue == null) return fallback;
    return int.tryParse(rawValue.toString()) ?? fallback;
  }

  bool boolean(List<String> keys, {required bool fallback}) {
    final rawValue = _first(keys);
    if (rawValue is bool) return rawValue;
    if (rawValue == null) return fallback;
    return rawValue.toString().trim().toLowerCase() != 'false';
  }

  T? typed<T>(List<String> keys) {
    final rawValue = _first(keys);
    return rawValue is T ? rawValue : null;
  }

  Object? _first(List<String> keys) {
    final value = raw;
    if (value is! Map) return null;
    for (final key in keys) {
      final rawValue = value[key];
      if (rawValue != null) return rawValue;
    }
    return null;
  }
}

class _OriginWorldRouteArgs {
  const _OriginWorldRouteArgs({required this.oid, required this.originId});

  factory _OriginWorldRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    return _OriginWorldRouteArgs(
      oid: args.directString().isNotEmpty
          ? args.directString()
          : args.string(const ['oid']),
      originId: args.integer(const ['originId']),
    );
  }

  final String oid;
  final int originId;
}

class _DiscussRouteArgs {
  const _DiscussRouteArgs({required this.oid, required this.originId});

  factory _DiscussRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final direct = args.directString();
    return _DiscussRouteArgs(
      oid: direct.isNotEmpty
          ? direct
          : args.string(const ['oid', 'origin_id', 'originId']),
      originId: args.integer(const ['originId', 'origin_id']),
    );
  }

  final String oid;
  final int originId;
}

class _PostDetailRouteArgs {
  const _PostDetailRouteArgs({required this.item});

  factory _PostDetailRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    return _PostDetailRouteArgs(
      item: args.typed<OriginDiscussListItem>(const ['item', 'discuss']),
    );
  }

  final OriginDiscussListItem? item;
}

class _WorldRouteArgs {
  const _WorldRouteArgs({required this.wid, required this.waitForTick1});

  factory _WorldRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final direct = args.directString();
    return _WorldRouteArgs(
      wid: direct.isNotEmpty ? direct : args.string(const ['wid']),
      waitForTick1: args.boolean(const [
        'wait_for_tick1',
        'waitForTick1',
      ], fallback: false),
    );
  }

  final String wid;
  final bool waitForTick1;
}

class _ChatRouteArgs {
  const _ChatRouteArgs({
    required this.peerUid,
    required this.peerName,
    required this.peerAvatar,
    required this.conversationId,
  });

  factory _ChatRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    return _ChatRouteArgs(
      peerUid: args.string(const ['peer_uid', 'peerUid', 'uid']),
      peerName: args.string(const ['peer_name', 'peerName', 'name']),
      peerAvatar: args.string(const ['peer_avatar', 'peerAvatar', 'avatar']),
      conversationId: args.string(const [
        'conv_id',
        'conversationId',
        'conversation_id',
      ]),
    );
  }

  final String peerUid;
  final String peerName;
  final String peerAvatar;
  final String conversationId;
}

class _LocationChatRouteArgs {
  const _LocationChatRouteArgs({
    required this.worldId,
    required this.locationId,
    required this.worldName,
    required this.locationName,
    required this.isLeafLocation,
    required this.chatroomConnection,
    required this.worldChatroomService,
  });

  factory _LocationChatRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    return _LocationChatRouteArgs(
      worldId: args.string(const ['world_id', 'worldId', 'wid']),
      locationId: args.string(const [
        'location_id',
        'locationId',
        'scene_id',
        'sceneId',
        'point_id',
        'pointId',
      ]),
      worldName: args.string(const ['world_name', 'worldName']),
      locationName: args.string(const ['locationName', 'location_name']),
      isLeafLocation: args.boolean(const [
        'is_leaf_location',
        'isLeafLocation',
      ], fallback: true),
      chatroomConnection: args.typed<ChatroomConnectionController>(const [
        'chatroom_connection',
        'chatroomConnection',
      ]),
      worldChatroomService: args.typed<WorldChatroomService>(const [
        'world_chatroom_service',
        'worldChatroomService',
      ]),
    );
  }

  final String worldId;
  final String locationId;
  final String worldName;
  final String locationName;
  final bool isLeafLocation;
  final ChatroomConnectionController? chatroomConnection;
  final WorldChatroomService? worldChatroomService;
}

class _EditRouteArgs {
  const _EditRouteArgs({required this.originId});

  factory _EditRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final direct = args.directString();
    return _EditRouteArgs(
      originId: direct.isNotEmpty
          ? direct
          : args.string(const ['origin_id', 'originId', 'oid']),
    );
  }

  final String originId;
}

class _UserInfoRouteArgs {
  const _UserInfoRouteArgs({required this.uid});

  factory _UserInfoRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final direct = args.directString();
    return _UserInfoRouteArgs(
      uid: direct.isNotEmpty
          ? direct
          : args.string(const ['uid', 'userId', 'id']),
    );
  }

  final String uid;
}

class _FollowsRouteArgs {
  const _FollowsRouteArgs({
    required this.uid,
    required this.initialIndex,
    required this.title,
  });

  factory _FollowsRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final direct = args.directString();
    return _FollowsRouteArgs(
      uid: direct.isNotEmpty
          ? direct
          : args.string(const ['uid', 'userId', 'id']),
      initialIndex: _tabIndex(args),
      title: _title(args),
    );
  }

  static int _tabIndex(_RouteArgs args) {
    final rawTab = args._first(const ['initialIndex', 'tabIndex', 'tab']);
    if (rawTab is int) return rawTab;
    if (rawTab == null) return 0;
    final tabText = rawTab.toString().trim().toLowerCase();
    return int.tryParse(tabText) ??
        (tabText == 'followers' || tabText == 'follower' ? 1 : 0);
  }

  static String? _title(_RouteArgs args) {
    final title = args.string(const ['title', 'name', 'displayName']).trim();
    return title.isEmpty ? null : title;
  }

  final String uid;
  final int initialIndex;
  final String? title;
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
        final args = _OriginWorldRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              OriginWorldPage(oid: args.oid, originId: args.originId),
        );
      case RouteNames.discuss:
        final args = _DiscussRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => DiscussPage(oid: args.oid, originId: args.originId),
        );
      case RouteNames.postDetail:
        final args = _PostDetailRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PostDetailPage(item: args.item),
        );
      case RouteNames.world:
        final args = _WorldRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              WorldPage(wid: args.wid, waitForTick1: args.waitForTick1),
        );
      case RouteNames.chat:
        final args = _ChatRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ChatPage(
            peerUid: args.peerUid,
            peerName: args.peerName,
            peerAvatar: args.peerAvatar,
            conversationId: args.conversationId,
          ),
        );
      case RouteNames.locationChat:
        final args = _LocationChatRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LocationChatPage(
            worldId: args.worldId,
            locationId: args.locationId,
            worldName: args.worldName,
            locationName: args.locationName,
            isLeafLocation: args.isLeafLocation,
            service: args.worldChatroomService,
            connection: args.chatroomConnection,
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
        final args = _EditRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => EditOriginPage(originId: args.originId),
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
        final args = _UserInfoRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => UserInfoPage(uid: args.uid),
        );
      case RouteNames.follows:
        final args = _FollowsRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => FollowsPage(
            uid: args.uid,
            initialIndex: args.initialIndex,
            initialTitle: args.title,
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
