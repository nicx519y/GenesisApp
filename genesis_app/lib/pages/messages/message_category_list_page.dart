import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/me/genesis_follow_user_list_tile.dart';
import '../../components/page_header.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_timestamp_formatter.dart';

class MessageCategoryListPage extends StatefulWidget {
  const MessageCategoryListPage({
    super.key,
    required this.title,
    required this.block,
    required this.emptyText,
    this.onNotificationsRead,
  });

  final String title;
  final String block;
  final String emptyText;
  final Future<void> Function()? onNotificationsRead;

  @override
  State<MessageCategoryListPage> createState() =>
      _MessageCategoryListPageState();
}

class _MessageCategoryListPageState extends State<MessageCategoryListPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _items = <_NotificationItem>[];
  final _initialUnreadIds = <String>{};
  final _loadingFollowUids = <String>{};
  final _followStateOverrides = <String, bool>{};
  var _page = 1;
  var _total = 0;
  var _loading = true;
  var _loadingMore = false;
  var _refreshing = false;
  Object? _error;

  bool get _hasMore => _items.length < _total;
  bool get _isCommentsBlock => widget.block == 'interaction';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    if (!_hasMore) return;
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _markCategoryRead() async {
    try {
      await AppServicesScope.read(
        context,
      ).api.v1.messages.markNotificationsRead(block: widget.block);
      if (!mounted) return;
      if (_items.any((item) => !item.isRead)) {
        setState(() {
          for (var index = 0; index < _items.length; index += 1) {
            _items[index] = _items[index].copyWith(isRead: true);
          }
        });
      }
      await widget.onNotificationsRead?.call();
    } catch (error, stackTrace) {
      debugPrint(
        '[Messages] markNotificationsRead failed block=${widget.block}: $error',
      );
      debugPrint('[Messages] markNotificationsRead stacktrace:\n$stackTrace');
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = _items.isEmpty;
      _refreshing = true;
      _loadingMore = false;
      _error = null;
    });
    await _loadPage(1, replace: true);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _refreshing) return;
    setState(() => _loadingMore = true);
    await _loadPage(_page + 1, replace: false);
  }

  Future<void> _loadPage(int page, {required bool replace}) async {
    try {
      final data = await AppServicesScope.read(context).api.v1.messages
          .notifications(block: widget.block, pn: page, rn: _pageSize);
      final rawItems = asJsonList(data['list']);
      final items = rawItems
          .map((item) => _NotificationItem.fromJson(asJsonMap(item)))
          .toList(growable: false);
      if (!mounted) return;
      if (replace) {
        _initialUnreadIds
          ..clear()
          ..addAll(items.where((item) => !item.isRead).map((item) => item.id));
      }
      setState(() {
        if (replace) {
          _items
            ..clear()
            ..addAll(items);
        } else {
          _items.addAll(items);
        }
        _page = page;
        _total = asInt(data['total'], fallback: _items.length);
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
        _error = null;
      });
      if (replace) unawaited(_markCategoryRead());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
        _error = error;
      });
    }
  }

  Future<void> _openJoinRequestActions(_NotificationItem item) async {
    if (item.joinRequestApprovalStatus != _JoinRequestApprovalStatus.pending) {
      await _openJoinRequestView(item);
      return;
    }

    final action = await showGenesisActionBox<_JoinRequestAction>(
      context: context,
      title: 'Join request',
      content: _JoinRequestDialogContent(
        item: item,
        statusOnly: false,
        onOpenUser: () => _openUserFromDialog(item.senderUid),
        onOpenWorld: () => _openWorldFromDialog(item.bizId),
      ),
      actions: const [
        GenesisActionBoxAction<_JoinRequestAction>(
          label: 'Approve',
          value: _JoinRequestAction.approve,
        ),
        GenesisActionBoxAction<_JoinRequestAction>(
          label: 'Reject',
          value: _JoinRequestAction.reject,
          color: Color(0xFF111111),
        ),
      ],
    );
    if (action == null || !mounted) return;
    await _reviewJoinRequest(item, action);
  }

  Future<void> _openJoinRequestView(_NotificationItem item) {
    return showGenesisActionBox<void>(
      context: context,
      title: 'Join request',
      content: _JoinRequestDialogContent(
        item: item,
        statusOnly: true,
        onOpenUser: () => _openUserFromDialog(item.senderUid),
        onOpenWorld: () => _openWorldFromDialog(item.bizId),
      ),
      actions: const <GenesisActionBoxAction<void>>[],
    );
  }

  void _openUserFromDialog(String uid) {
    final cleanUid = uid.trim();
    Navigator.of(context, rootNavigator: true).pop();
    if (cleanUid.isEmpty || !mounted) return;
    unawaited(
      Navigator.of(
        context,
      ).pushNamed(RouteNames.userInfo, arguments: {'uid': cleanUid}),
    );
  }

  void _openWorldFromDialog(String wid) {
    final cleanWid = wid.trim();
    Navigator.of(context, rootNavigator: true).pop();
    if (cleanWid.isEmpty || !mounted) return;
    unawaited(
      Navigator.of(
        context,
      ).pushNamed(RouteNames.world, arguments: {'wid': cleanWid}),
    );
  }

  Future<void> _reviewJoinRequest(
    _NotificationItem item,
    _JoinRequestAction action,
  ) async {
    final applyId = item.applyId.trim();
    if (applyId.isEmpty) {
      showGenesisToast(context, 'Missing join request id');
      return;
    }

    try {
      await AppServicesScope.read(
        context,
      ).api.v1.world.reviewApply(applyId: applyId, action: action.apiValue);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((candidate) => candidate.id == item.id);
        if (index == -1) return;
        _items[index] = _items[index].copyWith(
          isRead: true,
          approvalStatus: action.approvalStatus,
        );
      });
      showGenesisToast(context, action.successText);
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Review failed');
    }
  }

  Future<void> _toggleFollow(_NotificationItem item, bool isFollowed) async {
    final uid = item.followUserUid.trim();
    if (uid.isEmpty || _loadingFollowUids.contains(uid)) return;
    setState(() => _loadingFollowUids.add(uid));
    try {
      final api = AppServicesScope.read(context).api.v1.follow;
      if (isFollowed) {
        await api.unfollow(uid: uid);
      } else {
        await api.follow(uid: uid);
      }
      if (!mounted) return;
      setState(() {
        _followStateOverrides[uid] = !isFollowed;
        _loadingFollowUids.remove(uid);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFollowUids.remove(uid));
      showGenesisToast(context, 'Follow update failed');
    }
  }

  void _openNotification(_NotificationItem item) {
    if (item.isJoinRequest) {
      unawaited(_openJoinRequestActions(item));
      return;
    }
    if (item.isJoinRequestReview) {
      _openWorld(item.bizId);
      return;
    }
    if (item.isDiscussNotification) {
      Navigator.of(context).pushNamed(
        RouteNames.postDetail,
        arguments: {'item': item.toDiscussListItem()},
      );
    }
  }

  void _openWorld(String wid) {
    final cleanWid = wid.trim();
    if (cleanWid.isEmpty) return;
    Navigator.of(
      context,
    ).pushNamed(RouteNames.world, arguments: {'wid': cleanWid});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: GenesisBackAppBar(pageName: widget.title),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          const Center(
            child: Text(
              'Failed to load messages.',
              style: TextStyle(
                color: Color(0xFF94979E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          Center(
            child: Text(
              widget.emptyText,
              style: const TextStyle(
                color: Color(0xFF94979E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 18 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, index) {
        if (index < _items.length && _items[index].isFollowNotification) {
          return const SizedBox.shrink();
        }
        return const SizedBox(height: 24);
      },
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _items[index];
        final showUnreadDot = _initialUnreadIds.contains(item.id);
        if (_isCommentsBlock) {
          return _CommentNotificationRow(
            key: ValueKey(item.id),
            item: item,
            showUnreadDot: showUnreadDot,
            onTap: () => _openNotification(item),
          );
        }
        return _NotificationListItem(
          key: ValueKey(item.id),
          item: item,
          showUnreadDot: showUnreadDot,
          followIsLoading: _loadingFollowUids.contains(item.followUserUid),
          followStateOverride: _followStateOverrides[item.followUserUid],
          onTap: () => _openNotification(item),
          onToggleFollow: (isFollowed) => _toggleFollow(item, isFollowed),
        );
      },
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  const _NotificationListItem({
    super.key,
    required this.item,
    required this.showUnreadDot,
    required this.followIsLoading,
    required this.followStateOverride,
    required this.onTap,
    required this.onToggleFollow,
  });

  final _NotificationItem item;
  final bool showUnreadDot;
  final bool followIsLoading;
  final bool? followStateOverride;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleFollow;

  @override
  Widget build(BuildContext context) {
    if (item.isFollowNotification) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            key: ValueKey('message-follow-row-${item.followUserUid}'),
            height: GenesisFollowUserListTile.itemExtent,
            child: GenesisFollowUserListTile(
              uid: item.followUserUid,
              displayName: item.followUserName,
              avatarUrl: item.senderAvatar,
              isFollowed: followStateOverride ?? item.isFollowed,
              isLoading: followIsLoading,
              keyPrefix: 'message-follow',
              onToggleFollow: () =>
                  onToggleFollow(followStateOverride ?? item.isFollowed),
            ),
          ),
          if (showUnreadDot)
            const Positioned(
              right: -13,
              top: (GenesisFollowUserListTile.itemExtent - 7) / 2,
              child: _UnreadDot(),
            ),
        ],
      );
    }

    final content = InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: item.isJoinRequest || item.isJoinRequestReview
          ? _JoinRequestListItem(item: item)
          : _CommentNotificationListItem(item: item),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: content),
        const SizedBox(width: 10),
        SizedBox(
          width: 8,
          height: item.isFollowNotification
              ? GenesisFollowUserListTile.itemExtent
              : null,
          child: Align(
            alignment: item.isFollowNotification
                ? Alignment.center
                : Alignment.topCenter,
            child: showUnreadDot ? const _UnreadDot() : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('message-category-unread-dot'),
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFFF42C47),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CommentNotificationRow extends StatelessWidget {
  const _CommentNotificationRow({
    super.key,
    required this.item,
    required this.showUnreadDot,
    required this.onTap,
  });

  final _NotificationItem item;
  final bool showUnreadDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(right: showUnreadDot ? 18 : 0),
            child: _CommentNotificationListItem(item: item, isComments: true),
          ),
          if (showUnreadDot)
            const Positioned(right: 0, top: 5, child: _UnreadDot()),
        ],
      ),
    );
  }
}

