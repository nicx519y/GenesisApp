import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../pages/app_shell_page.dart';
import '../pages/create/create_origin_page.dart';
import '../pages/common/page_not_found_page.dart';
import '../pages/discuss/discuss_page.dart';
import '../pages/discuss/post_detail_page.dart';
import '../pages/edit/edit_origin_page.dart';
import '../pages/legal/legal_document_page.dart';
import '../pages/gems/gem_records_page.dart';
import '../pages/gems/gem_wallet_page.dart';
import '../pages/gems/memory_model_page.dart';
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
import '../network/models/world.dart';
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
  static const legal = '/legal';
  static const gemWallet = '/gems';
  static const gemRecords = '/gems/records';
  static const memoryModel = '/memory_model';
  static const pageNotFound = '/page_not_found';
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

  List<String> stringList(List<String> keys) {
    final rawValue = _first(keys);
    if (rawValue is Iterable) {
      return rawValue
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return const <String>[];
    return text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
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

class _LegalRouteArgs {
  const _LegalRouteArgs({required this.document});

  factory _LegalRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final document = args.string(const ['document', 'type']).trim();
    return _LegalRouteArgs(document: LegalDocument.fromRouteValue(document));
  }

  final LegalDocument document;
}

class _MemoryModelRouteArgs {
  const _MemoryModelRouteArgs({required this.worldId});

  factory _MemoryModelRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    return _MemoryModelRouteArgs(
      worldId: args.string(const [
        'world_id',
        'worldId',
        'wid',
      ], fallback: args.directString()).trim(),
    );
  }

  final String worldId;
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

class _HomeRouteArgs {
  const _HomeRouteArgs({required this.homeInitialTabIndex});

  factory _HomeRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final rawTab = args._first(const [
      'home_tab',
      'homeTab',
      'homeTabIndex',
      'homeInitialTabIndex',
    ]);
    final tabText = rawTab?.toString().trim().toLowerCase() ?? '';
    final tabIndex = switch (tabText) {
      'my_world' || 'my_worlds' || 'mine' => 0,
      'popular' => 1,
      _ => args.integer(const [
        'home_tab',
        'homeTab',
        'homeTabIndex',
        'homeInitialTabIndex',
      ], fallback: -1),
    };
    return _HomeRouteArgs(homeInitialTabIndex: tabIndex);
  }

  final int homeInitialTabIndex;

  int? get resolvedHomeInitialTabIndex {
    return homeInitialTabIndex < 0 ? null : homeInitialTabIndex;
  }
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
  const _WorldRouteArgs({
    required this.wid,
    required this.waitForTick1,
    this.initialWorldDetail,
  });

  factory _WorldRouteArgs.from(Object? raw) {
    final args = _RouteArgs(raw);
    final direct = args.directString();
    return _WorldRouteArgs(
      wid: direct.isNotEmpty ? direct : args.string(const ['wid']),
      waitForTick1: args.boolean(const [
        'wait_for_tick1',
        'waitForTick1',
      ], fallback: false),
      initialWorldDetail: args.typed<WorldDetail>(const [
        'initial_world_detail',
        'initialWorldDetail',
      ]),
    );
  }

  final String wid;
  final bool waitForTick1;
  final WorldDetail? initialWorldDetail;
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
    required this.backgroundImageUrl,
    required this.backgroundPreviewImageUrl,
    required this.isLeafLocation,
    required this.localMessageLocationIds,
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
      backgroundImageUrl: args.string(const [
        'background_image_url',
        'backgroundImageUrl',
        'map_url',
        'mapUrl',
      ]),
      backgroundPreviewImageUrl: args.string(const [
        'background_preview_image_url',
        'backgroundPreviewImageUrl',
        'preview_image_url',
        'previewImageUrl',
        'sm_url',
        'smUrl',
      ]),
      isLeafLocation: args.boolean(const [
        'is_leaf_location',
        'isLeafLocation',
      ], fallback: true),
      localMessageLocationIds: args.stringList(const [
        'local_message_location_ids',
        'localMessageLocationIds',
        'location_aliases',
        'locationAliases',
      ]),
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
  final String backgroundImageUrl;
  final String backgroundPreviewImageUrl;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
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
  static String pageClassNameForRouteName(String? routeName) {
    return switch (routeName) {
      RouteNames.home => 'AppShellPage',
      RouteNames.origin => 'AppShellPage',
      RouteNames.originWorld => 'OriginWorldPage',
      RouteNames.discuss => 'DiscussPage',
      RouteNames.postDetail => 'PostDetailPage',
      RouteNames.world => 'WorldPage',
      RouteNames.chat => 'ChatPage',
      RouteNames.locationChat => 'LocationChatPage',
      RouteNames.search => 'SearchPage',
      RouteNames.create => 'CreateOriginPage',
      RouteNames.edit => 'EditOriginPage',
      RouteNames.messages => 'AppShellPage',
      RouteNames.me => 'AppShellPage',
      RouteNames.notifications => 'MessageCategoryListPage',
      RouteNames.newFollowers => 'MessageCategoryListPage',
      RouteNames.comments => 'MessageCategoryListPage',
      RouteNames.userInfo => 'UserInfoPage',
      RouteNames.follows => 'FollowsPage',
      RouteNames.legal => 'LegalDocumentPage',
      RouteNames.gemWallet => 'GemWalletPage',
      RouteNames.gemRecords => 'GemRecordsPage',
      RouteNames.memoryModel => 'MemoryModelPage',
      RouteNames.pageNotFound => 'PageNotFoundPage',
      RouteNames.shell => 'AppShellPage',
      _ => 'PageNotFoundPage',
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.home:
        final args = _HomeRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AppShellPage(
            initialIndex: 0,
            homeInitialTabIndex: args.resolvedHomeInitialTabIndex,
          ),
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
          builder: (_) => WorldPage(
            wid: args.wid,
            waitForTick1: args.waitForTick1,
            initialWorldDetail: args.initialWorldDetail,
          ),
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
        return _LocationChatPageRoute(
          settings: settings,
          builder: (_) => LocationChatPage(
            worldId: args.worldId,
            locationId: args.locationId,
            worldName: args.worldName,
            locationName: args.locationName,
            backgroundImageUrl: args.backgroundImageUrl,
            backgroundPreviewImageUrl: args.backgroundPreviewImageUrl,
            isLeafLocation: args.isLeafLocation,
            localMessageLocationIds: args.localMessageLocationIds,
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
      case RouteNames.legal:
        final args = _LegalRouteArgs.from(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LegalDocumentPage(document: args.document),
        );
      case RouteNames.gemWallet:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const GemWalletPage(),
        );
      case RouteNames.gemRecords:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const GemRecordsPage(),
        );
      case RouteNames.memoryModel:
        final args = _MemoryModelRouteArgs.from(settings.arguments);
        return MaterialPageRoute<String>(
          settings: settings,
          builder: (_) => MemoryModelPage(worldId: args.worldId),
        );
      case RouteNames.pageNotFound:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PageNotFoundPage(),
        );
      case RouteNames.shell:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AppShellPage(initialIndex: 0),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PageNotFoundPage(),
        );
    }
  }
}

class _LocationChatPageRoute extends PageRoute<void>
    with CupertinoRouteTransitionMixin<void> {
  _LocationChatPageRoute({
    required this.builder,
    required RouteSettings settings,
  }) : super(settings: settings);

  final WidgetBuilder builder;

  @override
  String? get title => null;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool get popGestureInProgress => navigator?.userGestureInProgress ?? false;

  @override
  Widget buildContent(BuildContext context) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
      return Theme.of(context).pageTransitionsTheme.buildTransitions<void>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    final cupertinoTransition =
        CupertinoRouteTransitionMixin.buildPageTransitions<void>(
          this,
          context,
          animation,
          secondaryAnimation,
          child,
        );
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: cupertinoTransition,
    );
  }
}
