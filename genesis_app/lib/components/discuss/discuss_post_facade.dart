part of 'discuss_post_library.dart';

class DiscussPostInput extends StatefulWidget {
  const DiscussPostInput({
    super.key,
    required this.bizId,
    this.bizType = 1,
    this.placeholder = 'Write a post',
    this.title = 'New post',
    this.submitter,
    this.imagePicker,
    this.imageUploader,
    this.onSubmitted,
    this.requireLogin = true,
    this.compact = false,
    this.showCurrentUserAvatar = false,
  });

  final String bizId;
  final int bizType;
  final String placeholder;
  final String title;
  final DiscussPostSubmitter? submitter;
  final DiscussImagePicker? imagePicker;
  final DiscussImageUploader? imageUploader;
  final VoidCallback? onSubmitted;
  final bool requireLogin;
  final bool compact;
  final bool showCurrentUserAvatar;

  @override
  State<DiscussPostInput> createState() => _DiscussPostInputState();
}

Future<bool> showDiscussPostComposer({
  required BuildContext context,
  required String title,
  required String placeholder,
  required DiscussComposerSubmitter submitter,
  DiscussImagePicker? imagePicker,
  DiscussImageUploader? imageUploader,
  DiscussImageProgressUploader? imageProgressUploader,
  bool requireLogin = true,
}) async {
  if (requireLogin && !await ensureGenesisLogin(context)) return false;
  if (!context.mounted) return false;

  final submitted = await showGenesisGeneralDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      return _DiscussComposerSheet(
        title: title,
        placeholder: placeholder,
        pickImages:
            imagePicker ??
            (limit) =>
                pickGenesisImages(limit: limit, normalizeForUpload: true),
        pickImageResult: imagePicker == null
            ? (limit) =>
                  pickGenesisImageResult(limit: limit, normalizeForUpload: true)
            : null,
        uploadImage:
            imageUploader ??
            (image) async {
              final api = AppServicesScope.read(sheetContext).api;
              final uploaded = await api.v1.upload.image(
                bytes: image.bytes,
                filename: image.filename,
                contentType: image.contentType,
              );
              final url = GenesisImageResourceRegistry.resolve(
                uploaded,
              ).displayUrl;
              if (url.isEmpty) {
                throw StateError('Upload returned an empty URL');
              }
              return url;
            },
        uploadImageWithProgress:
            imageProgressUploader ??
            (imageUploader == null
                ? (image, {onSendProgress}) async {
                    final api = AppServicesScope.read(sheetContext).api;
                    final uploaded = await api.v1.upload.image(
                      bytes: image.bytes,
                      filename: image.filename,
                      contentType: image.contentType,
                      onSendProgress: onSendProgress,
                    );
                    final url = GenesisImageResourceRegistry.resolve(
                      uploaded,
                    ).displayUrl;
                    if (url.isEmpty) {
                      throw StateError('Upload returned an empty URL');
                    }
                    return url;
                  }
                : null),
        onSubmit: (content, images) async {
          await submitter(content, images);
        },
      );
    },
  );
  return submitted == true;
}

class _DiscussPostInputState extends State<DiscussPostInput> {
  bool _composerOpen = false;

  Future<void> _openComposer() async {
    if (_composerOpen || widget.bizId.trim().isEmpty) return;
    _composerOpen = true;

    final submitted = await showDiscussPostComposer(
      context: context,
      title: widget.title,
      placeholder: widget.placeholder,
      imagePicker: widget.imagePicker,
      imageUploader: widget.imageUploader ?? _uploadImage,
      imageProgressUploader: widget.imageUploader == null
          ? _uploadImageWithProgress
          : null,
      submitter: _submit,
      requireLogin: widget.requireLogin,
    );

    _composerOpen = false;
    if (!mounted || !submitted) return;
    widget.onSubmitted?.call();
  }

  Future<void> _submit(String content, List<String> images) async {
    final submitter = widget.submitter;
    if (submitter != null) {
      await submitter(content, images);
      return;
    }

    await AppServicesScope.read(context).api.v1.discuss.post(
      bizId: widget.bizId.trim(),
      bizType: widget.bizType,
      content: content,
      images: images,
    );
  }

  Future<String> _uploadImage(DiscussPickedImage image) async {
    final api = AppServicesScope.read(context).api;
    final uploaded = await api.v1.upload.image(
      bytes: image.bytes,
      filename: image.filename,
      contentType: image.contentType,
    );
    final url = GenesisImageResourceRegistry.resolve(uploaded).displayUrl;
    if (url.isEmpty) throw StateError('Upload returned an empty URL');
    return url;
  }

