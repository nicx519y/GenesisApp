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
  final _cards =
      <int, ({PhonePost post, int likes, bool liked, Widget child})>{};
  Object _readSnapshot() {
    final me = phone.person(phone.uid ?? '', type: 1);
    return (
      phone.accountGeneration,
      phone.posts,
      phone.authors,
      phone.authorFilter,
      phone.foreground,
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
  Widget _livePosts() {
    final ids = phone.posts.map((post) => post.id).toSet();
    _cards.removeWhere((id, _) => !ids.contains(id));
    return miniPhonePanel(
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
                  if (phone.authorFilter != id) {
                    phone.analytics.event(
                      'post_filter',
                      target: id ?? 'all',
                      stage: 'select',
                      data: phone.analytics.context('posts'),
                    );
                  }
                  phone.authorFilter = id;
                  unawaited(phone.refreshPosts());
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _livePostCard(PhonePost p) {
    final state = phone.postsController.likeState(
      p.id,
      count: p.likeCount,
      liked: p.isLiked,
    );
    final likes = state.count;
    final liked = state.liked;
    final cached = _cards[p.id];
    if (cached != null &&
        identical(cached.post, p) &&
        cached.likes == likes &&
        cached.liked == liked) {
      return cached.child;
    }
    final child = MiniPhonePostContent(
      phone: phone,
      onOpenPost: (id) => widget.onOpenPost(id),
      id: p.id,
      author: p.author,
      text: p.text,
      image: p.image,
      time: p.currentTime,
      likeCount: likes,
      isLiked: liked,
      previews: p.comments,
    );
    _cards[p.id] = (post: p, likes: likes, liked: liked, child: child);
    return child;
  }
}
