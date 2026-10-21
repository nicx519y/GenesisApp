import 'package:flutter/foundation.dart';

import '../../../network/models/music.dart';

typedef MusicLikesSnapshot = ({int read, Map<String, int> revisions});

/// Optimistic state and ordered submissions are isolated by catalogue file.
class MiniPhoneMusicLikes extends ChangeNotifier {
  final _states = <String, _LikeState>{};
  bool _disposed = false;
  int _read = 0;

  bool isLiked(String file) => _states[file]?.liked ?? false;
  int likeCount(String file) => _states[file]?.count ?? 0;

  /// Capture before starting HTTP, including which songs have no queued writes.
  MusicLikesSnapshot beginSnapshot() => (
    read: ++_read,
    revisions: {
      for (final entry in _states.entries)
        if (entry.value.pendingWrites == 0) entry.key: entry.value.revision,
    },
  );

  void applyCatalog(Iterable<MusicTrack> tracks, MusicLikesSnapshot snapshot) {
    if (_disposed || snapshot.read != _read) return;
    for (final track in tracks) {
      final state = _states.putIfAbsent(track.file, _LikeState.new);
      if (state.pendingWrites > 0 ||
          (snapshot.revisions[track.file] ?? 0) != state.revision) {
        continue;
      }
      state.confirmed = state.liked = track.isLiked;
      state.confirmedCount = track.likeCount;
    }
    notifyListeners();
  }

  Future<void> toggle(String file, Future<void> Function(bool liked) submit) {
    if (_disposed) return Future.value();
    final state = _states.putIfAbsent(file, _LikeState.new);
    final target = !state.liked;
    final revision = ++state.revision;
    state.liked = target;
    state.pendingWrites++;
    notifyListeners();
    final operation = state.queue.then((_) async {
      try {
        if (_disposed) return;
        await submit(target);
        // Repeated identical targets are idempotent, including after an older
        // queued operation failed. Count only changes from the confirmed state.
        state.confirmedCount = state.countFor(target);
        state.confirmed = target;
      } catch (_) {
        if (revision == state.revision) state.liked = state.confirmed;
        rethrow;
      } finally {
        state.pendingWrites--;
        if (!_disposed) notifyListeners();
      }
    });
    state.queue = operation.catchError((Object _) {});
    return operation;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

class _LikeState {
  bool liked = false;
  bool confirmed = false;
  int confirmedCount = 0;
  int revision = 0;
  int pendingWrites = 0;
  Future<void> queue = Future.value();

  int get count => countFor(liked);
  int countFor(bool target) {
    final value = confirmedCount + (target ? 1 : 0) - (confirmed ? 1 : 0);
    return value < 0 ? 0 : value;
  }
}
