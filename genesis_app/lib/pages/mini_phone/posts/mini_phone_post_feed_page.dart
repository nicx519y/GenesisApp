import 'dart:async';
import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import 'mini_phone_post_feed.dart';

import 'mini_phone_post_content.dart';
import 'mini_phone_post_authors.dart';

class MiniPhonePostFeedPage extends StatefulWidget {
  const MiniPhonePostFeedPage({
    super.key,
    required this.store,
    required this.active,
    required this.header,
    required this.onCreate,
    required this.onOpenPost,
  });
  final MiniPhoneStore store;
  final bool active;
  final Widget header;
  final VoidCallback onCreate;
  final ValueChanged<int> onOpenPost;
  @override
  State<MiniPhonePostFeedPage> createState() => _MiniPhonePostFeedPageState();
}

class _MiniPhonePostFeedPageState extends State<MiniPhonePostFeedPage> {
  MiniPhoneStore get phone => widget.store;
  late final _lists = MiniPhoneListRequests(
    phone.requests,
    isActive: () => widget.active && phone.phoneVisible,
  );
  late Object _snapshot;
  Object _readSnapshot() {
    final me = phone.person(phone.uid ?? '', type: 1);
    return (
      phone.accountGeneration,
      phone.posts,
      phone.authors,
      phone.authorFilter,
      phone.foreground,
      phone.busy.contains('posts'),
      phone.errors['posts'],
      phone.hasMore['posts'],
      me.id,
      me.name,
      me.avatar,
      phone.postsController.interactionRevision,
    );
  }

  @override
  void initState() {
    super.initState();
    _snapshot = _readSnapshot();
    phone.addListener(_changed);
  }

  void _changed() {
    final next = _readSnapshot();
    if (_snapshot == next) return;
    _snapshot = next;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    phone.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _livePosts();
  Widget _livePosts() => miniPhonePanel(
    widget.header,
    _lists.build(
      'posts',
      () => phone.refreshPosts(next: true),
      GenesisRefreshIndicator(
        onRefresh: () => _lists.refresh('posts', phone.refreshPosts),
        child: MiniPhonePostFeed(
          posts: phone.posts,
          footer: const SizedBox.shrink(),
          resetKey: (phone.accountGeneration, phone.authorFilter),
          active: widget.active && phone.foreground,
          itemBuilder: _livePostCard,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(
              miniPageInset,
              4,
              miniPageInset,
              16,
            ),
            child: MiniPhonePostAuthors(
              authors: phone.authors,
              me: phone.person(phone.uid ?? '', type: 1),
              selectedId: phone.authorFilter,
              onCreate: widget.onCreate,
              onSelect: (id) {
                phone.authorFilter = id;
                unawaited(phone.refreshPosts());
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _livePostCard(PhonePost p) => MiniPhonePostContent(
    phone: phone,
    onOpenPost: widget.onOpenPost,
    id: p.id,
    author: p.author,
    text: p.text,
    image: p.image,
    time: p.currentTime,
    likeCount: phone.details[p.id]?.likeCount ?? p.likeCount,
    isLiked: phone.details[p.id]?.isLiked ?? p.isLiked,
    commentCount: phone.details[p.id]?.commentCount ?? p.commentCount,
    previews: p.commentsPreview,
  );
}