class _JoinRequestListItem extends StatelessWidget {
  const _JoinRequestListItem({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final isReview = item.isJoinRequestReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isReview ? item.reviewTitleText : 'Join request',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (isReview)
          _StatusText(item: item)
        else ...[
          _JoinRequestSummaryText(item: item),
          const SizedBox(height: 8),
          _StatusText(item: item),
        ],
      ],
    );
  }
}

class _JoinRequestSummaryText extends StatelessWidget {
  const _JoinRequestSummaryText({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w400,
        ),
        children: [
          TextSpan(text: item.requesterName, style: _originBlueTextStyle),
          const TextSpan(text: ' request to join '),
          TextSpan(text: item.requestWorldName, style: _originBlueTextStyle),
          if (item.bizId.trim().isNotEmpty) TextSpan(text: '(${item.bizId})'),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Text(
      item.joinRequestStatusText,
      style: TextStyle(
        color: item.joinRequestStatusColor,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _CommentNotificationListItem extends StatelessWidget {
  const _CommentNotificationListItem({
    required this.item,
    this.isComments = false,
  });

  final _NotificationItem item;
  final bool isComments;

  @override
  Widget build(BuildContext context) {
    final titleStyle = isComments
        ? _commentNotificationTitleStyle
        : _notificationTitleStyle;
    final bodyStyle = isComments
        ? _commentNotificationBodyStyle
        : _notificationBodyStyle;
    final metaStyle = isComments
        ? _commentNotificationMetaStyle
        : _notificationMetaStyle;
    final verticalGap = 8.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.titleText, style: titleStyle),
        if (item.bodyText.isNotEmpty) ...[
          SizedBox(height: verticalGap),
          Text(item.bodyText, style: bodyStyle),
        ],
        if (item.metaText.isNotEmpty) ...[
          SizedBox(height: verticalGap),
          Text(item.metaText, style: metaStyle),
        ],
      ],
    );
  }
}

const _notificationTitleStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: 14,
  height: 1.18,
  fontWeight: FontWeight.w700,
);

const _notificationBodyStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: 12,
  height: 1.25,
  fontWeight: FontWeight.w400,
);