  Future<String> _uploadImageWithProgress(
    DiscussPickedImage image, {
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final api = AppServicesScope.read(context).api;
    final uploaded = await api.v1.upload.image(
      bytes: image.bytes,
      filename: image.filename,
      contentType: image.contentType,
      onSendProgress: onSendProgress,
    );
    final url = GenesisImageResourceRegistry.resolve(uploaded).displayUrl;
    if (url.isEmpty) throw StateError('Upload returned an empty URL');
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final input = Container(
      constraints: compact
          ? const BoxConstraints.tightFor(height: 40)
          : const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 13)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: compact
            ? context.genesisColors.foregroundStrong.withValues(alpha: 0.07)
            : context.genesisColors.inputBackground,
        borderRadius: BorderRadius.circular(compact ? 13 : 8),
      ),
      child: Text(
        widget.placeholder,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          height: compact ? 1 : 1.2,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: compact
              ? context.genesisColors.foregroundStrong.withValues(alpha: 0.32)
              : context.genesisColors.textFaint,
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openComposer,
      child: widget.showCurrentUserAvatar
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DiscussCurrentUserAvatar(
                  size: compact ? 34 : 40,
                  ringed: !compact,
                ),
                SizedBox(width: compact ? 10 : 8),
                Expanded(child: input),
              ],
            )
          : input,
    );
  }
}

class _DiscussCurrentUserAvatar extends StatefulWidget {
  const _DiscussCurrentUserAvatar({required this.size, this.ringed = true});

  final double size;
  final bool ringed;

  @override
  State<_DiscussCurrentUserAvatar> createState() =>
      _DiscussCurrentUserAvatarState();
}

class _DiscussCurrentUserAvatarState extends State<_DiscussCurrentUserAvatar> {
  ValueListenable<int>? _userInfoRevision;
  var _loadGeneration = 0;
  var _avatarUrl = '';
  var _displayName = 'User';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = AppServicesScope.read(
      context,
    ).sessionStore.userInfoRevision;
    if (identical(_userInfoRevision, revision)) return;
    _userInfoRevision?.removeListener(_handleUserInfoChanged);
    _userInfoRevision = revision..addListener(_handleUserInfoChanged);
    _loadCachedUserInfo();
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _userInfoRevision?.removeListener(_handleUserInfoChanged);
    super.dispose();
  }

  void _handleUserInfoChanged() => _loadCachedUserInfo();

  Future<void> _loadCachedUserInfo() async {
    final generation = ++_loadGeneration;
    final sessionStore = AppServicesScope.read(context).sessionStore;
    final userInfo = await sessionStore.readUserInfo();
    final uid = (await sessionStore.readUid())?.trim() ?? '';
    final nextName = _firstCachedUserString(userInfo, const [
      'name',
      'nickname',
      'user_name',
      'display_name',
    ]);
    final nextAvatar = asImageUrl(
      userInfo?['avatar'],
      fallback:
          userInfo?['avatar_url'] ??
          userInfo?['photoUrl'] ??
          userInfo?['photo_url'] ??
          userInfo?['picture'],
    );
    if (!mounted || generation != _loadGeneration) return;
    final resolvedName = nextName.isNotEmpty
        ? nextName
        : uid.isNotEmpty && !uid.startsWith('guest_')
        ? uid
        : 'User';
    if (_avatarUrl == nextAvatar && _displayName == resolvedName) return;
    setState(() {
      _avatarUrl = nextAvatar;
      _displayName = resolvedName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final ringed = widget.ringed;
    final avatar = GenesisAvatar(
      name: _displayName,
      url: _avatarUrl,
      size: ringed ? size - 3 : size,
      borderRadius: ringed ? 9.5 : size / 2,
      fallbackBackgroundColor: context.genesisColors.inputBackground,
      showFallbackWhileLoading: true,
    );
    if (!ringed) {
      return SizedBox(
        key: const ValueKey<String>('discuss-post-current-user-avatar'),
        width: size,
        height: size,
        child: avatar,
      );
    }
    return Container(
      key: const ValueKey<String>('discuss-post-current-user-avatar'),
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.genesisColors.danger, width: 1.5),
      ),
      child: avatar,
    );
  }
}

String _firstCachedUserString(
  Map<String, dynamic>? userInfo,
  Iterable<String> keys,
) {
  if (userInfo == null) return '';
  for (final key in keys) {
    final value = userInfo[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
