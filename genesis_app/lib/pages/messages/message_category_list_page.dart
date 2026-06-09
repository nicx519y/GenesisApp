import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';

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
  var _page = 1;
  var _total = 0;
  var _loading = true;
  var _loadingMore = false;
  var _refreshing = false;
  Object? _error;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
    unawaited(_markCategoryRead());
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
    final action = await showDialog<_JoinRequestAction>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => _JoinRequestDialog(item: item),
    );
    if (action == null || !mounted) return;
    await _reviewJoinRequest(item, action);
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
        right: 32,
        top: 26,
        bottom: 18 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _NotificationListItem(
          key: ValueKey(_items[index].id),
          item: _items[index],
          onTap: _items[index].isJoinRequest
              ? () => _openJoinRequestActions(_items[index])
              : null,
        );
      },
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  const _NotificationListItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  final _NotificationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = item.isJoinRequest
        ? _JoinRequestListItem(item: item)
        : _CommentStyleListItem(item: item);
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: child,
    );
  }
}

class _JoinRequestListItem extends StatelessWidget {
  const _JoinRequestListItem({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Join request',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.joinRequestSummary,
          style: const TextStyle(
            color: Color(0xFF5A6075),
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.joinRequestStatusText,
          style: TextStyle(
            color: item.joinRequestStatusColor,
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CommentStyleListItem extends StatelessWidget {
  const _CommentStyleListItem({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item.isFollowNotification
            ? _FollowNotificationTitle(item: item)
            : Text(
                item.titleText,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                ),
              ),
        if (item.bodyText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.bodyText,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        if (item.metaText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            item.metaText,
            style: const TextStyle(
              color: Color(0xFF8A8D93),
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _FollowNotificationTitle extends StatelessWidget {
  const _FollowNotificationTitle({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final userName = item.followUserName;
    if (userName.isEmpty) {
      return Text(item.titleText, style: _titleStyle);
    }

    final uid = item.followUserUid;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: uid.isEmpty
              ? null
              : () {
                  Navigator.of(
                    context,
                  ).pushNamed(RouteNames.userInfo, arguments: {'uid': uid});
                },
          child: Text(
            userName,
            style: const TextStyle(
              color: Color(0xFF5A6075),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF5A6075),
              fontSize: 14,
              height: 1.18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(item.followTitleSuffix, style: _titleStyle),
      ],
    );
  }

  static const _titleStyle = TextStyle(
    color: Colors.black,
    fontSize: 14,
    height: 1.18,
    fontWeight: FontWeight.w800,
  );
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.block,
    required this.type,
    required this.senderName,
    required this.senderUid,
    required this.bizId,
    required this.objId,
    required this.content,
    required this.worldName,
    required this.originName,
    required this.commentText,
    required this.isRead,
    required this.createdAt,
    required this.approvalStatus,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    final sender = _optionalJsonMap(json['sender']);
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
        asString(json['sender_name']),
      ]),
      senderUid: _firstNonEmpty([
        _mapString(sender, 'uid'),
        _mapString(sender, 'user_id'),
        asString(json['sender_uid']),
        asString(json['applicant_uid']),
      ]),
      bizId: bizId,
      objId: asString(json['obj_id'], fallback: asString(json['apply_id'])),
      content: content,
      worldName: worldName,
      originName: originName,
      commentText: _firstNonEmpty([
        asString(json['comment_content']),
        asString(json['comment_text']),
        asString(json['discuss_content']),
        asString(json['text']),
        content,
      ]),
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
  final String bizId;
  final String objId;
  final String content;
  final String worldName;
  final String originName;
  final String commentText;
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
      bizId: bizId,
      objId: objId,
      content: content,
      worldName: worldName,
      originName: originName,
      commentText: commentText,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  bool get isJoinRequest => block == 'world_apply' || type == 'world_apply';

  bool get isFollowNotification => block == 'follow' || type == 'follow';

  String get applyId => objId;

  String get requesterName {
    if (senderName.isNotEmpty) return senderName;
    return _firstNonEmpty([_extractRequesterNameFromJoinContent(content)]);
  }

  String get requestWorldName => _firstNonEmpty([worldName, bizId]);

  String get joinRequestSummary {
    final name = requesterName.isEmpty ? 'Someone' : requesterName;
    final world = requestWorldName.isEmpty ? 'this world' : requestWorldName;
    final id = bizId.trim();
    final suffix = id.isEmpty ? '' : '\n($id)';
    return '$name request to join $world$suffix';
  }

  String get joinRequestStatusText {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return 'Approved';
      case _JoinRequestApprovalStatus.rejected:
        return 'Rejected';
      case null:
      case _JoinRequestApprovalStatus.pending:
        return 'Awaiting your approval';
    }
  }

  Color get joinRequestStatusColor {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return const Color(0xFF25845C);
      case _JoinRequestApprovalStatus.rejected:
        return const Color(0xFF8A8D93);
      case null:
      case _JoinRequestApprovalStatus.pending:
        return const Color(0xFF25845C);
    }
  }

  String get titleText {
    final name = senderName.isEmpty ? 'Someone' : senderName;
    switch (type) {
      case 'discuss_like':
        return '$name liked your comment';
      case 'discuss_reply':
        return '$name replied to your comment';
      case 'discuss_comment':
        return '$name commented';
      case 'follow':
        return content.isEmpty ? '$name started following you' : content;
    }
    return content;
  }

  String get followUserName {
    if (!isFollowNotification) return '';
    if (senderName.isNotEmpty) return senderName;
    final suffix = ' started following you.';
    if (content.endsWith(suffix)) {
      return content.substring(0, content.length - suffix.length).trim();
    }
    return '';
  }

  String get followUserUid {
    if (!isFollowNotification) return '';
    return _firstNonEmpty([senderUid, objId, bizId]);
  }

  String get followTitleSuffix {
    if (!isFollowNotification) return '';
    final userName = followUserName;
    if (userName.isNotEmpty && content.startsWith(userName)) {
      final suffix = content.substring(userName.length);
      return suffix.isEmpty ? ' started following you.' : suffix;
    }
    return ' started following you.';
  }

  String get bodyText {
    if (type == 'follow') return '';
    if (type.startsWith('discuss_')) return commentText;
    return content == titleText ? '' : content;
  }

  String get metaText {
    final source = _firstNonEmpty([originName, worldName, bizId]);
    final time = createdAtText;
    if (source.isEmpty) return time;
    if (time.isEmpty) return '#$source';
    return '#$source · $time';
  }

  String get createdAtText {
    final value = createdAt;
    if (value == null) return '';
    final local = value.toLocal();
    final month = local.month.toString();
    final day = local.day.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
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

class _JoinRequestDialog extends StatelessWidget {
  const _JoinRequestDialog({required this.item});

  static const _maxWidth = 318.0;
  static const _radius = BorderRadius.all(Radius.circular(18));
  static const _divider = Color(0xFFE8E8EA);

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.transparent,
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: _radius,
                child: Material(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 26),
                      const Text(
                        'Join request',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _JoinRequestInfoRow(
                        title: item.requesterName.isEmpty
                            ? 'Someone'
                            : item.requesterName,
                        subtitle: item.senderUid,
                      ),
                      const SizedBox(height: 18),
                      _JoinRequestInfoRow(
                        title: item.requestWorldName.isEmpty
                            ? 'this world'
                            : item.requestWorldName,
                        subtitle: item.bizId,
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, thickness: 1, color: _divider),
                      _JoinRequestDialogButton(
                        label: 'Approve',
                        color: Color(0xFFF42C47),
                        onTap: () => Navigator.of(
                          context,
                        ).pop(_JoinRequestAction.approve),
                      ),
                      const Divider(height: 1, thickness: 1, color: _divider),
                      _JoinRequestDialogButton(
                        label: 'Reject',
                        color: Colors.black,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(_JoinRequestAction.reject),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: _radius,
                child: Material(
                  color: Colors.white,
                  child: _JoinRequestDialogButton(
                    label: 'Cancel',
                    color: Colors.black,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinRequestInfoRow extends StatelessWidget {
  const _JoinRequestInfoRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 3,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A8D93),
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '>',
            style: TextStyle(
              color: Color(0xFF8A8D93),
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestDialogButton extends StatelessWidget {
  const _JoinRequestDialogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 62,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
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

String _extractWorldNameFromJoinContent(String content) {
  final match = RegExp(
    r'\bjoin\s+(.+?)(?:\.|$)',
    caseSensitive: false,
  ).firstMatch(content.trim());
  return match?.group(1)?.trim() ?? '';
}
