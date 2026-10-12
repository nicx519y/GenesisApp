import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../../network/models/music.dart';
import 'mini_phone_music_likes.dart';

final miniPhoneMusic = MiniPhoneMusicService();

/// A single foreground session with at most two native decoders. The standby
/// decoder prepares the next track without playing or downloading a disk copy.
class MiniPhoneMusicService extends ChangeNotifier with WidgetsBindingObserver {
  MiniPhoneMusicService({AudioPlayer Function()? playerFactory})
    : _playerFactory = playerFactory ?? _createPlayer {
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  static AudioPlayer _createPlayer() => AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 5),
        maxBufferDuration: Duration(seconds: 5),
        bufferForPlaybackDuration: Duration(seconds: 1),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        prioritizeTimeOverSizeThresholds: true,
      ),
      darwinLoadControl: DarwinLoadControl(
        preferredForwardBufferDuration: Duration(seconds: 5),
      ),
    ),
  );

  final AudioPlayer Function() _playerFactory;
  final likes = MiniPhoneMusicLikes();
  _MusicDecoder? _active;
  _MusicDecoder? _standby;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void>? _catalogPending;
  Future<void> _commands = Future.value();
  MusicCatalog? _catalog;
  int _index = 0;
  int _selectionRevision = 0;
  bool _busy = false;
  bool _switching = false;
  bool _wantPlay = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _advanceScheduled = false;
  bool activated = false;
  bool catalogLoading = false;
  String? catalogError;
  String? playbackError;

  List<MusicTrack> get tracks => _catalog?.tracks ?? const [];
  int get index => _index.clamp(0, tracks.isEmpty ? 0 : tracks.length - 1);
  MusicTrack? get track => tracks.isEmpty ? null : tracks[index];
  MusicTrack? get nextTrack =>
      tracks.length < 2 ? null : tracks[(index + 1) % tracks.length];
  bool get foreground => _foreground;
  AudioPlayer? get _current =>
      _active?.trackIndex == index ? _active?.player : null;
  Duration get positionDuration => _current?.position ?? Duration.zero;
  Duration? get durationDuration => _current?.duration;
  Duration get bufferedPosition => _current?.bufferedPosition ?? Duration.zero;
  int get position => positionDuration.inSeconds;
  int? get duration => durationDuration?.inSeconds;
  bool get playing => _current?.playing ?? false;
  bool get playRequested => _wantPlay || playing;
  bool get loading =>
      _busy ||
      _switching ||
      (playbackError == null &&
          (_current?.processingState == ProcessingState.loading ||
              _current?.processingState == ProcessingState.buffering));
  bool get canSeek =>
      !_busy &&
      !_switching &&
      (_active?.ready ?? false) &&
      (durationDuration?.inMilliseconds ?? 0) > 0;

  Future<void> loadCatalog(Future<MusicCatalog> Function() loader) {
    if (_disposed || _catalog != null) return Future.value();
    return _catalogPending ??= Future.microtask(() => _loadCatalog(loader));
  }

  Future<void> _loadCatalog(Future<MusicCatalog> Function() loader) async {
    catalogLoading = true;
    catalogError = null;
    _notify();
    try {
      final catalog = await loader();
      if (!_disposed) _catalog = catalog;
    } catch (_) {
      if (!_disposed) catalogError = 'Unable to load music. Please retry.';
    } finally {
      catalogLoading = false;
      _catalogPending = null;
      _notify();
    }
  }

  _MusicDecoder _ensureActive() {
    if (_active == null) {
      _active = _MusicDecoder(_playerFactory());
      _bindActive();
    }
    return _active!;
  }

  void _bindActive() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final decoder = _active!;
    bool current() =>
        !_disposed &&
        identical(_active, decoder) &&
        decoder.trackIndex == index;
    void changed() {
      if (!current()) return;
      _notify();
      _maybeAdvance();
      _maybePreload();
    }

    _subscriptions.addAll([
      decoder.player.playerStateStream.listen((state) {
        if (!current()) return;
        if (!_busy &&
            !_switching &&
            state.processingState != ProcessingState.completed) {
          _wantPlay = state.playing;
        }
        changed();
      }),
      decoder.player.durationStream.listen((_) => changed()),
      decoder.player.positionStream.listen((_) => changed()),
      decoder.player.bufferedPositionStream.listen((_) => changed()),
      decoder.player.errorStream.listen((_) {
        if (current()) _failed();
      }),
    ]);
  }

  Future<void> _prepareDecoder(_MusicDecoder decoder, int target) {
    if (decoder.trackIndex == target) {
      if (decoder.ready) return Future.value();
      if (decoder.pending != null) return decoder.pending!;
    }
    final generation = ++decoder.generation;
    decoder.trackIndex = target;
    decoder.ready = false;
    decoder.failed = false;
    final pending = () async {
      await decoder.stopping;
      if (_disposed || decoder.generation != generation) return;
      await decoder.player.setLoopMode(LoopMode.off);
      await decoder.player.setAudioSources([
        AudioSource.uri(Uri.parse(tracks[target].audioUrl)),
      ], initialPosition: Duration.zero);
      if (!_disposed && decoder.generation == generation) decoder.ready = true;
    }();
    decoder.pending = pending;
    return pending.whenComplete(() {
      if (identical(decoder.pending, pending)) decoder.pending = null;
    });
  }

  void _maybePreload() {
    if (_disposed ||
        _busy ||
        _switching ||
        !_foreground ||
        !_wantPlay ||
        !playing ||
        _current?.processingState != ProcessingState.ready ||
        tracks.length < 2) {
      return;
    }
    final target = (index + 1) % tracks.length;
    final decoder = _standby ??= _MusicDecoder(_playerFactory());
    if (decoder.trackIndex == target &&
        (decoder.ready || decoder.pending != null || decoder.failed)) {
      return;
    }
    final preparation = _prepareDecoder(decoder, target);
    final generation = decoder.generation;
    unawaited(
      preparation.catchError((Object _) {
        if (!_disposed && decoder.generation == generation) {
          decoder.failed = true;
        }
        // Standby failures never change the current song's error/playing state.
      }),
    );
  }

  void _maybeAdvance() {
    if (_disposed ||
        _busy ||
        _switching ||
        _advanceScheduled ||
        !_foreground ||
        !_wantPlay ||
        _current?.processingState != ProcessingState.completed) {
      return;
    }
    _advanceScheduled = true;
    final revision = _selectionRevision;
    scheduleMicrotask(() {
      _advanceScheduled = false;
      if (!_disposed &&
          revision == _selectionRevision &&
          _foreground &&
          _wantPlay &&
          _current?.processingState == ProcessingState.completed) {
        unawaited(next());
      }
    });
  }

  Future<void> _run(Future<void> Function() action, {int? revision}) {
    if (_disposed || tracks.isEmpty) return Future.value();
    final expected = revision ?? _selectionRevision;
    _commands = _commands.then((_) async {
      if (_disposed || expected != _selectionRevision) return;
      _busy = true;
      playbackError = null;
      _notify();
      try {
        await action();
      } on PlayerInterruptedException {
        // An obsolete load was interrupted by selection/lifecycle cancellation.
      } catch (_) {
        if (!_disposed && expected == _selectionRevision) _failed();
      } finally {
        _busy = false;
        if (expected == _selectionRevision) _switching = false;
        _notify();
        _maybeAdvance();
        _maybePreload();
      }
    });
    return _commands;
  }

  void _playActive() {
    final decoder = _active;
    if (_disposed ||
        !_foreground ||
        !_wantPlay ||
        decoder == null ||
        !decoder.ready) {
      return;
    }
    final revision = _selectionRevision;
    unawaited(
      decoder.player.play().catchError((Object _) {
        if (!_disposed &&
            identical(_active, decoder) &&
            revision == _selectionRevision) {
          _failed();
        }
      }),
    );
  }

  Future<void> toggle() {
    if (_disposed || tracks.isEmpty || !_foreground) return Future.value();
    activated = true;
    if (playRequested) return pause();
    _wantPlay = true;
    _notify();
    return _run(() async {
      final decoder = _ensureActive();
      await _prepareDecoder(decoder, index);
      if (decoder.player.processingState == ProcessingState.completed) {
        await decoder.player.seek(Duration.zero);
      }
      _playActive();
    });
  }

  Future<void> pause() async {
    _wantPlay = false;
    _notify();
    try {
      await _active?.player.pause();
    } catch (_) {
      _failed();
    }
    _notify();
  }

  Future<void> seek(int seconds) => seekTo(Duration(seconds: seconds));
  Future<void> seekTo(Duration value) => _run(() async {
    final duration = durationDuration;
    if (!(_active?.ready ?? false) || duration == null) return;
    final position = Duration(
      milliseconds: value.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await _active!.player.seek(position);
  });

  Future<void> next() =>
      _switchTo(tracks.isEmpty ? 0 : (index + 1) % tracks.length);
  Future<void> previous() {
    if (positionDuration > const Duration(seconds: 3)) {
      return _switchTo(index);
    }
    return _switchTo(
      tracks.isEmpty ? 0 : (index + tracks.length - 1) % tracks.length,
    );
  }

  Future<void> _switchTo(int target) {
    if (_disposed || tracks.isEmpty) return Future.value();
    activated = true;
    _wantPlay = _foreground;
    if (target == index && (_active?.ready ?? false) && !_switching) {
      return _run(() async {
        await _active!.player.seek(Duration.zero);
        _playActive();
      });
    }
    _switching = true;
    final revision = ++_selectionRevision;
    _index = target;
    // Clear the old decoder's visible position/buffer and stop its sound now,
    // rather than waiting for the replacement song or image to load.
    final stopping = _cancelDecoder(_active);
    if (_standby != null && _standby!.trackIndex != target) {
      unawaited(_cancelDecoder(_standby));
    }
    _notify();
    return _run(() async {
      await stopping;
      if (_disposed || revision != _selectionRevision) return;
      final decoder = _standby ?? _ensureActive();
      try {
        await _prepareDecoder(decoder, target);
      } catch (_) {
        if (decoder.failed || identical(decoder, _standby)) {
          await _cancelDecoder(decoder);
          await _prepareDecoder(decoder, target);
        } else {
          rethrow;
        }
      }
      if (_disposed || revision != _selectionRevision) return;
      if (!identical(decoder, _active)) {
        final old = _active;
        _active = decoder;
        _standby = old;
        _bindActive();
      }
      _playActive();
    }, revision: revision);
  }

  Future<void> _cancelDecoder(_MusicDecoder? decoder) {
    if (decoder == null) return Future.value();
    decoder.generation++;
    decoder.ready = false;
    decoder.trackIndex = null;
    decoder.failed = false;
    decoder.stopping = decoder.player.stop().catchError((Object _) {});
    return decoder.stopping;
  }

  void resetPausedOnWorldExit() {
    if (playRequested || !activated) return;
    activated = false;
    _selectionRevision++;
    _switching = false;
    _index = 0;
    unawaited(_cancelDecoder(_active));
    unawaited(_cancelDecoder(_standby));
    _notify();
  }

  void _failed() {
    if (_disposed) return;
    _wantPlay = false;
    _active?.ready = false;
    playbackError = 'Unable to play this track. Tap play to retry.';
    unawaited(
      _active?.player.pause().catchError((Object _) {}) ?? Future.value(),
    );
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      unawaited(pause());
      final standby = _standby;
      if (standby != null && standby.trackIndex != null) {
        final duration = standby.player.duration;
        final target = duration != null && duration < const Duration(seconds: 5)
            ? duration
            : const Duration(seconds: 5);
        // setAudioSources can finish before the native buffer reaches its target.
        if (standby.pending != null ||
            standby.player.bufferedPosition < target) {
          unawaited(_cancelDecoder(standby));
        }
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    likes.dispose();
    _selectionRevision++;
    _wantPlay = false;
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    for (final decoder in [_active, _standby]) {
      if (decoder != null) {
        decoder.generation++;
        unawaited(decoder.player.dispose());
      }
    }
    super.dispose();
  }
}

class _MusicDecoder {
  _MusicDecoder(this.player);
  final AudioPlayer player;
  int? trackIndex;
  int generation = 0;
  bool ready = false;
  bool failed = false;
  Future<void>? pending;
  Future<void> stopping = Future.value();
}
