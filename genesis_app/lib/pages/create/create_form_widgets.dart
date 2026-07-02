import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/genesis_upload_progress_overlay.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../platform/native_image_picker.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../ui/text/genesis_text_input_formatters.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/image_format_guards.dart';

const Color createFormGreen = Color(0xFF338960);
const Color createFormFieldFill = Color(0xFFF4F4F6);
const Color createFormHint = Color(0xFFA8A8AD);
const Color createFormText = Color(0xFF111111);
const Color createFormMuted = Color(0xFF6F6F6F);
const Color createFormNote = Color(0xFF888888);
const Color createFormBorder = Color(0xFFE1E1E6);
const Color createFormDash = Color(0xFFB8CDBF);
const Color createFormDanger = Color(0xFFFF2442);
const String createFormDeleteIconAsset =
    'assets/custom-icons/svg/delete-icon.svg';
const String createFormInfoIconAsset = 'assets/custom-icons/svg/info.svg';
const TextStyle createFormSupportTextStyle = TextStyle(
  fontSize: 12,
  height: 1.25,
);

final Object createFormTextFieldTapRegionGroup = Object();

class CreateTextFieldBlock extends StatefulWidget {
  const CreateTextFieldBlock({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLength,
    this.showCounter = true,
    this.note,
    this.minLines = 1,
    this.maxLines,
    this.prefix,
    this.labelSize = 14,
    this.labelFontWeight = FontWeight.w600,
    this.labelInputGap = 10,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
    this.scrollPadding,
    this.inputFormatters = const [],
    this.focusNode,
    this.nextFocusNode,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final bool showCounter;
  final String? note;
  final int minLines;
  final int? maxLines;
  final Widget? prefix;
  final double labelSize;
  final FontWeight labelFontWeight;
  final double labelInputGap;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsets? scrollPadding;
  final List<TextInputFormatter> inputFormatters;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;

  @override
  State<CreateTextFieldBlock> createState() => _CreateTextFieldBlockState();
}

class _CreateTextFieldBlockState extends State<CreateTextFieldBlock> {
  late final FocusNode _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    widget.controller.addListener(_normalizeControllerText);
    _normalizeControllerText();
  }

  @override
  void didUpdateWidget(covariant CreateTextFieldBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_normalizeControllerText);
      widget.controller.addListener(_normalizeControllerText);
      _normalizeControllerText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_normalizeControllerText);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _normalizeControllerText() {
    final value = widget.controller.value;
    final sanitized = genesisDisplaySafeTextEditingValue(value);
    if (sanitized == value) return;
    widget.controller.value = sanitized;
  }

