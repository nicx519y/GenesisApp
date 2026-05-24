import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../network/models/unread_summary.dart';
import '../../network/models/world_message.dart';
import '../../routers/app_router.dart';
import '../../app/bootstrap/app_services_scope.dart';
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
  bool _loading = true;
  List<_DirectMessageConversation> _conversations = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversations());
  }

  Future<void> _loadConversations() async {
    final api = AppServicesScope.read(context).api;
    final conversations = <_DirectMessageConversation>[];
    try {
      final worlds = await api.getMyWorlds(limit: 12, offset: 0);
      for (final world in worlds) {
        final detail = await api.getWorld(world.wid);
        final location = detail.worldLocations
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (item) => _asString(item['point_id']).trim().isNotEmpty,
              orElse: () => const <String, dynamic>{},
            );
        final pointId = _asString(location['point_id']).trim();
        final sceneId = _asString(location['location_id']).trim();
        if (pointId.isEmpty) continue;

        final locationName = _asString(location['location_name']).trim();
        var preview = '';
        DateTime? updatedAt = DateTime.tryParse(world.updatedAtText);

        try {
          final page = await api.getLocationMessages(
            wid: world.wid,
            pointId: pointId,
            locationId: sceneId,
            limit: 20,
            offset: 0,
          );
          final latest = _findLatest(page.data);
          if (latest != null) {
            preview = latest.content.trim();
            updatedAt = latest.createdAt ?? updatedAt;
          }
        } catch (_) {}

        conversations.add(
          _DirectMessageConversation(
            wid: world.wid,
            pointId: pointId,
            sceneId: sceneId,
            title: locationName.isEmpty ? world.name : locationName,
            subtitle: preview,
            updatedAt: updatedAt,
          ),
        );
      }
    } catch (_) {}

    conversations.sort((a, b) {
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _loading = false;
    });
  }

  WorldMessage? _findLatest(List<WorldMessage> items) {
    if (items.isEmpty) return null;
    WorldMessage latest = items.first;
    var latestMillis =
        latest.createdAt?.millisecondsSinceEpoch ??
        DateTime.fromMillisecondsSinceEpoch(0).millisecondsSinceEpoch;
    for (final item in items.skip(1)) {
      final itemMillis =
          item.createdAt?.millisecondsSinceEpoch ??
          DateTime.fromMillisecondsSinceEpoch(0).millisecondsSinceEpoch;
      if (itemMillis > latestMillis) {
        latest = item;
        latestMillis = itemMillis;
      }
    }
    return latest;
  }

  String _asString(Object? value) {
    if (value == null) return '';
    return value.toString();
  }

  Future<void> _openConversation(_DirectMessageConversation item) async {
    await Navigator.of(context).pushNamed(
      RouteNames.chat,
      arguments: {
        'wid': item.wid,
        'pointId': item.pointId,
        'sceneId': item.sceneId,
        'locationName': item.title,
      },
    );
    if (!mounted) return;
    unawaited(_loadConversations());
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                    conversations: conversations,
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
  const _ConversationList({required this.conversations, required this.onTap});

  final List<_DirectMessageConversation> conversations;
  final Future<void> Function(_DirectMessageConversation item) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 4,
        bottom: 18 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = conversations[index];
        final subtitle = item.subtitle.isEmpty
            ? 'Tap to start chatting'
            : item.subtitle;
        return Material(
          color: const Color(0xFFF6F7F8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => unawaited(onTap(item)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  _Avatar(title: item.title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
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
                  Text(
                    _formatTime(item.updatedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA0A8),
                      fontWeight: FontWeight.w600,
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

  static String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final targetStart = DateTime(local.year, local.month, local.day);
    if (targetStart == dayStart) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${local.month}/${local.day}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    final initials = trimmed.isEmpty
        ? 'DM'
        : trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF262A33), Color(0xFF4B5565)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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

class _DirectMessageConversation {
  const _DirectMessageConversation({
    required this.wid,
    required this.pointId,
    required this.sceneId,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
  });

  final String wid;
  final String pointId;
  final String sceneId;
  final String title;
  final String subtitle;
  final DateTime? updatedAt;
}
