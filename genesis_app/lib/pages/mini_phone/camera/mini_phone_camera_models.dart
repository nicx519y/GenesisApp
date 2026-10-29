import 'dart:async';

import '../../../network/mini_phone/mini_phone_models.dart';

/// Client-side context, not a proposed backend request schema.
class MiniPhoneCameraScope {
  const MiniPhoneCameraScope({
    required this.environment,
    required this.accountId,
    required this.worldId,
  });

  final String environment, accountId, worldId;

  @override
  bool operator ==(Object other) =>
      other is MiniPhoneCameraScope &&
      other.environment == environment &&
      other.accountId == accountId &&
      other.worldId == worldId;

  @override
  int get hashCode => Object.hash(environment, accountId, worldId);
}

enum MiniPhoneCameraPhase { compose, generating, result }

/// Only the caller can confirm album synchronization. None makes no promise.
enum MiniPhoneCameraPhotosStatus { none, syncing, saved, failed }

class MiniPhoneCameraRequest {
  MiniPhoneCameraRequest({
    required this.scope,
    required Iterable<PhonePerson> participants,
    required this.prompt,
  }) : participants = List.unmodifiable(participants);

  final MiniPhoneCameraScope scope;
  final List<PhonePerson> participants;
  final String prompt;

  /// Composition preference from the approved design, not a transport field.
  double get aspectRatio => 3 / 4;
}

/// A real image returned by the injected adapter. No synthetic message/asset ID.
class MiniPhoneCameraResult {
  MiniPhoneCameraResult({
    required this.imageUrl,
    this.photosStatus = MiniPhoneCameraPhotosStatus.none,
  }) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw ArgumentError.value(
        imageUrl,
        'imageUrl',
        'Expected a real HTTP image',
      );
    }
  }

  final String imageUrl;
  final MiniPhoneCameraPhotosStatus photosStatus;
}

/// Cancellation also invalidates local delivery. The adapter must check this
/// token before performing caller-owned message/album synchronization.
class MiniPhoneCameraCancellation {
  MiniPhoneCameraCancellation(bool Function() isCurrent)
    : _isCurrent = isCurrent;

  final bool Function() _isCurrent;
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted || !_isCurrent();
  Future<void> get whenCancelled => _cancelled.future;

  void throwIfCancelled() {
    if (isCancelled) throw const MiniPhoneCameraCancelled();
  }

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

class MiniPhoneCameraCancelled implements Exception {
  const MiniPhoneCameraCancelled();
}

typedef MiniPhoneCameraGenerate =
    Future<MiniPhoneCameraResult> Function(
      MiniPhoneCameraRequest request,
      MiniPhoneCameraCancellation cancellation,
    );
