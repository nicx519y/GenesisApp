import '../../../l10n/genesis_localizations.dart';
import 'dart:async';
import '../../../utils/display_name_formatter.dart';
import 'package:flutter/material.dart';
import '../../../app/bootstrap/app_services_scope.dart';
import '../../../components/common/genesis_center_toast.dart';
import '../../../network/api_exception.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_music_service.dart';
import 'mini_phone_music_widgets.dart';

class MiniPhoneMusicPlayer extends StatefulWidget {
  const MiniPhoneMusicPlayer({super.key, required this.music});
  final MiniPhoneMusicService music;
  @override
  State<MiniPhoneMusicPlayer> createState() => MiniPhoneMusicPlayerState();
}

class MiniPhoneMusicPlayerState extends State<MiniPhoneMusicPlayer> {
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
        : context.l10n.miniPhoneMusicLikeFailed,
    brightness: Brightness.dark,
  );

  Future<void> _toggleLike(String file) async {
    final api = AppServicesScope.read(context).api;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    try {
      _music.trackLike(file, !_music.likes.isLiked(file));
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
              : context.l10n.miniPhoneMusicLikeFailed,
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

  void _next() => _music.userNext('music');
  void _previous() => _music.userPrevious('music');
  void _togglePlay() => _music.userToggle('music');

  @override
  Widget build(BuildContext context) {
    final track = _music.track;
    if (track == null) {
      return const SizedBox.expand();
    }
    final liked = _music.likes.isLiked(track.file);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 12),
      child: LayoutBuilder(
        builder: (context, bounds) {
          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, coverBounds) => MiniMusicCover(
                    track: track,
                    nextTrack: _music.nextTrack,
                    preloadNext:
                        _music.playing && _music.foreground && !_music.loading,
                    width: coverBounds.maxWidth,
                    height: coverBounds.maxHeight,
                    radius: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Reserve cover space on short screens while keeping controls visible.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (bounds.maxHeight * .7 - 16).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: bounds.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MiniMusicMarquee(
                                identity: (track.file, 'title'),
                                text: track.title,
                                style: miniStyle(
                                  20,
                                  FontWeight.w700,
                                ).copyWith(height: 1.3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              toggled: liked,
                              child: IconButton(
                                tooltip: liked
                                    ? context.l10n.miniPhoneUnlikeTrack(
                                        title: track.title,
                                      )
                                    : context.l10n.miniPhoneLikeTrack(
                                        title: track.title,
                                      ),
                                onPressed: () =>
                                    unawaited(_toggleLike(track.file)),
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                padding: EdgeInsets.zero,
                                icon: MiniIcon(
                                  'heart',
                                  size: 23,
                                  color: liked ? miniPink : miniWhite,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MiniMusicMarquee(
                            identity: (track.file, 'artist'),
                            text: track.artist,
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MiniMusicMarquee(
                            identity: (track.file, 'worldo'),
                            text: context.l10n.miniPhoneFromWorldo(
                              name: originDisplayName(track.sourceWorldoName),
                            ),
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
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
                            _control(
                              'music-backward',
                              context.l10n.miniPhonePreviousTrack,
                              _previous,
                            ),
                            const SizedBox(width: 38),
                            Semantics(
                              toggled: _music.playRequested,
                              label: _music.playRequested
                                  ? context.l10n.miniPhonePause
                                  : context.l10n.miniPhonePlay,
                              button: true,
                              child: IconButton(
                                onPressed: _togglePlay,
                                style: IconButton.styleFrom(
                                  backgroundColor: miniRed,
                                  minimumSize: const Size(64, 64),
                                  maximumSize: const Size(64, 64),
                                ),
                                icon: Transform.translate(
                                  offset: Offset(
                                    _music.playRequested ? 0 : 2,
                                    0,
                                  ),
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
                            _control(
                              'music-forward',
                              context.l10n.miniPhoneNextTrack,
                              _next,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
class MiniPhoneHomeMusicCard extends StatelessWidget {
  const MiniPhoneHomeMusicCard({
    super.key,
    required this.onOpen,
    required this.music,
  });
  final MiniPhoneMusicService music;
  final VoidCallback onOpen;

  Widget _control(String icon, String label, VoidCallback onTap) => IconButton(
    tooltip: label,
    onPressed: music.loading ? null : onTap,
    style: IconButton.styleFrom(
      fixedSize: const Size(48, 40),
      padding: EdgeInsets.zero,
      alignment: Alignment.center,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
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
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: context.l10n.miniPhoneOpenMusic(title: track.title),
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
                        const SizedBox(height: 2),
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
              _control(
                'music-backward',
                context.l10n.miniPhonePreviousTrack,
                () => music.userPrevious('home'),
              ),
              const SizedBox(width: 20),
              Semantics(
                toggled: music.playRequested,
                child: IconButton(
                  tooltip: music.playRequested
                      ? context.l10n.miniPhonePause
                      : context.l10n.miniPhonePlay,
                  onPressed: () => music.userToggle('home'),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(48, 40),
                    maximumSize: const Size(48, 40),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              _control(
                'music-forward',
                context.l10n.miniPhoneNextTrack,
                () => music.userNext('home'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
