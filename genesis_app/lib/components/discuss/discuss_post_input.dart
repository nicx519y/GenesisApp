import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../auth/login_guard.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_modal_routes.dart';
import '../common/genesis_upload_progress_overlay.dart';
import '../../platform/native_image_picker.dart';
import '../../ui/components/genesis_edge_swipe_back.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/image_upload_processing.dart';

export '../../platform/native_image_picker.dart' show DiscussPickedImage;

typedef DiscussPostSubmitter =
    Future<Map<String, dynamic>> Function(String content, List<String> images);
typedef DiscussComposerSubmitter =
    Future<void> Function(String content, List<String> images);
typedef DiscussImagePicker =
    Future<List<DiscussPickedImage>> Function(int limit);
typedef DiscussImageUploader =
    Future<String> Function(DiscussPickedImage image);

const int discussPostMaxImages = 6;
const int _discussComposerMinTextLines = 3;
const int _discussComposerMaxTextLines = 6;
const double _discussComposerFontSize = 14;
const double _discussComposerLineHeight = 1.25;
const Duration _discussComposerScrimFadeDuration = Duration(milliseconds: 180);
const Duration _discussComposerSheetDismissDuration = Duration(
  milliseconds: 160,
);
const Duration _discussUploadProgressTick = Duration(milliseconds: 270);
const int _discussUploadProgressBytesPerSecond = 50 * 1024;
const double _discussUploadProgressCap = 0.92;
const int _discussUploadMaxWidth = 800;

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
  bool requireLogin = true,
}) async {
  if (requireLogin && !await ensureGenesisLogin(context)) return false;
  if (!context.mounted) return false;

  final submitted = await showGenesisGeneralDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    systemBarColor: Colors.white,
    transitionDuration: Duration.zero,
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      return _DiscussComposerSheet(
        title: title,
        placeholder: placeholder,
        pickImages: imagePicker ?? (limit) => pickGenesisImages(limit: limit),
        uploadImage:
            imageUploader ??
            (image) async {
              final api = AppServicesScope.read(sheetContext).api;
              final uploadImage = await resizeImageToMaxWidth(
                bytes: image.bytes,
                filename: image.filename,
                contentType: image.contentType,
                maxWidth: _discussUploadMaxWidth,
              );
              final uploaded = await api.v1.upload.image(
                bytes: uploadImage.bytes,
                filename: uploadImage.filename,
                contentType: uploadImage.contentType,
              );
              final url = GenesisImageResourceRegistry.resolve(
                uploaded,
              ).displayUrl;
              if (url.isEmpty) {
                throw StateError('Upload returned an empty URL');
              }
              return url;
            },
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
      imagePicker: widget.imagePicker ?? _pickImages,
      imageUploader: widget.imageUploader ?? _uploadImage,
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

  Future<List<DiscussPickedImage>> _pickImages(int limit) async {
    return pickGenesisImages(limit: limit);
  }

  Future<String> _uploadImage(DiscussPickedImage image) async {
    final api = AppServicesScope.read(context).api;
    final uploadImage = await resizeImageToMaxWidth(
      bytes: image.bytes,
      filename: image.filename,
      contentType: image.contentType,
      maxWidth: _discussUploadMaxWidth,
    );
    final uploaded = await api.v1.upload.image(
      bytes: uploadImage.bytes,
      filename: uploadImage.filename,
      contentType: uploadImage.contentType,
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
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.placeholder,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: Color(0xFF888888),
          ),
        ),
      ),
    );
  }
}

class _DiscussComposerSheet extends StatefulWidget {
  const _DiscussComposerSheet({
    required this.title,
    required this.placeholder,
    required this.pickImages,
    required this.uploadImage,
    required this.onSubmit,
  });

  final String title;
  final String placeholder;
  final DiscussImagePicker pickImages;
  final DiscussImageUploader uploadImage;
  final Future<void> Function(String content, List<String> images) onSubmit;

  @override
  State<_DiscussComposerSheet> createState() => _DiscussComposerSheetState();
}

