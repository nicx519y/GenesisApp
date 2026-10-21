import '../../../l10n/genesis_l10n.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import '../../../network/models/music.dart';
import '../../../platform/system_image_picker_activity.dart';
import 'mini_phone_music_likes.dart';
import '../state/mini_phone_analytics.dart';
import 'mini_phone_music_progress.dart';
import 'mini_phone_music_cache.dart';

/// A single foreground session with at most two native decoders. The standby
/// decoder prepares the next track without playing. Only played tracks are
/// added to the persistent audio cache.
class MiniPhoneMusicService extends ChangeNotifier with WidgetsBindingObserver {
  MiniPhoneMusicService({
    AudioPlayer Function()? playerFactory,
    MiniPhoneMusicProgressStore? progressStore,
    MiniPhoneMusicCache? audioCache,
    SystemImagePickerActivity? pickerActivity,
  }) : _playerFactory = playerFactory ?? _createPlayer,
       _progressStore = progressStore,
       _audioCache = audioCache ?? LocalMiniPhoneMusicCache.shared,
       _pickerActivity = pickerActivity ?? systemImagePickerActivity {
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = lifecycle ?? AppLifecycleState.resumed;
    _pickerActivity.addListener(_pickerChanged);
    _restorePending = _progressStore == null
        ? Future.value()
        : _restoreProgress();
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

  MiniPhoneAnalytics? analytics;
  final AudioPlayer Function() _playerFactory;
  final MiniPhoneMusicProgressStore? _progressStore;
  final MiniPhoneMusicCache _audioCache;
  Duration? _pendingSeek;
  int _seekRevision = 0;
  final SystemImagePickerActivity _pickerActivity;
  late final Future<void> _restorePending;
  MiniPhoneMusicProgress? _restoredProgress;
  Duration _resumePosition = Duration.zero;
  Duration? _resumeDuration;
  Timer? _saveTimer;
  Future<void> _savePending = Future.value();
  Future<void> _releasePending = Future.value();
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  bool get isDisposed => _disposed;
  Future<void> get released => _releasePending;
  Future<void> get progressSaved => _savePending;
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
  bool _worldAttached = true;
  bool _disposed = false;
  bool _advanceScheduled = false;
  bool activated = false;
  bool _entrySuppressed = false;

  /// Entry controls belong to the current World, independently of saved music.
  bool get entryActivated => activated && !_entrySuppressed;
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
  Duration get positionDuration =>
      _pendingSeek ??
      ((_active?.ready ?? false)
          ? _current?.position ?? _resumePosition
          : _resumePosition);
  Duration? get durationDuration => _current?.duration ?? _resumeDuration;
  Duration get bufferedPosition => (_active?.ready ?? false)
      ? _current?.bufferedPosition ?? Duration.zero
      : Duration.zero;
  int get position => positionDuration.inSeconds;
  int? get duration => durationDuration?.inSeconds;
  bool get playing => !_disposed && (_current?.playing ?? false);
  bool get playRequested => !_disposed && (_wantPlay || playing);
  bool get loading =>
      _busy ||
      _switching ||
      (playbackError == null &&
          (_current?.processingState == ProcessingState.loading ||
              _current?.processingState == ProcessingState.buffering));
  bool get canSeek =>
      _worldAttached &&
      !_disposed &&
      (durationDuration?.inMilliseconds ?? 0) > 0;

  void attachWorld() {
    if (_disposed) return;
    _worldAttached = true;
    _entrySuppressed = true;
    _notify();
  }

  /// Retain ready decoders and catalogue, but revoke old World playback work.
  void detachWorld() {
    if (_disposed || !_worldAttached) return;
    _worldAttached = false;
    _selectionRevision++;
    _switching = false;
    final hadPendingSeek = _pendingSeek != null;
    _resumePosition = positionDuration;
    _resumeDuration = durationDuration;
    _pendingSeek = null;
    _seekRevision++;
    final pending = <Future<void>>[];
    for (final decoder in [_active, _standby]) {
      if (decoder != null &&
          (!decoder.ready || (hadPendingSeek && identical(decoder, _active)))) {
        pending.add(_cancelDecoder(decoder));
      }
    }
    pending.add(pause());
    // A newly attached World must wait for the previous native pause/stop.
    final settled = Future.wait(pending);
    _commands = _commands.then((_) => settled).then((_) {});
  }

  Future<void> loadCatalog(Future<MusicCatalog> Function() loader) {
    if (_disposed || _catalog != null) return Future.value();
    return refreshLikes(loader);
  }

  /// Refresh engagement without replacing cached tracks or native decoders.
  Future<void> refreshLikes(Future<MusicCatalog> Function() loader) {
    if (_disposed) return Future.value();
    return _catalogPending ??= Future.microtask(() => _loadCatalog(loader));
  }

  Future<void> _loadCatalog(Future<MusicCatalog> Function() loader) async {
    final snapshot = likes.beginSnapshot();
    catalogLoading = true;
    catalogError = null;
    _notify();
    try {
      final catalog = await loader();
      await _restorePending;
      if (!_disposed) {
        likes.applyCatalog(catalog.tracks, snapshot);
        if (_catalog != null) return;
        _catalog = catalog;
        final saved = _restoredProgress;
        if (saved != null) {
          final restoredIndex = tracks.indexWhere(
            (track) => track.file == saved.file,
          );
          if (restoredIndex >= 0) {
            _index = restoredIndex;
            _resumePosition = saved.position;
            _resumeDuration = saved.duration;
            activated = true;
          }
        }
        _restoredProgress = null;
      }
    } catch (_) {
      if (!_disposed) {
        catalogError = GenesisL10n.current.miniPhoneLoadMusicFailed;
      }
    } finally {
      catalogLoading = false;
      _catalogPending = null;
      _notify();
    }
  }

  Future<void> _restoreProgress() async {
    try {
      final saved = await _progressStore?.read();
      if (!_disposed) {
        _restoredProgress = saved;
        activated = saved != null;
        _notify();
      }
    } catch (_) {
      /* A local cache failure must not prevent playback. */
    }
  }

  Future<void> saveProgress() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final current = track;
    if (_disposed || _progressStore == null || !activated || current == null) {
      return _savePending;
    }
    final snapshot = MiniPhoneMusicProgress(
      file: current.file,
      position: positionDuration,
      duration: durationDuration,
    );
    return _savePending = Future.sync(
      () => _progressStore.write(snapshot),
    ).catchError((Object _) {});
  }