  void _handleEditingComplete() {
    final customHandler = widget.onEditingComplete;
    if (customHandler != null) {
      customHandler();
      return;
    }

    final nextFocusNode = widget.nextFocusNode;
    if (nextFocusNode != null && nextFocusNode.canRequestFocus) {
      nextFocusNode.requestFocus();
      return;
    }

    if (!_focusNode.nextFocus()) {
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: TextStyle(
              color: createFormText,
              fontSize: widget.labelSize,
              fontWeight: widget.labelFontWeight,
              height: 1.2,
            ),
          ),
          // Field internal spacing: label -> input box.
          SizedBox(height: widget.labelInputGap),
        ],
        Container(
          decoration: BoxDecoration(
            color: createFormFieldFill,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          alignment: _isSingleLine ? Alignment.center : Alignment.topCenter,
          child: Row(
            crossAxisAlignment: _isSingleLine
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (widget.prefix != null) ...[
                widget.prefix!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextFieldTapRegion(
                  groupId: createFormTextFieldTapRegionGroup,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    scrollPadding:
                        widget.scrollPadding ??
                        const EdgeInsets.fromLTRB(4, 4, 4, 20),
                    onChanged: widget.onChanged,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    textInputAction:
                        widget.textInputAction ?? TextInputAction.done,
                    onEditingComplete: _handleEditingComplete,
                    onSubmitted: widget.onSubmitted,
                    inputFormatters: [
                      const GenesisDisplaySafeTextInputFormatter(),
                      ...widget.inputFormatters,
                    ],
                    maxLength: widget.maxLength,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    style: GenesisTypography.withFallback(
                      const TextStyle(
                        color: createFormText,
                        fontSize: 14,
                        height: 1.42,
                      ),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: widget.hintText,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: GenesisTypography.withFallback(
                        const TextStyle(
                          color: createFormHint,
                          fontSize: 14,
                          letterSpacing: 0,
                          height: 1.42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_hasSupportLine) ...[
          const SizedBox(height: 8),
          _CreateFieldSupportLine(
            note: widget.note,
            counter: widget.maxLength == null || !widget.showCounter
                ? null
                : '${widget.controller.text.characters.length} / ${widget.maxLength}',
          ),
        ],
      ],
    );
  }

  bool get _hasNote => widget.note?.trim().isNotEmpty == true;

  bool get _hasSupportLine =>
      _hasNote || (widget.maxLength != null && widget.showCounter);

  bool get _isSingleLine =>
      (widget.maxLines ?? widget.minLines) == 1 && widget.minLines == 1;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;
}

class _CreateFieldSupportLine extends StatelessWidget {
  const _CreateFieldSupportLine({required this.note, required this.counter});

  final String? note;
  final String? counter;

  @override
  Widget build(BuildContext context) {
    final normalizedNote = note?.trim() ?? '';
    final hasNote = normalizedNote.isNotEmpty;
    if (!hasNote) {
      return Align(
        alignment: Alignment.centerRight,
        child: _CreateFieldCounter(counter: counter ?? ''),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: CreateFormNote(note: normalizedNote)),
        if (counter != null) ...[
          const SizedBox(width: 12),
          _CreateFieldCounter(counter: counter!),
        ],
      ],
    );
  }
}

class CreateFormNote extends StatelessWidget {
  const CreateFormNote({super.key, required this.note, this.markdown = false});

  final String note;
  final bool markdown;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: SvgPicture.asset(
            createFormInfoIconAsset,
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              createFormNote,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _CreateFormNoteText(note: note, markdown: markdown),
        ),
      ],
    );
  }
}

class _CreateFormNoteText extends StatelessWidget {
  const _CreateFormNoteText({required this.note, required this.markdown});

  final String note;
  final bool markdown;

  @override
  Widget build(BuildContext context) {
    final baseStyle = createFormSupportTextStyle.copyWith(
      color: createFormNote,
    );
    if (!markdown) {
      return Text(note, softWrap: true, style: baseStyle);
    }

    final platform = Theme.of(context).platform;
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: _markdownSpans(note, platform),
      ),
    );
  }

  List<InlineSpan> _markdownSpans(String value, TargetPlatform platform) {
    final spans = <InlineSpan>[];
    var index = 0;
    while (index < value.length) {
      final boldStart = value.indexOf('**', index);
      final italicStart = value.indexOf('*', index);
      final nextStart = _nextMarkdownStart(boldStart, italicStart);
      if (nextStart < 0) {
        spans.add(TextSpan(text: value.substring(index)));
        break;
      }
      if (nextStart > index) {
        spans.add(TextSpan(text: value.substring(index, nextStart)));
      }

      if (boldStart == nextStart) {
        final end = value.indexOf('**', nextStart + 2);
        if (end < 0) {
          spans.add(TextSpan(text: value.substring(nextStart)));
          break;
        }
        spans.add(
          TextSpan(
            text: value.substring(nextStart + 2, end),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        index = end + 2;
      } else {
        final end = value.indexOf('*', nextStart + 1);
        if (end < 0) {
          spans.add(TextSpan(text: value.substring(nextStart)));
          break;
        }
        spans.addAll(
          _inlineEmphasisSpans(value.substring(nextStart + 1, end), platform),
        );
        index = end + 1;
      }
    }
    return spans;
  }

  int _nextMarkdownStart(int boldStart, int italicStart) {
    final normalizedItalicStart = italicStart == boldStart
        ? _valueNotFound
        : italicStart;
    if (boldStart < 0) return normalizedItalicStart;
    if (normalizedItalicStart < 0) return boldStart;
    return boldStart < normalizedItalicStart
        ? boldStart
        : normalizedItalicStart;
  }
}

List<InlineSpan> _inlineEmphasisSpans(String text, TargetPlatform platform) {
  final style = GenesisTypography.inlineEmphasis(
    const TextStyle(),
    platform: platform,
  );
  if (platform != TargetPlatform.iOS) {
    return <InlineSpan>[TextSpan(text: text, style: style)];
  }

  return _emphasisTextPieces(text)
      .map(
        (piece) => piece.trim().isEmpty
            ? TextSpan(text: piece, style: style)
            : _skewedInlineEmphasisSpan(piece, style),
      )
      .toList(growable: false);
}

InlineSpan _skewedInlineEmphasisSpan(String text, TextStyle style) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(GenesisTypography.iosInlineEmphasisSkew),
      transformHitTests: false,
      child: Text(text, style: style),
    ),
  );
}

