import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../network/api_exception.dart';
import '../../../network/mini_phone/mini_phone_api.dart';
import '../../../network/models/photo_task.dart';
import '../../../network/photo_generation_monitor.dart';
import '../../../l10n/genesis_l10n.dart';
import '../state/mini_phone_requests.dart';
import '../state/mini_phone_write.dart';
import 'mini_phone_camera_selections.dart';

/// World-owned jobs. Page disposal only closes the draft, never these writes.
/// Uses the phone's existing journal and identity generation.
class MiniPhoneCameraTasks extends ChangeNotifier {
  MiniPhoneCameraTasks({
    required this.api,
    required this.worldId,
    required this.requests,
    required this.pending,
    required this.saveJournal,
    required this.onChanged,
    required this.onSuccess,
    this.namespace = '',
    this.generationMonitor,
  });
  final MiniPhoneApi api;
  final String worldId;
  final String namespace;
  final PhotoGenerationMonitor? Function()? generationMonitor;
  final MiniPhoneRequests requests;
  final Map<String, PhoneWrite> pending;
  final Future<bool> Function() saveJournal;
  final VoidCallback onChanged, onSuccess;
  PhoneCameraOptions? options;
  late final selections = MiniPhoneCameraSelections(requests: requests);
  String? get selectedStyle => selections.style;
  bool submitting = false;
  bool _disposed = false;
  Future<PhoneCameraOptions?>? _optionsFlight;
  final _hiddenFailures = <String>{};
  final _restoredTaskIds = <String>{};
  final _viewed = <String>{};
  int acceptanceRevision = 0;

  List<PhoneWrite> get records => pending.values
      .where((w) => w.kind == 'camera' && !w.rejected)
      .toList()
      .reversed
      .toList();
  List<PhoneWrite> get visibleRecords =>
      records.where((w) => !_hiddenFailures.contains(w.id)).toList();
  int get pendingCount =>
      records.where((w) => w.cameraPhoto?.terminal != true).length;
  PhotoTask? get latestSuccess => records
      .map((w) => w.cameraPhoto)
      .where((p) => p?.status == PhotoTaskStatus.succeeded)
      .firstOrNull;
  bool get unread => records.any(
    (w) => w.cameraPhoto?.terminal == true && !_viewed.contains(w.id),
  );
  PhoneCameraStyle? get style =>
      options?.styles.where((s) => s.label == selectedStyle).firstOrNull;

  void selectStyle(String label) {
    if (options?.styles.any((s) => s.label == label) != true) return;
    selections.selectStyle(label);
    _notify();
  }

  /// Another World may have changed the global choices since this page closed.
  Future<void> restoreSelections() async {
    final generation = requests.generation;
    await selections.restore();
    if (!_current(generation)) return;
    if (options case final cached?) selections.applyOptions(cached);
    _notify();
  }

  Future<PhoneCameraOptions?> loadOptions() {
    if (_optionsFlight case final flight?) return flight;
    final generation = requests.generation;
    final selectionsReady = selections.restore();
    late final Future<PhoneCameraOptions?> flight;
    flight = () async {
      try {
        final result = await api.cameraOptions(worldId);
        await selectionsReady;
        if (!_current(generation)) return null;
        // Refresh again after a slow response to pick up other Worlds' edits.
        await selections.restore();
        if (!_current(generation)) return null;
        if (result.worldId != worldId) {
          throw const FormatException('Camera World mismatch');
        }
        options = result;
        selections.applyOptions(result);
        _notify();
        return result;
      } finally {
        if (identical(_optionsFlight, flight)) _optionsFlight = null;
      }
    }();
    _optionsFlight = flight;
    return flight;
  }

  String _bodyKey(Map<String, dynamic> body) =>
      jsonEncode({...body}..remove('client_request_id'));
  PhoneWrite? unresolved(PhoneCameraRequest request) => pending.values
      .where(
        (w) =>
            w.kind == 'camera' &&
            !w.accepted &&
            !w.rejected &&
            w.content.isNotEmpty &&
            _bodyKey(Map<String, dynamic>.from(jsonDecode(w.content) as Map)) ==
                _bodyKey(request.toJson()),
      )
      .firstOrNull;

  String? recordCaptureClick() => _disposed || requests.uid == null
      ? null
      : generationMonitor?.call()?.recordClick('camera');

