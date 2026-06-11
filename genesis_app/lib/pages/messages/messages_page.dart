import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/polling_scheduler.dart';
import '../../components/page_header.dart';
import '../../network/direct_message_conversation_store.dart';
import '../../network/models/unread_summary.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/relative_time_formatter.dart';
import 'message_category_list_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({
    super.key,
    this.unreadSummary = UnreadSummary.zero,
    this.onMessagesDataRefresh,
    this.isActiveListenable,
    this.nowProvider,
  });

  final UnreadSummary unreadSummary;
  final Future<void> Function()? onMessagesDataRefresh;
  final ValueListenable<bool>? isActiveListenable;
  @visibleForTesting
  final DateTime Function()? nowProvider;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _scrollController = ScrollController();
  GenesisPollingScheduler? _conversationPoller;
  Timer? _timeRefreshTimer;
  late final DirectMessageConversationStore _conversationStore;
  late DateTime _timeLabelNow;
  bool _loadedLocalConversations = false;
  bool _syncingConversations = false;

  @override
  void initState() {
    super.initState();
    _conversationStore = AppServicesScope.read(
      context,
    ).directMessageConversations;
    _timeLabelNow = _now();
    widget.isActiveListenable?.addListener(_handleActiveChanged);
    _timeRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshTimeLabels();
    });
    unawaited(_bootstrapConversations());
    if (widget.onMessagesDataRefresh == null) {
      _conversationPoller = GenesisPollingScheduler(
        interval: const Duration(seconds: 5),
        onTick: _syncConversations,
      )..start(immediately: false);
    }
  }

  @override
  void didUpdateWidget(covariant MessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveListenable == widget.isActiveListenable) return;
    oldWidget.isActiveListenable?.removeListener(_handleActiveChanged);
    widget.isActiveListenable?.addListener(_handleActiveChanged);
    if (_isActive) _refreshTimeLabels();
  }

  @override
  void dispose() {
    widget.isActiveListenable?.removeListener(_handleActiveChanged);
    _conversationPoller?.stop();
    _timeRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isActive => widget.isActiveListenable?.value ?? true;

  void _handleActiveChanged() {
    if (_isActive) _refreshTimeLabels();
  }

  void _refreshTimeLabels() {
    if (!mounted || !_isActive) return;
    setState(() => _timeLabelNow = _now());
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  Future<void> _bootstrapConversations() async {
    try {
      await _conversationStore.loadFromDb();
      if (!mounted) return;
      setState(() => _loadedLocalConversations = true);
      if (widget.onMessagesDataRefresh == null) {
        await _syncConversations();
      }
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

  Future<void> _refreshMessagesData() {
    final refresh = widget.onMessagesDataRefresh;
    if (refresh != null) return refresh();
    return _syncConversations();
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
    unawaited(_refreshMessagesData());
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
                  onMessagesDataRefresh: widget.onMessagesDataRefresh,
                ),
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/following.png',
                  backgroundColor: Color(0xFFFFF0D8),
                  label: 'New followers',
                  routeName: RouteNames.newFollowers,
                  block: 'follow',
                  emptyText: 'No new followers yet.',
                  unreadCount: unreadSummary.followerUnread,
                  onMessagesDataRefresh: widget.onMessagesDataRefresh,
                ),
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/comment.png',
                  backgroundColor: Color(0xFFE9F0FF),
                  label: 'Comments',
                  routeName: RouteNames.comments,
                  block: 'interaction',
                  emptyText: 'No comments yet.',
                  unreadCount: unreadSummary.commentUnread,
                  onMessagesDataRefresh: widget.onMessagesDataRefresh,
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
                if (!_loadedLocalConversations) {
                  return const Center(child: CircularProgressIndicator());
                }
                return RefreshIndicator(
                  onRefresh: _refreshMessagesData,
                  child: conversationIds.isEmpty
                      ? const _NoMessagesFooter()
                      : _ConversationList(
                          controller: _scrollController,
                          conversationIds: conversationIds,
                          conversationStore: _conversationStore,
                          onTap: _openConversation,
                          timeLabelNow: _timeLabelNow,
                        ),
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
    required this.onMessagesDataRefresh,
  });

  final String iconAsset;
  final Color backgroundColor;
  final String label;
  final String routeName;
  final String block;
  final String emptyText;
  final int unreadCount;
  final Future<void> Function()? onMessagesDataRefresh;

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
              onNotificationsRead: onMessagesDataRefresh,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        iconAsset,
                        width: 25,
                        height: 25,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
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
        color: const Color(0xFFF42C47),
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
    required this.timeLabelNow,
  });

  final ScrollController controller;
  final List<String> conversationIds;
  final DirectMessageConversationStore conversationStore;
  final Future<void> Function(DirectMessageConversationRecord item) onTap;
  final DateTime timeLabelNow;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
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
          builder: (context, item, _) => _ConversationTile(
            item: item,
            onTap: onTap,
            displayTime: formatRelativeTime(
              item.lastMessageAtTime,
              fallback: item.lastMessageAt,
              now: timeLabelNow,
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.onTap,
    required this.displayTime,
  });

  static const double _avatarSize = 48;
  static const double _avatarBorderRadius = 5;

  final DirectMessageConversationRecord item;
  final Future<void> Function(DirectMessageConversationRecord item) onTap;
  final String displayTime;

  @override
  Widget build(BuildContext context) {
    final displayPeerName = formatUidForDisplay(
      item.peerName,
      fallback: 'Unknown user',
    );
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => unawaited(onTap(item)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                avatarUrl: item.avatarUrl,
                title: displayPeerName,
                size: _avatarSize,
                borderRadius: _avatarBorderRadius,
                avatarKey: ValueKey('dm-avatar-${item.conversationId}'),
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
                            displayPeerName,
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
                            displayTime,
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
    required this.size,
    required this.borderRadius,
    required this.avatarKey,
    required this.unreadCount,
    required this.unreadBadgeKey,
  });

  final String avatarUrl;
  final String title;
  final double size;
  final double borderRadius;
  final Key avatarKey;
  final int unreadCount;
  final Key unreadBadgeKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GenesisAvatar(
            key: avatarKey,
            url: avatarUrl,
            name: title,
            size: size,
            borderRadius: borderRadius,
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: const Center(
            key: ValueKey('direct-messages-empty-state'),
            child: Text(
              'no private messages yet.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94979E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