List<String> _emphasisTextPieces(String text) {
  final pieces = <String>[];
  for (final match in RegExp(r'\s+|[^\s]+').allMatches(text)) {
    final piece = match.group(0)!;
    if (piece.trim().isEmpty || !_shouldSplitEmphasisPiece(piece)) {
      pieces.add(piece);
      continue;
    }
    pieces.addAll(piece.runes.map(String.fromCharCode));
  }
  return pieces;
}

bool _shouldSplitEmphasisPiece(String piece) {
  var runeCount = 0;
  for (final rune in piece.runes) {
    runeCount += 1;
    if (rune > 0x7F || runeCount > 16) return true;
  }
  return false;
}

const int _valueNotFound = -1;

class _CreateFieldCounter extends StatelessWidget {
  const _CreateFieldCounter({required this.counter});

  final String counter;

  @override
  Widget build(BuildContext context) {
    return Text(
      counter,
      textAlign: TextAlign.right,
      style: createFormSupportTextStyle.copyWith(color: createFormMuted),
    );
  }
}

class CreateKeyboardDismissArea extends StatelessWidget {
  const CreateKeyboardDismissArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class CreateFormCard extends StatelessWidget {
  const CreateFormCard({
    super.key,
    required this.title,
    required this.onDelete,
    required this.child,
  });

  final String title;
  final VoidCallback onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: createFormBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: createFormText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(13, -4),
                child: IconButton(
                  onPressed: onDelete,
                  icon: SvgPicture.asset(
                    createFormDeleteIconAsset,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF888888),
                      BlendMode.srcIn,
                    ),
                  ),
                  splashRadius: 22,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

Future<bool> confirmCreateFormDelete(
  BuildContext context, {
  required String itemLabel,
}) async {
  final confirmed = await showGenesisDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          'Delete $itemLabel?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text('This item has content. Delete it anyway?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

class CreateUploadBox extends StatefulWidget {
  const CreateUploadBox({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.width = 132,
    this.height = 176,
    this.iconSize = 38,
    this.borderRadius = GenesisImageRadii.contentValue,
    this.cropSize,
    this.previewAlignment = Alignment.center,
    this.showRemoveLinkWhenFilled = true,
    this.emptyLabelFontWeight = FontWeight.w600,
    this.emptyLabelFontSize = 12,
    this.removeLinkFontWeight = FontWeight.w600,
    this.emptyIconLabelGap = 12,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final double width;
  final double height;
  final double iconSize;
  final double borderRadius;
  final Size? cropSize;
  final Alignment previewAlignment;
  final bool showRemoveLinkWhenFilled;
  final FontWeight emptyLabelFontWeight;
  final double emptyLabelFontSize;
  final FontWeight removeLinkFontWeight;
  final double emptyIconLabelGap;

  @override
  State<CreateUploadBox> createState() => _CreateUploadBoxState();
}

class _CreateUploadBoxState extends State<CreateUploadBox> {
  Uint8List? _previewBytes;
  bool _isUploading = false;
  bool _isUploadProcessing = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(CreateUploadBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _previewBytes = null;
      _isUploading = false;
      _isUploadProcessing = false;
      _uploadProgress = 0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted || _isUploading) return;
    if (_previewBytes != null) {
      setState(() {
        _previewBytes = null;
        _isUploadProcessing = false;
        _uploadProgress = 0;
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.controller.text.trim();
    final hasImage = _previewBytes != null || imageUrl.isNotEmpty;
    final uploadBox = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        onTap: _isUploading ? null : () => _pickCropAndUpload(context),
        child: CustomPaint(
          painter: CreateDashedRRectPainter(
            color: createFormDash,
            radius: widget.borderRadius,
            strokeWidth: 1.2,
          ),
          child: Container(
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x6BF4F4F6),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: !hasImage
                ? _EmptyUpload(
                    widget.label,
                    widget.iconSize,
                    widget.emptyLabelFontWeight,
                    widget.emptyLabelFontSize,
                    widget.emptyIconLabelGap,
                  )
                : _Preview(
                    imageUrl: imageUrl,
                    imageBytes: _previewBytes,
                    isUploading: _isUploading,
                    isProcessing: _isUploadProcessing,
                    progress: _uploadProgress,
                    alignment: widget.previewAlignment,
                  ),
          ),
        ),
      ),
    );
    if (!widget.showRemoveLinkWhenFilled || !hasImage) return uploadBox;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        uploadBox,
        const SizedBox(height: 6),
        TextButton(
          key: const ValueKey('create-upload-remove'),
          onPressed: _isUploading ? null : _removeImage,
          style: TextButton.styleFrom(
            foregroundColor: createFormDanger,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: widget.removeLinkFontWeight,
            ),
          ),
          child: const Text('Remove'),
        ),
      ],
    );
  }