const _notificationMetaStyle = TextStyle(
  color: Color(0xFF8A8D93),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

const _commentNotificationTitleStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: 14,
  height: 1.18,
  fontWeight: FontWeight.w700,
);

const _commentNotificationBodyStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: 12,
  height: 1.25,
  fontWeight: FontWeight.w400,
);

const _commentNotificationMetaStyle = TextStyle(
  color: Color(0xFF8A8D93),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

const _originBlueTextStyle = TextStyle(color: Color(0xFF2F4F7A));

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.block,
    required this.type,
    required this.senderName,
    required this.senderUid,
    required this.senderAvatar,
    required this.bizId,
    required this.objId,
    required this.content,
    required this.worldName,
    required this.originName,
    required this.commentText,
    required this.isFollowed,
    required this.isRead,
    required this.createdAt,
    required this.approvalStatus,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    final sender = _optionalJsonMap(json['sender']);
    final user = _optionalJsonMap(json['user']);
    final relation = _optionalJsonMap(json['relation']);
    final comment = _optionalJsonMap(json['comment']);
    final reply = _optionalJsonMap(json['reply']);
    final target = _optionalJsonMap(json['target']);
    final type = asString(json['notice_type']);
    final block = asString(json['notice_block']);
    final content = asString(
      json['content'],
      fallback: asString(json['message'], fallback: 'New message'),
    );
    final bizId = asString(
      json['biz_id'],
      fallback: asString(json['world_id']),
    );
    final worldName = _firstNonEmpty([
      asString(json['world_name']),
      _mapString(json, 'world_title'),
      _mapString(json, 'target_world_name'),
      _mapString(_optionalJsonMap(json['world']), 'world_name'),
      _mapString(_optionalJsonMap(json['world']), 'name'),
      _mapString(_optionalJsonMap(json['target']), 'world_name'),
      _mapString(_optionalJsonMap(json['target']), 'name'),
      _extractWorldNameFromJoinContent(content),
    ]);
    final originName = _firstNonEmpty([
      asString(json['origin_name']),
      _mapString(json, 'biz_name'),
      _mapString(_optionalJsonMap(json['origin']), 'origin_name'),
      _mapString(_optionalJsonMap(json['origin']), 'name'),
      _mapString(_optionalJsonMap(json['target']), 'origin_name'),
      _mapString(_optionalJsonMap(json['target']), 'name'),
    ]);
    return _NotificationItem(
      id: asString(json['notification_id'], fallback: asString(json['id'])),
      block: block,
      type: type,
      senderName: _firstNonEmpty([
        _mapString(sender, 'name'),
        _mapString(sender, 'username'),
        _mapString(sender, 'nick_name'),
        _mapString(user, 'name'),
        _mapString(user, 'display_name'),
        _mapString(user, 'nickname'),
        asString(json['sender_name']),
      ]),
      senderUid: _firstNonEmpty([
        _mapString(sender, 'uid'),
        _mapString(sender, 'user_id'),
        _mapString(user, 'uid'),
        _mapString(user, 'target_user_id'),
        asString(json['sender_uid']),
        asString(json['applicant_uid']),
      ]),
      senderAvatar: asImageUrl(
        _firstNonNull([
          sender?['avatar'],
          sender?['avatar_url'],
          user?['avatar'],
          user?['avatar_url'],
          json['avatar'],
          json['avatar_url'],
        ]),
      ),
      bizId: bizId,
      objId: _firstNonEmpty([
        asString(json['obj_id']),
        asString(json['apply_id']),
        asString(json['discuss_id']),
        asString(json['root_discuss_id']),
      ]),
      content: content,
      worldName: worldName,
      originName: originName,
      commentText: _firstNonEmpty([
        asString(json['comment_content']),
        asString(json['comment_text']),
        asString(json['discuss_content']),
        asString(json['target_content']),
        asString(json['target_text']),
        _mapString(comment, 'content'),
        _mapString(reply, 'content'),
        _mapString(target, 'comment_content'),
        _mapString(target, 'content'),
        asString(json['text']),
        _extractCommentBodyFromContent(content),
        content,
      ]),
      isFollowed:
          asBool(relation?['i_followed']) ||
          asBool(relation?['is_followed']) ||
          asBool(user?['i_followed']) ||
          asBool(user?['is_followed']) ||
          asBool(json['i_followed']) ||
          asBool(json['is_followed']),
      isRead: asBool(json['is_read']),
      createdAt: asDateTime(json['created_at']),
      approvalStatus: _approvalStatusFromJson(json),
    );
  }

  final String id;
  final String block;
  final String type;
  final String senderName;
  final String senderUid;
  final String senderAvatar;
  final String bizId;
  final String objId;
  final String content;
  final String worldName;
  final String originName;
  final String commentText;
  final bool isFollowed;
  final bool isRead;
  final DateTime? createdAt;
  final _JoinRequestApprovalStatus? approvalStatus;

  _NotificationItem copyWith({
    bool? isRead,
    _JoinRequestApprovalStatus? approvalStatus,
  }) {
    return _NotificationItem(
      id: id,
      block: block,
      type: type,
      senderName: senderName,
      senderUid: senderUid,
      senderAvatar: senderAvatar,
      bizId: bizId,
      objId: objId,
      content: content,
      worldName: worldName,
      originName: originName,
      commentText: commentText,
      isFollowed: isFollowed,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  bool get isJoinRequestReview => type == 'world_apply_review';

  bool get isJoinRequest {
    if (isJoinRequestReview) return false;
    return type == 'world_apply' || block == 'world_apply';
  }

  bool get isFollowNotification => block == 'follow' || type == 'follow';

  bool get isDiscussNotification =>
      block == 'interaction' || type.startsWith('discuss_');

  String get applyId => objId;

  String get senderDisplayName =>
      senderName.isEmpty ? 'Someone' : formatUidForDisplay(senderName);

  String get requesterName {
    if (senderName.isNotEmpty) return formatUidForDisplay(senderName);
    return _firstNonEmpty([
      _extractRequesterNameFromJoinContent(content),
      'Someone',
    ]);
  }

  String get requestWorldName => _firstNonEmpty([worldName, bizId]);

  String get joinRequestSummary {
    final name = requesterName;
    final world = requestWorldName.isEmpty ? 'this world' : requestWorldName;
    final id = bizId.trim();
    final suffix = id.isEmpty ? '' : '($id)';
    return '$name request to join $world$suffix';
  }

  String get reviewTitleText {
    final world = requestWorldName.isEmpty ? 'this world' : requestWorldName;
    final id = bizId.trim();
    return 'request to $world${id.isEmpty ? '' : '($id)'}';
  }

  _JoinRequestApprovalStatus get joinRequestApprovalStatus {
    return approvalStatus ?? _JoinRequestApprovalStatus.pending;
  }

  String get joinRequestStatusText {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return 'Approved';
      case _JoinRequestApprovalStatus.rejected:
        return 'Rejected';
      case _JoinRequestApprovalStatus.pending:
        return 'Awaiting your approval';
      case null:
        return isJoinRequestReview ? 'Approved' : 'Awaiting your approval';
    }
  }

  Color get joinRequestStatusColor {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return const Color(0xFF25845C);
      case _JoinRequestApprovalStatus.rejected:
        return const Color(0xFF8A8D93);
      case _JoinRequestApprovalStatus.pending:
        return const Color(0xFF25845C);
      case null:
        return const Color(0xFF25845C);
    }
  }

  String get discussTitleSuffix {
    final normalizedType = type.toLowerCase();
    final normalizedContent = content.toLowerCase();
    if (normalizedType == 'discuss_comment') {
      return ' comment your origin';
    }
    if (normalizedType == 'discuss_reply') {
      return ' reply to you';
    }
    if (normalizedType == 'discuss_like') {
      return ' like your comment';
    }
    if (normalizedType.contains('like') ||
        normalizedContent.contains('liked your comment') ||
        normalizedContent.contains('like your comment')) {
      return ' like your comment';
    }
    if (normalizedType.contains('reply') ||
        normalizedContent.contains('replied to you') ||
        normalizedContent.contains('reply to you')) {
      return ' reply to you';
    }
    if (normalizedType.contains('comment') ||
        normalizedContent.contains('commented on your origin') ||
        normalizedContent.contains('comment your origin')) {
      return ' comment your origin';
    }
    return content.isEmpty ? ' sent you a message' : ' $content';
  }

  String get titleText => '$senderDisplayName$discussTitleSuffix';

  String get followUserName {
    if (!isFollowNotification) return '';
    if (senderName.isNotEmpty) {
      return formatUidForDisplay(senderName, fallback: 'User');
    }
    final suffix = ' started following you.';
    if (content.endsWith(suffix)) {
      return formatUidForDisplay(
        content.substring(0, content.length - suffix.length).trim(),
        fallback: 'User',
      );
    }
    return formatUidForDisplay(followUserUid, fallback: 'User');
  }

  String get followUserUid {
    if (!isFollowNotification) return '';
    return _firstNonEmpty([senderUid, objId, bizId]);
  }

  String get bodyText {
    if (isDiscussNotification) {
      final trimmedComment = commentText.trim();
      if (trimmedComment.isEmpty) return '';
      final normalizedComment = trimmedComment.toLowerCase();
      final normalizedTitle = titleText.toLowerCase();
      if (normalizedComment == normalizedTitle) return '';
      return trimmedComment;
    }
    return content;
  }

  String get metaText {
    final source = isDiscussNotification
        ? _firstNonEmpty([originName, worldName])
        : _firstNonEmpty([originName, worldName, bizId]);
    final time = createdAtText;
    if (source.isEmpty) return time;
    if (time.isEmpty) return '#$source';
    return '#$source · $time';
  }

  String get createdAtText {
    return formatGenesisDateTime(createdAt);
  }

  OriginDiscussListItem toDiscussListItem() {
    return OriginDiscussListItem(
      discussId: objId,
      bizId: bizId,
      authorUid: senderUid,
      authorName: senderDisplayName,
      avatar: senderAvatar,
      content: commentText,
      replyCount: 0,
      createdAt: createdAt,
      seed: senderUid.isEmpty ? senderDisplayName : senderUid,
      latestReplies: const <Map<String, dynamic>>[],
    );
  }
}

