import '../../../../l10n/genesis_l10n.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../network/models/miniphone_info.dart';
import '../../../../platform/session/user_session_store.dart';
import 'mini_phone_wallpaper_cache.dart';
import '../../state/mini_phone_analytics.dart';

typedef MiniWallpaperUploader =
    Future<String> Function(
      MiniWallpaperPhoto photo,
      void Function(int sent, int total) onProgress,
    );

class MiniWallpaperPhoto {
  const MiniWallpaperPhoto({
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.prepareUpload,
  });
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final Future<MiniWallpaperPhoto> Function(void Function(double) onProgress)?
  prepareUpload;
}

/// Route-scoped state. The backend owns persistence and cross-World sharing.
class MiniPhoneWallpaperController extends ChangeNotifier {
  MiniPhoneWallpaperController({
    required this.worldId,
    required this.sessionStore,
    required Future<MiniphoneInfo> Function() load,
    required Future<void> Function(String url) save,
    required MiniWallpaperUploader upload,
    this.cache,
  }) : _load = load,
       _save = save,
       _upload = upload {
    sessionStore.userInfoRevision.addListener(_sessionChanged);
  }

  MiniPhoneAnalytics? analytics;
  final String worldId;
  final UserSessionStore sessionStore;
  final Future<MiniphoneInfo> Function() _load;
  final Future<void> Function(String) _save;
  final MiniWallpaperUploader _upload;
  final MiniPhoneWallpaperCache? cache;
  String displayBackgroundImage = '';
  Uint8List? displayBytes;
  bool get cacheReady => cache == null || _cacheReady;
  int get identityRevision => _epoch;
  String get _cacheOwner => _uid ?? '__guest__';
  bool _cacheReady = false;
  Future<void>? _restorePending;
  String backgroundImage = '';
  String draftImage = '';
  MiniWallpaperPhoto? draftPhoto;
  Uint8List? appliedPreviewBytes;
  List<MiniphoneWallpaper> wallpapers = const [];
  bool loading = false;
  bool saving = false;
  bool uploading = false;
  bool preparing = false;
  bool loaded = false;
  double uploadProgress = 0;
  double saveProgress = 0;
  String? loadError;
  String? feedback;
  String? _uploadedUrl;
  MiniWallpaperPhoto? _preparedPhoto;
  String? _uid;
  bool _identityKnown = false;
  bool _disposed = false;
  int _epoch = 0;
  int _readVersion = 0;
  int _draftVersion = 0;
  Future<void>? _pendingRead;
  Timer? _submissionProgressTimer;

  bool get available => worldId.trim().isNotEmpty;

  void _sessionChanged() => unawaited(refresh());

  static String get _identityError =>
      GenesisL10n.current.miniPhoneAccountFailed;