  Future<void> submit(PhoneCameraRequest draft, {String? attemptId}) async {
    if (submitting || requests.uid == null || _disposed) return;
    if (hasConflict(draft)) {
      throw ApiException(
        message: GenesisL10n.current.cameraRequestConflict,
        serverErrMsg: GenesisL10n.current.cameraRequestConflict,
        kind: ApiExceptionKind.business,
        code: 2062,
      );
    }
    final generation = requests.generation;
    final previous = unresolved(draft);
    final request = previous == null
        ? draft
        : PhoneCameraRequest.fromJson(jsonDecode(previous.content) as Map);
    final write =
        previous ??
        PhoneWrite(
          request.requestId,
          'camera',
          request.requestId,
          jsonEncode(request.toJson()),
        );
    pending[write.key] = write;
    submitting = true;
    _notify();
    PhotoGenerationMonitor? monitor;
    try {
      if (!await saveJournal()) {
        throw StateError(GenesisL10n.current.miniPhoneSaveRequestsFailed);
      }
      if (!_current(generation)) return;
      monitor = generationMonitor?.call();
      monitor?.start('camera', write.id, attemptId: attemptId);
      final receipt = await api.createCameraPhoto(request);
      if (!_current(generation)) return;
      if (receipt.worldId != worldId ||
          receipt.photo.requestId.isNotEmpty &&
              receipt.photo.requestId != write.id) {
        throw const FormatException('Camera receipt identity mismatch');
      }
      monitor?.acceptReceipt('camera', write.id, receipt.photo);
      accept(receipt.photo, requestId: write.id);
      await saveJournal();
    } catch (error) {
      if (!_current(generation)) return;
      if (error is ApiException && error.kind == ApiExceptionKind.business) {
        monitor?.reject('camera', write.id, errorCode: error.code);
      }
      // A push can confirm acceptance while the HTTP response is lost.
      if (!write.accepted) {
        write.uncertain = true;
        if (error is ApiException && error.kind == ApiExceptionKind.business) {
          write.rejected = true;
          // 2062 must never be bypassed using a newly generated request ID.
          if (error.code == 2062) write.cameraConflict = true;
        }
        await saveJournal();
        rethrow;
      }
    } finally {
      if (_current(generation)) {
        submitting = false;
        _notify();
      }
    }
  }

  bool hasConflict(PhoneCameraRequest draft) => pending.values.any(
    (w) =>
        w.kind == 'camera' &&
        w.cameraConflict &&
        w.content.isNotEmpty &&
        _bodyKey(Map<String, dynamic>.from(jsonDecode(w.content) as Map)) ==
            _bodyKey(draft.toJson()),
  );

  void accept(PhotoTask photo, {String? requestId}) {
    if (_disposed || requests.uid == null) return;
    final id = requestId ?? photo.requestId;
    final taskWrite = pending.values
        .where(
          (w) => w.kind == 'camera' && w.cameraPhoto?.taskId == photo.taskId,
        )
        .firstOrNull;
    final requestWrite = id.isEmpty
        ? null
        : pending.values
              .where((w) => w.kind == 'camera' && w.id == id)
              .firstOrNull;
    var write = requestWrite ?? taskWrite;
    if (taskWrite != null &&
        requestWrite != null &&
        !identical(taskWrite, requestWrite)) {
      if (taskWrite.cameraPhoto?.terminal == true) {
        photo = taskWrite.cameraPhoto!;
      }
      requestWrite.cameraInAlbum |= taskWrite.cameraInAlbum;
      if (_hiddenFailures.remove(taskWrite.id)) {
        _hiddenFailures.add(requestWrite.id);
      }
      if (_viewed.remove(taskWrite.id)) _viewed.add(requestWrite.id);
      pending.remove(taskWrite.key);
    }
    if (write?.cameraPhoto?.terminal == true) return;
    // Unknown online tasks retain only their real task identity until a receipt
    // associates an original request. They can never be submitted as a new body.
    write ??= PhoneWrite(
      id.isEmpty ? 'task:${photo.taskId}' : id,
      'camera',
      id.isEmpty ? 'task:${photo.taskId}' : id,
      '',
    );
    final newlyAccepted = !write.accepted && taskWrite?.accepted != true;
    write.accepted = true;
    write.rejected = false;
    write.uncertain = false;
    write.cameraPhoto = photo;
    pending[write.key] = write;
    if (newlyAccepted) acceptanceRevision++;
    if (photo.status == PhotoTaskStatus.succeeded) onSuccess();
    unawaited(saveJournal());
    _notify();
  }

