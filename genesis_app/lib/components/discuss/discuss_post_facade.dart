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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openComposer,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.genesisColors.inputBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.placeholder,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: context.genesisColors.textFaint,
          ),
        ),
      ),
    );
  }
}
