import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../network/models/personalization.dart';

class PersonalizationState {
  const PersonalizationState({
    this.data,
    this.uid,
    this.error,
    this.loading = false,
  });
  final PersonalizationData? data;
  final String? uid;
  final Object? error;
  final bool loading;
}

/// Server-owned completion, scoped to the current UID or guest device.
class PersonalizationStore {
  PersonalizationStore({
    required this.load,
    required this.save,
    required this.readLoginUid,
  });
  final Future<PersonalizationData> Function() load;
  final Future<PersonalizationProfile> Function(PersonalizationProfile) save;
  final Future<String?> Function() readLoginUid;
  final state = ValueNotifier(const PersonalizationState());
  final blocksOtherPrompts = ValueNotifier(true);
  Future<PersonalizationData?>? _request;
  int _generation = 0;
  bool _presenting = false;
  bool _started = false;
  bool _disposed = false;
  bool _enabled = true;
  bool get isEnabled => _enabled;
  bool get isStarted => _started;
  bool get isPresenting => _presenting;

  void _publish(PersonalizationState value) {
    if (_disposed) return;
    state.value = value;
    blocksOtherPrompts.value =
        _presenting || (_enabled && value.data?.profile.completed != true);
  }

  void setEnabled(bool enabled) {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    _generation++;
    _request = null;
    _started = false;
    _publish(const PersonalizationState());
  }

  Future<PersonalizationData?> start() {
    if (_disposed || !_enabled) return Future.value(null);
    if (_started) return _request ?? Future.value(state.value.data);
    _started = true;
    return refresh();
  }

  Future<PersonalizationData?> refresh() {
    if (_disposed || !_enabled) return Future.value(null);
    return _refresh();
  }

  /// Worldo still needs the preference when the onboarding form is disabled.
  /// Reuse the startup request/data rather than issuing a second GET.
  Future<PersonalizationData?> loadForOriginFeed() {
    if (_disposed) return Future.value(null);
    if (_request != null) return _request!;
    if (state.value.data != null || state.value.error != null) {
      return Future.value(state.value.data);
    }
    return _refresh();
  }

  Future<PersonalizationData?> _refresh() {
    if (_request != null) return _request!;
    final generation = _generation;
    late final Future<PersonalizationData?> request;
    request = _load(generation).whenComplete(() {
      if (identical(_request, request)) _request = null;
    });
    _request = request;
    return request;
  }

  Future<PersonalizationData?> _load(int generation) async {
    bool current() => !_disposed && generation == _generation;
    String? uid;
    _publish(const PersonalizationState(loading: true));
    try {
      uid = await readLoginUid().timeout(const Duration(seconds: 20));
      if (!current()) return null;
      final data = await load().timeout(const Duration(seconds: 20));
      final currentUid = await readLoginUid().timeout(
        const Duration(seconds: 20),
      );
      if (!current()) return null;
      if (uid != currentUid) {
        resetForSession();
        return null;
      }
      _publish(PersonalizationState(data: data, uid: uid));
      return data;
    } catch (error) {
      if (current()) _publish(PersonalizationState(uid: uid, error: error));
      return null;
    }
  }

  Future<void> submit(PersonalizationProfile profile) async {
    final generation = _generation;
    final snapshot = state.value;
    bool current() => !_disposed && generation == _generation;
    if (snapshot.data?.accepts(profile) != true) {
      throw const FormatException('Please select your gender and age.');
    }
    final uid = await readLoginUid();
    if (!current() || snapshot.uid != uid) {
      throw StateError('Personalization session changed');
    }
    final saved = await save(profile).timeout(const Duration(seconds: 20));
    final currentUid = await readLoginUid();
    if (!current() || uid != currentUid) {
      throw StateError('Personalization session changed');
    }
    if (!saved.completed) throw StateError('Personalization was not completed');
    _publish(
      PersonalizationState(
        uid: uid,
        data: PersonalizationData(profile: saved, form: snapshot.data!.form),
      ),
    );
  }

  void beginPresentation() {
    _presenting = true;
    blocksOtherPrompts.value = true;
  }

  void endPresentation() {
    if (_disposed) return;
    _presenting = false;
    _publish(state.value);
  }

  void resetForSession() {
    if (_disposed) return;
    _generation++;
    _request = null;
    _publish(const PersonalizationState());
    if (_started) unawaited(refresh());
  }

  void dispose() {
    _disposed = true;
    _generation++;
    state.dispose();
    blocksOtherPrompts.dispose();
  }
}
