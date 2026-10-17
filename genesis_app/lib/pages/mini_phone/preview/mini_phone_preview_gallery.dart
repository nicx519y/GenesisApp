import 'package:flutter/material.dart';
import '../session/mini_phone_session.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_preview_photo.dart';

Future<void> showMiniPhonePreviewGallery(
  BuildContext context,
  MiniPhoneSession session,
  List<MiniPhonePreviewPhoto> photos,
  int index, {
  required VoidCallback onClose,
}) async {
  var closing = false;
  session.resume.viewerPhotos = photos;
  session.resume.viewerIndex = index;
  await session.push<void>(
    context,
    DialogRoute<void>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => _MiniPhotoGallery(
        photos: photos,
        initialIndex: index,
        onIndex: (index) => session.resume.viewerIndex = index,
        onClose: () {
          Navigator.of(dialogContext).pop();
          closing = true;
          onClose();
        },
      ),
    ),
  );
  if (!closing) session.resume.viewerPhotos = null;
}

class _MiniPhotoGallery extends StatefulWidget {
  const _MiniPhotoGallery({
    required this.photos,
    required this.initialIndex,
    required this.onIndex,
    required this.onClose,
  });
  final ValueChanged<int> onIndex;
  final VoidCallback onClose;
  final List<MiniPhonePreviewPhoto> photos;
  final int initialIndex;
  @override
  State<_MiniPhotoGallery> createState() => _MiniPhotoGalleryState();
}

class _MiniPhotoGalleryState extends State<_MiniPhotoGallery> {
  late final PageController _pages;
  late int _index;
  bool _zoomed = false;
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: miniBackground,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MiniIcon('back', size: 20),
                        const SizedBox(width: 12),
                        Text('Photo', style: miniPageTitle),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.photos.length > 1)
                    Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  const SizedBox(width: 12),
                  MiniIconButton('close', 'Close mini phone', widget.onClose),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (value) => setState(() {
                _index = value;
                _zoomed = false;
                widget.onIndex(value);
              }),
              itemBuilder: (context, index) => _MiniPhotoFrame(
                key: ValueKey(index),
                photo: widget.photos[index],
                onZoom: (zoomed) {
                  if (mounted && index == _index && zoomed != _zoomed) {
                    setState(() => _zoomed = zoomed);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(miniPageInset),
            child: Text(
              'From this world · Original image',
              style: miniStyle(12, FontWeight.w400, miniSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniPhotoFrame extends StatefulWidget {
  const _MiniPhotoFrame({super.key, required this.photo, required this.onZoom});
  final MiniPhonePreviewPhoto photo;
  final ValueChanged<bool> onZoom;
  @override
  State<_MiniPhotoFrame> createState() => _MiniPhotoFrameState();
}

class _MiniPhotoFrameState extends State<_MiniPhotoFrame> {
  final _transform = TransformationController();
  bool _zoomed = false;
  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoom(zoomed);
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_changed);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _transform,
    minScale: 1,
    maxScale: 4,
    panEnabled: _zoomed,
    child: Center(
      child: Stack(
        children: [
          if (widget.photo.bytes != null)
            Image.memory(widget.photo.bytes!, fit: BoxFit.contain)
          else
            Image.asset(
              '$miniPhoneAssets${widget.photo.asset}',
              fit: BoxFit.contain,
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Text(
                '@${widget.photo.author.short}',
                style: miniStyle(12, FontWeight.w600).copyWith(
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
