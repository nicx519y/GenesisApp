part of 'mini_phone_page.dart';

extension _MiniPhoneLive on _MiniPhonePageState {
  MiniDemoPerson _livePersonPresentation(PhonePerson p) =>
      MiniDemoPerson(p.id, p.name, p.name, p.avatar, 'live', '', '', 0);
  void _loadLiveScreen(MiniPhoneScreen next) {
    final data = phone!;
    data.activeCharId = next == MiniPhoneScreen.chat ? liveContact?.id : null;
    data.activePostId = next == MiniPhoneScreen.comments ? livePostId : null;
    data.postsVisible = next == MiniPhoneScreen.posts;
    data.notificationsVisible = false;
    data.albumVisible = next == MiniPhoneScreen.photos;
    switch (next) {
      case MiniPhoneScreen.home:
        data.scheduleRefresh(recoverChats: false);
      case MiniPhoneScreen.messages:
        data.unreadSessionsOnly = false;
        unawaited(data.refreshSessions());
        unawaited(data.refreshPeople());
      case MiniPhoneScreen.chat:
        // The chat owns its initial history request.
        break;
      case MiniPhoneScreen.posts:
        unawaited(data.refreshPosts(markRead: true));
      case MiniPhoneScreen.comments:
        if (livePostId != null) {
          unawaited(data.refreshDetail(livePostId!));
          unawaited(data.refreshComments(livePostId!));
        }
      case MiniPhoneScreen.photos:
        unawaited(data.refreshAlbum());
      default:
        break;
    }
  }

  void _openLiveChat(PhonePerson p) {
    liveContact = p;
    _go(MiniPhoneScreen.chat);
  }

  void _openLivePost(int id) {
    livePostId = id;
    replyToComment = null;
    commentInput.clear();
    _go(MiniPhoneScreen.comments);
  }

  Widget _phoneAvatar(PhonePerson p, double size, {double? radius}) =>
      p.type == 2
      ? GenesisCharacterAvatar(
          url: p.avatar,
          name: p.name,
          size: size,
          borderRadius: radius ?? size / 2,
        )
      : GenesisAvatar(
          url: p.avatar,
          name: p.name,
          size: size,
          borderRadius: radius ?? size / 2,
        );
  Map<String, String> get _visiblePhoneErrors {
    final data = phone;
    final errors = <String, String>{};
    if (_session.isDisposed ||
        data != null && (!data.phoneVisible || !data.foreground)) {
      return errors;
    }
    final keys = [
      'cache',
      'journal',
      'identity',
      ...switch (screen) {
        MiniPhoneScreen.home => ['home', 'unread', 'people', 'postSummary'],
        MiniPhoneScreen.messages => ['sessions', 'people'],
        MiniPhoneScreen.posts => [
          'posts',
          'postAuthors',
          'postSummary',
          'readPosts',
          for (final p in data?.posts ?? <PhonePost>[]) 'like:${p.id}',
        ],
        MiniPhoneScreen.comments => [
          'detail:$livePostId',
          'comments:$livePostId',
          'comment:$livePostId',
          'like:$livePostId',
        ],
        MiniPhoneScreen.create => ['post:new'],
        MiniPhoneScreen.photos => ['album'],
        _ => <String>[],
      },
    ];
    if (data != null) {
      // Wait for the two Messages requests so a shared failure is shown once.
      final messagesLoading =
          screen == MiniPhoneScreen.messages &&
          (data.busy.contains('sessions') || data.busy.contains('people'));
      if (!messagesLoading) {
        for (final key in keys) {
          final message = data.errors[key];
          if (message != null && !data.busy.contains(key)) {
            errors['${screen.name}:$key'] = message;
          }
        }
      }
    }
    if (phone != null &&
        screen == MiniPhoneScreen.create &&
        postDraft.error != null) {
      errors['post-photo'] = postDraft.error!;
    }
    if (screen == MiniPhoneScreen.settings &&
        !wallpaper.loading &&
        wallpaper.loadError != null) {
      errors['wallpaper'] = wallpaper.loadError!;
    }
    return errors;
  }

