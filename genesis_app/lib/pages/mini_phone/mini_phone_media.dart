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
    ListView(
      padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 190,
              height: 265,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _wallpaperBackground(draftWallpaper, draftWallpaperPhoto),
                  const ColoredBox(color: Color(0x22000000)),
                  Column(
                    children: [
                      const SizedBox(height: 25),
                      Text('Day 2', style: miniStyle(14)),
                      Text('01:04', style: miniStyle(38, FontWeight.w600)),
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
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Wallpaper', style: miniStyle(14, FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final w in miniDemoWallpapers.entries)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _update(() {
                      draftWallpaper = w.key;
                      draftWallpaperPhoto = null;
                      feedback = '';
                    }),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              width: 2,
                              color:
                                  draftWallpaperPhoto == null &&
                                      draftWallpaper == w.key
                                  ? miniPink
                                  : Colors.transparent,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: _wallpaperBackground(w.key, null),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(w.value, style: miniStyle(14)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => _pickPhoto(wallpaper: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Choose from device', style: miniStyle(14)),
                ),
                const MiniIcon('image', size: 20),
              ],
            ),
          ),
        ),
        _button('Apply wallpaper', () {
          store.applyWallpaper(draftWallpaper, draftWallpaperPhoto);
          _update(() => feedback = 'Wallpaper applied. See it on Home.');
        }, primary: true),
        if (feedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              feedback,
              style: miniStyle(12, FontWeight.w400, miniPink),
            ),
          ),
        const SizedBox(height: 26),
        _button('Reset phone', _confirmReset),
        const SizedBox(height: 20),
      ],
    ),
    subtitle: 'Make this phone feel like yours.',
  );

  Future<void> _pickPhoto({required bool wallpaper}) async {
    final target = screen;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
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
        if (wallpaper) {
          draftWallpaperPhoto = bytes;
        } else {
          draftPhoto = bytes;
        }
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

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: miniRaised,
        title: Text('Reset phone?', style: miniPageTitle),
        content: Text(
          'Clear this phone’s messages, posts, comments and wallpaper.',
          style: miniStyle(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final timer in _replyTimers) {
      timer.cancel();
    }
    _replyTimers.clear();
    store.reset();
    postInput.clear();
    messageInput.clear();
    commentInput.clear();
    draftPhoto = null;
    authorFilter = null;
    expandedNotificationGroups.clear();
    homePagerPosition = 0;
    if (homePages.hasClients) homePages.jumpToPage(0);
    typing = false;
    _go(MiniPhoneScreen.home);
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
    await showDialog<void>(
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
