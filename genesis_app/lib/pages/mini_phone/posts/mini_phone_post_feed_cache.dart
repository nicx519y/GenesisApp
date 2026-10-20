import 'package:flutter/foundation.dart';

import '../../../network/mini_phone/mini_phone_models.dart';

/// One author's loaded window, owned by the current World/account session.
class MiniPhonePostFeedCache {
  List<PhonePost> posts = const [];
  int? page;
  bool? hasMore;

  void reconcile(
    List<PhonePost> incoming, {
    required bool append,
    required int page,
    required bool hasMore,
  }) {
    final previous = {for (final post in posts) post.id: post};
    final merged = <int, PhonePost>{if (append) ...previous};
    for (final post in incoming) {
      final old = previous[post.id];
      merged[post.id] = old != null && _samePost(old, post) ? old : post;
    }
    final updated = merged.values.toList(growable: false);
    // Preserve both row identities and the list identity on a no-op response.
    if (!listEquals(posts, updated)) posts = updated;
    this.page = page;
    this.hasMore = hasMore;
  }
}

Object _person(PhonePerson p) => (p.id, p.name, p.avatar, p.type);

Object _comment(PhoneComment c) => (
  c.id,
  c.postId,
  c.type,
  _person(c.author),
  c.text,
  c.currentTime,
  c.publishedAt,
  c.replyToCommentId,
  c.replyToCharId,
);

bool _samePost(PhonePost a, PhonePost b) =>
    (
          a.id,
          a.worldId,
          _person(a.author),
          a.text,
          a.image,
          a.currentTime,
          a.publishedAt,
          a.likeCount,
          a.isLiked,
        ) ==
        (
          b.id,
          b.worldId,
          _person(b.author),
          b.text,
          b.image,
          b.currentTime,
          b.publishedAt,
          b.likeCount,
          b.isLiked,
        ) &&
    listEquals(
      a.comments.map(_comment).toList(),
      b.comments.map(_comment).toList(),
    );
