import 'package:flutter/foundation.dart';

import '../../../network/api_exception.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_requests.dart';
import 'mini_phone_camera_models.dart';

/// Owns only the camera draft and presentation. The adapter owns generation,
/// real request identities, retries and all message/album synchronization.
class MiniPhoneCameraController extends ChangeNotifier {
  MiniPhoneCameraController({
    required this.requests,
    required MiniPhoneCameraScope scope,
  }) : _scope = scope,
       _accountGeneration = requests.generation;

  final MiniPhoneRequests requests;
  MiniPhoneCameraScope _scope;
  int _accountGeneration;
  int _version = 0;
  bool _disposed = false, _closed = false;
  Object? _viewOwner;
  List<PhonePerson> _people = const [];
  final Set<String> _selected = {};
  String _prompt = '';
  MiniPhoneCameraPhase _phase = MiniPhoneCameraPhase.compose;
  MiniPhoneCameraResult? _result;
  MiniPhoneCameraResult? _sourceResult;
  MiniPhoneCameraRequest? _resultRequest;
  MiniPhoneCameraCancellation? _cancellation;
  Object? _failure;

  MiniPhoneCameraScope get scope => _scope;
  MiniPhoneCameraPhase get phase => _phase;
  String get prompt => _prompt;
  MiniPhoneCameraResult? get result => _result;
  MiniPhoneCameraRequest? get resultRequest => _resultRequest;
  bool get hasFailure => _failure != null;
  Object? get failure => _failure;
  String? get failureMessage =>
      _failure is ApiException ? (_failure as ApiException).message : null;
  List<PhonePerson> get selectedPeople => List.unmodifiable(
    _people.where((person) => _selected.contains(person.key)),
  );
  bool isSelected(PhonePerson person) => _selected.contains(person.key);
  bool get _contextCurrent =>
      !_disposed &&
      !_closed &&
      requests.isCurrent(_accountGeneration) &&
      requests.uid == _scope.accountId;
  bool get canGenerate =>
      _contextCurrent &&
      _phase == MiniPhoneCameraPhase.compose &&
      selectedPeople.isNotEmpty &&
      _prompt.trim().isNotEmpty;

  /// Call on environment/account/World changes, including a refreshed account
  /// generation with the same UID. This clears all previous context's data.
  void bindScope(MiniPhoneCameraScope value, {bool notify = true}) {
    if (_disposed) return;
    if (_scope == value && _accountGeneration == requests.generation) return;
    _invalidate();
    _scope = value;
    _accountGeneration = requests.generation;
    _clear();
    if (notify) notifyListeners();
  }

  /// Called by the page on entry. Does not revive an old account generation.
  Object open() {
    final owner = Object();
    if (!_disposed) {
      _closed = false;
      _viewOwner = owner;
    }
    return owner;
  }

  void setPeople(Iterable<PhonePerson> people) {
    if (_disposed) return;
    final byKey = {for (final person in people) person.key: person};
    _people = List.unmodifiable(byKey.values);
    _selected.removeWhere((key) => !byKey.containsKey(key));
  }

  void togglePerson(PhonePerson person) {
    if (_disposed || _closed || _phase != MiniPhoneCameraPhase.compose) return;
    if (!_people.any((value) => value.key == person.key)) return;
    if (!_selected.remove(person.key)) _selected.add(person.key);
    _failure = null;
    notifyListeners();
  }

  void setPrompt(String value) {
    if (_disposed || _closed || _phase != MiniPhoneCameraPhase.compose) return;
    if (_prompt == value) return;
    _prompt = value;
    _failure = null;
    notifyListeners();
  }

  Future<void> generate(MiniPhoneCameraGenerate? adapter) async {
    if (adapter == null || !canGenerate) return;
    final version = ++_version;
    final request = MiniPhoneCameraRequest(
      scope: _scope,
      participants: selectedPeople,
      prompt: _prompt.trim(),
    );
    final cancellation = MiniPhoneCameraCancellation(
      () => _contextCurrent && _version == version,
    );
    _cancellation = cancellation;
    _failure = null;
    _phase = MiniPhoneCameraPhase.generating;
    notifyListeners();
    try {
      cancellation.throwIfCancelled();
      final output = await adapter(request, cancellation);
      if (cancellation.isCancelled) return;
      _result = output;
      _sourceResult = output;
      _resultRequest = request;
      _phase = MiniPhoneCameraPhase.result;
    } on MiniPhoneCameraCancelled {
      if (!cancellation.isCancelled) _phase = MiniPhoneCameraPhase.compose;
    } catch (error) {
      if (cancellation.isCancelled) return;
      _failure = error;
      _phase = MiniPhoneCameraPhase.compose;
    } finally {
      if (!cancellation.isCancelled) {
        _cancellation = null;
        notifyListeners();
      }
    }
  }

  /// Cancel/back retains the current draft but prevents late result delivery.
  void cancel() {
    if (_disposed) return;
    _invalidate();
    _phase = MiniPhoneCameraPhase.compose;
    _failure = null;
    notifyListeners();
  }

  void takeAnother() {
    if (!_contextCurrent) return;
    _result = null;
    _sourceResult = null;
    _resultRequest = null;
    cancel();
  }

  /// The caller can publish actual sync state after handling a real result.
  /// Identity guards prevent an old album callback from updating a new photo.
  void updatePhotosStatus(
    MiniPhoneCameraResult expected,
    MiniPhoneCameraPhotosStatus status,
  ) {
    if (!_contextCurrent ||
        (!identical(_result, expected) &&
            !identical(_sourceResult, expected))) {
      return;
    }
    _result = MiniPhoneCameraResult(
      imageUrl: expected.imageUrl,
      photosStatus: status,
    );
    notifyListeners();
  }

  /// Parent must call on World/phone closure even while a route remains mounted.
  void close({Object? owner}) {
    if (_disposed) return;
    // A replaced page may be disposed after its replacement has mounted using
    // this same session controller. It must not close the new page's request.
    if (owner != null && !identical(owner, _viewOwner)) return;
    _viewOwner = null;
    _closed = true;
    _invalidate();
    _result = null;
    _sourceResult = null;
    _resultRequest = null;
    _failure = null;
    _phase = MiniPhoneCameraPhase.compose;
    notifyListeners();
  }

  void _invalidate() {
    _version++;
    _cancellation?.cancel();
    _cancellation = null;
  }

  void _clear() {
    _selected.clear();
    _people = const [];
    _prompt = '';
    _result = null;
    _sourceResult = null;
    _resultRequest = null;
    _failure = null;
    _phase = MiniPhoneCameraPhase.compose;
  }

  @override
  void dispose() {
    _invalidate();
    _clear();
    _disposed = true;
    _viewOwner = null;
    super.dispose();
  }
}