  void _removeImage() {
    setState(() {
      _previewBytes = null;
      _isUploading = false;
      _isUploadProcessing = false;
      _uploadProgress = 0;
    });
    widget.controller.clear();
    widget.onChanged();
  }

  Future<void> _pickCropAndUpload(BuildContext context) async {
    try {
      final picked = await pickGenesisImages(limit: 1);
      if (picked.isEmpty) return;
      final image = picked.first;
      if (!context.mounted) return;

      final crop = await Navigator.of(context).push<LocalImageCropResult>(
        MaterialPageRoute<LocalImageCropResult>(
          builder: (_) => LocalImageCropPage(
            imageBytes: image.bytes,
            cropSize: _resolvedCropSize,
            filename: _pngFilenameFor(image.filename),
            contentType: 'image/png',
            uploadOnConfirm: false,
          ),
        ),
      );
      if (crop == null || !context.mounted) return;

      final previousUrl = widget.controller.text;
      setState(() {
        _previewBytes = crop.bytes;
        _isUploading = true;
        _isUploadProcessing = false;
        _uploadProgress = 0.02;
      });
      widget.controller.clear();
      widget.onChanged();
      unawaited(_uploadCroppedImage(context, crop, previousUrl));
    } on UnsupportedGifImageException {
      if (!context.mounted) return;
      _showMessage(unsupportedGifImageMessage);
    } catch (_) {
      if (!context.mounted) return;
      _showMessage('Image upload failed.');
    }
  }

  void _showMessage(String message) {
    showGenesisToast(context, message);
  }

  Size get _resolvedCropSize {
    final cropSize = widget.cropSize;
    if (cropSize != null) return cropSize;
    return Size(
      (widget.width * 4).roundToDouble().clamp(1, 4096).toDouble(),
      (widget.height * 4).roundToDouble().clamp(1, 4096).toDouble(),
    );
  }

