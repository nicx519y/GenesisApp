import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../network/mini_phone/mini_phone_camera_models.dart';
import '../state/mini_phone_requests.dart';
import 'mini_phone_camera_models.dart';

/// Device-wide camera choices, separate from World options and drafts.
class MiniPhoneCameraSelections extends ChangeNotifier {
  MiniPhoneCameraSelections({required this.requests});

  final MiniPhoneRequests requests;
  static final _writes = <String, Future<void>>{};
  String? style;
  CameraPhotoRatio photoRatio = CameraPhotoRatio.portrait;
  int _styleRevision = 0, _ratioRevision = 0;
  Future<void>? _restoreFlight;
  Future<void> saved = Future.value();
  bool _disposed = false;

  static const _key = 'phone-camera-selections-global-v1';

  bool _current(int generation) =>
      !_disposed && requests.isCurrent(generation) && requests.uid != null;

  Future<void> restore() {
    if (_restoreFlight case final flight?) return flight;
    final generation = requests.generation;
    if (!_current(generation)) return Future.value();
    final key = _key;
    final styleRevision = _styleRevision, ratioRevision = _ratioRevision;
    late final Future<void> flight;
    flight = () async {
      try {
        await _writes['$key:style'];
        await _writes['$key:aspect-ratio'];
        final prefs = await SharedPreferences.getInstance();
        if (!_current(generation)) return;
        if (_styleRevision == styleRevision) {
          style = prefs.getString('$key:style');
        }
        if (_ratioRevision == ratioRevision) {
          photoRatio =
              CameraPhotoRatio.values
                  .where(
                    (ratio) =>
                        ratio.label == prefs.getString('$key:aspect-ratio'),
                  )
                  .firstOrNull ??
              CameraPhotoRatio.portrait;
        }
        notifyListeners();
      } catch (_) {
        // Missing or damaged preferences must not prevent using the camera.
      } finally {
        if (identical(_restoreFlight, flight)) _restoreFlight = null;
      }
    }();
    return _restoreFlight = flight;
  }

  void applyOptions(PhoneCameraOptions options) {
    if (!_current(requests.generation)) return;
    if (!options.styles.any((candidate) => candidate.label == style)) {
      style = options.styles.first.label;
      _styleRevision++;
    }
    _save('style', style!);
    _save('aspect-ratio', photoRatio.label);
  }

  void selectStyle(String value) {
    if (!_current(requests.generation) || style == value) return;
    style = value;
    _styleRevision++;
    _save('style', value);
  }

  void selectRatio(CameraPhotoRatio value) {
    if (!_current(requests.generation) || photoRatio == value) return;
    photoRatio = value;
    _ratioRevision++;
    _save('aspect-ratio', value.label);
    notifyListeners();
  }

  void _save(String field, String value) {
    final key = '$_key:$field';
    final previous = _writes[key];
    final write = () async {
      try {
        await previous;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (_) {
        // Keep the in-memory choice usable if device storage is unavailable.
      }
    }();
    _writes[key] = write;
    saved = Future.wait([saved, write]);
    unawaited(_clearWrite(write, key));
  }

  Future<void> _clearWrite(Future<void> write, String key) async {
    await write;
    if (identical(_writes[key], write)) _writes.remove(key);
  }

  void reset() {
    style = null;
    photoRatio = CameraPhotoRatio.portrait;
    _styleRevision = _ratioRevision = 0;
    _restoreFlight = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