  Future<bool> _syncIdentity() async {
    final epoch = _epoch;
    String? uid;
    try {
      uid = await sessionStore.readLoginUid();
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        loadError = feedback = _identityError;
        _cacheReady = true;
        _notify();
      }
      return false;
    }
    if (_disposed || epoch != _epoch) return false;
    if (loadError == _identityError) loadError = null;
    if (feedback == _identityError) feedback = null;
    if (_identityKnown && _uid == uid) return true;
    _identityKnown = true;
    _uid = uid;
    _stopSubmissionProgress();
    _epoch++;
    _readVersion++;
    _draftVersion++;
    _pendingRead = null;
    _restorePending = null;
    _cacheReady = false;
    displayBackgroundImage = '';
    displayBytes = null;
    backgroundImage = draftImage = '';
    draftPhoto = null;
    appliedPreviewBytes = null;
    _preparedPhoto = null;
    saveProgress = uploadProgress = 0;
    _uploadedUrl = null;
    wallpapers = const [];
    loaded = loading = saving = uploading = preparing = false;
    loadError = feedback = null;
    _notify();
    return true;
  }

  Future<bool> _current(int epoch) async {
    if (_disposed || epoch != _epoch) return false;
    return await _syncIdentity() && !_disposed && epoch == _epoch;
  }

  Future<void> refresh({bool resetDraft = false}) async {
    if (_disposed || !available) return;
    if (!await _syncIdentity()) return;
    if (_disposed || saving) return;
    if (resetDraft) discardDraft();
    final pending = _pendingRead;
    if (pending != null) {
      final draftVersion = _draftVersion;
      await pending;
      if (!_disposed &&
          resetDraft &&
          draftVersion == _draftVersion &&
          !saving) {
        draftImage = backgroundImage;
        _notify();
      }
      return;
    }
    final epoch = _epoch;
    final version = ++_readVersion;
    final draftVersion = _draftVersion;
    loading = true;
    loadError = null;
    _notify();
    final request = _read(epoch, version, draftVersion);
    _pendingRead = request;
    await request;
    if (!_disposed && identical(_pendingRead, request)) _pendingRead = null;
  }

  Future<void> _read(int epoch, int version, int draftVersion) async {
    final restore = _restorePending ??= _restoreCache(
      epoch,
      version,
      draftVersion,
    );
    try {
      final info = await _load();
      await restore;
      if (!await _current(epoch) || version != _readVersion) return;
      backgroundImage = info.backgroundImage;
      wallpapers = info.wallpapers;
      loaded = true;
      if (draftVersion == _draftVersion) {
        draftImage = backgroundImage;
        draftPhoto = null;
        _uploadedUrl = null;
        _preparedPhoto = null;
        appliedPreviewBytes = null;
        saveProgress = 0;
      }
      loading = false;
      _notify();
      await _storeDisplay(epoch, version, info);
    } catch (_) {
      await restore;
      if (await _current(epoch) && version == _readVersion) {
        loadError = GenesisL10n.current.miniPhoneLoadWallpapersFailed;
      }
    } finally {
      if (!_disposed && epoch == _epoch && version == _readVersion) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _restoreCache(int epoch, int version, int draftVersion) async {
    final local = cache;
    if (local == null) return;
    try {
      final snapshot = await local.read(_cacheOwner, worldId);
      if (!await _current(epoch) ||
          version != _readVersion ||
          snapshot == null) {
        return;
      }
      backgroundImage = snapshot.info.backgroundImage;
      wallpapers = snapshot.info.wallpapers;
      loaded = true;
      if (draftVersion == _draftVersion) draftImage = backgroundImage;
      if (snapshot.bytes != null || backgroundImage.isEmpty) {
        displayBackgroundImage = backgroundImage;
        displayBytes = snapshot.bytes;
      }
    } catch (_) {
      // Missing/corrupt cache must never prevent the entry request.
    } finally {
      if (!_disposed && epoch == _epoch) {
        _cacheReady = true;
        _notify();
      }
    }
  }

  Future<void> _storeDisplay(int epoch, int version, MiniphoneInfo info) async {
    final local = cache;
    if (local == null) return;
    final owner = _cacheOwner;
    try {
      final url = info.backgroundImage;
      final bytes = url.isEmpty
          ? null
          : url == displayBackgroundImage && displayBytes != null
          ? displayBytes
          : await local.loadImage(url);
      if (!await _current(epoch) || version != _readVersion) return;
      displayBackgroundImage = url;
      displayBytes = bytes;
      _notify();
      await local.write(owner, worldId, info);
    } catch (_) {
      // Keep the last usable background both on screen and on disk. Still
      // cache fresh catalogue data so Settings remains usable offline.
      if (!await _current(epoch) || version != _readVersion) return;
      try {
        await local.write(
          owner,
          worldId,
          MiniphoneInfo(
            backgroundImage: displayBackgroundImage,
            wallpapers: info.wallpapers,
          ),
        );
      } catch (_) {
        // Persistence is best effort; a disk failure is not an API failure.
      }
    }
  }

  void discardDraft() {
    if (_disposed || saving) return;
    _draftVersion++;
    draftImage = backgroundImage;
    draftPhoto = null;
    _uploadedUrl = null;
    _preparedPhoto = null;
    appliedPreviewBytes = null;
    saveProgress = 0;
    feedback = null;
    _notify();
  }

  Future<void> beginEditing() async {
    discardDraft();
    final version = _draftVersion;
    await _pendingRead;
    if (_disposed || saving || version != _draftVersion) return;
    draftImage = backgroundImage;
    _notify();
  }

  void select(String url) {
    if (_disposed || saving) return;
    _draftVersion++;
    draftImage = url;
    draftPhoto = null;
    _uploadedUrl = null;
    _preparedPhoto = null;
    appliedPreviewBytes = null;
    saveProgress = 0;
    feedback = null;
    _notify();
  }

  void selectPhoto(MiniWallpaperPhoto photo) {
    if (_disposed || saving) return;
    _draftVersion++;
    draftPhoto = photo;
    _uploadedUrl = null;
    _preparedPhoto = null;
    appliedPreviewBytes = null;
    saveProgress = 0;
    feedback = null;
    _notify();
  }

  Future<bool> apply() async {
    if (_disposed || saving || !available) return false;
    final selectedVersion = _draftVersion;
    if (!await _syncIdentity()) return false;
    if (_disposed || saving || selectedVersion != _draftVersion) return false;
    if (_uid == null) return false;
    final epoch = _epoch;
    final attempt = analytics?.beginAttempt(
      'wallpaper_save',
      target: 'wallpaper',
      source: 'settings',
      data: {'wallpaper_type': draftPhoto == null ? 'preset' : 'custom'},
    );
    var sent = false;
    saving = true;
    saveProgress = uploadProgress = 0;
    feedback = null;
    // A GET started before this write must never undo the successful save.
    _readVersion++;
    _pendingRead = null;
    loading = false;
    final operation = _readVersion;
    _notify();
    try {
      var url = draftImage;
      final photo = draftPhoto;
      var uploadPhoto = photo;
      if (photo != null) {
        preparing = true;
        _notify();
        final preparedPhoto =
            _preparedPhoto ??
            await (photo.prepareUpload?.call((progress) {
                  if (!_disposed &&
                      epoch == _epoch &&
                      operation == _readVersion &&
                      preparing) {
                    final next = .2 * progress.clamp(0.0, 1.0);
                    if (next > saveProgress) {
                      saveProgress = next;
                      _notify();
                    }
                  }
                }) ??
                Future<MiniWallpaperPhoto>.value(photo));
        if (!await _current(epoch)) return false;
        uploadPhoto = _preparedPhoto = preparedPhoto;
        preparing = false;
        saveProgress = .2;
        _notify();
        url = _uploadedUrl ?? '';
        if (url.isEmpty) {
          uploading = true;
          uploadProgress = 0;
          saveProgress = .21;
          _notify();
          url = await _upload(preparedPhoto, (sent, total) {
            if (!_disposed &&
                epoch == _epoch &&
                operation == _readVersion &&
                uploading &&
                total > 0) {
              final progress = (sent / total).clamp(0.0, 1.0);
              if (progress > uploadProgress) {
                uploadProgress = progress;
                saveProgress = .21 + .69 * progress;
                _notify();
              }
            }
          });
          if (!await _current(epoch)) return false;
          if (url.isEmpty || !isValidMiniphoneBackground(url)) {
            throw const FormatException('Upload returned an invalid image URL');
          }
          _uploadedUrl = url;
          uploading = false;
          saveProgress = .9;
          _notify();
        }
      }
      if (!isValidMiniphoneBackground(url)) {
        throw const FormatException('Invalid background URL');
      }
      if (!await _current(epoch)) return false;
      saveProgress = .91;
      _notify();
      _startSubmissionProgress(epoch, operation);
      sent = true;
      await _save(url);
      attempt?.finish('saved');
      if (!await _current(epoch)) return false;
      backgroundImage = draftImage = url;
      // Keep rendering the exact selected bytes after Apply. Do not switch to
      // the upload URL and download the same picture again.
      if (photo != null) {
        displayBackgroundImage = url;
        displayBytes = uploadPhoto!.bytes;
        appliedPreviewBytes = photo.bytes;
        _cacheReady = true;
      }
      draftPhoto = null;
      _uploadedUrl = null;
      _preparedPhoto = null;
      _notify();
      final info = MiniphoneInfo(backgroundImage: url, wallpapers: wallpapers);
      if (photo != null) {
        final local = cache;
        final owner = _cacheOwner;
        try {
          await local?.writeImage(
            url,
            uploadPhoto!.bytes,
            uploadPhoto.contentType,
          );
          if (!await _current(epoch)) return false;
          await local?.write(owner, worldId, info);
        } catch (_) {
          // The server has already accepted the change. A local disk failure
          // must not undo the visible image or report an API save failure.
        }
        if (!await _current(epoch)) return false;
      } else {
        // Home needs the original bytes, not Settings' CDN thumbnail. Keep
        // Apply busy until the replacement is ready (or loading has failed).
        await _storeDisplay(epoch, operation, info);
        if (!await _current(epoch)) return false;
      }
      _stopSubmissionProgress();
      saveProgress = 1;
      feedback = GenesisL10n.current.miniPhoneWallpaperApplied;
      return true;
    } catch (error) {
      attempt?.fail(
        error,
        sent: sent,
        errorStage: sent
            ? 'request'
            : preparing
            ? 'prepare'
            : uploading
            ? 'upload'
            : 'validation',
      );
      if (await _current(epoch)) {
        feedback = preparing
            ? GenesisL10n.current.miniPhonePreparePhotoFailed
            : uploading
            ? GenesisL10n.current.miniPhoneUploadPhotoFailed
            : GenesisL10n.current.miniPhoneSaveWallpaperFailed;
      }
      return false;
    } finally {
      if (!_disposed && epoch == _epoch) {
        _stopSubmissionProgress();
        saving = uploading = preparing = false;
        _notify();
      }
    }
  }

  void _startSubmissionProgress(int epoch, int operation) {
    _stopSubmissionProgress();
    _submissionProgressTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (timer) {
        if (_disposed ||
            !saving ||
            epoch != _epoch ||
            operation != _readVersion) {
          timer.cancel();
          return;
        }
        // Submission and original-image loading have no progress events.
        // Ease toward 99% until the entire Apply operation settles.
        final next = saveProgress + (.99 - saveProgress) * .03;
        if (next > saveProgress && next < 1) {
          saveProgress = next.clamp(.91, .99);
          _notify();
        }
      },
    );
  }

  void _stopSubmissionProgress() {
    _submissionProgressTimer?.cancel();
    _submissionProgressTimer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _stopSubmissionProgress();
    _disposed = true;
    _epoch++;
    sessionStore.userInfoRevision.removeListener(_sessionChanged);
    super.dispose();
  }
}
