import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'genesis_center_toast.dart';

class LocalImageCropPage extends StatefulWidget {
  const LocalImageCropPage({
    super.key,
    required this.imageBytes,
    required this.cropSize,
    this.onUpload,
    this.filename = 'crop.png',
    this.contentType = 'image/png',
    this.uploadOnConfirm = true,
  });

  final Uint8List imageBytes;
  final Size cropSize;
  final String filename;
  final String contentType;
  final bool uploadOnConfirm;
  final Future<String> Function(LocalImageCropResult result)? onUpload;

  @override
  State<LocalImageCropPage> createState() => _LocalImageCropPageState();
}

class LocalImageCropResult {
  const LocalImageCropResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String filename;
  final String contentType;
}

class _LocalImageCropPageState extends State<LocalImageCropPage> {
  ui.Image? _image;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  double _scale = 1;
  Offset _offset = Offset.zero;
  Size? _imageViewSize;
  Size? _viewportSize;
  Rect? _cropRect;
  String? _layoutSignature;

  double _gestureStartScale = 1;
  Offset _gestureSceneFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        codec.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _isLoading = false;
      });
      codec.dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Image load failed';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 30),
                    color: Colors.white,
                  ),
                  const Spacer(),
                  if (_isSubmitting)
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isSubmitting || _image == null
                        ? null
                        : _cropAndUpload,
                    icon: const Icon(Icons.check, size: 30),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null || _image == null) {
      return Center(
        child: Text(
          _error ?? 'Image load failed',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final cropSize = _fitCropSize(viewportSize);
        final cropRect = Rect.fromCenter(
          center: viewportSize.center(Offset.zero),
          width: cropSize.width,
          height: cropSize.height,
        );
        _ensureLayout(viewportSize, cropRect);

        final imageViewSize = _imageViewSize!;
        final scaledSize = imageViewSize * _scale;
        final topLeft =
            viewportSize.center(Offset.zero) -
            Offset(scaledSize.width / 2, scaledSize.height / 2) +
            _offset;

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  child: Container(color: Colors.black),
                ),
              ),
              Positioned(
                left: topLeft.dx,
                top: topLeft.dy,
                width: scaledSize.width,
                height: scaledSize.height,
                child: IgnorePointer(
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  size: viewportSize,
                  painter: _CropOverlayPainter(cropRect),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Size _fitCropSize(Size viewportSize) {
    final requestedWidth = widget.cropSize.width <= 0
        ? 1.0
        : widget.cropSize.width;
    final requestedHeight = widget.cropSize.height <= 0
        ? 1.0
        : widget.cropSize.height;
    final maxWidth = (viewportSize.width - 48).clamp(1.0, viewportSize.width);
    final maxHeight = (viewportSize.height - 48).clamp(
      1.0,
      viewportSize.height,
    );
    final scale = (maxWidth / requestedWidth) < (maxHeight / requestedHeight)
        ? maxWidth / requestedWidth
        : maxHeight / requestedHeight;
    return Size(requestedWidth * scale, requestedHeight * scale);
  }

  void _ensureLayout(Size viewportSize, Rect cropRect) {
    final image = _image;
    if (image == null) return;
    final signature =
        '${viewportSize.width}x${viewportSize.height}:${cropRect.width}x${cropRect.height}:${image.width}x${image.height}';
    if (_layoutSignature == signature) return;

    final imageAspect = image.width / image.height;
    final cropAspect = cropRect.width / cropRect.height;
    final imageViewSize = imageAspect > cropAspect
        ? Size(cropRect.height * imageAspect, cropRect.height)
        : Size(cropRect.width, cropRect.width / imageAspect);

    _layoutSignature = signature;
    _viewportSize = viewportSize;
    _cropRect = cropRect;
    _imageViewSize = imageViewSize;
    _scale = 1;
    _offset = _clampOffset(Offset.zero, _scale, viewportSize, cropRect);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final viewportSize = _viewportSize;
    if (viewportSize == null) return;
    final center = viewportSize.center(Offset.zero);
    _gestureStartScale = _scale;
    _gestureSceneFocal = (details.localFocalPoint - center - _offset) / _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final viewportSize = _viewportSize;
    final cropRect = _cropRect;
    if (viewportSize == null || cropRect == null || _imageViewSize == null) {
      return;
    }
    final center = viewportSize.center(Offset.zero);
    final nextScale = (_gestureStartScale * details.scale).clamp(1.0, 5.0);
    final nextOffset =
        details.localFocalPoint - center - _gestureSceneFocal * nextScale;
    setState(() {
      _scale = nextScale;
      _offset = _clampOffset(nextOffset, nextScale, viewportSize, cropRect);
    });
  }

  Offset _clampOffset(
    Offset candidate,
    double scale,
    Size viewportSize,
    Rect cropRect,
  ) {
    final imageViewSize = _imageViewSize;
    if (imageViewSize == null) return candidate;

    final scaledSize = imageViewSize * scale;
    final center = viewportSize.center(Offset.zero);
    var dx = candidate.dx;
    var dy = candidate.dy;

    var left = center.dx + dx - scaledSize.width / 2;
    var right = left + scaledSize.width;
    if (left > cropRect.left) {
      dx -= left - cropRect.left;
    } else if (right < cropRect.right) {
      dx += cropRect.right - right;
    }

    var top = center.dy + dy - scaledSize.height / 2;
    var bottom = top + scaledSize.height;
    if (top > cropRect.top) {
      dy -= top - cropRect.top;
    } else if (bottom < cropRect.bottom) {
      dy += cropRect.bottom - bottom;
    }

    return Offset(dx, dy);
  }

  Future<void> _cropAndUpload() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      final crop = await _crop();
      if (!widget.uploadOnConfirm) {
        if (!mounted) return;
        Navigator.of(context).pop(crop);
        return;
      }
      final upload = widget.onUpload;
      if (upload == null) {
        throw StateError('Upload handler is not configured');
      }
      final url = (await upload(crop)).trim();
      if (url.isEmpty) {
        throw StateError('Upload returned an empty URL');
      }
      if (!mounted) return;
      Navigator.of(context).pop(url);
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Upload failed');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<LocalImageCropResult> _crop() async {
    final image = _image;
    final viewportSize = _viewportSize;
    final cropRect = _cropRect;
    final imageViewSize = _imageViewSize;
    if (image == null ||
        viewportSize == null ||
        cropRect == null ||
        imageViewSize == null) {
      throw StateError('Crop layout is not ready');
    }

    final scaledSize = imageViewSize * _scale;
    final topLeft =
        viewportSize.center(Offset.zero) -
        Offset(scaledSize.width / 2, scaledSize.height / 2) +
        _offset;
    final logicalRect = Rect.fromLTRB(
      ((cropRect.left - topLeft.dx) / _scale).clamp(0.0, imageViewSize.width),
      ((cropRect.top - topLeft.dy) / _scale).clamp(0.0, imageViewSize.height),
      ((cropRect.right - topLeft.dx) / _scale).clamp(0.0, imageViewSize.width),
      ((cropRect.bottom - topLeft.dy) / _scale).clamp(
        0.0,
        imageViewSize.height,
      ),
    );
    final sourceRect = Rect.fromLTRB(
      logicalRect.left / imageViewSize.width * image.width,
      logicalRect.top / imageViewSize.height * image.height,
      logicalRect.right / imageViewSize.width * image.width,
      logicalRect.bottom / imageViewSize.height * image.height,
    );

    final targetWidth = widget.cropSize.width.round().clamp(1, 4096);
    final targetHeight = widget.cropSize.height.round().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      sourceRect,
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(targetWidth, targetHeight);
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    croppedImage.dispose();
    picture.dispose();
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Crop failed');
    }
    return LocalImageCropResult(
      bytes: bytes,
      width: targetWidth,
      height: targetHeight,
      filename: widget.filename,
      contentType: widget.contentType,
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter(this.cropRect);

  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(cropRect);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect;
  }
}
