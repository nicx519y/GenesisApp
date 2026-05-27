import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/local_image_crop_page.dart';
import '../../platform/native_image_picker.dart';

const Color createFormGreen = Color(0xFF198B64);
const Color createFormFieldFill = Color(0xFFF4F4F6);
const Color createFormHint = Color(0xFFA8A8AD);
const Color createFormText = Color(0xFF111111);
const Color createFormMuted = Color(0xFF6F6F6F);
const Color createFormBorder = Color(0xFFE1E1E6);
const Color createFormDash = Color(0xFFB8CDBF);

final Object createFormTextFieldTapRegionGroup = Object();

class CreateTextFieldBlock extends StatelessWidget {
  const CreateTextFieldBlock({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLength,
    this.minLines = 1,
    this.maxLines,
    this.prefix,
    this.labelSize = 14,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final int minLines;
  final int? maxLines;
  final Widget? prefix;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              color: createFormText,
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
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
              if (prefix != null) ...[prefix!, const SizedBox(width: 8)],
              Expanded(
                child: TextFieldTapRegion(
                  groupId: createFormTextFieldTapRegionGroup,
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    maxLength: maxLength,
                    minLines: minLines,
                    maxLines: maxLines,
                    style: const TextStyle(
                      color: createFormText,
                      fontSize: 14,
                      height: 1.42,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: hintText,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: const TextStyle(
                        color: createFormHint,
                        fontSize: 14,
                        height: 1.42,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (maxLength != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length} / $maxLength',
              style: const TextStyle(
                color: createFormMuted,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool get _isSingleLine => (maxLines ?? minLines) == 1 && minLines == 1;
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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 26,
                  color: Color(0xFF8F8F8F),
                ),
                splashRadius: 22,
                visualDensity: VisualDensity.compact,
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          'Delete $itemLabel?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
    this.cropSize,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final double width;
  final double height;
  final double iconSize;
  final Size? cropSize;

  @override
  State<CreateUploadBox> createState() => _CreateUploadBoxState();
}

class _CreateUploadBoxState extends State<CreateUploadBox> {
  Uint8List? _previewBytes;
  Timer? _progressTimer;
  bool _isUploading = false;
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
      _progressTimer?.cancel();
      _previewBytes = null;
      _isUploading = false;
      _uploadProgress = 0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _progressTimer?.cancel();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted || _isUploading) return;
    if (widget.controller.text.trim().isEmpty && _previewBytes != null) {
      _progressTimer?.cancel();
      setState(() {
        _previewBytes = null;
        _uploadProgress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.controller.text.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isUploading ? null : () => _pickCropAndUpload(context),
        child: CustomPaint(
          painter: CreateDashedRRectPainter(
            color: createFormDash,
            radius: 14,
            strokeWidth: 1.2,
          ),
          child: Container(
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x6BF4F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: _previewBytes == null && imageUrl.isEmpty
                ? _EmptyUpload(widget.label, widget.iconSize)
                : _Preview(
                    imageUrl: imageUrl,
                    imageBytes: _previewBytes,
                    isUploading: _isUploading,
                    progress: _uploadProgress,
                  ),
          ),
        ),
      ),
    );
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
        _uploadProgress = 0;
      });
      widget.controller.clear();
      widget.onChanged();
      _startProgressTimer();
      unawaited(_uploadCroppedImage(context, crop, previousUrl));
    } catch (_) {
      if (!context.mounted) return;
      _showMessage('Image upload failed.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      );
      if (!mounted) return;
      final url = '${uploaded['url'] ?? ''}'.trim();
      if (url.isEmpty) {
        throw StateError('Upload returned an empty URL');
      }
      _progressTimer?.cancel();
      setState(() {
        _uploadProgress = 1;
        _isUploading = false;
      });
      widget.controller.text = url;
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _progressTimer?.cancel();
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _previewBytes = null;
      });
      widget.controller.text = previousUrl;
      widget.onChanged();
      _showMessage('Image upload failed.');
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || !_isUploading) return;
      setState(() {
        final remaining = 0.92 - _uploadProgress;
        if (remaining <= 0) {
          _uploadProgress = 0.92;
        } else {
          _uploadProgress += remaining < 0.02 ? remaining : 0.02;
        }
      });
    });
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
  const _EmptyUpload(this.label, this.iconSize);

  final String label;
  final double iconSize;

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
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: createFormMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
    required this.progress,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final bool isUploading;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    final image = bytes != null
        ? Image.memory(
            bytes,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          )
        : Image.network(
            imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.check_circle_outline,
              color: createFormGreen,
              size: 34,
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (isUploading) _UploadProgressOverlay(progress: progress),
      ],
    );
  }
}

class _UploadProgressOverlay extends StatelessWidget {
  const _UploadProgressOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    final coverFactor = (1 - normalized).clamp(0.0, 1.0).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: coverFactor,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.48)),
          ),
        ),
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                '${(normalized * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