enum _JoinRequestAction {
  approve,
  reject;

  String get apiValue {
    switch (this) {
      case _JoinRequestAction.approve:
        return 'approve';
      case _JoinRequestAction.reject:
        return 'reject';
    }
  }

  _JoinRequestApprovalStatus get approvalStatus {
    switch (this) {
      case _JoinRequestAction.approve:
        return _JoinRequestApprovalStatus.approved;
      case _JoinRequestAction.reject:
        return _JoinRequestApprovalStatus.rejected;
    }
  }

  String get successText {
    switch (this) {
      case _JoinRequestAction.approve:
        return 'Approved';
      case _JoinRequestAction.reject:
        return 'Rejected';
    }
  }
}

enum _JoinRequestApprovalStatus { pending, approved, rejected }

class _JoinRequestDialogContent extends StatelessWidget {
  const _JoinRequestDialogContent({
    required this.item,
    required this.statusOnly,
    required this.onOpenUser,
    required this.onOpenWorld,
  });

  final _NotificationItem item;
  final bool statusOnly;
  final VoidCallback onOpenUser;
  final VoidCallback onOpenWorld;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _JoinRequestDialogInfoRow(
            title: item.requesterName,
            subtitle: item.senderUid,
            onTap: onOpenUser,
          ),
          const SizedBox(height: 4),
          _JoinRequestDialogInfoRow(
            title: item.requestWorldName.isEmpty
                ? 'this world'
                : item.requestWorldName,
            subtitle: item.bizId,
            onTap: onOpenWorld,
          ),
          if (statusOnly) ...[
            const SizedBox(height: 12),
            _StatusText(item: item),
          ],
        ],
      ),
    );
  }
}

