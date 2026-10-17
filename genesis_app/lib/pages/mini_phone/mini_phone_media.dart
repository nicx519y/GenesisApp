part of 'mini_phone_page.dart';

extension _MiniPhoneMedia on _MiniPhonePageState {
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

  Widget _settings() => _panel(
    'Settings',
    GenesisRefreshIndicator(
      onRefresh: wallpaper.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: miniPhoneWallpaperPreviewWidth,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _wallpaperBackground(
                        wallpaper.draftImage,
                        wallpaper.draftPhoto?.bytes ??
                            wallpaper.appliedPreviewBytes,
                        settingsPreview: true,
                      ),
                      const ColoredBox(color: Color(0x22000000)),
                      Column(
                        children: [
                          const SizedBox(height: 25),
                          Text(
                            phone?.worldDay ?? 'Day 2',
                            textScaler: TextScaler.noScaling,
                            style: miniStyle(14),
                          ),
                          Text(
                            phone?.clockTime ?? '01:04',
                            textScaler: TextScaler.noScaling,
                            style: miniStyle(38, FontWeight.w600),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final i in [
                                  'messages',
                                  'posts',
                                  'photos',
                                  'settings',
                                ])
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: miniRaised,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: MiniIcon(i, size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (wallpaper.saving || wallpaper.saveProgress == 1)
                        IgnorePointer(
                          child: GenesisUploadProgressOverlay(
                            progress: wallpaper.saveProgress,
                            showIndicator: false,
                            revealFromBottom: true,
                            animationDuration: const Duration(
                              milliseconds: 180,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Wallpaper', style: miniStyle(14, FontWeight.w600)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (wallpaper.wallpapers.length + 1).clamp(
                1,
                constraints.maxWidth < 280 ? 2 : 4,
              );
              final width = (constraints.maxWidth - columns * 8) / columns;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        selected: wallpaper.draftPhoto != null,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  width: 2,
                                  color: wallpaper.draftPhoto != null
                                      ? miniPink
                                      : Colors.transparent,
                                ),
                              ),
                              child: Material(
                                color: GenesisColors.darkCardBackground,
                                borderRadius: BorderRadius.circular(8),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap:
                                      !wallpaper.available ||
                                          wallpaper.saving ||
                                          _authorizingWallpaper
                                      ? null
                                      : () => _pickPhoto(wallpaper: true),
                                  child: const SizedBox(
                                    height: 100,
                                    width: double.infinity,
                                    child: Center(
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 24,
                                        color: miniPink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('Upload', style: miniStyle(14)),
                          ],
                        ),
                      ),
                    ),
                    for (final w in wallpaper.wallpapers)
                      SizedBox(
                        width: width,
                        child: Semantics(
                          button: true,
                          selected:
                              wallpaper.draftPhoto == null &&
                              wallpaper.draftImage == w.imageUrl,
                          child: InkWell(
                            onTap: wallpaper.saving || _authorizingWallpaper
                                ? null
                                : () {
                                    wallpaper.select(w.imageUrl);
                                    _update(() => feedback = '');
                                  },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      width: 2,
                                      color:
                                          wallpaper.draftPhoto == null &&
                                              wallpaper.draftImage == w.imageUrl
                                          ? miniPink
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 100,
                                      width: double.infinity,
                                      child: MiniPhoneWallpaperPreview(
                                        key: ValueKey(w.imageUrl),
                                        url: w.imageUrl,
                                        placeholder: const ColoredBox(
                                          color: miniRaised,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  w.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _button(
            'Apply wallpaper',
            !wallpaper.available ||
                    wallpaper.saving ||
                    _authorizingWallpaper ||
                    (!wallpaper.loaded && wallpaper.draftPhoto == null)
                ? null
                : _applyWallpaper,
            primary: true,
            isLoading: wallpaper.saving,
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
    subtitle: 'Make this phone feel like yours.',
  );

  Future<void> _pickPhoto({required bool wallpaper}) async {
    if (wallpaper) return _pickWallpaperPhoto();
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

  Future<void> _pickWallpaperPhoto() async {
    final target = screen;
    final revision = wallpaper.identityRevision;
    bool isCurrent() =>
        mounted &&
        screen == target &&
        wallpaper.identityRevision == revision &&
        !wallpaper.saving &&
        !_authorizingWallpaper;
    if (!isCurrent()) return;
    try {
      final owner = await wallpaper.sessionStore.readLoginUid();
      if (!isCurrent()) return;
      final picked = await pickGenesisImages(limit: 1);
      if (picked.isEmpty || !mounted || !isCurrent()) return;
      final crop = await _session.push<LocalImageCropResult>(
        context,
        MaterialPageRoute<LocalImageCropResult>(
          builder: (_) => LocalImageCropPage(
            imageBytes: picked.first.bytes,
            // Match the Location cover's crop, scaling and encoding pipeline.
            cropSize: const Size(1500, 3000),
            filename: 'wallpaper.png',
            contentType: 'image/png',
            uploadOnConfirm: false,
            deferUploadPreparation: true,
          ),
        ),
      );
      if (crop == null || !isCurrent()) return;
      final currentOwner = await wallpaper.sessionStore.readLoginUid();
      if (currentOwner != owner || !isCurrent()) return;
      _update(() {
        wallpaper.selectPhoto(
          MiniWallpaperPhoto(
            bytes: crop.bytes,
            filename: crop.filename,
            contentType: crop.contentType,
            prepareUpload: crop.prepareUpload == null
                ? null
                : (onProgress) async {
                    // Paint the full cover before starting image preparation.
                    await WidgetsBinding.instance.endOfFrame;
                    final prepared = await crop.prepareUpload!(onProgress);
                    return MiniWallpaperPhoto(
                      bytes: prepared.bytes,
                      filename: prepared.filename,
                      contentType: prepared.contentType,
                    );
                  },
          ),
        );
        feedback = '';
      });
    } on UnsupportedGifImageException {
      if (mounted && isCurrent()) {
        showGenesisToast(context, unsupportedGifImageMessage);
      }
    } catch (_) {
      if (mounted && isCurrent()) {
        showGenesisToast(
          context,
          'Could not open this photo. Please try another.',
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
              _MiniPhotoItem(
                asset: miniDemoPhotos[i],
                author: miniDemoPhotoAuthors[i],
              ),
          ]
        : [
            _MiniPhotoItem(
              asset: asset,
              bytes: bytes,
              author: author ?? miniDemoMe,
            ),
          ];
    await _openPhotoGallery(photos, galleryIndex ?? 0);
  }

  Future<void> _openPhotoGallery(List<_MiniPhotoItem> photos, int index) async {
    _miniResume.viewerPhotos = photos;
    _miniResume.viewerIndex = index;
    await _session.push<void>(
      context,
      DialogRoute<void>(
        context: context,
        useSafeArea: false,
        builder: (dialogContext) => _MiniPhotoGallery(
          photos: photos,
          initialIndex: index,
          onIndex: (index) => _miniResume.viewerIndex = index,
          onClose: () {
            Navigator.of(dialogContext).pop();
            _close();
          },
        ),
      ),
    );
    if (!_closing) _miniResume.viewerPhotos = null;
  }
}

class _MiniPhotoItem {
  const _MiniPhotoItem({this.asset, this.bytes, required this.author});
  final String? asset;
  final Uint8List? bytes;
  final MiniDemoPerson author;
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
  final List<_MiniPhotoItem> photos;
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
  final _MiniPhotoItem photo;
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
