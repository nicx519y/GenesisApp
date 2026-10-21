import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_cache.dart';

/// Lifecycle/widget tests exercise the decoder without native disk IO.
class TestMusicCache implements MiniPhoneMusicCache {
  const TestMusicCache();
  @override
  Future<Uri?> find(MusicTrack track) async => null;
  @override
  Future<void> remember(MusicTrack track) async {}
}

/// A decoder boundary with controllable loading and completion. It models stop
/// interrupting a pending native load and play() waiting until pause/completion.
class TestMusicPlayer implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final buffers = StreamController<Duration>.broadcast(sync: true);
  final errors = StreamController<PlayerException>.broadcast(sync: true);
  Completer<void>? loadGate;
  Completer<void>? seekGate;
  final seekTargets = <Duration>[];
  Completer<void>? playback;
  int failLoads = 0, loads = 0, plays = 0, stops = 0, seeks = 0;
  int _generation = 0;
  int _seekGeneration = 0;
  bool disposed = false;
  void Function()? onPlay;
  List<AudioSource> sources = [];
  @override
  LoopMode loopMode = LoopMode.off;
  @override
  bool playing = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration bufferedPosition = Duration.zero;
  @override
  Duration? duration;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration> get bufferedPositionStream => buffers.stream;
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  String? get url => sources.isEmpty
      ? null
      : (sources.single as UriAudioSource).uri.toString();
  void emitState() {
    if (!states.isClosed) states.add(PlayerState(playing, processingState));
  }

  void buffer(Duration value) {
    bufferedPosition = value;
    buffers.add(value);
  }

  void completeTrack() {
    processingState = ProcessingState.completed;
    emitState();
    if (!(playback?.isCompleted ?? true)) playback!.complete();
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loopMode = mode;
  }

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    final generation = ++_generation;
    loads++;
    sources = audioSources;
    position = initialPosition ?? Duration.zero;
    bufferedPosition = Duration.zero;
    duration = null;
    processingState = ProcessingState.loading;
    emitState();
    await loadGate?.future;
    if (disposed || generation != _generation) {
      throw PlayerInterruptedException('Stopped');
    }
    if (failLoads > 0) {
      failLoads--;
      throw PlayerException(404, 'Not found', null);
    }
    duration = const Duration(seconds: 90);
    bufferedPosition = const Duration(seconds: 5);
    durations.add(duration);
    buffers.add(bufferedPosition);
    processingState = ProcessingState.ready;
    emitState();
    return duration;
  }

  @override
  Future<void> play() {
    plays++;
    playing = true;
    if (playback == null || playback!.isCompleted) playback = Completer<void>();
    onPlay?.call();
    emitState();
    return playback!.future;
  }

  @override
  Future<void> pause() async {
    playing = false;
    emitState();
    if (!(playback?.isCompleted ?? true)) playback!.complete();
  }

  @override
  Future<void> stop() async {
    stops++;
    _generation++;
    _seekGeneration++;
    if (!(loadGate?.isCompleted ?? true)) loadGate!.complete();
    playing = false;
    position = Duration.zero;
    duration = null;
    bufferedPosition = Duration.zero;
    processingState = ProcessingState.idle;
    emitState();
    if (!(playback?.isCompleted ?? true)) playback!.complete();
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    final generation = ++_seekGeneration;
    seeks++;
    seekTargets.add(position ?? Duration.zero);
    await seekGate?.future;
    if (generation != _seekGeneration) return;
    this.position = position ?? Duration.zero;
    if (processingState == ProcessingState.completed) {
      processingState = ProcessingState.ready;
    }
    positions.add(this.position);
    emitState();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
    await Future.wait([
      states.close(),
      durations.close(),
      positions.close(),
      buffers.close(),
      errors.close(),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
