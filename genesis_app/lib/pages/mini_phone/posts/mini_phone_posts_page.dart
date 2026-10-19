import 'package:flutter/material.dart';
import '../session/mini_phone_session.dart';
import '../session/mini_phone_screen.dart';
import 'mini_phone_create_post_page.dart';
import 'mini_phone_comments_page.dart';
import 'mini_phone_post_feed_page.dart';

class MiniPhonePostsPage extends StatelessWidget {
  const MiniPhonePostsPage({
    super.key,
    required this.session,
    required this.screen,
    required this.active,
    required this.header,
    this.postId,
    required this.onBack,
    required this.onCreate,
    required this.onPublished,
    required this.onOpenPost,
  });
  final MiniPhoneSession session;
  final MiniPhoneScreen screen;
  final bool active;
  final Widget header;
  final int? postId;
  final VoidCallback onBack, onCreate, onPublished;
  final ValueChanged<int> onOpenPost;
  @override
  Widget build(BuildContext context) => switch (screen) {
    MiniPhoneScreen.create => MiniPhoneCreatePostPage(
      store: session.data!,
      draft: session.postDraft!,
      active: active,
      header: header,
      onPublished: onPublished,
    ),
    MiniPhoneScreen.comments => MiniPhoneCommentsPage(
      store: session.data!,
      postId: postId,
      active: active,
      header: header,
      onOpenPost: onOpenPost,
    ),
    _ => MiniPhonePostFeedPage(
      store: session.data!,
      active: active,
      header: header,
      onCreate: onCreate,
      onOpenPost: onOpenPost,
    ),
  };
}
