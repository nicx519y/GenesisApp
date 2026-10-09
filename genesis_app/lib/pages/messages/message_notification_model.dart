part of 'message_category_list_page.dart';

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.block,
    required this.type,
    required this.senderName,
    required this.senderUid,
    required this.senderAvatar,
    this.senderDeleted = false,
    this.senderGender = '',
    this.senderAge = '',
    this.senderMembershipStatus = 0,
    required this.bizId,
    this.worldDeleted = false,
    this.originDeleted = false,
    required this.objId,
    required this.rootDiscussId,
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
    final actor = sender?.isNotEmpty == true ? sender : user;
    final relation = _optionalJsonMap(json['relation']);
    final comment = _optionalJsonMap(json['comment']);
    final reply = _optionalJsonMap(json['reply']);
    final target = _optionalJsonMap(json['target']);
    final type = asString(json['notice_type']);
    final block = asString(json['notice_block']);
    final content = asString(
      json['content'],
      fallback: asString(
        json['message'],
        fallback: GenesisL10n.current.inboxNewMessage,
      ),
    );
    final bizId = asString(
      json['biz_id'],
      fallback: asString(json['world_id']),
    );
    final isWorldApply =
        block == 'world_apply' || type.startsWith('world_apply');
    final worldName = _firstNonEmpty([
      if (isWorldApply) asString(json['biz_name']),
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
      senderGender: asString(actor?['gender']),
      senderAge: asString(actor?['age']),
      senderMembershipStatus: asUserMembershipStatus(
        actor?['membership_status'],
      ),
      senderDeleted: entityDeleted(
        sender?['deleted'],
        fallback:
            user?['deleted'] ?? json['sender_deleted'] ?? json['user_deleted'],
      ),
      bizId: bizId,
      worldDeleted: entityDeleted(
        json['world_deleted'],
        fallback:
            _optionalJsonMap(json['world'])?['world_deleted'] ??
            _optionalJsonMap(json['world'])?['deleted'],
      ),
      originDeleted: entityDeleted(
        json['origin_deleted'],
        fallback:
            _optionalJsonMap(json['origin'])?['origin_deleted'] ??
            _optionalJsonMap(json['origin'])?['deleted'] ??
            _optionalJsonMap(json['target'])?['origin_deleted'] ??
            _optionalJsonMap(json['target'])?['deleted'],
      ),
      objId: _firstNonEmpty([
        asString(json['obj_id']),
        asString(json['apply_id']),
        asString(json['discuss_id']),
        asString(json['root_discuss_id']),
      ]),
      rootDiscussId: _firstNonEmpty([
        asString(json['root_discuss_id']),
        _mapString(comment, 'root_discuss_id'),
        _mapString(reply, 'root_discuss_id'),
        _mapString(target, 'root_discuss_id'),
        asString(json['discuss_id']),
        asString(json['obj_id']),
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
      isFollowed: json.containsKey('is_followed')
          ? asBool(json['is_followed'])
          : _relationIsFollowed(relation) ||
                _relationIsFollowed(user) ||
                _relationIsFollowed(json),
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
  final bool senderDeleted;
  final String senderGender;
  final String senderAge;
  final int senderMembershipStatus;
  final String bizId;
  final bool worldDeleted;
  final bool originDeleted;
  final String objId;
  final String rootDiscussId;
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
    bool? worldDeleted,
    _JoinRequestApprovalStatus? approvalStatus,
  }) {
    return _NotificationItem(
      id: id,
      block: block,
      type: type,
      senderName: senderName,
      senderUid: senderUid,
      senderAvatar: senderAvatar,
      senderDeleted: senderDeleted,
      senderGender: senderGender,
      senderAge: senderAge,
      senderMembershipStatus: senderMembershipStatus,
      bizId: bizId,
      worldDeleted: worldDeleted ?? this.worldDeleted,
      originDeleted: originDeleted,
      objId: objId,
      rootDiscussId: rootDiscussId,
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

  String get senderDisplayName {
    if (senderDeleted) return deletedEntityDisplayText;
    return senderName.isEmpty
        ? GenesisL10n.current.inboxSomeone
        : formatUidForDisplay(senderName);
  }

  String get requesterName {
    if (senderDeleted) return deletedEntityDisplayText;
    if (senderName.isNotEmpty) return senderName;
    return _firstNonEmpty([
      _extractRequesterNameFromJoinContent(content),
      GenesisL10n.current.inboxSomeone,
    ]);
  }

  String get requestWorldName {
    if (worldDeleted) return deletedEntityDisplayText;
    final cleanWorldName = worldName.trim();
    final cleanBizId = bizId.trim();
    if (cleanWorldName.isEmpty || cleanWorldName == cleanBizId) {
      return cleanBizId;
    }
    return cleanWorldName;
  }

  String get requestWorldSummaryName {
    if (worldDeleted) return deletedEntityDisplayText;
    final cleanWorldName = worldName.trim();
    final cleanBizId = bizId.trim();
    if (cleanWorldName.isEmpty || cleanWorldName == cleanBizId) {
      return cleanBizId.isEmpty ? GenesisL10n.current.inboxWorld : cleanBizId;
    }
    return cleanWorldName;
  }

  String get requestWorldIdLabel {
    return deletedAwareIdLabel(bizId, deleted: worldDeleted);
  }

  bool get shouldShowRequestWorldId {
    if (worldDeleted) return true;
    final id = bizId.trim();
    return id.isNotEmpty && requestWorldSummaryName != id;
  }

  String get joinRequestSummary {
    final name = requesterName;
    final world = requestWorldSummaryName;
    final suffix = shouldShowRequestWorldId ? '($requestWorldIdLabel)' : '';
    return GenesisL10n.current.inboxNameRequestJoinWorldSuffix(
      name: (name).toString(),
      world: (world).toString(),
      suffix: (suffix).toString(),
    );
  }

  String get reviewTitleText {
    final world = requestWorldSummaryName;
    return GenesisL10n.current.inboxJoinRequestTitle(
      world: (world).toString(),
      worldIdSuffix: (shouldShowRequestWorldId ? '($requestWorldIdLabel)' : '')
          .toString(),
    );
  }

  _JoinRequestApprovalStatus get joinRequestApprovalStatus {
    return approvalStatus ?? _JoinRequestApprovalStatus.pending;
  }

  String get joinRequestListStatusText {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return GenesisL10n.current.approvedStatus;
      case _JoinRequestApprovalStatus.rejected:
        return GenesisL10n.current.rejectedStatus;
      case _JoinRequestApprovalStatus.pending:
        return isJoinRequestReview
            ? GenesisL10n.current.awaitingApprovalStatus
            : GenesisL10n.current.awaitingYourApprovalStatus;
      case null:
        return isJoinRequestReview
            ? GenesisL10n.current.approvedStatus
            : GenesisL10n.current.awaitingYourApprovalStatus;
    }
  }

  String get joinRequestStatusText {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return GenesisL10n.current.approvedStatus;
      case _JoinRequestApprovalStatus.rejected:
        return GenesisL10n.current.rejectedStatus;
      case _JoinRequestApprovalStatus.pending:
        return GenesisL10n.current.awaitingYourApprovalStatus;
      case null:
        return isJoinRequestReview
            ? GenesisL10n.current.approvedStatus
            : GenesisL10n.current.awaitingYourApprovalStatus;
    }
  }

  Color get joinRequestStatusColor {
    switch (approvalStatus) {
      case _JoinRequestApprovalStatus.approved:
        return GenesisColors.redSecondary;
      case _JoinRequestApprovalStatus.rejected:
        return GenesisColors.darkTextTertiary;
      case _JoinRequestApprovalStatus.pending:
        return GenesisColors.redSecondary;
      case null:
        return GenesisColors.redSecondary;
    }
  }

  String get discussTitleSuffix {
    final normalizedType = type.toLowerCase();
    final normalizedContent = content.toLowerCase();
    if (normalizedType == 'discuss_comment') {
      return GenesisL10n.current.inboxCommentWorldo;
    }
    if (normalizedType == 'discuss_reply') {
      return GenesisL10n.current.inboxReply;
    }
    if (normalizedType == 'discuss_like') {
      return GenesisL10n.current.inboxLikeComment;
    }
    if (normalizedType.contains('like') ||
        normalizedContent.contains(GenesisL10n.current.inboxLikedComment) ||
        normalizedContent.contains(
          GenesisL10n.current.inboxComment2LikeComment,
        )) {
      return GenesisL10n.current.inboxLikeComment;
    }
    if (normalizedType.contains('reply') ||
        normalizedContent.contains(GenesisL10n.current.inboxReplied) ||
        normalizedContent.contains(GenesisL10n.current.inboxYou2Reply)) {
      return GenesisL10n.current.inboxReply;
    }
    if (normalizedType.contains('comment') ||
        normalizedContent.contains(GenesisL10n.current.inboxCommentedOrigin) ||
        normalizedContent.contains(GenesisL10n.current.inboxCommentOrigin)) {
      return GenesisL10n.current.inboxCommentWorldo;
    }
    return content.isEmpty ? GenesisL10n.current.inboxSentMessage : ' $content';
  }

  String discussTitleTemplate(AppLocalizations l10n) {
    final senderName = GenesisLocalizedRichText.placeholder('senderName');
    final senderBadge = GenesisLocalizedRichText.placeholder('senderBadge');
    final normalizedType = type.toLowerCase();
    final normalizedContent = content.toLowerCase();
    if (normalizedType == 'discuss_comment') {
      return l10n.notificationCommentedOnWorldo(
        senderName: senderName,
        senderBadge: senderBadge,
      );
    }
    if (normalizedType == 'discuss_reply') {
      return l10n.notificationRepliedToYou(
        senderName: senderName,
        senderBadge: senderBadge,
      );
    }
    if (normalizedType == 'discuss_like') {
      return l10n.notificationLikedComment(
        senderName: senderName,
        senderBadge: senderBadge,
      );
    }
    if (normalizedType.contains('like') ||
        normalizedContent.contains(GenesisL10n.current.inboxLikedComment) ||
        normalizedContent.contains(
          GenesisL10n.current.inboxComment2LikeComment,
        )) {
      return l10n.notificationLikedComment(
        senderName: senderName,
        senderBadge: senderBadge,
      );
    }
    if (normalizedType.contains('reply') ||
        normalizedContent.contains(GenesisL10n.current.inboxReplied) ||
        normalizedContent.contains(GenesisL10n.current.inboxYou2Reply)) {
      return l10n.notificationRepliedToYou(
        senderName: senderName,
        senderBadge: senderBadge,
      );
    }
    if (normalizedType.contains('comment') ||
        normalizedContent.contains(GenesisL10n.current.inboxCommentedOrigin) ||
        normalizedContent.contains(GenesisL10n.current.inboxCommentOrigin)) {
      return l10n.notificationCommentedOnWorldo(
        senderName: senderName,
        senderBadge: senderBadge,
      );
    }
    return content.isEmpty
        ? l10n.notificationSentMessage(
            senderName: senderName,
            senderBadge: senderBadge,
          )
        : l10n.notificationGenericContent(
            senderName: senderName,
            senderBadge: senderBadge,
            content: GenesisLocalizedRichText.placeholder('content'),
          );
  }

  String get titleText => '$senderDisplayName$discussTitleSuffix';

  String get followUserName {
    if (!isFollowNotification) return '';
    if (senderDeleted) return deletedEntityDisplayText;
    if (senderName.isNotEmpty) {
      return formatUidForDisplay(
        senderName,
        fallback: GenesisL10n.current.worldoUser,
      );
    }
    final suffix = GenesisL10n.current.inboxStartedFollowing;
    if (content.endsWith(suffix)) {
      return formatUidForDisplay(
        content.substring(0, content.length - suffix.length).trim(),
        fallback: GenesisL10n.current.worldoUser,
      );
    }
    return GenesisL10n.current.worldoUser;
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
    final source = isDiscussNotification || originDeleted || worldDeleted
        ? discussSourceLabel
        : _firstNonEmpty([
            originName.trim(),
            worldName.trim(),
            requestWorldIdLabel,
          ]);
    final time = createdAtText;
    if (source.isEmpty) return time;
    final displaySource = originName.trim().isEmpty
        ? source
        : originDisplayName(source);
    if (time.isEmpty) return displaySource;
    return '$displaySource · $time';
  }

  bool get discussSourceDeleted => originDeleted || worldDeleted;

  String get discussSourceLabel {
    if (discussSourceDeleted) return deletedEntityDisplayText;
    if (originName.trim().isNotEmpty) return originName.trim();
    if (worldName.trim().isNotEmpty) return worldName.trim();
    return bizId.trim();
  }

  String get createdAtText {
    return formatGenesisDateTime(createdAt);
  }

  OriginDiscussListItem toDiscussListItem() {
    return OriginDiscussListItem(
      discussId: objId,
      rootDiscussId: rootDiscussId,
      bizId: bizId,
      authorUid: senderUid,
      authorDeleted: senderDeleted,
      authorGender: senderGender,
      authorAge: senderAge,
      authorMembershipStatus: senderMembershipStatus,
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
