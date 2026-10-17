part of 'mini_phone_preview.dart';

extension _MiniPhonePosts on _MiniPhonePreviewState {
  Widget _posts() => _panel(
    'Posts',
    ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            miniPageInset,
            4,
            miniPageInset,
            16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _personShortcut(miniDemoMe, create: true),
              const SizedBox(width: 12),
              Expanded(
                child: miniPhoneAllAuthorsShortcut(
                  selected: authorFilter == null,
                  onTap: () => _update(() => authorFilter = null),
                ),
              ),
              for (final p in miniDemoPeople) _personShortcut(p),
            ],
          ),
        ),
        for (final p in store.posts.where(
          (p) => authorFilter == null || p.person.id == authorFilter,
        ))
          _post(p),
      ],
    ),
  );
  Widget _personShortcut(MiniDemoPerson p, {bool create = false}) => Expanded(
    child: GestureDetector(
      onTap: () {
        if (create) {
          _go(MiniPhoneScreen.create);
        } else {
          _update(() => authorFilter = authorFilter == p.id ? null : p.id);
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
                    color: authorFilter == p.id
                        ? miniPink
                        : const Color(0x33FFFFFF),
                  ),
                ),
                child: MiniAvatar(p, size: 54),
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
            create ? 'Create' : p.short,
            textAlign: TextAlign.center,
            style: miniStyle(12, FontWeight.w500),
          ),
        ],
      ),
    ),
  );
  void _openComments(MiniDemoPost post) {
    activePost = post;
    store.markPostRead(post);
    commentInput.clear();
    _go(MiniPhoneScreen.comments);
  }

  Widget _post(MiniDemoPost p, {bool detail = false}) => Container(
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
        MiniAvatar(p.person, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    p.person == miniDemoMe ? 'Adrian' : p.person.short,
                    style: miniStyle(14, FontWeight.w600),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '@${p.person == miniDemoMe ? 'adrian' : p.person.short.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                  Text(
                    p.time,
                    style: miniStyle(12, FontWeight.w400, miniSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (p.text.isNotEmpty) Text(p.text, style: miniStyle(14)),
              if (p.asset != null || p.photo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: detail ? 170 : 290,
                      maxHeight: detail ? 180 : 300,
                    ),
                    child: GestureDetector(
                      onTap: () => _viewPhoto(
                        asset: p.asset,
                        bytes: p.photo,
                        author: p.person,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: p.photo != null
                            ? Image.memory(p.photo!, fit: BoxFit.contain)
                            : Image.asset(
                                '$miniPhoneAssets${p.asset}',
                                fit: BoxFit.contain,
                              ),
                      ),
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
                      p.comments.length,
                      () => _openComments(p),
                    ),
                    const SizedBox(width: 20),
                    miniPhonePostAction(
                      'heart',
                      'Like',
                      p.likes + (p.liked ? 1 : 0),
                      () => store.toggleLike(p),
                      selected: p.liked,
                    ),
                  ],
                ),
              ),
              if (!detail)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openComments(p),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 6),
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in p.comments.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${c.person == miniDemoMe ? 'Adrian' : c.person.short}  ',
                                    style: miniStyle(12, FontWeight.w600),
                                  ),
                                  if (c.replyTo != null)
                                    TextSpan(
                                      text: '@${c.replyTo!.short} ',
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
                          p.comments.length > 3
                              ? 'View all ${p.comments.length} comments'
                              : p.comments.isEmpty
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
  Widget _comments() {
    final p = activePost ?? store.posts.first;
    return _panel(
      'Comments',
      ListView(
        controller: commentsScroll,
        children: [
          _post(p, detail: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              miniPageInset,
              18,
              miniPageInset,
              8,
            ),
            child: Text(
              '${p.comments.length} comments',
              style: miniStyle(14, FontWeight.w600),
            ),
          ),
          if (p.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(miniPageInset),
              child: Text(
                'Be the first to share your thoughts.',
                style: miniStyle(12, FontWeight.w400, miniSecondary),
              ),
            ),
          for (final c in p.comments)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: miniPageInset,
                vertical: 16,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: miniDivider, width: .5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MiniAvatar(c.person, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              c.person == miniDemoMe
                                  ? 'Adrian'
                                  : c.person.short,
                              style: miniStyle(14, FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              c.time,
                              style: miniStyle(
                                12,
                                FontWeight.w400,
                                miniTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (c.replyTo != null)
                                TextSpan(
                                  text: '@${c.replyTo!.short} ',
                                  style: miniStyle(
                                    14,
                                    FontWeight.w600,
                                    miniPink,
                                  ),
                                ),
                              TextSpan(text: c.text),
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
        ],
      ),
      footer: Container(
        padding: const EdgeInsets.fromLTRB(miniPageInset, 12, miniPageInset, 5),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: miniDivider, width: .5)),
        ),
        child: Row(
          children: [
            const MiniAvatar(miniDemoMe, size: 31),
            const SizedBox(width: 9),
            Expanded(child: _input(commentInput, 'Write a comment…')),
            const SizedBox(width: 8),
            miniPhoneSendButton(
              commentInput.text.trim().isEmpty
                  ? null
                  : () {
                      store.comment(p, commentInput.text);
                      commentInput.clear();
                      _scrollToEnd(commentsScroll);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _create() => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: miniPageInset,
            vertical: 8,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: _back,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: miniWhite,
                ),
                child: Row(
                  children: [
                    const MiniIcon('back', size: 20),
                    const SizedBox(width: 12),
                    Text('Create post', style: miniPageTitle),
                  ],
                ),
              ),
              const Spacer(),
              miniPhoneButton(
                'Post',
                postInput.text.trim().isEmpty && draftPhoto == null
                    ? null
                    : () {
                        store.publish(postInput.text, draftPhoto);
                        postInput.clear();
                        draftPhoto = null;
                        authorFilter = null;
                        _go(MiniPhoneScreen.posts);
                      },
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
                    const MiniAvatar(miniDemoMe, size: 40),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adrian', style: miniStyle(14, FontWeight.w600)),
                        Text(
                          'Ashford Estate',
                          style: miniStyle(12, FontWeight.w400, miniSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: postInput,
                  minLines: 6,
                  maxLines: 10,
                  maxLength: 500,
                  onChanged: (_) => _update(() {}),
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
                    Text(
                      '${postInput.text.length}/500',
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
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
                          onTap: () => _pickPhoto(wallpaper: false),
                          borderRadius: BorderRadius.circular(13),
                          child: draftPhoto != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.memory(
                                    draftPhoto!,
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
                                      'Upload',
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
                            'Add a photo to your post.\nSupported formats: JPG, PNG, WebP.\nUp to 3 MB.',
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
                          if (draftPhoto != null) ...[
                            miniPhoneButton(
                              'Replace photo',
                              () => _pickPhoto(wallpaper: false),
                            ),
                            miniPhoneButton(
                              'Remove photo',
                              () => _update(() => draftPhoto = null),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (feedback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      feedback,
                      style: miniStyle(12, FontWeight.w400, miniPink),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