  void _scheduleProgressSave() {
    if (_progressStore == null || _disposed || !playing || _saveTimer != null) {
      return;
    }
    _saveTimer = Timer(const Duration(seconds: 2), () {
      _saveTimer = null;
      unawaited(saveProgress());
    });
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
      _scheduleProgressSave();
    }

    _subscriptions.addAll([
      decoder.player.playerStateStream.listen((state) {
        if (!current()) return;
        if (!_busy &&
            !_switching &&
            state.processingState != ProcessingState.completed) {
          _wantPlay = _worldAttached && state.playing;
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
      if (_disposed || decoder.generation != generation) return;
      final track = tracks[target];
      final cached = await _audioCache
          .find(track)
          .catchError((Object _) => null);
      if (_disposed || decoder.generation != generation) return;
      Future<void> load(Uri uri) async {
        await decoder.player.setAudioSources(
          [AudioSource.uri(uri)],
          initialPosition: identical(decoder, _active) && target == index
              ? _resumePosition
              : Duration.zero,
        );
      }

      try {
        await load(cached ?? Uri.parse(track.audioUrl));
      } catch (_) {
        if (cached == null || _disposed || decoder.generation != generation) {
          rethrow;
        }
        // A missing, evicted or unreadable local file can still stream.
        await load(Uri.parse(track.audioUrl));
      }
      if (!_disposed && decoder.generation == generation) {
        final duration = decoder.player.duration;
        if (identical(decoder, _active) &&
            duration != null &&
            _resumePosition > duration) {
          await decoder.player.seek(duration);
        }
        if (!_disposed && decoder.generation == generation) {
          decoder.ready = true;
        }
      }
    }();
    decoder.pending = pending;
    return pending.whenComplete(() {
      if (identical(decoder.pending, pending)) decoder.pending = null;
    });
  }

  void _maybePreload() {
    if (_disposed ||
        !_worldAttached ||
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
        !_worldAttached ||
        _busy ||
        _switching ||
        _advanceScheduled ||
        _pendingSeek != null ||
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
          _pendingSeek == null &&
          _foreground &&
          _wantPlay &&
          _current?.processingState == ProcessingState.completed) {
        unawaited(next());
      }
    });
  }

  Future<void> _run(Future<void> Function() action, {int? revision}) {
    if (_disposed || !_worldAttached || tracks.isEmpty) return Future.value();
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
        !_worldAttached ||
        !_foreground ||
        !_wantPlay ||
        decoder == null ||
        !decoder.ready) {
      return;
    }
    final revision = _selectionRevision;
    unawaited(_audioCache.remember(track!).catchError((Object _) {}));
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

  void _trackControl(String operation, String? source) {
    if (source == null || _disposed || tracks.isEmpty || !_foreground) return;
    analytics?.event(
      'music_control',
      target: track!.file,
      stage: operation,
      data: analytics!.context(source),
    );
  }

  void trackLike(String file, bool liked) {
    if (_disposed) return;
    analytics?.event(
      'music_like',
      target: file,
      stage: liked ? 'like' : 'unlike',
      data: analytics!.context('music'),
    );
  }

  Future<void> userToggle(String source) {
    _trackControl(playRequested ? 'pause' : 'play', source);
    return toggle();
  }

  Future<void> userNext(String source) {
    _trackControl('next', source);
    return next();
  }

  Future<void> userPrevious(String source) {
    _trackControl('previous', source);
    return previous();
  }

  Future<void> toggle() {
    if (_disposed || !_worldAttached || tracks.isEmpty || !_foreground) {
      return Future.value();
    }
    activated = true;
    _entrySuppressed = false;
    if (playRequested) return pause();
    _wantPlay = true;
    final revision = _selectionRevision;
    _notify();
    return _run(() async {
      final decoder = _ensureActive();
      await _prepareDecoder(decoder, index);
      if (_disposed || revision != _selectionRevision) return;
      if (_pendingSeek != null) {
        await _applyPendingSeek(decoder);
      } else if (decoder.player.processingState == ProcessingState.completed) {
        await decoder.player.seek(Duration.zero);
      }
      if (_disposed || revision != _selectionRevision) return;
      _playActive();
    });
  }

  Future<void> pause() async {
    _wantPlay = false;
    _notify();
    unawaited(saveProgress());
    try {
      await _active?.player.pause();
    } catch (_) {
      _failed();
    }
    _notify();
  }

  Future<void> seek(int seconds) => seekTo(Duration(seconds: seconds));
  Future<void> seekTo(Duration value) {
    final duration = durationDuration;
    if (!canSeek || duration == null) return Future.value();
    _pendingSeek = Duration(
      milliseconds: value.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    _resumePosition = _pendingSeek!;
    _seekRevision++;
    _notify();
    unawaited(saveProgress());
    final decoder = _active;
    if (decoder != null && decoder.ready) {
      // Native seeks replace an older buffering seek. Do not put these behind
      // the command queue, which could wait forever for the old target to load.
      return _applyPendingSeek(decoder);
    }
    return _run(() async {
      final decoder = _active;
      if (decoder != null) await _applyPendingSeek(decoder);
    });
  }

  Future<void> _applyPendingSeek(_MusicDecoder decoder) async {
    final selection = _selectionRevision;
    if (_disposed ||
        !identical(_active, decoder) ||
        !decoder.ready ||
        _pendingSeek == null) {
      return;
    }
    final revision = _seekRevision;
    final duration = decoder.player.duration;
    final target = Duration(
      milliseconds: _pendingSeek!.inMilliseconds.clamp(
        0,
        duration?.inMilliseconds ?? 1 << 53,
      ),
    );
    try {
      await decoder.player.seek(target);
    } catch (_) {
      if (!_disposed &&
          selection == _selectionRevision &&
          revision == _seekRevision) {
        _failed();
      }
      return;
    }
    if (_disposed ||
        selection != _selectionRevision ||
        revision != _seekRevision) {
      return;
    }
    _resumePosition = target;
    _pendingSeek = null;
    unawaited(saveProgress());
    _notify();
    _maybeAdvance();
  }

  Future<void> next() {
    return _switchTo(tracks.isEmpty ? 0 : (index + 1) % tracks.length);
  }

  Future<void> previous() {
    if (positionDuration > const Duration(seconds: 3)) {
      return _switchTo(index);
    }
    return _switchTo(
      tracks.isEmpty ? 0 : (index + tracks.length - 1) % tracks.length,
    );
  }

  Future<void> _switchTo(int target) {
    if (_disposed || !_worldAttached || tracks.isEmpty) return Future.value();
    activated = true;
    _entrySuppressed = false;
    _wantPlay = _foreground;
    _pendingSeek = null;
    _seekRevision++;
    if (target == index && (_active?.ready ?? false) && !_switching) {
      return _run(() async {
        await _active!.player.seek(Duration.zero);
        _playActive();
        unawaited(saveProgress());
      });
    }
    _switching = true;
    final revision = ++_selectionRevision;
    _index = target;
    _resumePosition = Duration.zero;
    _resumeDuration = null;
    // Clear the old decoder's visible position/buffer and stop its sound now,
    // rather than waiting for the replacement song or image to load.
    final stopping = _cancelDecoder(_active);
    if (_standby != null && _standby!.trackIndex != target) {
      unawaited(_cancelDecoder(_standby));
    }
    _notify();
    unawaited(saveProgress());
    return _run(() async {
      await stopping;
      if (_disposed || revision != _selectionRevision) return;
      final decoder = _standby ?? _ensureActive();
      try {
        await _prepareDecoder(decoder, target);
      } catch (_) {
        if (_disposed || revision != _selectionRevision) return;
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
      await _applyPendingSeek(decoder);
      if (_disposed || revision != _selectionRevision) return;
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

  void _failed() {
    if (_disposed) return;
    _wantPlay = false;
    _active?.ready = false;
    playbackError = GenesisL10n.current.miniPhonePlayMusicFailed;
    unawaited(
      _active?.player.pause().catchError((Object _) {}) ?? Future.value(),
    );
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _applyLifecycle();
  }

  void _pickerChanged() {
    if (_disposed) return;
    // Flutter may report the picker result before its resumed notification.
    _lifecycle = _pickerActivity.backgrounded
        ? AppLifecycleState.paused
        : WidgetsBinding.instance.lifecycleState ?? _lifecycle;
    _applyLifecycle();
  }

  void _applyLifecycle() {
    _foreground =
        _lifecycle == AppLifecycleState.resumed ||
        _pickerActivity.allows(_lifecycle);
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
    unawaited(saveProgress());
    _saveTimer?.cancel();
    _disposed = true;
    activated = false;
    _pickerActivity.removeListener(_pickerChanged);
    likes.dispose();
    _selectionRevision++;
    _wantPlay = false;
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final releases = <Future<void>>[];
    for (final decoder in [_active, _standby]) {
      if (decoder != null) {
        decoder.generation++;
        releases.add(decoder.player.dispose().catchError((Object _) {}));
      }
    }
    _releasePending = Future.wait(releases).then((_) {});
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
