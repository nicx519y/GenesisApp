import 'package:flutter/foundation.dart';

import '../../network/models/music.dart';

/// Optimistic state and ordered submissions are isolated by catalogue file.
class MiniPhoneMusicLikes extends ChangeNotifier {
  final _states = <String, _LikeState>{};
  bool _disposed = false;

  bool isLiked(String file) => _states[file]?.liked ?? false;

  Future<void> loadStatus(
    String file,
    Future<MusicLikeStatus> Function() loader,
  ) async {
    if (_disposed) return;
    final state = _states.putIfAbsent(file, _LikeState.new);
    // A refresh cannot read ahead of a queued write and undo its local state.
    if (state.pendingWrites > 0) return;
    final revision = state.revision;
    final read = ++state.read;
    final status = await loader();
    if (_disposed || revision != state.revision || read != state.read) return;
    if (status.file != file) {
      throw const FormatException('Music like status file does not match');
    }
    state.confirmed = state.liked = status.isLiked;
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
        await submit(target);
        state.confirmed = target;
      } catch (_) {
        // Older failures must not undo a more recent optimistic tap. The last
        // operation rolls back to the last server-confirmed state if it fails.
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
  int revision = 0;
  int read = 0;
  int pendingWrites = 0;
  Future<void> queue = Future.value();
}
