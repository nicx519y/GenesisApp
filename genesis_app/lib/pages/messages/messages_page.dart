import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../network/direct_message_conversation_store.dart';
import '../../network/models/unread_summary.dart';
import '../../routers/app_router.dart';
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
  final _scrollController = ScrollController();
  Timer? _conversationPollTimer;
  late final DirectMessageConversationStore _conversationStore;
  bool _loadedLocalConversations = false;
  bool _syncingConversations = false;

  @override
  void initState() {
    super.initState();
    _conversationStore = AppServicesScope.read(
      context,
    ).directMessageConversations;
    unawaited(_bootstrapConversations());
    _conversationPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_syncConversations());
    });
  }

  @override
  void dispose() {
    _conversationPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapConversations() async {
    try {
      await _conversationStore.loadFromDb();
      if (!mounted) return;
      setState(() => _loadedLocalConversations = true);
      await _syncConversations();
    } catch (error, stackTrace) {
      debugPrint('[Messages][DM] bootstrap failed: $error');
      debugPrint('[Messages][DM] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() => _loadedLocalConversations = true);
    }
  }

  Future<void> _syncConversations() async {
    if (_syncingConversations) return;
    setState(() => _syncingConversations = true);
    try {
      await _conversationStore.syncConversations();
    } catch (error, stackTrace) {
      debugPrint('[Messages][DM] sync failed: $error');
      debugPrint('[Messages][DM] stacktrace:\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _syncingConversations = false);
      }
    }
  }

  Future<void> _openConversation(DirectMessageConversationRecord item) async {
    final peerUid = item.peerUid.trim();
    if (peerUid.isEmpty) {
      debugPrint(
        '[Messages][DM] conversation ${item.conversationId} has no peer uid',
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      RouteNames.chat,
      arguments: {
        'peer_uid': peerUid,
        'peer_name': item.peerName,
        'peer_avatar': item.avatarUrl,
        'conv_id': item.conversationId,
      },
    );
    if (!mounted) return;
    unawaited(_syncConversations());
  }

  @override
  Widget build(BuildContext context) {
    final unreadSummary = widget.unreadSummary;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            pageName: 'Messages',
            showSearchBar: false,
            topPadding: 18,
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/notification.png',
                  backgroundColor: Color(0xFFDDF2EF),
                  label: 'Notifications',
                  routeName: RouteNames.notifications,
                  block: 'world_apply',
                  emptyText: 'No notifications yet.',
                  unreadCount: unreadSummary.systemUnread,
                  onUnreadSummaryRefresh: widget.onUnreadSummaryRefresh,
                ),
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/following.png',
                  backgroundColor: Color(0xFFFFF0D8),
                  label: 'New followers',
                  routeName: RouteNames.newFollowers,
                  block: 'follow',
                  emptyText: 'No new followers yet.',
                  unreadCount: unreadSummary.followerUnread,
                  onUnreadSummaryRefresh: widget.onUnreadSummaryRefresh,
                ),
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/comment.png',
                  backgroundColor: Color(0xFFE9F0FF),
                  label: 'Comments',
                  routeName: RouteNames.comments,
                  block: 'interaction',
                  emptyText: 'No comments yet.',
                  unreadCount: unreadSummary.commentUnread,
                  onUnreadSummaryRefresh: widget.onUnreadSummaryRefresh,
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Text(
                  'Private chats',
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
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _conversationStore.orderedConversationIds,
              builder: (context, conversationIds, _) {
                if (!_loadedLocalConversations ||
                    (conversationIds.isEmpty && _syncingConversations)) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (conversationIds.isEmpty) return const _NoMessagesFooter();
                return _ConversationList(
                  controller: _scrollController,
                  conversationIds: conversationIds,
                  conversationStore: _conversationStore,
                  onTap: _openConversation,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMenuButton extends StatelessWidget {
  const _MessageMenuButton({
    required this.iconAsset,
    required this.backgroundColor,
    required this.label,
    required this.routeName,
    required this.block,
    required this.emptyText,
    required this.unreadCount,
    required this.onUnreadSummaryRefresh,
  });

  final String iconAsset;
  final Color backgroundColor;
  final String label;
  final String routeName;
  final String block;
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
              block: block,
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
                width: 62,
                height: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        iconAsset,
                        width: 31,
                        height: 31,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: _UnreadBadge(
                        key: ValueKey('message-menu-$routeName-unread-badge'),
                        count: unreadCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
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
    required this.conversationIds,
    required this.conversationStore,
    required this.onTap,
  });

  final ScrollController controller;
  final List<String> conversationIds;
  final DirectMessageConversationStore conversationStore;
  final Future<void> Function(DirectMessageConversationRecord item) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 0,
        bottom: 18 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: conversationIds.length,
      separatorBuilder: (_, _) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final conversationId = conversationIds[index];
        final listenable = conversationStore.rowListenable(conversationId);
        if (listenable == null) return const SizedBox.shrink();
        return ValueListenableBuilder<DirectMessageConversationRecord>(
          key: ValueKey(conversationId),
          valueListenable: listenable,
          builder: (context, item, _) =>
              _ConversationTile(item: item, onTap: onTap),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});

  final DirectMessageConversationRecord item;
  final Future<void> Function(DirectMessageConversationRecord item) onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => unawaited(onTap(item)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
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
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
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
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 60),
                      child: Text(
                        item.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF80848D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
        color: const Color(0xFF0E97D3),
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
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  )
                : Image.network(
                    avatarUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          );

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: SizedBox(width: 56, height: 56, child: avatar),
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