  /// Read-only reconciliation. A notification supplies task/asset identity;
  /// album content alone is never matched by timestamp, description or URL.
  Future<void> reconcileInbox(
    Future<Map<String, dynamic>> Function(int page) fetchNotices,
    List<PhoneAlbumAsset> cachedAlbum,
  ) async {
    if (_recovering || _disposed || requests.uid == null) return;
    final generation = requests.generation;
    final wanted = <String, ({String requestId, PhotoTask task})>{
      for (final w in records)
        if (w.cameraPhoto case final p? when !p.terminal)
          p.taskId: (requestId: w.id, task: p),
    };
    if (wanted.isEmpty) return;
    final monitor = generationMonitor?.call();
    _recovering = true;
    try {
      final successAssets = <int, PhotoTask>{};
      var page = 1, read = 0;
      while (_current(generation) && wanted.isNotEmpty) {
        final response = await fetchNotices(page++);
        if (!_current(generation)) return;
        final list = (response['list'] as List? ?? const []).whereType<Map>();
        for (final notice in list) {
          final target = notice['photo_target'];
          if (notice['biz_id'] != worldId ||
              target is! Map ||
              target['source'] != 'camera') {
            continue;
          }
          final match = wanted[notice['obj_id']];
          if (match == null) continue;
          final task = match.task;
          final status = switch (notice['notice_type']) {
            'photo_failed' => PhotoTaskStatus.failed,
            'photo_succeeded' => PhotoTaskStatus.succeeded,
            _ => null,
          };
          if (status == null) continue;
          if (status == PhotoTaskStatus.succeeded) {
            successAssets[photoTaskId(target['asset_id'])] = task;
          }
          monitor?.observe(
            'camera',
            PhotoTask(
              taskId: task.taskId,
              requestId: task.requestId,
              status: status,
            ),
            requestId: match.requestId,
          );
          if (status == PhotoTaskStatus.failed) {
            accept(
              PhotoTask(
                taskId: task.taskId,
                requestId: task.requestId,
                status: PhotoTaskStatus.failed,
                failureCode: 'unknown',
                failureMessage: notice['content'] is String
                    ? notice['content'] as String
                    : '',
              ),
            );
            // A restored failure is not a new live failure on this visit.
            if (_restoredTaskIds.contains(task.taskId)) {
              _hiddenFailures.add(
                records
                    .firstWhere((w) => w.cameraPhoto?.taskId == task.taskId)
                    .id,
              );
            }
          }
          wanted.remove(task.taskId);
        }
        read += list.length;
        final total = response['total'];
        if (list.isEmpty ||
            total is int && read >= total ||
            list.length < 100) {
          break;
        }
      }
      void mergeAssets(Iterable<PhoneAlbumAsset> assets) {
        for (final asset in assets) {
          final task = successAssets.remove(asset.id);
          if (task == null || asset.image.isEmpty) continue;
          accept(
            PhotoTask(
              taskId: task.taskId,
              requestId: task.requestId,
              status: PhotoTaskStatus.succeeded,
              assetId: asset.id,
              imageUrl: asset.image,
              description: asset.description,
            ),
          );
        }
      }

      mergeAssets(cachedAlbum);
      confirmAlbum(cachedAlbum);
      var albumPage = 1;
      while (successAssets.isNotEmpty && _current(generation)) {
        final result = await api.album(worldId, pn: albumPage++, rn: 100);
        if (!_current(generation)) return;
        mergeAssets(result.list);
        confirmAlbum(result.list);
        if (!result.hasMore) break;
      }
    } finally {
      if (_current(generation)) {
        _recovering = false;
        _notify();
      }
    }
  }

  bool _recovering = false;

  void confirmAlbum(Iterable<PhoneAlbumAsset> assets) {
    final ids = assets.map((a) => a.id).toSet();
    var changed = false;
    for (final write in records) {
      if (!write.cameraInAlbum &&
          write.cameraPhoto?.status == PhotoTaskStatus.succeeded &&
          ids.contains(write.cameraPhoto?.assetId)) {
        write.cameraInAlbum = true;
        changed = true;
      }
    }
    if (changed) {
      unawaited(saveJournal());
      _notify();
    }
  }

  void restored() {
    _viewed.addAll(
      records.where((w) => w.cameraPhoto?.terminal == true).map((w) => w.id),
    );
    _restoredTaskIds.addAll(
      records.map((w) => w.cameraPhoto?.taskId).whereType<String>(),
    );
    _hiddenFailures.addAll(
      records
          .where((w) => w.cameraPhoto?.status == PhotoTaskStatus.failed)
          .map((w) => w.id),
    );
  }

  void beginAlbumVisit() {
    _viewed.addAll(
      records.where((w) => w.cameraPhoto?.terminal == true).map((w) => w.id),
    );
  }

  void endAlbumVisit() {
    _hiddenFailures.addAll(
      records
          .where((w) => w.cameraPhoto?.status == PhotoTaskStatus.failed)
          .map((w) => w.id),
    );
    _viewed.addAll(
      records.where((w) => w.cameraPhoto?.terminal == true).map((w) => w.id),
    );
  }

  void reset() {
    options = null;
    selections.reset();
    submitting = false;
    _recovering = false;
    _optionsFlight = null;
    _hiddenFailures.clear();
    _restoredTaskIds.clear();
    _viewed.clear();
    acceptanceRevision = 0;
  }

  bool _current(int generation) =>
      !_disposed && requests.isCurrent(generation) && requests.uid != null;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
      onChanged();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    selections.dispose();
    super.dispose();
  }

  static String newRequestId() => const Uuid().v4();
}
