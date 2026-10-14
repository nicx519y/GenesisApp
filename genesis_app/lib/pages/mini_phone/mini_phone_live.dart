part of 'mini_phone_page.dart';

extension _MiniPhoneLive on _MiniPhonePageState {
  MiniDemoPerson _livePersonPresentation(PhonePerson p) =>
      MiniDemoPerson(p.id, p.name, p.name, p.avatar, 'live', '', '', 0);
  void _loadLiveScreen(MiniPhoneScreen next) {
    final data = phone!;
    data.activeCharId = next == MiniPhoneScreen.chat ? liveContact?.id : null;
    data.activePostId = next == MiniPhoneScreen.comments ? livePostId : null;
    data.postsVisible = next == MiniPhoneScreen.posts;
    data.notificationsVisible = next == MiniPhoneScreen.notifications;
    data.albumVisible = next == MiniPhoneScreen.photos;
    switch (next) {
      case MiniPhoneScreen.home:
        data.scheduleRefresh();
      case MiniPhoneScreen.messages:
        unawaited(data.refreshSessions());
      case MiniPhoneScreen.chat:
        if (liveContact != null) {
          unawaited(data.refreshMessages(liveContact!.id));
        }
      case MiniPhoneScreen.posts:
        unawaited(data.refreshPosts(markRead: true));
      case MiniPhoneScreen.comments:
        if (livePostId != null) unawaited(data.refreshDetail(livePostId!));
      case MiniPhoneScreen.photos:
        unawaited(data.refreshAlbum());
      case MiniPhoneScreen.notifications:
        unawaited(data.refreshNotifications());
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
  Widget _liveStatus(
    String key,
    Future<dynamic> Function() retry, {
    bool empty = false,
  }) {
    final error = phone!.errors[key];
    if (phone!.busy.contains(key)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: GenesisLoadingIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(error, style: miniStyle(12, FontWeight.w400, miniSecondary)),
            TextButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (empty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nothing here yet.',
          style: miniStyle(14, FontWeight.w400, miniSecondary),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _more(String key, Future<dynamic> Function() next) =>
      phone!.hasMore[key] == true
      ? Center(
          child: TextButton(
            onPressed: phone!.busy.contains(key) ? null : next,
            child: const Text('Load more'),
          ),
        )
      : const SizedBox.shrink();
  Future<void> _selectContact() async {
    await phone!.refreshPeople();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: miniBackground,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            GenesisActionSheetHeader(
              title: 'New message',
              showClose: true,
              onClose: () => Navigator.pop(context),
            ),
            _liveStatus(
              'people',
              phone!.refreshPeople,
              empty: phone!.people.isEmpty,
            ),
            for (final p in phone!.contacts)
              ListTile(
                leading: _phoneAvatar(p, 40),
                title: Text(p.name, style: miniStyle()),
                onTap: () {
                  Navigator.pop(context);
                  _openLiveChat(p);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _liveMessages() => _panel(
    'Messages',
    GenesisRefreshIndicator(
      onRefresh: () async {
        await phone!.refreshSessions();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Unread'),
                  selected: phone!.unreadSessionsOnly,
                  onSelected: (v) {
                    phone!.unreadSessionsOnly = v;
                    unawaited(phone!.refreshSessions());
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selectContact,
                  child: const Text('New message'),
                ),
              ],
            ),
          ),
          for (final s in phone!.sessions)
            InkWell(
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
                            child: GenesisCountBadge(count: s.unreadCount),
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
                              Flexible(
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
                          Text(
                            '${s.lastMessage?.senderType == 'user' ? 'You: ' : ''}${s.lastMessage?.content ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
              ),
            ),
          _liveStatus(
            'sessions',
            phone!.refreshSessions,
            empty: phone!.sessions.isEmpty,
          ),
          _more('sessions', () => phone!.refreshSessions(next: true)),
        ],
      ),
    ),
  );
  Widget _livePosts() => _panel(
    'Posts',
    GenesisRefreshIndicator(
      onRefresh: () async {
        await phone!.refreshPosts();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 84 + MediaQuery.textScalerOf(context).scale(12) * 1.5,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _authorShortcut(null),
                for (final p in phone!.authors.values) _authorShortcut(p),
              ],
            ),
          ),
          if (phone!.authorFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () {
                  phone!.authorFilter = null;
                  unawaited(phone!.refreshPosts());
                },
                child: const Text('Show all posts'),
              ),
            ),
          for (final p in phone!.posts) _livePostCard(p),
          _liveStatus(
            'posts',
            phone!.refreshPosts,
            empty: phone!.posts.isEmpty,
          ),
          _liveStatus('readPosts', () => phone!.refreshPosts(markRead: true)),
          _more('posts', () => phone!.refreshPosts(next: true)),
        ],
      ),
    ),
  );
  Widget _authorShortcut(PhonePerson? p) => SizedBox(
    width: 78,
    child: InkWell(
      onTap: () {
        if (p == null) {
          _go(MiniPhoneScreen.create);
          return;
        }
        phone!.authorFilter = phone!.authorFilter?.key == p.key ? null : p;
        unawaited(phone!.refreshPosts());
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: p != null && phone!.authorFilter?.key == p.key
                    ? miniPink
                    : const Color(0x33FFFFFF),
              ),
            ),
            child: p == null
                ? const SizedBox.square(
                    dimension: 54,
                    child: Icon(Icons.add, color: miniWhite),
                  )
                : _phoneAvatar(p, 54),
          ),
          const SizedBox(height: 7),
          Text(
            p?.name ?? 'Create',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: miniStyle(12, FontWeight.w500),
          ),
        ],
      ),
    ),
  );
  Widget _liveImage(String url, {double maxHeight = 300}) => GestureDetector(
    onTap: () => showGenesisImageViewer(context, imageUrls: [url]),
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 290),
          child: GenesisListImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    ),
  );
  Widget _livePostCard(PhonePost p) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: miniDivider, width: .5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _phoneAvatar(p.author, 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.author.name,
                      style: miniStyle(14, FontWeight.w600),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      p.currentTime,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(p.text, style: miniStyle(14)),
              if (p.image.isNotEmpty) _liveImage(p.image),
              Row(
                children: [
                  _postAction(
                    'messages',
                    'Comments',
                    p.commentCount,
                    () => _openLivePost(p.id),
                  ),
                  const SizedBox(width: 20),
                  _postAction(
                    'heart',
                    'Like',
                    p.likeCount,
                    () => phone!.setLiked(
                      p.id,
                      !(phone!.likeTargets[p.id] ?? p.isLiked),
                    ),
                    selected: p.isLiked,
                  ),
                ],
              ),
              _liveStatus('like:${p.id}', () => phone!.refreshDetail(p.id)),
              InkWell(
                onTap: () => _openLivePost(p.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in p.commentsPreview.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${c.author.name}  ',
                                style: miniStyle(12, FontWeight.w600),
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
                    Text(
                      p.commentCount == 0
                          ? 'Be the first to comment'
                          : 'View all ${p.commentCount} comments',
                      style: miniStyle(12, FontWeight.w400, miniPink),
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
  Future<void> _chooseReply(int id) async {
    await phone!.refreshComments(id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: miniBackground,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: phone!,
        builder: (_, _) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .65,
            child: Column(
              children: [
                GenesisActionSheetHeader(
                  title: 'Reply to a comment',
                  showClose: true,
                  onClose: () => Navigator.pop(sheetContext),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final c in phone!.comments[id] ?? <PhoneComment>[])
                        ListTile(
                          title: Text(
                            c.author.name,
                            style: miniStyle(14, FontWeight.w600),
                          ),
                          subtitle: Text(c.text, style: miniStyle()),
                          onTap: () {
                            _update(() => replyToComment = c);
                            Navigator.pop(sheetContext);
                          },
                        ),
                      _liveStatus(
                        'comments:$id',
                        () => phone!.refreshComments(id),
                      ),
                      _more(
                        'comments:$id',
                        () => phone!.refreshComments(id, next: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveComments() {
    final id = livePostId;
    if (id == null) return _panel('Comments', const SizedBox.shrink());
    final d = phone!.details[id];
    return _panel(
      'Comments',
      GenesisRefreshIndicator(
        onRefresh: () async {
          await phone!.refreshDetail(id);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (d != null) ...[
              Row(
                children: [
                  _phoneAvatar(phone!.person(d.charId), 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(d.name, style: miniStyle(14, FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(d.content, style: miniStyle()),
              if (d.image.isNotEmpty) _liveImage(d.image, maxHeight: 180),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _postAction(
                    'heart',
                    'Like',
                    d.likeCount,
                    () => phone!.setLiked(
                      id,
                      !(phone!.likeTargets[id] ?? d.isLiked),
                    ),
                    selected: d.isLiked,
                  ),
                  TextButton(
                    onPressed: () => _chooseReply(id),
                    child: const Text('Reply to a comment'),
                  ),
                ],
              ),
              Text(
                '${d.commentCount} comments',
                style: miniStyle(14, FontWeight.w600),
              ),
              for (final c in d.comments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _phoneAvatar(phone!.person(c.charId), 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: miniStyle(14, FontWeight.w600)),
                            const SizedBox(height: 5),
                            Text(c.content, style: miniStyle()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            _liveStatus('detail:$id', () => phone!.refreshDetail(id)),
            _liveStatus('like:$id', () => phone!.refreshDetail(id)),
            _writeStatus('comment:$id'),
          ],
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyToComment != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reply to ${replyToComment!.author.name}',
                      style: miniStyle(12),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _update(() => replyToComment = null),
                    icon: const Icon(Icons.close, color: miniWhite),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: _input(commentInput, 'Write a comment…', limit: null),
                ),
                const SizedBox(width: 8),
                _sendButton(
                  commentInput.text.trim().isEmpty ||
                          phone!.unresolved('comment:$id') ||
                          phone!.busy.contains('comment:$id')
                      ? null
                      : () async {
                          final text = commentInput.text;
                          final ok = await phone!.write(
                            'comment',
                            '$id',
                            text,
                            replyTo: replyToComment?.id,
                          );
                          if (mounted && ok) {
                            _update(() {
                              if (commentInput.text == text) {
                                commentInput.clear();
                              }
                              replyToComment = null;
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

  Widget _writeStatus(String key) {
    final w = phone!.pending[key];
    final error = phone!.errors[key];
    if (w == null && error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            error ?? 'Awaiting confirmation…',
            style: miniStyle(12, FontWeight.w400, miniSecondary),
          ),
          if (w != null && !phone!.busy.contains(key))
            TextButton(
              onPressed: () async {
                final ok = await phone!.write(
                  w.kind,
                  w.target,
                  w.content,
                  retry: true,
                );
                if (!mounted || !ok) return;
                if (w.kind == 'post') {
                  if (postInput.text == w.content) postInput.clear();
                  selectedPostPhoto = null;
                  _go(MiniPhoneScreen.posts);
                }
                if (w.kind == 'comment' && commentInput.text == w.content) {
                  commentInput.clear();
                }
              },
              child: const Text('Retry same request'),
            ),
        ],
      ),
    );
  }

  Widget _liveCreate() => _panel(
    'Create post',
    ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(phone!.worldName, style: miniStyle(14, FontWeight.w600)),
        TextField(
          controller: postInput,
          minLines: 6,
          maxLines: 10,
          onChanged: (_) => _changed(),
          style: miniStyle(),
          decoration: InputDecoration(
            hintText: 'What’s on your mind?',
            hintStyle: miniStyle(14, FontWeight.w400, miniPlaceholder),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 20),
        Text('Photo (Optional)', style: miniStyle(14, FontWeight.w600)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            selectingPostPhoto = true;
            _go(MiniPhoneScreen.photos);
          },
          child: SizedBox(
            width: 132,
            height: 176,
            child: selectedPostPhoto == null
                ? const Center(child: Text('Choose from Photos'))
                : GenesisListImage(
                    imageUrl: selectedPostPhoto!.image,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
        if (selectedPostPhoto != null)
          TextButton(
            onPressed: () => _update(() => selectedPostPhoto = null),
            child: const Text('Remove photo'),
          ),
        _writeStatus('post:new'),
      ],
    ),
    footer: Padding(
      padding: const EdgeInsets.all(16),
      child: _button(
        'Post',
        postInput.text.trim().isEmpty ||
                phone!.unresolved('post:new') ||
                phone!.busy.contains('post:new')
            ? null
            : () async {
                final text = postInput.text;
                final ok = await phone!.write(
                  'post',
                  'new',
                  text,
                  image: selectedPostPhoto?.image,
                );
                if (!mounted || !ok) return;
                if (postInput.text == text) postInput.clear();
                selectedPostPhoto = null;
                phone!.authorFilter = null;
                _go(MiniPhoneScreen.posts);
              },
        primary: true,
        isLoading: phone!.busy.contains('post:new'),
      ),
    ),
  );
  Widget _livePhotos() => _panel(
    selectingPostPhoto ? 'Choose photo' : 'Photos',
    GenesisRefreshIndicator(
      onRefresh: () async {
        await phone!.refreshAlbum();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final a = phone!.album[index];
              return InkWell(
                onTap: a.image.isEmpty
                    ? null
                    : () {
                        if (selectingPostPhoto) {
                          selectedPostPhoto = a;
                          selectingPostPhoto = false;
                          _go(MiniPhoneScreen.create);
                        } else {
                          showGenesisImageViewer(
                            context,
                            imageUrls: phone!.album
                                .map((e) => e.image)
                                .toList(),
                            initialIndex: index,
                          );
                        }
                      },
                child: GenesisListImage(
                  imageUrl: a.thumbnail.isEmpty ? a.image : a.thumbnail,
                  borderRadius: BorderRadius.zero,
                  fit: BoxFit.cover,
                  placeholder: IconButton(
                    tooltip: 'Refresh photo',
                    onPressed: phone!.refreshAlbum,
                    icon: const Icon(Icons.refresh, color: miniWhite),
                  ),
                ),
              );
            }, childCount: phone!.album.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
          ),
          SliverToBoxAdapter(
            child: _liveStatus(
              'album',
              phone!.refreshAlbum,
              empty: phone!.album.isEmpty,
            ),
          ),
          SliverToBoxAdapter(
            child: _more('album', () => phone!.refreshAlbum(next: true)),
          ),
        ],
      ),
    ),
  );
  String _notificationText(PhoneNotification n) => switch (n.eventType) {
    'post' => 'Published a post',
    'like' => 'Liked a post',
    'comment' => 'Commented on a post',
    'reply' => 'Replied to a comment',
    _ => 'Post activity',
  };
  Widget _liveNotifications() => _panel(
    'Post notifications',
    Column(
      children: [
        SwitchListTile(
          title: Text('Unread only', style: miniStyle()),
          value: phone!.unreadNotificationsOnly,
          onChanged: (value) {
            phone!.unreadNotificationsOnly = value;
            unawaited(phone!.refreshNotifications());
          },
        ),
        Expanded(
          child: ListView(
            children: [
              for (final n
                  in phone!.notifications?.list ?? <PhoneNotification>[])
                ListTile(
                  leading: _phoneAvatar(
                    phone!.person(n.actorId, type: n.actorType),
                    40,
                  ),
                  title: Text(
                    phone!.person(n.actorId, type: n.actorType).name,
                    style: miniStyle(14, FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_notificationText(n)} · ${n.currentTime}',
                    style: miniStyle(12, FontWeight.w400, miniSecondary),
                  ),
                  trailing: n.readAt == null
                      ? const Icon(Icons.circle, size: 6, color: miniPink)
                      : null,
                  onTap: () => _openLivePost(n.postId),
                ),
              _liveStatus(
                'notifications',
                phone!.refreshNotifications,
                empty: phone!.notifications?.list.isEmpty ?? true,
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed:
                  (phone!.notifications?.pn ?? 1) <= 1 ||
                      phone!.busy.contains('notifications')
                  ? null
                  : () => phone!.refreshNotifications(
                      pn: phone!.notifications!.pn - 1,
                    ),
              child: const Text('Previous'),
            ),
            Text('${phone!.notifications?.pn ?? 1}', style: miniStyle()),
            TextButton(
              onPressed:
                  phone!.notifications?.hasMore != true ||
                      phone!.busy.contains('notifications')
                  ? null
                  : () => phone!.refreshNotifications(
                      pn: phone!.notifications!.pn + 1,
                    ),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}