  void _notifyPhoneErrors() {
    final current = _visiblePhoneErrors;
    _shownPhoneErrors.removeWhere((key, value) => current[key] != value);
    if (current.isEmpty || _phoneErrorToastScheduled) return;
    _phoneErrorToastScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneErrorToastScheduled = false;
      if (!mounted || _session.isDisposed) return;
      final errors = _visiblePhoneErrors;
      final shown = _shownPhoneErrors.values.toSet();
      final fresh = errors.entries
          .where(
            (entry) =>
                _shownPhoneErrors[entry.key] != entry.value &&
                !shown.contains(entry.value),
          )
          .map((entry) => entry.value)
          .toSet();
      _shownPhoneErrors.addAll(errors);
      if (fresh.isNotEmpty) showGenesisToast(context, fresh.join('\n'));
    });
  }

  Future<void> _refreshPhoneList(
    String key,
    Future<dynamic> Function() load,
  ) async {
    _update(() => _refreshingPhoneLists.add(key));
    try {
      await load();
    } finally {
      _update(() => _refreshingPhoneLists.remove(key));
    }
  }

  Widget _pagedPhoneList(
    String key,
    Future<dynamic> Function() next,
    Widget child,
  ) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      if (notification.depth == 0 &&
          notification.metrics.axis == Axis.vertical &&
          notification.metrics.extentAfter < 160 &&
          ((notification is ScrollUpdateNotification &&
                  (notification.scrollDelta ?? 0) > 0) ||
              (notification is OverscrollNotification &&
                  notification.overscroll > 0)) &&
          phone!.hasMore[key] == true &&
          !phone!.busy.contains(key) &&
          !phone!.errors.containsKey(key) &&
          !_refreshingPhoneLists.contains(key)) {
        unawaited(next());
      }
      return false;
    },
    child: child,
  );

  Widget _liveMessages() => _panel(
    'Messages',
    _pagedPhoneList(
      'sessions',
      () => phone!.refreshSessions(next: true),
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final s in phone!.conversations)
            InkWell(
              key: ValueKey('mini-phone-conversation-${s.person.id}'),
              onTap: () => _openLiveChat(s.person),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _phoneAvatar(s.person, 48, radius: 8),
                        if (s.unreadCount > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: MiniBadge(s.unreadCount),
                          ),
                      ],
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.person.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(14, FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 112,
                                ),
                                child: Text(
                                  s.lastMessage?.currentTime ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(
                                    11,
                                    FontWeight.w400,
                                    miniTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 60),
                            child: Text(
                              '${s.lastMessage?.senderId == phone!.uid ? 'You: ' : ''}${s.lastMessage?.content ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: miniStyle(
                                12,
                                FontWeight.w400,
                                miniSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  PhonePerson get _liveMe => phone!.person(phone!.uid ?? '', type: 1);

  Widget _livePosts() => _panel(
    'Posts',
    _pagedPhoneList(
      'posts',
      () => phone!.refreshPosts(next: true),
      GenesisRefreshIndicator(
        onRefresh: () => _refreshPhoneList('posts', phone!.refreshPosts),
        child: MiniPhonePostFeed(
          posts: phone!.posts,
          footer: const SizedBox.shrink(),
          resetKey: (phone!.accountGeneration, phone!.authorFilter),
          active: screen == MiniPhoneScreen.posts && phone!.foreground,
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
                final authors = phone!.authors.toList();
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
                        child: _allAuthorsShortcut(
                          selected: phone!.authorFilter == null,
                          onTap: () {
                            if (phone!.authorFilter == null) return;
                            phone!.authorFilter = null;
                            unawaited(phone!.refreshPosts());
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
            _go(MiniPhoneScreen.create);
          } else {
            phone!.authorFilter = phone!.authorFilter == p.id ? null : p.id;
            unawaited(phone!.refreshPosts());
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
                      color: !create && phone!.authorFilter == p.id
                          ? miniPink
                          : const Color(0x33FFFFFF),
                    ),
                  ),
                  child: _phoneAvatar(p, 54),
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
    likeCount: phone!.details[p.id]?.likeCount ?? p.likeCount,
    isLiked: phone!.details[p.id]?.isLiked ?? p.isLiked,
    commentCount: phone!.details[p.id]?.commentCount ?? p.commentCount,
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
        _phoneAvatar(author, 40),
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
                    _postAction(
                      'messages',
                      'Comments',
                      commentCount,
                      () => _openLivePost(id),
                    ),
                    const SizedBox(width: 20),
                    _postAction(
                      'heart',
                      'Like',
                      likeCount,
                      () => phone!.setLiked(
                        id,
                        !(phone!.likeTargets[id] ?? isLiked),
                      ),
                      selected: isLiked,
                    ),
                  ],
                ),
              ),
              if (!detail)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openLivePost(id),
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
                                          '@${phone!.person(c.replyToCharId!).name} ',
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
          _phoneAvatar(author, 36),
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
                          text: '@${phone!.person(replyToCharId).name} ',
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
    final d = phone!.details[id];
    final comments = phone!.comments[id] ?? <PhoneComment>[];
    final post = phone!.posts.where((p) => p.id == id).firstOrNull;
    Future<void> refresh() async {
      await Future.wait([phone!.refreshDetail(id), phone!.refreshComments(id)]);
    }

    return _panel(
      'Comments',
      _pagedPhoneList(
        'comments:$id',
        () => phone!.refreshComments(id, next: true),
        GenesisRefreshIndicator(
          onRefresh: () => _refreshPhoneList('detail:$id', refresh),
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
                    phone!.person(d.charId).avatar,
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
                        phone!.person(c.charId).avatar,
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
                _phoneAvatar(_liveMe, 31),
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
                _sendButton(
                  commentInput.text.trim().isEmpty ||
                          phone!.busy.contains('comment:$id')
                      ? null
                      : () async {
                          final pending = phone!.pending['comment:$id'];
                          final retry = pending != null && !pending.rejected;
                          final text = retry
                              ? pending.content
                              : commentInput.text;
                          final ok = await phone!.write(
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
    final data = phone!;
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
        _session.isDisposed ||
        generation != data.accountGeneration ||
        !ok) {
      return;
    }
    // Navigation remains available while sending; don't pull the user back.
    if (screen == MiniPhoneScreen.create) {
      data.authorFilter = null;
      _go(MiniPhoneScreen.posts);
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
                  onPressed: _back,
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
              _button(
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
                    _phoneAvatar(_liveMe, 40),
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
                            phone!.worldName,
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
                        painter: _MiniUploadBorder(),
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
                            _button(
                              'Replace photo',
                              postDraft.locked || postDraft.preparing
                                  ? null
                                  : _chooseLivePhoto,
                            ),
                            _button(
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
  Widget _livePhotos() => _panel(
    'Photos',
    _pagedPhoneList(
      'album',
      () => phone!.refreshAlbum(next: true),
      GenesisRefreshIndicator(
        onRefresh: () => _refreshPhoneList('album', phone!.refreshAlbum),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _livePhotoTile(phone!.album[index]),
                childCount: phone!.album.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _livePhotoTile(PhoneAlbumAsset asset) => LayoutBuilder(
    builder: (context, bounds) {
      final thumbnail = asset.image.trim().isEmpty
          ? asset.thumbnail
          : asset.image;
      final preview = miniPhonePhotoThumbnailProvider(
        thumbnail,
        width: bounds.maxWidth,
        height: bounds.maxHeight,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        fit: BoxFit.cover,
      );
      final image = GenesisStaticNetworkImage(
        imageUrl: preview.imageUrl,
        fit: BoxFit.cover,
        placeholder: (_) => const ColoredBox(color: Color(0x1FFFFFFF)),
        errorWidget: (_, _) => const ColoredBox(color: Color(0x1FFFFFFF)),
      );
      if (asset.image.trim().isEmpty) return image;
      return GenesisImageViewerSourceAnchor(
        key: ValueKey('mini-phone-album-${asset.id}'),
        previewImageProvider: preview,
        fit: BoxFit.cover,
        onTap: (source) {
          final photos = phone!.album
              .where((a) => a.image.trim().isNotEmpty)
              .toList();
          final initialIndex = photos.indexWhere((a) => a.id == asset.id);
          if (initialIndex < 0) return;
          showGenesisImageViewer(
            context,
            imageUrls: [for (final photo in photos) photo.image],
            previewImageProviders: [
              for (final photo in photos)
                miniPhonePhotoThumbnailProvider(
                  photo.image,
                  width: bounds.maxWidth,
                  height: bounds.maxHeight,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  fit: BoxFit.cover,
                ),
            ],
            initialIndex: initialIndex,
            source: source,
          );
        },
        child: image,
      );
    },
  );

  String _notificationText(PhoneNotification n) => switch (n.eventType) {
    'post' => 'Published a post',
    'like' => 'Liked a post',
    'comment' => 'Commented on a post',
    'reply' => 'Replied to a comment',
    _ => 'Post activity',
  };
}
