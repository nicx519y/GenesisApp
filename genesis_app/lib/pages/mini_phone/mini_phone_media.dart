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
          onTap: () => _viewPhoto(asset: miniDemoPhotos[i]),
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
                  draftWallpaperPhoto == null
                      ? Image.asset(
                          '$miniPhoneAssets$draftWallpaper',
                          fit: BoxFit.cover,
                        )
                      : Image.memory(draftWallpaperPhoto!, fit: BoxFit.cover),
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
                            child: Image.asset(
                              '$miniPhoneAssets${w.key}',
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
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

  Future<void> _viewPhoto({String? asset, Uint8List? bytes}) async {
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: miniBackground,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(miniPageInset),
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
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : Image.asset(
                            '$miniPhoneAssets$asset',
                            fit: BoxFit.contain,
                          ),
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
      ),
    );
  }
}
