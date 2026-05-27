import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../network/json_utils.dart';
import '../../network/models/unread_summary.dart';
import '../../routers/app_router.dart';
import '../../utils/relative_time_formatter.dart';
import 'message_category_list_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    this.unreadSummary = UnreadSummary.zero,
    this.onUnreadSummaryRefresh,
  });

  final UnreadSummary unreadSummary;
  final Future<void> Function()? onUnreadSummaryRefresh;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  Timer? _conversationPollTimer;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  int _loadedPageCount = 0;
  int _total = 0;
  List<_DirectMessageConversation> _conversations = const [];

  bool get _hasMore => _conversations.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
    _conversationPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollConversations());
    });
  }

  @override
  void dispose() {
    _conversationPollTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        _refreshing ||
        !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    await _replaceLoadedPages(pageCount: 1);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loading || _loadingMore || _refreshing) return;
    final nextPage = _loadedPageCount + 1;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetchConversationsPage(nextPage);
      if (!mounted) return;
      setState(() {
        _conversations = [..._conversations, ...page.items];
        _loadedPageCount = nextPage;
        _total = page.total;
        _loadingMore = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[Messages][DM] load page $nextPage failed: $error');
      debugPrint('[Messages][DM] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _pollConversations() async {
    if (_loading || _loadingMore || _refreshing) return;
    final pageCount = _loadedPageCount == 0 ? 1 : _loadedPageCount;
    await _replaceLoadedPages(pageCount: pageCount);
  }

  Future<void> _replaceLoadedPages({required int pageCount}) async {
    _refreshing = true;
    try {
      final pages = <_DirectMessageConversationPage>[];
      for (var page = 1; page <= pageCount; page += 1) {
        pages.add(await _fetchConversationsPage(page));
      }
      final conversations = [for (final page in pages) ...page.items];
      final total = pages.isEmpty ? 0 : pages.last.total;
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loadedPageCount = pageCount;
        _total = total;
        _loading = false;
        _refreshing = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[Messages][DM] refresh failed: $error');
      debugPrint('[Messages][DM] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<_DirectMessageConversationPage> _fetchConversationsPage(
    int page,
  ) async {
    final data = await AppServicesScope.read(
      context,
    ).api.v1.dm.conversations(pn: page, rn: _pageSize);
    final rawItems = data['list'] is List
        ? asJsonList(data['list'])
        : const <Object?>[];
    final items = rawItems
        .map((item) => _DirectMessageConversation.fromJson(asJsonMap(item)))
        .toList(growable: false);
    return _DirectMessageConversationPage(
      items: items,
      total: asInt(data['total'], fallback: items.length),
    );
  }

  Future<void> _openConversation(_DirectMessageConversation item) async {
    debugPrint('[Messages][DM] tapped conversation ${item.conversationId}');
    if (!mounted) return;
    unawaited(_pollConversations());
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _conversations;
    final unreadSummary = widget.unreadSummary;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(pageName: 'Messages', showSearchBar: false),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MessageMenuButton(
                  icon: Icons.notifications_active_rounded,
                  label: 'Notifications',
                  routeName: RouteNames.notifications,
                  category: 'system',
                  emptyText: 'No notifications yet.',
                  unreadCount: unreadSummary.systemUnread,
                  onUnreadSummaryRefresh: widget.onUnreadSummaryRefresh,
                ),
                _MessageMenuButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'New followers',
                  routeName: RouteNames.newFollowers,
                  category: 'follower',
                  emptyText: 'No new followers yet.',
                  unreadCount: unreadSummary.followerUnread,
                  onUnreadSummaryRefresh: widget.onUnreadSummaryRefresh,
                ),
                _MessageMenuButton(
                  icon: Icons.mode_comment_outlined,
                  label: 'Comments',
                  routeName: RouteNames.comments,
                  category: 'comment',
                  emptyText: 'No comments yet.',
                  unreadCount: unreadSummary.commentUnread,
                  onUnreadSummaryRefresh: widget.onUnreadSummaryRefresh,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Text(
                  'Direct messages',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                _UnreadBadge(
                  key: const ValueKey('direct-messages-unread-badge'),
                  count: unreadSummary.dmUnread,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                ? const _NoMessagesFooter()
                : _ConversationList(
                    controller: _scrollController,
                    conversations: conversations,
                    loadingMore: _loadingMore,
                    onTap: _openConversation,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageMenuButton extends StatelessWidget {
  const _MessageMenuButton({
    required this.icon,
    required this.label,
    required this.routeName,
    required this.category,
    required this.emptyText,
    required this.unreadCount,
    required this.onUnreadSummaryRefresh,
  });

  final IconData icon;
  final String label;
  final String routeName;
  final String category;
  final String emptyText;
  final int unreadCount;
  final Future<void> Function()? onUnreadSummaryRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: routeName),
            builder: (_) => MessageCategoryListPage(
              title: label,
              category: category,
              emptyText: emptyText,
              onNotificationsRead: onUnreadSummaryRefresh,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              SizedBox(
                width: 44,
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 30, color: Colors.black87),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _UnreadBadge(
                        key: ValueKey('message-menu-$routeName-unread-badge'),
                        count: unreadCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE02424),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.conversations,
    required this.loadingMore,
    required this.onTap,
  });

  final ScrollController controller;
  final List<_DirectMessageConversation> conversations;
  final bool loadingMore;
  final Future<void> Function(_DirectMessageConversation item) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 4,
        bottom: 18 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: conversations.length + (loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= conversations.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = conversations[index];
        return Material(
          color: const Color(0xFFF6F7F8),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => unawaited(onTap(item)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  _Avatar(
                    avatarUrl: item.avatarUrl,
                    title: item.peerName,
                    unreadCount: item.unreadCount,
                    unreadBadgeKey: ValueKey(
                      'dm-avatar-${item.conversationId}-unread-badge',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF80848D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      item.lastMessageAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA0A8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarUrl,
    required this.title,
    required this.unreadCount,
    required this.unreadBadgeKey,
  });

  final String avatarUrl;
  final String title;
  final int unreadCount;
  final Key unreadBadgeKey;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    final initials = trimmed.isEmpty
        ? 'DM'
        : trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
    final fallback = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF262A33),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final avatar = avatarUrl.trim().isEmpty
        ? fallback
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: avatarUrl.startsWith('assets/')
                ? Image.asset(
                    avatarUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  )
                : Image.network(
                    avatarUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          );

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: SizedBox(width: 44, height: 44, child: avatar),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _UnreadBadge(key: unreadBadgeKey, count: unreadCount),
          ),
        ],
      ),
    );
  }
}

class _DirectMessageConversationPage {
  const _DirectMessageConversationPage({
    required this.items,
    required this.total,
  });

  final List<_DirectMessageConversation> items;
  final int total;
}

class _DirectMessageConversation {
  const _DirectMessageConversation({
    required this.conversationId,
    required this.avatarUrl,
    required this.peerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory _DirectMessageConversation.fromJson(Map<String, dynamic> json) {
    final peer = asJsonMap(json['peer'] ?? const <String, dynamic>{});
    return _DirectMessageConversation(
      conversationId: asString(json['conv_id']),
      avatarUrl: asString(peer['avatar']),
      peerName: asString(peer['name'], fallback: 'Unknown user'),
      lastMessage: asString(json['last_message']),
      lastMessageAt: formatRelativeTimestamp(json['last_message_at']),
      unreadCount: asInt(json['unread_cnt']),
    );
  }

  final String conversationId;
  final String avatarUrl;
  final String peerName;
  final String lastMessage;
  final String lastMessageAt;
  final int unreadCount;
}

class _NoMessagesFooter extends StatelessWidget {
  const _NoMessagesFooter();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 56 + MediaQuery.paddingOf(context).bottom,
        ),
        child: const Text(
          'no private messages yet.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF94979E),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
