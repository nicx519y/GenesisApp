import 'dart:async';
import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';
import '../../../app/bootstrap/app_services_scope.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../ui/components/genesis_list_image.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../../../platform/native_image_picker.dart';
import '../../../utils/image_upload_processing.dart';
import '../../../utils/upload_image_byte_limit.dart';
import '../../../utils/genesis_image_resource.dart';
import '../session/mini_phone_session.dart';
import '../session/mini_phone_screen.dart';
import 'mini_phone_post_draft.dart';
import 'mini_phone_post_feed.dart';
import 'mini_phone_post_thumbnail.dart';

class MiniPhonePostsPage extends StatefulWidget {
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
  State<MiniPhonePostsPage> createState() => _MiniPhonePostsPageState();
}

class _MiniPhonePostsPageState extends State<MiniPhonePostsPage> {
  MiniPhoneStore get phone => widget.session.data!;
  MiniPhonePostDraft get postDraft => widget.session.postDraft!;
  int? get livePostId => widget.postId;
  PhoneComment? replyToComment;
  final commentInput = TextEditingController();
  final postInput = TextEditingController();
  final commentsScroll = ScrollController();
  late final _lists = MiniPhoneListRequests(phone);
  late int _generation;
  @override
  void initState() {
    super.initState();
    _generation = phone.accountGeneration;
    postInput.text = postDraft.text;
    phone.addListener(_changed);
    postDraft.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    if (_generation != phone.accountGeneration) {
      _generation = phone.accountGeneration;
      commentInput.clear();
      replyToComment = null;
    }
    if (postInput.text != postDraft.text) postInput.text = postDraft.text;
    setState(() {});
  }

