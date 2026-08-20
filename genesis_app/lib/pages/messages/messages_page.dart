import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/polling_scheduler.dart';
import '../../components/common/genesis_timestamp_text.dart';
import '../../components/messages/genesis_message_theme.dart';
import '../../network/direct_message_conversation_store.dart';
import '../../network/models/unread_summary.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_page_header.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_unread_badge.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
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
        interval: const Duration(seconds: 30),
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
    final peerAvatar = selectGenesisImageUrl(
      item.avatarUrl,
      logicalWidth: _ConversationTile._avatarSize,
      logicalHeight: _ConversationTile._avatarSize,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    await Navigator.of(context).pushNamed(
      RouteNames.chat,
      arguments: {
        'peer_uid': peerUid,
        'peer_name': item.peerName,
        'peer_avatar': peerAvatar,
        'conv_id': item.conversationId,
      },
    );
    if (!mounted) return;
    unawaited(_refreshMessagesData());
  }

  @override
  Widget build(BuildContext context) {
    final unreadSummary = widget.unreadSummary;
    final worldoRedesign = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.genesisColors.pageBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (worldoRedesign)
            const _WorldoMessagesHeader()
          else
            const GenesisPageHeader(title: 'Messages', showSearchField: false),
          if (!worldoRedesign) const SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: worldoRedesign ? 22 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/notification.png',
                  backgroundColor:
                      context.genesisMessageColors.notificationsSurface,
                  label: 'Notifications',
                  routeName: RouteNames.notifications,
                  block: 'world_apply',
                  emptyText: 'No notifications yet.',
                  unreadCount: unreadSummary.systemUnread,
                  onMessagesDataRefresh: widget.onMessagesDataRefresh,
                ),
                if (worldoRedesign) const SizedBox(width: 8),
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/following.png',
                  backgroundColor:
                      context.genesisMessageColors.followersSurface,
                  label: 'New followers',
                  displayLabel: 'Followers',
                  routeName: RouteNames.newFollowers,
                  block: 'follow',
                  emptyText: 'No new followers yet.',
                  unreadCount: unreadSummary.followerUnread,
                  onMessagesDataRefresh: widget.onMessagesDataRefresh,
                ),
                if (worldoRedesign) const SizedBox(width: 8),
                _MessageMenuButton(
                  iconAsset: 'assets/custom-icons/png/comment.png',
                  backgroundColor: context.genesisMessageColors.commentsSurface,
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
          SizedBox(height: worldoRedesign ? 26 : 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: worldoRedesign ? 22 : 18),
            child: Text(
              'Private chats',
              style: worldoRedesign
                  ? TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                      color: context.genesisColors.textTertiary,
                    )
                  : const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(height: worldoRedesign ? 4 : 8),
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

class _WorldoMessagesHeader extends StatelessWidget {
  const _WorldoMessagesHeader();

  @override
  Widget build(BuildContext context) {
    return GenesisTopSafeArea(
      backgroundColor: context.genesisColors.pageBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Text(
          'Messages',
          key: const ValueKey('worldo-messages-title'),
          style: TextStyle(
            fontSize: 24,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.36,
            color: context.genesisColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MessageMenuButton extends StatelessWidget {
  const _MessageMenuButton({
    required this.iconAsset,
    required this.backgroundColor,
    required this.label,
    this.displayLabel,
    required this.routeName,
    required this.block,
    required this.emptyText,
    required this.unreadCount,
    required this.onMessagesDataRefresh,
  });

  final String iconAsset;
  final Color backgroundColor;
  final String label;
  final String? displayLabel;
  final String routeName;
  final String block;
  final String emptyText;
  final int unreadCount;
  final Future<void> Function()? onMessagesDataRefresh;

  @override
  Widget build(BuildContext context) {
    final worldoRedesign = Theme.of(context).brightness == Brightness.dark;
    final visibleLabel = displayLabel ?? label;
    if (worldoRedesign) {
      final colors = context.genesisColors;
      final statusText = unreadCount > 0 ? '$unreadCount new' : 'All read';
      return Expanded(
        child: SizedBox(
          height: 56,
          child: Material(
            key: ValueKey<String>('message-menu-$routeName-surface'),
            color: colors.inputBackground,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey<String>('message-menu-$routeName'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openCategory(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        visibleLabel,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        statusText,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: unreadCount > 0
                              ? colors.danger
                              : colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 96,
      height: 80,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCategory(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      iconAsset,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Transform.translate(
                      offset: const Offset(4, -4),
                      child: GenesisUnreadBadge(
                        key: ValueKey('message-menu-$routeName-unread-badge'),
                        count: unreadCount,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              visibleLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: context.genesisColors.textHighEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: (_) => MessageCategoryListPage(
          title: label,
          block: block,
          emptyText: emptyText,
          onNotificationsRead: onMessagesDataRefresh,
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
    final worldoRedesign = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(
        left: worldoRedesign ? 22 : 18,
        right: worldoRedesign ? 22 : 18,
        top: 0,
        bottom: worldoRedesign
            ? 18
            : 18 + GenesisSafeAreaInsets.bottom(context),
      ),
      itemCount: conversationIds.length,
      separatorBuilder: (_, _) => worldoRedesign
          ? Divider(
              height: 1,
              thickness: 1,
              color: context.genesisColors.dividerSubtle,
            )
          : const SizedBox(height: 0),
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
            displayTime: item.lastMessageAtTime,
            displayTimeFallback: item.lastMessageAt,
            displayTimeNow: timeLabelNow,
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
    required this.displayTimeFallback,
    required this.displayTimeNow,
  });

  static const double _avatarSize = 48;
  static const double _avatarBorderRadius = GenesisAvatarRadii.user;

  final DirectMessageConversationRecord item;
  final Future<void> Function(DirectMessageConversationRecord item) onTap;
  final DateTime? displayTime;
  final String displayTimeFallback;
  final DateTime? displayTimeNow;

  @override
  Widget build(BuildContext context) {
    final worldoRedesign = Theme.of(context).brightness == Brightness.dark;
    final avatarSize = worldoRedesign ? 44.0 : _avatarSize;
    final avatarBorderRadius = worldoRedesign ? 14.0 : _avatarBorderRadius;
    final displayPeerName = formatUidForDisplay(
      item.peerName,
      fallback: 'Unknown user',
    );
    return Material(
      color: worldoRedesign
          ? context.genesisColors.pageBackground
          : context.genesisColors.surface,
      child: InkWell(
        onTap: () => unawaited(onTap(item)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: worldoRedesign ? 13 : 8),
          child: Row(
            crossAxisAlignment: worldoRedesign
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              _Avatar(
                avatarUrl: item.avatarUrl,
                title: displayPeerName,
                size: avatarSize,
                borderRadius: avatarBorderRadius,
                avatarKey: ValueKey('dm-avatar-${item.conversationId}'),
                unreadCount: item.unreadCount,
                unreadBadgeKey: ValueKey(
                  'dm-avatar-${item.conversationId}-unread-badge',
                ),
              ),
              SizedBox(width: worldoRedesign ? 12 : 13),
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
                            style: TextStyle(
                              fontSize: worldoRedesign ? 13 : 14,
                              height: worldoRedesign ? 1.15 : null,
                              fontWeight: FontWeight.w600,
                              color: worldoRedesign
                                  ? context.genesisColors.textPrimary
                                  : context.genesisColors.textHighEmphasis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 112),
                          child: GenesisTimestampText(
                            timestamp: displayTime,
                            fallback: displayTimeFallback,
                            now: displayTimeNow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: worldoRedesign ? 9.5 : 11,
                              height: worldoRedesign ? 1 : null,
                              color: context.genesisColors.textFaint,
                              fontWeight: worldoRedesign
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.only(right: worldoRedesign ? 0 : 60),
                      child: Text(
                        item.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: worldoRedesign ? 1.45 : null,
                          fontWeight: FontWeight.w400,
                          color: worldoRedesign
                              ? const Color(0xFF9A949F)
                              : context.genesisColors.textMuted,
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
            showFallbackWhileLoading: false,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Transform.translate(
              offset: const Offset(4, -4),
              child: GenesisUnreadBadge(
                key: unreadBadgeKey,
                count: unreadCount,
              ),
            ),
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
          height: MediaQuery.sizeOf(context).height * 0.45 - 4,
          child: Center(
            key: ValueKey('direct-messages-empty-state'),
            child: Text(
              'Chat with your friends on Worldo.',
              style: TextStyle(
                fontSize: 14,
                color: context.genesisColors.textSupporting,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
