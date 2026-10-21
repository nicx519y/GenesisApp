import '../../../l10n/genesis_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';

import 'mini_phone_post_content.dart';

class MiniPhoneCommentsPage extends StatefulWidget {
  const MiniPhoneCommentsPage({
    super.key,
    required this.store,
    required this.postId,
    required this.active,
    required this.header,
    required this.onOpenPost,
    this.readNotificationsOnEntry = false,
  });
  final MiniPhoneStore store;
  final int? postId;
  final bool active;
  final Widget header;
  final ValueChanged<int> onOpenPost;
  final bool readNotificationsOnEntry;
  @override
  State<MiniPhoneCommentsPage> createState() => _MiniPhoneCommentsPageState();
}

class _MiniPhoneCommentsPageState extends State<MiniPhoneCommentsPage>
    with WidgetsBindingObserver {
  MiniPhoneStore get phone => widget.store;
  int? get livePostId => widget.postId;
  PhonePerson get _liveMe => phone.person(phone.uid ?? '', type: 1);
  PhoneComment? replyToComment;
  final commentInput = TextEditingController();
  final commentFocus = FocusNode();
  final commentsScroll = ScrollController();
  PhonePost? _seed;
  PhonePostDetail? _detail, _observedDetail;
  List<PhoneComment>? _comments, _observedComments;
  int? _seedLikes;
  bool? _seedLiked;
  bool _freshDetail = false, _loading = true, _started = false;
  bool _keyboardOpen = false, _followBottom = false, _alignScheduled = false;
  bool _sending = false, _sendFollow = false;
  bool _notificationReadAttempted = false;
  int _entry = 0;
  late int _generation;
  Object? _snapshot;
  Object _readSnapshot() => (
    phone.accountGeneration,
    phone.details[livePostId],
    phone.comments[livePostId],
    phone.posts,
    phone.authors,
    phone.likeTargets[livePostId],
    phone.postsController.interactionRevision,
    phone.busy.contains('comment:$livePostId'),
    phone.busy.contains('comments:$livePostId'),
    phone.errors['comments:$livePostId'],
    phone.foreground,
    phone.phoneVisible,
    (_liveMe.id, _liveMe.name, _liveMe.avatar),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    phone.addListener(_changed);
    _beginEntry();
  }

  void _beginEntry() {
    final entry = ++_entry;
    _generation = phone.accountGeneration;
    _seed = phone.posts.where((p) => p.id == livePostId).firstOrNull;
    _observedDetail = phone.details[livePostId];
    _detail = _seed == null ? _observedDetail : null;
    _seedLikes = _observedDetail?.likeCount ?? _seed?.likeCount;
    _seedLiked = _observedDetail?.isLiked ?? _seed?.isLiked;
    _observedComments = phone.comments[livePostId];
    _snapshot = _readSnapshot();
    _comments = null;
    _freshDetail = false;
    _loading = true;
    _started = false;
    _notificationReadAttempted = false;
    _followBottom = _sendFollow = _sending = false;
    commentInput.clear();
    replyToComment = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || entry != _entry || !widget.active) return;
      if (commentsScroll.hasClients) commentsScroll.jumpTo(0);
      final id = livePostId;
      if (id == null) return;
      if (!phone.isLocallyReady) await phone.localReady;
      if (!mounted || entry != _entry || !widget.active) return;
      _started = true;
      await Future.wait([
        _refreshDetail(id, onEntry: true),
        phone.refreshComments(id, onEntry: true),
      ]);
      if (!mounted || entry != _entry) return;
      _changed();
    });
  }

  Future<bool> _refreshDetail(int id, {bool onEntry = false}) async {
    final entry = _entry, generation = _generation;
    final ok = await phone.refreshDetail(id, onEntry: onEntry);
    if (ok &&
        mounted &&
        entry == _entry &&
        generation == phone.accountGeneration &&
        widget.readNotificationsOnEntry &&
        !_notificationReadAttempted &&
        widget.active &&
        phone.foreground &&
        phone.phoneVisible) {
      _notificationReadAttempted = true;
      // The World-owned controller finishes the receipt even if this page closes.
      unawaited(phone.markPostsRead());
    }
    return ok;
  }

  void _changed() {
    if (!mounted) return;
    final next = _readSnapshot();
    if (next == _snapshot &&
        (!_started ||
            _loading == phone.busy.contains('comments:$livePostId'))) {
      return;
    }
    _snapshot = next;
    if (_generation != phone.accountGeneration) {
      commentFocus.unfocus();
      _beginEntry();
    } else {
      final detail = phone.details[livePostId];
      if (detail != null && !identical(detail, _observedDetail)) {
        _detail = detail;
        _freshDetail = true;
      }
      _observedDetail = detail;
      final comments = phone.comments[livePostId];
      if (comments != null && !identical(comments, _observedComments)) {
        _comments = comments;
      }
      _observedComments = comments;
      if (_started) _loading = phone.busy.contains('comments:$livePostId');
    }
    setState(() {});
    _queueAlign();
  }

  @override
  void didUpdateWidget(covariant MiniPhoneCommentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_changed);
      phone.addListener(_changed);
    }
    if (oldWidget.postId != widget.postId ||
        oldWidget.store != widget.store ||
        (!oldWidget.active && widget.active)) {
      commentFocus.unfocus();
      _beginEntry();
    }
    if (!widget.active) _followBottom = _sendFollow = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncKeyboard();
  }

  @override
  void didChangeMetrics() {
    if (mounted) _syncKeyboard();
  }

  void _syncKeyboard() {
    final open = View.of(context).viewInsets.bottom > 0;
    if (open && !_keyboardOpen && commentFocus.hasFocus && widget.active) {
      _followBottom = true;
    }
    if (!open && _keyboardOpen && !_sending) _followBottom = false;
    _keyboardOpen = open;
    _queueAlign();
  }

  void _queueAlign() {
    if (_alignScheduled || !_followBottom) return;
    _alignScheduled = true;
    final entry = _entry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignScheduled = false;
      if (!mounted ||
          entry != _entry ||
          !widget.active ||
          !phone.phoneVisible ||
          !phone.foreground ||
          !_followBottom ||
          livePostId == null ||
          ((_comments == null || _loading || _sending) &&
              phone.postsController.outgoingComments(livePostId!).isEmpty) ||
          (!_sendFollow && (!_keyboardOpen || !commentFocus.hasFocus)) ||
          !commentsScroll.hasClients) {
        return;
      }
      final position = commentsScroll.position;
      if ((position.maxScrollExtent - position.pixels).abs() > 0.5) {
        commentsScroll.jumpTo(position.maxScrollExtent);
        // Sliver extents can change as the last rows are laid out.
        _queueAlign();
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
      _sendFollow = false;
      if (!_keyboardOpen) _followBottom = false;
    });
  }

  @override
  void dispose() {
    _entry++;
    WidgetsBinding.instance.removeObserver(this);
    phone.removeListener(_changed);
    commentFocus.dispose();
    commentInput.dispose();
    commentsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _queueAlign();
    return _liveComments();
  }

  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  Widget _panel(String title, Widget body, {Widget? footer}) =>
      miniPhonePanel(widget.header, body, footer: footer);
  Widget _input(
    TextEditingController controller,
    String hint, {
    int? limit = 500,
  }) => miniPhoneInput(
    controller,
    hint,
    limit: limit,
    focusNode: commentFocus,
    onChanged: () => _update(() {}),
  );
  Widget _liveCommentRow(
    PhonePerson author,
    String content, {
    String time = '',
    PhoneComment? replyTarget,
    String? replyToCharId,
    String? replyToName,
  }) => InkWell(
    onTap: replyTarget == null
        ? null
        : () => _update(
            () => replyToComment = replyToComment?.id == replyTarget.id
                ? null
                : replyTarget,
          ),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: miniPageInset,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: miniDivider, width: .5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          miniPhonePersonAvatar(author, 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author.name,
                        style: miniStyle(14, FontWeight.w600),
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          time,
                          style: miniStyle(12, FontWeight.w400, miniTertiary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    children: [
                      if (replyToName != null || replyToCharId != null)
                        TextSpan(
                          text:
                              '@${replyToName ?? phone.person(replyToCharId!).name} ',
                          style: miniStyle(14, FontWeight.w600, miniPink),
                        ),
                      TextSpan(text: content),
                    ],
                  ),
                  style: miniStyle(14),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _liveComments() {
    final id = livePostId;
    if (id == null) {
      return _panel(context.l10n.miniPhoneComments, const SizedBox.shrink());
    }
    final d = _detail;
    final post = _seed;
    final outgoing = phone.postsController.outgoingComments(id).toList();
    final baseCount =
        _comments?.length ?? (_freshDetail ? d?.commentCount : null);
    final count = baseCount == null
        ? null
        : baseCount +
              outgoing
                  .where((c) => _comments != null || !c.write.accepted)
                  .length;
    final likes = phone.postsController.likeState(
      id,
      count: d?.likeCount ?? _seedLikes ?? 0,
      liked: d?.isLiked ?? _seedLiked ?? false,
    );
    Future<void> refresh() async {
      await Future.wait([_refreshDetail(id), phone.refreshComments(id)]);
    }

    return _panel(
      context.l10n.miniPhoneComments,
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          _queueAlign();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if ((notification is ScrollStartNotification &&
                    notification.dragDetails != null) ||
                (notification is ScrollUpdateNotification &&
                    notification.dragDetails != null) ||
                notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
              _followBottom = _sendFollow = false;
            }
            return false;
          },
          child: GenesisRefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              controller: commentsScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (d != null || post != null)
                  MiniPhonePostContent(
                    phone: phone,
                    onOpenPost: widget.onOpenPost,
                    id: id,
                    author: d == null
                        ? post!.author
                        : PhonePerson(
                            d.charId,
                            d.name,
                            post?.author.id == d.charId &&
                                    post!.author.avatar.isNotEmpty
                                ? post.author.avatar
                                : phone.person(d.charId).avatar,
                          ),
                    text: d?.content ?? post!.text,
                    image: d?.image ?? post!.image,
                    time: post?.currentTime ?? '',
                    likeCount: likes.count,
                    isLiked: likes.liked,
                    commentCount: count,
                    detail: true,
                  ),
                if (count != null || _loading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      miniPageInset,
                      18,
                      miniPageInset,
                      8,
                    ),
                    child: _CommentCountHeader(count: count),
                  ),
                if (_comments == null && _loading)
                  const _CommentSkeleton()
                else if (_comments != null) ...[
                  if (_comments!.isEmpty && outgoing.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(miniPageInset),
                      child: Text(
                        context.l10n.miniPhoneFirstComment,
                        style: miniStyle(12, FontWeight.w400, miniSecondary),
                      ),
                    ),
                  for (final c in _comments!)
                    _liveCommentRow(
                      c.author,
                      c.text,
                      time: c.currentTime,
                      replyTarget: c,
                      replyToCharId: c.replyToCharId,
                    ),
                ],
                for (final c in outgoing)
                  KeyedSubtree(
                    key: ValueKey('mini-phone-outgoing-comment-${c.write.id}'),
                    child: _liveCommentRow(
                      c.author,
                      c.write.content,
                      replyToName: c.replyToAuthor?.name,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      footer: Container(
        padding: const EdgeInsets.fromLTRB(miniPageInset, 12, miniPageInset, 5),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: miniDivider, width: .5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              key: const ValueKey('mini-phone-comment-input'),
              children: [
                miniPhonePersonAvatar(_liveMe, 31),
                const SizedBox(width: 9),
                Expanded(
                  child: _input(
                    commentInput,
                    replyToComment == null
                        ? context.l10n.miniPhoneCommentHint
                        : context.l10n.miniPhoneReplyHint(
                            name: replyToComment!.author.name,
                          ),
                    limit: null,
                  ),
                ),
                const SizedBox(width: 8),
                miniPhoneSendButton(
                  commentInput.text.trim().isEmpty ||
                          phone.busy.contains('comment:$id')
                      ? null
                      : () async {
                          final pending = phone.pending['comment:$id'];
                          final retry = pending != null && !pending.rejected;
                          final text = retry
                              ? pending.content
                              : commentInput.text;
                          final target = retry
                              ? phone.comments[id]
                                    ?.where((c) => c.id == pending.replyTo)
                                    .firstOrNull
                              : replyToComment;
                          final entry = _entry;
                          _followBottom = _sendFollow = _sending = true;
                          _update(() {
                            if (commentInput.text == text) commentInput.clear();
                            replyToComment = null;
                          });
                          final ok = await phone.write(
                            'comment',
                            '$id',
                            text,
                            replyTo: retry ? pending.replyTo : target?.id,
                            retry: retry,
                          );
                          if (!mounted || entry != _entry) return;
                          _sending = false;
                          if (ok) {
                            if (phone.errors.containsKey('comments:$id')) {
                              _followBottom = _sendFollow = false;
                            } else {
                              _queueAlign();
                            }
                          } else {
                            _followBottom = _sendFollow = false;
                            _update(() {
                              if (commentInput.text.isEmpty) {
                                commentInput.text = text;
                                replyToComment = target;
                              }
                            });
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCountHeader extends StatelessWidget {
  const _CommentCountHeader({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: AlignmentDirectional.centerStart,
    children: [
      // Keep the real text metrics, including accessibility text scaling.
      Visibility(
        visible: count != null,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: Text(
          context.l10n.miniPhoneCommentCount(count: count ?? 0),
          style: miniStyle(14, FontWeight.w600),
        ),
      ),
      if (count == null)
        Container(
          width: 80,
          height: 14,
          decoration: BoxDecoration(
            color: miniLine,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}

/// Static placeholders mirror comment rows without implying a comment count.
class _CommentSkeleton extends StatelessWidget {
  const _CommentSkeleton();
  Widget _bone({double? width, required double height, double radius = 4}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: miniLine,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      key: const ValueKey('mini-phone-comments-skeleton'),
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: miniPageInset,
              vertical: 16,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: miniDivider, width: .5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bone(width: 36, height: 36, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: .35,
                        child: _bone(height: 14),
                      ),
                      const SizedBox(height: 9),
                      _bone(height: 14),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: .7,
                        child: _bone(height: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