  @override
  void didUpdateWidget(MiniPhonePostsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      commentInput.clear();
      replyToComment = null;
    }
  }

  @override
  void dispose() {
    phone.removeListener(_changed);
    postDraft.removeListener(_changed);
    commentInput.dispose();
    postInput.dispose();
    commentsScroll.dispose();
    super.dispose();
  }

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
  @override
  Widget build(BuildContext context) => switch (widget.screen) {
    MiniPhoneScreen.comments => _liveComments(),
    MiniPhoneScreen.create => _liveCreate(),
    _ => _livePosts(),
  };

  PhonePerson get _liveMe => phone.person(phone.uid ?? '', type: 1);

  Widget _livePosts() => _panel(
    'Posts',
    _lists.build(
      'posts',
      () => phone.refreshPosts(next: true),
      GenesisRefreshIndicator(
        onRefresh: () => _lists.refresh('posts', phone.refreshPosts),
        child: MiniPhonePostFeed(
          posts: phone.posts,
          footer: const SizedBox.shrink(),
          resetKey: (phone.accountGeneration, phone.authorFilter),
          active:
              widget.active &&
              widget.screen == MiniPhoneScreen.posts &&
              phone.foreground,
          itemBuilder: _livePostCard,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(
              miniPageInset,
              4,
              miniPageInset,
              16,
            ),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final authors = phone.authors.toList();
                final width = ((bounds.maxWidth - 12) / (authors.length + 2))
                    .clamp(64.0, double.infinity);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: width,
                        child: _authorShortcut(_liveMe, create: true),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: width,
                        child: miniPhoneAllAuthorsShortcut(
                          selected: phone.authorFilter == null,
                          onTap: () {
                            if (phone.authorFilter == null) return;
                            phone.authorFilter = null;
                            unawaited(phone.refreshPosts());
                          },
                        ),
                      ),
                      for (final person in authors)
                        SizedBox(width: width, child: _authorShortcut(person)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _authorShortcut(PhonePerson p, {bool create = false}) =>
      GestureDetector(
        key: ValueKey('mini-phone-post-author-${create ? 'create' : p.id}'),
        onTap: () {
          if (create) {
            widget.onCreate();
          } else {
            phone.authorFilter = phone.authorFilter == p.id ? null : p.id;
            unawaited(phone.refreshPosts());
          }
        },
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !create && phone.authorFilter == p.id
                          ? miniPink
                          : const Color(0x33FFFFFF),
                    ),
                  ),
                  child: miniPhonePersonAvatar(p, 54),
                ),
                if (create)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: miniRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: MiniIcon('plus', size: 11)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              create ? 'Create' : p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: miniStyle(12, FontWeight.w500),
            ),
          ],
        ),
      );
  Widget _liveImage(
    String url, {
    double maxHeight = 300,
    double maxWidth = 290,
  }) => GestureDetector(
    onTap: () => showGenesisImageViewer(context, imageUrls: [url]),
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
          child: GenesisListImage(
            imageUrl: url,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    ),
  );
  Widget _livePostCard(PhonePost p) => _livePostLayout(
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

  Widget _livePostLayout({
    required int id,
    required PhonePerson author,
    required String text,
    required String image,
    required String time,
    required int likeCount,
    required bool isLiked,
    required int commentCount,
    List<PhoneComment> previews = const [],
    bool detail = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: miniPageInset,
      vertical: 12,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: miniDivider, width: .5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        miniPhonePersonAvatar(author, 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(14, FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (text.isNotEmpty) Text(text, style: miniStyle(14)),
              if (image.isNotEmpty)
                if (detail)
                  _liveImage(image, maxWidth: 170, maxHeight: 180)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MiniPhonePostThumbnail(
                      imageUrl: image,
                      onTap: (preview, source) => showGenesisImageViewer(
                        context,
                        imageUrls: [image],
                        previewImageProviders: [preview],
                        source: source,
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    miniPhonePostAction(
                      'messages',
                      'Comments',
                      commentCount,
                      () => widget.onOpenPost(id),
                    ),
                    const SizedBox(width: 20),
                    miniPhonePostAction(
                      'heart',
                      'Like',
                      likeCount,
                      () => phone.setLiked(
                        id,
                        !(phone.likeTargets[id] ?? isLiked),
                      ),
                      selected: isLiked,
                    ),
                  ],
                ),
              ),
              if (!detail)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onOpenPost(id),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 6),
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in previews.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${c.author.name}  ',
                                    style: miniStyle(12, FontWeight.w600),
                                  ),
                                  if (c.replyToCharId != null)
                                    TextSpan(
                                      text:
                                          '@${phone.person(c.replyToCharId!).name} ',
                                      style: miniStyle(
                                        12,
                                        FontWeight.w600,
                                        miniPink,
                                      ),
                                    ),
                                  TextSpan(
                                    text: c.text,
                                    style: miniStyle(
                                      12,
                                      FontWeight.w400,
                                      miniSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          commentCount > 3
                              ? 'View all $commentCount comments'
                              : commentCount == 0
                              ? 'Be the first to comment'
                              : 'View comments',
                          style: miniStyle(12, FontWeight.w400, miniPink),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
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
                _livePostLayout(
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

  Future<void> _chooseLivePhoto() => postDraft.choose(() async {
    final files = await pickGenesisImageFiles(
      limit: 1,
      normalizeForUpload: true,
      allowGif: true,
    );
    if (files.isEmpty) return null;
    final file = files.first;
    return fitPreparedUploadImage(
      ProcessedUploadImage(
        bytes: await file.readAsBytes(),
        filename: imageFilename(file),
        contentType: file.mimeType ?? guessImageContentType(file.name),
      ),
    );
  });

  Future<void> _publishLivePost() async {
    final data = phone;
    final generation = data.accountGeneration;
    final ok = await postDraft.submit((photo) async {
      final api = AppServicesScope.read(context).api;
      final result = await api.v1.upload.image(
        bytes: photo.bytes,
        filename: photo.filename,
        contentType: photo.contentType,
      );
      return GenesisImageResourceRegistry.resolve(result).displayUrl;
    });
    if (!mounted ||
        widget.session.isDisposed ||
        generation != data.accountGeneration ||
        !ok) {
      return;
    }
    // Navigation remains available while sending; don't pull the user back.
    if (widget.active && widget.screen == MiniPhoneScreen.create) {
      data.authorFilter = null;
      widget.onPublished();
    }
  }

  Widget _liveCreate() => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: miniPageInset,
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onBack,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: miniWhite,
                  ),
                  child: Row(
                    children: [
                      const MiniIcon('back', size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Create post',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: miniPageTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              miniPhoneButton(
                'Post',
                postDraft.canSubmit ? _publishLivePost : null,
                isLoading: postDraft.submitting,
                showLoadingIndicator: true,
                primary: true,
              ),
              const SizedBox(width: 8),
              const SizedBox.square(dimension: 28),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(miniPageInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    miniPhonePersonAvatar(_liveMe, 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _liveMe.name,
                            style: miniStyle(14, FontWeight.w600),
                          ),
                          Text(
                            phone.worldName,
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: postInput,
                  readOnly: postDraft.locked,
                  minLines: 6,
                  maxLines: 10,
                  onChanged: (value) {
                    postDraft.setText(value);
                    _update(() {});
                  },
                  style: miniStyle(14),
                  decoration: InputDecoration(
                    hintText: 'What’s on your mind?',
                    hintStyle: miniStyle(14, FontWeight.w400, miniPlaceholder),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share a moment from your world.',
                        style: miniStyle(12, FontWeight.w400, miniSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Photo ',
                        style: miniStyle(14, FontWeight.w600),
                      ),
                      TextSpan(
                        text: '(Optional)',
                        style: miniStyle(12, FontWeight.w400, miniSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 132,
                      height: 176,
                      child: CustomPaint(
                        painter: MiniPhoneUploadBorder(),
                        child: InkWell(
                          onTap: postDraft.locked || postDraft.preparing
                              ? null
                              : _chooseLivePhoto,
                          borderRadius: BorderRadius.circular(13),
                          child: postDraft.photo != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.memory(
                                    postDraft.photo!.bytes,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.image_outlined),
                                    ),
                                  ),
                                )
                              : postDraft.uploadedUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: GenesisListImage(
                                    imageUrl: postDraft.uploadedUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const MiniIcon(
                                      'upload',
                                      size: 22,
                                      color: miniPink,
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      'Choose photo',
                                      style: miniStyle(
                                        12,
                                        FontWeight.w600,
                                        miniPink,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a photo to your post.',
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
                          if (postDraft.photo != null ||
                              postDraft.uploadedUrl != null) ...[
                            miniPhoneButton(
                              'Replace photo',
                              postDraft.locked || postDraft.preparing
                                  ? null
                                  : _chooseLivePhoto,
                            ),
                            miniPhoneButton(
                              'Remove photo',
                              postDraft.locked || postDraft.preparing
                                  ? null
                                  : postDraft.removePhoto,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
