import 'package:flutter/foundation.dart';

import 'mini_phone_music_progress.dart';
import 'mini_phone_music_service.dart';

/// App-scoped owner. World sessions borrow the current account's player.
class MiniPhoneMusicOwner {
  MiniPhoneMusicOwner({
    required this.namespace,
    required this.readUid,
    required this.accountRevision,
    MiniPhoneMusicService Function(MiniPhoneMusicProgressStore)? createMusic,
  }) : _createMusic =
           createMusic ??
           ((store) => MiniPhoneMusicService(progressStore: store)) {
    accountRevision.addListener(_reset);
  }

  final String namespace;
  final Future<String?> Function() readUid;
  final Listenable accountRevision;
  final MiniPhoneMusicService Function(MiniPhoneMusicProgressStore)
  _createMusic;
  MiniPhoneMusicService? _music;
  MiniPhoneMusicLease? _current;
  bool _disposed = false;

  MiniPhoneMusicLease acquire(String worldId) {
    if (_disposed) throw StateError('Music owner is disposed');
    _current?.release();
    final music = _music ??= _createMusic(
      LocalMiniPhoneMusicProgressStore(
        namespace: namespace,
        legacyWorldId: worldId,
        owner: readUid().catchError((Object _) => null),
      ),
    );
    music.attachWorld();
    return _current = MiniPhoneMusicLease._(this, music);
  }

  void _release(MiniPhoneMusicLease lease) {
    if (!identical(_current, lease)) return;
    _current = null;
    lease.music.analytics = null;
    lease.music.detachWorld();
  }

  void _reset() {
    _current = null;
    final music = _music;
    _music = null;
    music?.analytics = null;
    music?.dispose();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    accountRevision.removeListener(_reset);
    _reset();
  }
}

class MiniPhoneMusicLease {
  MiniPhoneMusicLease._(this._owner, this.music);

  final MiniPhoneMusicOwner _owner;
  final MiniPhoneMusicService music;

  void release() => _owner._release(this);
}