class _JoinRequestDialogInfoRow extends StatelessWidget {
  const _JoinRequestDialogInfoRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: title, style: _originBlueTextStyle),
                    if (subtitle.trim().isNotEmpty)
                      TextSpan(text: ' $subtitle'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '>',
              style: TextStyle(
                color: Color(0xFF8A8D93),
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic>? _optionalJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String _mapString(Map<String, dynamic>? map, String key) {
  if (map == null) return '';
  return asString(map[key]);
}

String _firstNonEmpty(Iterable<String> values, {String fallback = ''}) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

Object? _firstNonNull(Iterable<Object?> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

_JoinRequestApprovalStatus? _approvalStatusFromJson(Map<String, dynamic> json) {
  final raw = _firstNonEmpty([
    asString(json['apply_status']),
    asString(json['status']),
    asString(json['review_status']),
  ]).toLowerCase();
  if (raw == '20' || raw == 'approved' || raw == 'approve') {
    return _JoinRequestApprovalStatus.approved;
  }
  if (raw == '30' || raw == 'rejected' || raw == 'reject') {
    return _JoinRequestApprovalStatus.rejected;
  }
  if (raw == '10' || raw == 'pending') {
    return _JoinRequestApprovalStatus.pending;
  }
  return null;
}

String _extractRequesterNameFromJoinContent(String content) {
  final match = RegExp(
    r'^(.+?)\s+(?:request|requests|wants|want)\s+to\s+join\b',
    caseSensitive: false,
  ).firstMatch(content.trim());
  return match?.group(1)?.trim() ?? '';
}

String _extractCommentBodyFromContent(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return '';
  final quoted = RegExp(r'["“](.+?)["”]').firstMatch(trimmed);
  if (quoted != null) return quoted.group(1)?.trim() ?? '';
  final colonIndex = trimmed.indexOf(':');
  if (colonIndex == -1 || colonIndex == trimmed.length - 1) return '';
  return trimmed.substring(colonIndex + 1).trim();
}

String _extractWorldNameFromJoinContent(String content) {
  final match = RegExp(
    r'\bjoin\s+(.+?)(?:\.|$)',
    caseSensitive: false,
  ).firstMatch(content.trim());
  return match?.group(1)?.trim() ?? '';
}
