part of 'mini_phone_page.dart';

class _MiniMusicPlayer extends StatefulWidget {
  const _MiniMusicPlayer({required this.music});
  final MiniPhoneMusicService music;
  @override
  State<_MiniMusicPlayer> createState() => _MiniMusicPlayerState();
}

class _MiniMusicPlayerState extends State<_MiniMusicPlayer> {
  String? _statusFile;
  bool _ready = false;
  String? _shownMusicError;
  MiniPhoneMusicService get _music => widget.music;
  @override
  void initState() {
    super.initState();
    _music.addListener(_changed);
    _music.likes.addListener(_likesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ready = true;
      _loadCatalog();
      _loadLikeStatus();
    });
  }

  Future<void> _loadCatalog() => _music.loadCatalog(
    () => AppServicesScope.read(context).api.fetchMusicCatalog(),
  );

  void _changed() {
    if (!mounted) return;
    final error = _music.catalogError ?? _music.playbackError;
    if (error != _shownMusicError) {
      _shownMusicError = error;
      if (error != null) showGenesisToast(context, error);
    }
    setState(() {});
    if (_ready) _loadLikeStatus();
  }

  void _likesChanged() {
    if (mounted) setState(() {});
  }

  void _loadLikeStatus() {
    final file = _music.track?.file;
    if (file == null || file == _statusFile) return;
    _statusFile = file;
    final api = AppServicesScope.read(context).api;
    unawaited(() async {
      try {
        await _music.likes.loadStatus(
          file,
          () => api.fetchMusicLikeStatus(file: file),
        );
      } catch (error) {
        if (mounted && _music.track?.file == file) _likeError(error);
      }
    }());
  }

  void _likeError(Object error) => showGenesisToast(
    context,
    error is ApiException
        ? error.message
        : 'Unable to update music like status. Please retry.',
    brightness: Brightness.dark,
  );

  Future<void> _toggleLike(String file) async {
    final api = AppServicesScope.read(context).api;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    try {
      await _music.likes.toggle(
        file,
        (liked) =>
            liked ? api.likeMusic(file: file) : api.unlikeMusic(file: file),
      );
    } catch (error) {
      if (overlay != null && overlay.mounted) {
        showGenesisToastInOverlay(
          overlay,
          error is ApiException
              ? error.message
              : 'Unable to update music like status. Please retry.',
          brightness: Brightness.dark,
        );
      }
    }
  }

  @override
  void dispose() {
    _music.removeListener(_changed);
    _music.likes.removeListener(_likesChanged);
    super.dispose();
  }

  void _next() => _music.next();
  void _previous() => _music.previous();
  void _togglePlay() => _music.toggle();

  @override
  Widget build(BuildContext context) {
    final track = _music.track;
    if (track == null) {
      return GenesisRefreshIndicator(
        onRefresh: _loadCatalog,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [],
        ),
      );
    }
    final liked = _music.likes.isLiked(track.file);
    return LayoutBuilder(
      builder: (context, bounds) {
        final availableWidth = (bounds.maxWidth - 52).clamp(0.0, 320.0);
        final coverWidth = ((bounds.maxHeight - 250) / 1.5)
            .clamp(80.0, 320.0)
            .clamp(0.0, availableWidth);
        return GenesisRefreshIndicator(
          onRefresh: _loadCatalog,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 4, 26, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  children: [
                    MiniMusicCover(
                      track: track,
                      nextTrack: _music.nextTrack,
                      preloadNext:
                          _music.playing &&
                          _music.foreground &&
                          !_music.loading,
                      width: coverWidth,
                      height: coverWidth * 1.5,
                      radius: 16,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MiniMusicMarquee(
                                identity: (track.file, 'title'),
                                text: track.title,
                                style: miniStyle(
                                  24,
                                  FontWeight.w700,
                                ).copyWith(height: 1.2, letterSpacing: -.7),
                              ),
                              const SizedBox(height: 6),
                              MiniMusicMarquee(
                                identity: (track.file, 'artist'),
                                text: track.artist,
                                style: miniStyle(
                                  12,
                                  FontWeight.w400,
                                  miniSecondary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              MiniMusicMarquee(
                                identity: (track.file, 'worldo'),
                                text:
                                    'From ${originDisplayName(track.sourceWorldoName)}',
                                style: miniStyle(
                                  12,
                                  FontWeight.w400,
                                  miniSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Semantics(
                          button: true,
                          toggled: liked,
                          label: '${liked ? 'Unlike' : 'Like'} ${track.title}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => unawaited(_toggleLike(track.file)),
                            child: SizedBox(
                              width: 44,
                              height: 54,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MiniIcon(
                                    'heart',
                                    size: 23,
                                    color: liked ? miniPink : miniWhite,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MiniMusicSeekBar(
                      identity: track.file,
                      position: _music.positionDuration,
                      duration: _music.durationDuration,
                      buffered: _music.bufferedPosition,
                      enabled: _music.canSeek,
                      onSeek: _music.seekTo,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _control('music-backward', 'Previous track', _previous),
                        const SizedBox(width: 38),
                        Semantics(
                          toggled: _music.playRequested,
                          label: _music.playRequested ? 'Pause' : 'Play',
                          button: true,
                          child: IconButton(
                            onPressed: _togglePlay,
                            style: IconButton.styleFrom(
                              backgroundColor: miniRed,
                              minimumSize: const Size(64, 64),
                              maximumSize: const Size(64, 64),
                            ),
                            icon: Transform.translate(
                              offset: Offset(_music.playRequested ? 0 : 2, 0),
                              child: MiniIcon(
                                _music.playRequested
                                    ? 'music-pause'
                                    : 'music-play',
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 38),
                        _control('music-forward', 'Next track', _next),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _control(String icon, String label, VoidCallback action) => IconButton(
    tooltip: label,
    onPressed: _music.loading ? null : action,
    constraints: const BoxConstraints.tightFor(width: 44, height: 48),
    padding: EdgeInsets.zero,
    icon: MiniIcon(icon, size: 28),
  );
}

/// Home controls share the Music app's foreground player and catalogue.
class _MiniHomeMusicCard extends StatelessWidget {
  const _MiniHomeMusicCard({required this.onOpen, required this.music});
  final MiniPhoneMusicService music;
  final VoidCallback onOpen;

  Widget _control(String icon, String label, VoidCallback onTap) => IconButton(
    tooltip: label,
    onPressed: music.loading ? null : onTap,
    constraints: const BoxConstraints.tightFor(width: 48, height: 40),
    padding: EdgeInsets.zero,
    icon: MiniIcon(icon, size: 24),
  );

  @override
  Widget build(BuildContext context) {
    final track = music.track;
    if (track == null) return const SizedBox.shrink();
    return MiniGlass(
      key: const ValueKey('mini-phone-home-music'),
      light: true,
      outlined: false,
      opacity: .36,
      radius: 21,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Open Music: ${track.title}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Row(
                children: [
                  MiniMusicCover(
                    track: track,
                    nextTrack: music.nextTrack,
                    preloadNext:
                        music.playing && music.foreground && !music.loading,
                    width: 44,
                    height: 66,
                    radius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MiniMusicMarquee(
                          identity: (track.file, 'title'),
                          text: track.title,
                          style: miniStyle(16, FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        MiniMusicMarquee(
                          identity: (track.file, 'artist'),
                          text: track.artist,
                          style: miniStyle(14, FontWeight.w400, miniSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          MiniMusicSeekBar(
            identity: track.file,
            compact: true,
            position: music.positionDuration,
            duration: music.durationDuration,
            buffered: music.bufferedPosition,
            enabled: music.canSeek,
            onSeek: music.seekTo,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _control('music-backward', 'Previous track', music.previous),
              const SizedBox(width: 20),
              Semantics(
                toggled: music.playRequested,
                child: IconButton(
                  tooltip: music.playRequested ? 'Pause' : 'Play',
                  onPressed: music.toggle,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(48, 40),
                    maximumSize: const Size(48, 40),
                  ),
                  icon: Transform.translate(
                    offset: Offset(music.playRequested ? 0 : 2, 0),
                    child: MiniIcon(
                      music.playRequested ? 'music-pause' : 'music-play',
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              _control('music-forward', 'Next track', music.next),
            ],
          ),
        ],
      ),
    );
  }
}