  Future<void> _uploadCroppedImage(
    BuildContext context,
    LocalImageCropResult crop,
    String previousUrl,
  ) async {
    try {
      final uploaded = await AppServicesScope.read(context).api.v1.upload.image(
        bytes: crop.bytes,
        filename: crop.filename,
        contentType: crop.contentType,
        onSendProgress: (sentBytes, totalBytes) {
          if (!mounted || !_isUploading) return;
          final total = totalBytes <= 0 ? 1 : totalBytes;
          final isProcessing = totalBytes > 0 && sentBytes >= totalBytes;
          setState(() {
            _isUploadProcessing = isProcessing;
            _uploadProgress = (sentBytes / total).clamp(0.0, 1.0).toDouble();
          });
        },
      );
      if (!mounted) return;
      final url = GenesisImageResourceRegistry.resolve(uploaded).displayUrl;
      if (url.isEmpty) {
        throw StateError('Upload returned an empty URL');
      }
      setState(() {
        _isUploadProcessing = false;
        _uploadProgress = 1;
      });
      widget.controller.text = url;
      setState(() {
        _isUploading = false;
      });
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isUploadProcessing = false;
        _uploadProgress = 0;
        _previewBytes = null;
      });
      widget.controller.text = previousUrl;
      widget.onChanged();
      _showMessage('Image upload failed.');
    }
  }

  String _pngFilenameFor(String filename) {
    final normalized = filename.trim();
    if (normalized.isEmpty) return 'crop.png';
    final withoutExtension = normalized.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final base = withoutExtension.trim().isEmpty ? 'crop' : withoutExtension;
    return '$base.png';
  }
}

class _EmptyUpload extends StatelessWidget {
  const _EmptyUpload(
    this.label,
    this.iconSize,
    this.labelFontWeight,
    this.labelFontSize,
    this.iconLabelGap,
  );

  final String label;
  final double iconSize;
  final FontWeight labelFontWeight;
  final double labelFontSize;
  final double iconLabelGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          color: createFormGreen,
          size: iconSize,
        ),
        SizedBox(height: iconLabelGap),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: createFormMuted,
            fontSize: labelFontSize,
            fontWeight: labelFontWeight,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.imageUrl,
    required this.imageBytes,
    required this.isUploading,
    required this.isProcessing,
    required this.progress,
    required this.alignment,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final bool isUploading;
  final bool isProcessing;
  final double progress;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final bytes = imageBytes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedUrl = selectGenesisImageUrl(
          url,
          logicalWidth: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null,
          logicalHeight: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : null,
          devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
        );
        final Widget image = bytes != null
            ? Image.memory(
                bytes,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: alignment,
              )
            : selectedUrl.isEmpty
            ? const _PreviewPlaceholder(showSpinner: false)
            : selectedUrl.startsWith('assets/')
            ? Image.asset(
                selectedUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: alignment,
                errorBuilder: (_, error, ___) {
                  return const _PreviewErrorIcon();
                },
              )
            : GenesisStaticNetworkImage(
                imageUrl: selectedUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: alignment,
                onImageLoaded: () {
                  debugPrint(
                    '[CreateUploadBox] static image ready: "$selectedUrl"',
                  );
                },
                placeholder: (_) {
                  debugPrint(
                    '[CreateUploadBox] static image loading: "$selectedUrl"',
                  );
                  return const _PreviewPlaceholder(showSpinner: false);
                },
                errorWidget: (_, error) {
                  debugPrint(
                    '[CreateUploadBox] static image failed: '
                    'url="$selectedUrl", error="$error"',
                  );
                  return const _PreviewErrorIcon();
                },
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (isUploading)
              GenesisUploadProgressOverlay(
                progress: progress,
                processing: isProcessing,
              ),
          ],
        );
      },
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({this.showSpinner = true});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFEFF2),
      child: showSpinner
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: createFormGreen,
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

class _PreviewErrorIcon extends StatelessWidget {
  const _PreviewErrorIcon();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEFEFF2),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: createFormGreen,
          size: 34,
        ),
      ),
    );
  }
}

class CreateAddButton extends StatelessWidget {
  const CreateAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 58,
  });

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: CustomPaint(
          painter: CreateDashedRRectPainter(
            color: createFormDash,
            radius: 8,
            strokeWidth: 1.2,
          ),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: createFormText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateDashedRRectPainter extends CustomPainter {
  CreateDashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 8;
    const double dashSpace = 7;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CreateDashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
