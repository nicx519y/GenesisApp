part of 'mini_phone_preview.dart';

extension _MiniPhoneMedia on _MiniPhonePreviewState {
  Widget _photos() => _panel(
    'Photos',
    GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: miniDemoPhotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemBuilder: (context, i) => Semantics(
        label: 'Open photo ${i + 1}',
        button: true,
        child: GestureDetector(
          onTap: () => _viewPhoto(galleryIndex: i),
          child: Image.asset(
            '$miniPhoneAssets${miniDemoPhotos[i]}',
            fit: BoxFit.cover,
          ),
        ),
      ),
    ),
  );

  Future<void> _pickPhoto({required bool wallpaper}) async {
    final target = screen;
    if (!mounted) return;
    try {
      final file = await systemImagePickerActivity.run(
        () => ImagePicker().pickImage(source: ImageSource.gallery),
      );
      if (file == null || !mounted || screen != target) return;
      final bytes = await file.readAsBytes();
      if (!mounted || screen != target) return;
      if (bytes.length > 3 * 1024 * 1024) {
        _update(() => feedback = 'Choose an image smaller than 3 MB.');
        return;
      }
      final png =
          bytes.length > 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47;
      final jpg =
          bytes.length > 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      final webp =
          bytes.length > 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      if (!png && !jpg && !webp) {
        _update(() => feedback = 'Please choose a JPG, PNG or WebP image.');
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 600);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      if (!mounted || screen != target) return;
      _update(() {
        draftPhoto = bytes;
        feedback = '';
      });
    } catch (_) {
      if (mounted && screen == target) {
        _update(
          () => feedback = 'Could not open this photo. Please try another.',
        );
      }
    }
  }

  Future<void> _viewPhoto({
    String? asset,
    Uint8List? bytes,
    MiniDemoPerson? author,
    int? galleryIndex,
  }) async {
    final photos = galleryIndex != null
        ? [
            for (var i = 0; i < miniDemoPhotos.length; i++)
              MiniPhonePreviewPhoto(
                asset: miniDemoPhotos[i],
                author: miniDemoPhotoAuthors[i],
              ),
          ]
        : [
            MiniPhonePreviewPhoto(
              asset: asset,
              bytes: bytes,
              author: author ?? miniDemoMe,
            ),
          ];
    await _openPhotoGallery(photos, galleryIndex ?? 0);
  }

  Future<void> _openPhotoGallery(
    List<MiniPhonePreviewPhoto> photos,
    int index,
  ) => showMiniPhonePreviewGallery(
    context,
    widget.session,
    photos,
    index,
    onClose: widget.onClose,
  );
}
