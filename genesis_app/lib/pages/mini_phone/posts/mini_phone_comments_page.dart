import 'dart:async';
import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';
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
  });
  final MiniPhoneStore store;
  final int? postId;
  final bool active;
  final Widget header;
  final ValueChanged<int> onOpenPost;
  @override
  State<MiniPhoneCommentsPage> createState() => _MiniPhoneCommentsPageState();
}

class _MiniPhoneCommentsPageState extends State<MiniPhoneCommentsPage> {
  MiniPhoneStore get phone => widget.store;
  int? get livePostId => widget.postId;
  PhonePerson get _liveMe => phone.person(phone.uid ?? '', type: 1);
  PhoneComment? replyToComment;
  final commentInput = TextEditingController();
  final commentsScroll = ScrollController();
  late final _lists = MiniPhoneListRequests(
    phone.requests,
    isActive: () => widget.active && phone.phoneVisible,
  );
  late int _generation;
  Object? _snapshot;
  Object _readSnapshot() => (
    phone.accountGeneration,
    phone.details[livePostId],
    phone.comments[livePostId],
    phone.posts,
    phone.authors,
    phone.likeTargets[livePostId],
    phone.busy.contains('comment:$livePostId'),
    phone.busy.contains('comments:$livePostId'),
    phone.errors['comments:$livePostId'],
    (_liveMe.id, _liveMe.name, _liveMe.avatar),
  );
  @override
  void initState() {
    super.initState();
    _generation = phone.accountGeneration;
    _snapshot = _readSnapshot();
    phone.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    final next = _readSnapshot();
    if (next == _snapshot) return;
    _snapshot = next;
    if (_generation != phone.accountGeneration) {
      _generation = phone.accountGeneration;
      commentInput.clear();
      replyToComment = null;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant MiniPhoneCommentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      commentInput.clear();
      replyToComment = null;
    }
  }

  @override
  void dispose() {
    phone.removeListener(_changed);
    commentInput.dispose();
    commentsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _liveComments();
  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  void _scrollToEnd(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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
    onChanged: () => _update(() {}),
  );
  Widget _liveCommentRow(
    PhonePerson author,
    String content, {
    String time = '',
    PhoneComment? replyTarget,
    String? replyToCharId,
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
                      if (replyToCharId != null)
                        TextSpan(
                          text: '@${phone.person(replyToCharId).name} ',
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
    if (id == null) return _panel('Comments', const SizedBox.shrink());
    final d = phone.details[id];
    final comments = phone.comments[id] ?? <PhoneComment>[];
    final post = phone.posts.where((p) => p.id == id).firstOrNull;
    Future<void> refresh() async {
      await Future.wait([phone.refreshDetail(id), phone.refreshComments(id)]);
    }

    return _panel(
      'Comments',
      _lists.build(
        'comments:$id',
        () => phone.refreshComments(id, next: true),
        GenesisRefreshIndicator(
          onRefresh: () => _lists.refresh('detail:$id', refresh),
          child: ListView(
            controller: commentsScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (d != null) ...[
                MiniPhonePostContent(
                  phone: phone,
                  onOpenPost: widget.onOpenPost,
                  id: id,
                  author: PhonePerson(
                    d.charId,
                    d.name,
                    phone.person(d.charId).avatar,
                  ),
                  text: d.content,
                  image: d.image,
                  time: post?.currentTime ?? '',
                  likeCount: d.likeCount,
                  isLiked: d.isLiked,
                  commentCount: d.commentCount,
                  detail: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    miniPageInset,
                    18,
                    miniPageInset,
                    8,
                  ),
                  child: Text(
                    '${d.commentCount} comments',
                    style: miniStyle(14, FontWeight.w600),
                  ),
                ),
                if (d.commentCount == 0)
                  Padding(
                    padding: const EdgeInsets.all(miniPageInset),
                    child: Text(
                      'Be the first to share your thoughts.',
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                if (comments.isNotEmpty)
                  for (final c in comments)
                    _liveCommentRow(
                      c.author,
                      c.text,
                      time: c.currentTime,
                      replyTarget: c,
                      replyToCharId: c.replyToCharId,
                    )
                else
                  for (final c in d.comments)
                    _liveCommentRow(
                      PhonePerson(
                        c.charId,
                        c.name,
                        phone.person(c.charId).avatar,
                      ),
                      c.content,
                    ),
              ],
            ],
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
                        ? 'Write a comment…'
                        : 'Reply to ${replyToComment!.author.name}…',
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
                          final ok = await phone.write(
                            'comment',
                            '$id',
                            text,
                            replyTo: replyToComment?.id,
                            retry: retry,
                          );
                          if (mounted && ok) {
                            _update(() {
                              if (commentInput.text == text) {
                                commentInput.clear();
                              }
                              replyToComment = null;
                            });
                            _scrollToEnd(commentsScroll);
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
