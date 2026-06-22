import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../auth/login_guard.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_modal_routes.dart';
import '../common/genesis_upload_progress_overlay.dart';
import '../../platform/native_image_picker.dart';
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
const double _discussComposerTextHeightAllowance = 2;
const double _discussComposerActionHeight = 50;
const Duration _discussComposerKeyboardPreopenTimeout = Duration(
  milliseconds: 760,
);
const Duration _discussComposerKeyboardStableDelay = Duration(
  milliseconds: 140,
);
const Duration _discussComposerScrimFadeDuration = Duration(milliseconds: 160);
const Duration _discussComposerSheetRevealDuration = Duration(
  milliseconds: 500,
);
const Duration _discussComposerKeyboardHideLeadDuration = Duration(
  milliseconds: 350,
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

  final submitted = await showGenesisModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    systemBarColor: Colors.white,
    restoreSystemUiOverlayStyle: kGenesisDefaultSystemUiOverlayStyle,
    sheetAnimationStyle: AnimationStyle.noAnimation,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height),
    builder: (sheetContext) {
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final TextEditingController _keyboardWarmUpController =
      TextEditingController();
  final FocusNode _keyboardWarmUpFocusNode = FocusNode();
  late final AnimationController _scrimController = AnimationController(
    vsync: this,
    duration: _discussComposerScrimFadeDuration,
    reverseDuration: _discussComposerScrimFadeDuration,
  );
  final List<_DiscussImageAttachment> _images = <_DiscussImageAttachment>[];
  final List<Timer> _metricsSyncTimers = <Timer>[];
  Timer? _pickerReturnScrimGuardTimer;
  Timer? _keyboardPreopenTimer;
  Timer? _keyboardStableTimer;
  bool _submitting = false;
  bool _pickerOpen = false;
  bool _closing = false;
  bool _composerReady = false;
  bool _composerVisible = false;
  bool _keyboardWasVisible = false;
  bool _ignoreKeyboardHideUntilVisible = false;
  bool _waitingForKeyboardRestoreAfterPicker = false;
  bool _ignoreKeyboardDismissAfterPicker = false;
  bool _ignoreScrimDismissAfterPicker = false;
  bool _keyboardHideDismissQueued = false;
  int _nextImageId = 0;
  int _metricsSyncToken = 0;
  double? _closingKeyboardInset;
  double _lastMeasuredKeyboardInset = -1;
  double _lastWarmUpKeyboardInset = -1;

  bool get _canSend {
    if (_submitting || _images.any((image) => image.failed)) return false;
    return _controller.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scrimController.forward());
      _syncKeyboardMetrics();
      _keyboardWarmUpFocusNode.requestFocus();
      _keyboardPreopenTimer = Timer(
        _discussComposerKeyboardPreopenTimeout,
        _showComposerAfterKeyboardReady,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsSyncToken += 1;
    _pickerReturnScrimGuardTimer?.cancel();
    _keyboardPreopenTimer?.cancel();
    _keyboardStableTimer?.cancel();
    for (final timer in _metricsSyncTimers) {
      timer.cancel();
    }
    _metricsSyncTimers.clear();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _composerFocusNode.dispose();
    _keyboardWarmUpController.dispose();
    _keyboardWarmUpFocusNode.dispose();
    _scrimController.dispose();
    for (final image in _images) {
      image.progressTimer?.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleKeyboardMetricsSync();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _showComposerAfterKeyboardReady() {
    if (!mounted || _composerReady || _closing) return;
    _keyboardPreopenTimer?.cancel();
    _keyboardPreopenTimer = null;
    _keyboardStableTimer?.cancel();
    _keyboardStableTimer = null;
    setState(() => _composerReady = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      setState(() => _composerVisible = true);
      _composerFocusNode.requestFocus();
      _syncKeyboardMetrics();
    });
  }

  void _scheduleKeyboardMetricsSync() {
    if (!mounted) return;
    final token = ++_metricsSyncToken;
    for (final timer in _metricsSyncTimers) {
      timer.cancel();
    }
    _metricsSyncTimers.clear();
    _syncKeyboardMetrics();
    for (final delay in const <Duration>[
      Duration(milliseconds: 16),
      Duration(milliseconds: 80),
      Duration(milliseconds: 180),
      Duration(milliseconds: 320),
      Duration(milliseconds: 480),
      Duration(milliseconds: 640),
    ]) {
      late final Timer timer;
      timer = Timer(delay, () {
        _metricsSyncTimers.remove(timer);
        if (!mounted || token != _metricsSyncToken) return;
        _syncKeyboardMetrics();
      });
      _metricsSyncTimers.add(timer);
    }
  }

  void _syncKeyboardMetrics() {
    if (!mounted) return;
    final measuredInset = _keyboardInsetBottom(context, MediaQuery.of(context));
    if (!_composerReady) {
      _handleKeyboardWarmUpInset(measuredInset);
      return;
    }
    final insetChanged = (measuredInset - _lastMeasuredKeyboardInset).abs() > 1;
    _lastMeasuredKeyboardInset = measuredInset;
    if (!_composerReady) return;
    _trackVisibleKeyboard(measuredInset);
    if (measuredInset <= 0 && _shouldDismissForHiddenKeyboard) {
      unawaited(_dismiss());
      return;
    }
    if (insetChanged) setState(() {});
  }

  void _handleKeyboardWarmUpInset(double measuredInset) {
    if (measuredInset <= 0 || _closing) return;
    final insetChanged = (measuredInset - _lastWarmUpKeyboardInset).abs() > 1;
    _lastWarmUpKeyboardInset = measuredInset;
    if (insetChanged) {
      _keyboardStableTimer?.cancel();
      _keyboardStableTimer = Timer(
        _discussComposerKeyboardStableDelay,
        _showComposerAfterKeyboardReady,
      );
    }
  }

  void _trackVisibleKeyboard(double measuredInset) {
    if (measuredInset <= 0) return;
    _keyboardWasVisible = true;
    if (_waitingForKeyboardRestoreAfterPicker) {
      _waitingForKeyboardRestoreAfterPicker = false;
      _ignoreKeyboardDismissAfterPicker = false;
    }
    _ignoreKeyboardHideUntilVisible = false;
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
        !_ignoreKeyboardHideUntilVisible &&
        !_waitingForKeyboardRestoreAfterPicker &&
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
      _ignoreKeyboardHideUntilVisible = true;
      _waitingForKeyboardRestoreAfterPicker = true;
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
        _scheduleKeyboardMetricsSync();
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
      _closingKeyboardInset = _keyboardInsetBottom(
        context,
        MediaQuery.of(context),
      );
      _composerVisible = false;
    });
    await Future<void>.delayed(_discussComposerKeyboardHideLeadDuration);
    if (!mounted) return;
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    await Future<void>.delayed(
      _discussComposerSheetRevealDuration -
          _discussComposerKeyboardHideLeadDuration,
    );
    if (!mounted) return;
    await _waitForKeyboardHidden();
    if (!mounted) return;
    await _scrimController.reverse();
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _waitForKeyboardHidden() async {
    for (final delay in const <Duration>[
      Duration(milliseconds: 16),
      Duration(milliseconds: 80),
      Duration(milliseconds: 160),
      Duration(milliseconds: 260),
    ]) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      if (_keyboardInsetBottom(context, MediaQuery.of(context)) <= 0) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final measuredKeyboardInset = _keyboardInsetBottom(context, media);
    _trackVisibleKeyboard(measuredKeyboardInset);
    if (measuredKeyboardInset <= 0 && _shouldDismissForHiddenKeyboard) {
      _queueDismissForHiddenKeyboard();
    }
    final keyboardInset = _closing && _closingKeyboardInset != null
        ? _closingKeyboardInset!
        : measuredKeyboardInset;
    final maxSheetHeight = math.max(
      0.0,
      media.size.height - keyboardInset - media.padding.top - 12,
    );
    final composerContentWidth = math.max(0.0, media.size.width - 32);
    final composerTextLines = _discussComposerVisibleTextLines(
      text: _controller.text,
      placeholder: widget.placeholder,
      maxWidth: composerContentWidth,
    );
    final hasImages = _images.isNotEmpty;
    final sheetHeight = math.min(
      _discussComposerPreferredSheetHeight(
        media.size.width,
        composerTextLines,
        hasImages: hasImages,
      ),
      maxSheetHeight,
    );
    final hiddenSlideOffset = _closing && sheetHeight > 0
        ? Offset(0, 1 + keyboardInset / sheetHeight)
        : const Offset(0, 1);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_dismiss());
      },
      child: SizedBox.expand(
        child: Stack(
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
            Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: !_composerReady
                    ? _DiscussHiddenKeyboardWarmUpField(
                        controller: _keyboardWarmUpController,
                        focusNode: _keyboardWarmUpFocusNode,
                      )
                    : AnimatedSlide(
                        duration: _discussComposerSheetRevealDuration,
                        curve: Curves.easeOutCubic,
                        offset: _composerVisible
                            ? Offset.zero
                            : hiddenSlideOffset,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: GenesisBottomSheetPanel(
                            key: const ValueKey('discuss-composer-sheet'),
                            title: widget.title,
                            height: sheetHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _controller,
                                  focusNode: _composerFocusNode,
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
                                    hintText: widget.placeholder,
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
                                    images: _images,
                                    showAddButton:
                                        _images.length < discussPostMaxImages,
                                    submitting: _submitting,
                                    onAdd: _pickAndUploadImages,
                                    onRemove: _removeImage,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                Row(
                                  children: [
                                    IconButton(
                                      key: const ValueKey(
                                        'discuss-image-picker-button',
                                      ),
                                      onPressed: _submitting
                                          ? null
                                          : _pickAndUploadImages,
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
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
                                      onPressed: _canSend ? _send : null,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF4B5F8E,
                                        ),
                                        disabledForegroundColor: const Color(
                                          0xFF9BA4B8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          height: 1.1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: _submitting
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Send'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscussHiddenKeyboardWarmUpField extends StatelessWidget {
  const _DiscussHiddenKeyboardWarmUpField({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0,
        child: Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
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

double _keyboardInsetBottom(BuildContext context, MediaQueryData media) {
  final view = View.of(context);
  final viewInset = view.viewInsets.bottom / view.devicePixelRatio;
  var dispatcherInset = 0.0;
  for (final dispatcherView
      in WidgetsBinding.instance.platformDispatcher.views) {
    dispatcherInset = math.max(
      dispatcherInset,
      dispatcherView.viewInsets.bottom / dispatcherView.devicePixelRatio,
    );
  }
  return math.max(
    media.viewInsets.bottom,
    math.max(viewInset, dispatcherInset),
  );
}

double _discussComposerPreferredSheetHeight(
  double screenWidth,
  int textLines, {
  required bool hasImages,
}) {
  final contentWidth = math.max(0.0, screenWidth - 32);
  final gap = _discussImageGap(contentWidth);
  final imageStripHeight = hasImages
      ? _discussImageTileSize(contentWidth, gap) + 8
      : 0.0;
  final textHeight =
      _discussComposerFontSize * _discussComposerLineHeight * textLines +
      _discussComposerTextHeightAllowance;
  final imageSectionHeight = hasImages ? imageStripHeight + 14 : 0.0;

  return 22 +
      GenesisBottomSheetPanel.titleStyle.fontSize! *
          GenesisBottomSheetPanel.titleStyle.height! +
      18 +
      textHeight +
      14 +
      imageSectionHeight +
      _discussComposerActionHeight +
      14;
}

int _discussComposerVisibleTextLines({
  required String text,
  required String placeholder,
  required double maxWidth,
}) {
  if (maxWidth <= 0) return _discussComposerMinTextLines;
  final measuredText = text.isEmpty ? placeholder : text;
  final painter = TextPainter(
    text: TextSpan(
      text: measuredText,
      style: const TextStyle(
        fontSize: _discussComposerFontSize,
        height: _discussComposerLineHeight,
        fontWeight: FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  final lineCount = painter.computeLineMetrics().length;
  painter.dispose();
  return lineCount
      .clamp(_discussComposerMinTextLines, _discussComposerMaxTextLines)
      .toInt();
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