class _DiscussComposerSheetState extends State<_DiscussComposerSheet>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  late final AnimationController _scrimController = AnimationController(
    vsync: this,
    duration: _discussComposerScrimFadeDuration,
    reverseDuration: _discussComposerSheetDismissDuration,
  );
  late final AnimationController _sheetDismissController = AnimationController(
    vsync: this,
    duration: _discussComposerSheetDismissDuration,
  );
  final List<_DiscussImageAttachment> _images = <_DiscussImageAttachment>[];
  Timer? _pickerReturnScrimGuardTimer;
  bool _submitting = false;
  bool _pickerOpen = false;
  bool _closing = false;
  bool _keyboardWasVisible = false;
  bool _ignoreKeyboardDismissAfterPicker = false;
  bool _ignoreScrimDismissAfterPicker = false;
  bool _keyboardHideDismissQueued = false;
  int _nextImageId = 0;

  bool get _canSend {
    if (_submitting || _images.any((image) => image.failed)) return false;
    return _controller.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _sheetDismissController.addListener(_handleSheetDismissTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scrimController.forward());
      _composerFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pickerReturnScrimGuardTimer?.cancel();
    _sheetDismissController.removeListener(_handleSheetDismissTick);
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _composerFocusNode.dispose();
    _scrimController.dispose();
    _sheetDismissController.dispose();
    for (final image in _images) {
      image.progressTimer?.cancel();
    }
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _handleSheetDismissTick() {
    if (!mounted || !_closing) return;
    setState(() {});
  }

  void _trackVisibleKeyboard(double measuredInset) {
    if (measuredInset <= 0) return;
    _keyboardWasVisible = true;
    _ignoreKeyboardDismissAfterPicker = false;
    _keyboardHideDismissQueued = false;
  }

  void _queueDismissForHiddenKeyboard() {
    if (_keyboardHideDismissQueued) return;
    _keyboardHideDismissQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardHideDismissQueued = false;
      if (!mounted || !_shouldDismissForHiddenKeyboard) return;
      unawaited(_dismiss());
    });
  }

  bool get _shouldDismissForHiddenKeyboard {
    return _keyboardWasVisible &&
        !_ignoreKeyboardDismissAfterPicker &&
        !_pickerOpen &&
        _images.isEmpty &&
        !_closing &&
        !_submitting;
  }

  void _startPickerReturnScrimGuardTimer() {
    _pickerReturnScrimGuardTimer?.cancel();
    _pickerReturnScrimGuardTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _ignoreScrimDismissAfterPicker = false);
    });
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _submitting = true);
    try {
      await Future.wait(_images.map((image) => image.uploadFuture));
      final imageUrls = _images
          .map((image) => image.url?.trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
      await widget.onSubmit(_controller.text.trim(), imageUrls);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showGenesisToast(context, 'Post failed');
    }
  }

  Future<void> _pickAndUploadImages() async {
    if (_submitting || _images.length >= discussPostMaxImages) return;
    final available = discussPostMaxImages - _images.length;
    List<DiscussPickedImage>? picked;
    Object? pickError;
    setState(() {
      _pickerOpen = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      picked = await widget.pickImages(available);
    } catch (error, stackTrace) {
      pickError = error;
      debugPrint('Discuss image selection failed: $error\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _pickerOpen = false;
          _ignoreScrimDismissAfterPicker = true;
          _ignoreKeyboardDismissAfterPicker = true;
        });
        _startPickerReturnScrimGuardTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _closing) return;
          _composerFocusNode.requestFocus();
        });
      }
    }
    if (!mounted) return;
    if (pickError != null) {
      showGenesisToast(context, _imagePickErrorText(pickError));
      return;
    }
    if (picked == null || picked.isEmpty) return;

    final selected = picked.take(available).toList(growable: false);
    final added = <_DiscussImageAttachment>[];
    for (final image in selected) {
      added.add(_DiscussImageAttachment(id: _nextImageId++, image: image));
    }
    setState(() => _images.addAll(added));

    for (final attachment in added) {
      final uploadFuture = _uploadAttachment(attachment);
      attachment.uploadFuture = uploadFuture;
      _startAttachmentProgressTimer(attachment);
    }
  }

  Future<void> _uploadAttachment(_DiscussImageAttachment attachment) async {
    try {
      final url = await widget.uploadImage(attachment.image);
      if (!mounted || !_images.contains(attachment)) return;
      attachment.progressTimer?.cancel();
      setState(() {
        attachment.progress = 1;
        attachment.url = url;
        attachment.uploading = false;
      });
    } catch (_) {
      if (!mounted || !_images.contains(attachment)) return;
      attachment.progressTimer?.cancel();
      setState(() {
        attachment.failed = true;
        attachment.uploading = false;
      });
      showGenesisToast(context, 'Image upload failed');
      rethrow;
    }
  }

  void _removeImage(_DiscussImageAttachment image) {
    if (_submitting) return;
    image.progressTimer?.cancel();
    setState(() => _images.remove(image));
  }

  void _startAttachmentProgressTimer(_DiscussImageAttachment attachment) {
    attachment.progressTimer?.cancel();
    final byteCount = attachment.image.bytes.length;
    final stopwatch = Stopwatch()..start();
    attachment.progressTimer = Timer.periodic(_discussUploadProgressTick, (_) {
      if (!mounted || !_images.contains(attachment) || !attachment.uploading) {
        attachment.progressTimer?.cancel();
        return;
      }
      setState(() {
        attachment.progress = _estimatedDiscussUploadProgress(
          byteCount: byteCount,
          elapsed: stopwatch.elapsed,
        );
      });
    });
  }

  double _estimatedDiscussUploadProgress({
    required int byteCount,
    required Duration elapsed,
  }) {
    final estimatedBytes = byteCount <= 0 ? 1 : byteCount;
    final estimatedDurationMs =
        estimatedBytes / _discussUploadProgressBytesPerSecond * 1000;
    if (estimatedDurationMs <= 0) return _discussUploadProgressCap;
    return (elapsed.inMilliseconds / estimatedDurationMs)
        .clamp(0.0, _discussUploadProgressCap)
        .toDouble();
  }

  void _handleScrimTap() {
    if (_pickerOpen) return;
    if (_ignoreScrimDismissAfterPicker) {
      _pickerReturnScrimGuardTimer?.cancel();
      _pickerReturnScrimGuardTimer = null;
      setState(() => _ignoreScrimDismissAfterPicker = false);
      return;
    }
    unawaited(_dismiss());
  }

  Future<void> _dismiss() async {
    if (_submitting || _closing) return;
    setState(() {
      _closing = true;
    });
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    await Future.wait([
      _sheetDismissController.forward(),
      _scrimController.reverse(),
    ]);
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    _trackVisibleKeyboard(keyboardInset);
    if (keyboardInset <= 0 && _shouldDismissForHiddenKeyboard) {
      _queueDismissForHiddenKeyboard();
    }
    final closingSlideProgress = _closing
        ? Curves.easeInCubic.transform(_sheetDismissController.value)
        : 0.0;
    final hasImages = _images.isNotEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_dismiss());
      },
      child: GenesisEdgeSwipeBack(
        onBack: () => unawaited(_dismiss()),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: _scrimController,
                  child: GestureDetector(
                    key: const ValueKey('discuss-composer-scrim-dismiss'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleScrimTap,
                    child: const ColoredBox(
                      color: kGenesisSubtleModalBarrierColor,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionalTranslation(
                  translation: Offset(0, closingSlideProgress),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: _DiscussComposerPanel(
                      title: widget.title,
                      placeholder: widget.placeholder,
                      controller: _controller,
                      focusNode: _composerFocusNode,
                      hasImages: hasImages,
                      images: _images,
                      submitting: _submitting,
                      canSend: _canSend,
                      onPickImages: _pickAndUploadImages,
                      onRemoveImage: _removeImage,
                      onSend: _send,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscussComposerPanel extends StatelessWidget {
  const _DiscussComposerPanel({
    required this.title,
    required this.placeholder,
    required this.controller,
    required this.focusNode,
    required this.hasImages,
    required this.images,
    required this.submitting,
    required this.canSend,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSend,
  });

  final String title;
  final String placeholder;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasImages;
  final List<_DiscussImageAttachment> images;
  final bool submitting;
  final bool canSend;
  final VoidCallback onPickImages;
  final ValueChanged<_DiscussImageAttachment> onRemoveImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('discuss-composer-sheet'),
      color: Colors.white,
      borderRadius: GenesisBottomSheetPanel.borderRadius,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GenesisBottomSheetPanel.titleStyle),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: _discussComposerMinTextLines,
                maxLines: _discussComposerMaxTextLines,
                cursorColor: const Color(0xFF6C657A),
                style: const TextStyle(
                  fontSize: _discussComposerFontSize,
                  height: _discussComposerLineHeight,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111111),
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    fontSize: _discussComposerFontSize,
                    height: _discussComposerLineHeight,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: Color(0xFFB8B8B8),
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 14),
              if (hasImages) ...[
                _DiscussImageStrip(
                  images: images,
                  showAddButton: images.length < discussPostMaxImages,
                  submitting: submitting,
                  onAdd: onPickImages,
                  onRemove: onRemoveImage,
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('discuss-image-picker-button'),
                    onPressed: submitting ? null : onPickImages,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 30,
                      color: Color(0xFF00834C),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: canSend ? onSend : null,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5F8E),
                      disabledForegroundColor: const Color(0xFF9BA4B8),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscussImageAttachment {
  _DiscussImageAttachment({required this.id, required this.image})
    : uploadFuture = Future<void>.value();

  final int id;
  final DiscussPickedImage image;
  late Future<void> uploadFuture;
  Timer? progressTimer;
  String? url;
  double progress = 0;
  bool uploading = true;
  bool failed = false;
}

class _DiscussImageStrip extends StatelessWidget {
  const _DiscussImageStrip({
    required this.images,
    required this.showAddButton,
    required this.submitting,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_DiscussImageAttachment> images;
  final bool showAddButton;
  final bool submitting;
  final VoidCallback onAdd;
  final ValueChanged<_DiscussImageAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = _discussImageGap(constraints.maxWidth);
        final tileSize = _discussImageTileSize(constraints.maxWidth, gap);
        final itemCount = images.length + (showAddButton ? 1 : 0);

        return SizedBox(
          key: const ValueKey('discuss-image-strip'),
          height: tileSize + 8,
          child: itemCount == 0
              ? const SizedBox.expand()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var index = 0; index < itemCount; index++) ...[
                      if (index == images.length)
                        _DiscussImageAddTile(
                          size: tileSize,
                          enabled: !submitting,
                          onTap: onAdd,
                        )
                      else
                        _DiscussImageTile(
                          size: tileSize,
                          attachment: images[index],
                          submitting: submitting,
                          onRemove: () => onRemove(images[index]),
                        ),
                      if (index != itemCount - 1) SizedBox(width: gap),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _DiscussImageAddTile extends StatelessWidget {
  const _DiscussImageAddTile({
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('discuss-image-add-button'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E3E3), width: 1.4),
        ),
        child: const Icon(Icons.add, size: 28, color: Color(0xFF8E8E8E)),
      ),
    );
  }
}

class _DiscussImageTile extends StatelessWidget {
  const _DiscussImageTile({
    required this.size,
    required this.attachment,
    required this.submitting,
    required this.onRemove,
  });

  final double size;
  final _DiscussImageAttachment attachment;
  final bool submitting;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: GenesisImageRadii.content,
              child: SizedBox(
                key: ValueKey('discuss-image-thumb-${attachment.id}'),
                width: size,
                height: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(attachment.image.bytes, fit: BoxFit.cover),
                    if (attachment.uploading)
                      GenesisUploadProgressOverlay(
                        progress: attachment.progress,
                      ),
                    if (attachment.failed)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.48),
                        child: const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              key: ValueKey('discuss-image-remove-${attachment.id}'),
              onTap: submitting ? null : onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F4F4F),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _imagePickErrorText(Object error) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission')) {
      return 'Photo access denied';
    }
  }
  return 'Image selection failed';
}

double _discussImageGap(double maxWidth) {
  if (maxWidth <= 0) return 8;
  return (maxWidth * 0.026).clamp(6.0, 12.0).toDouble();
}

double _discussImageTileSize(double maxWidth, double gap) {
  if (maxWidth <= 0) return 52;
  return ((maxWidth - gap * (discussPostMaxImages - 1)) / discussPostMaxImages)
      .clamp(36.0, maxWidth)
      .toDouble();
}
