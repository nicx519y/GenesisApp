import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/app/app_metadata_service.dart';
import '../../platform/app/external_url_opener.dart';
import '../../platform/channels/genesis_method_channels.dart';

enum AppReviewOutcome { completed, deferred, storeOpened }

/// Requests a review, not a guaranteed visible prompt or completed rating.
class AppReviewService {
  AppReviewService({
    Future<void> Function()? request,
    Future<bool> Function(String)? open,
    Future<bool> Function(String)? readAttempt,
    Future<void> Function(String)? writeAttempt,
    Future<String> Function()? packageName,
    TargetPlatform? platform,
    this.appleStoreId = const String.fromEnvironment(
      'GENESIS_APP_STORE_ID',
      defaultValue: '6781946729',
    ),
  }) : _request =
           request ??
           (() => GenesisMethodChannels.device.invokeMethod<void>(
             'requestAppReview',
           )),
       _open = open ?? const NativeExternalUrlOpener().open,
       _read = readAttempt ?? _readDefault,
       _write = writeAttempt ?? _writeDefault,
       _packageName =
           packageName ??
           (() async =>
               (await AppMetadataService.buildAppVersion()).packageName),
       _platform = platform ?? defaultTargetPlatform;

  final Future<void> Function() _request;
  final Future<bool> Function(String) _open;
  final Future<bool> Function(String) _read;
  final Future<void> Function(String) _write;
  final Future<String> Function() _packageName;
  final TargetPlatform _platform;
  final String appleStoreId;
  bool _busy = false;

  static String _key(String owner) => 'rating_store_attempt_v1:$owner';
  static Future<bool> _readDefault(String owner) async =>
      (await SharedPreferences.getInstance()).getBool(_key(owner)) ?? false;
  static Future<void> _writeDefault(String owner) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _key(owner),
      true,
    );
    if (!saved) throw StateError('Review attempt could not be saved');
  }

  Future<AppReviewOutcome?> requestFor(
    String owner, {
    bool Function()? isCurrent,
  }) async {
    if (_busy) return null;
    bool current() => isCurrent?.call() ?? true;
    _busy = true;
    try {
      final attempted = await _read(owner);
      if (!current()) return null;
      if (attempted) {
        return await openListing(isCurrent: current);
      }
      // Save before handing off: no retry based on whether a dialog was visible.
      await _write(owner);
      if (!current()) return null;
      try {
        await _request();
        return _platform == TargetPlatform.iOS
            ? AppReviewOutcome.deferred
            : AppReviewOutcome.completed;
      } catch (_) {
        if (current()) return await openListing(isCurrent: current);
      }
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<AppReviewOutcome?> openListing({bool Function()? isCurrent}) async {
    final List<String> urls;
    if (_platform == TargetPlatform.android) {
      final id = await _packageName();
      if (id.isEmpty) throw StateError('Missing application package name');
      urls = [
        'market://details?id=$id',
        'https://play.google.com/store/apps/details?id=$id',
      ];
    } else if (_platform == TargetPlatform.iOS &&
        RegExp(r'^\d+$').hasMatch(appleStoreId)) {
      urls = [
        'itms-apps://itunes.apple.com/app/id$appleStoreId?action=write-review',
        'https://apps.apple.com/app/id$appleStoreId?action=write-review',
      ];
    } else {
      throw StateError('Missing App Store ID or unsupported platform');
    }
    for (final url in urls) {
      if (isCurrent?.call() == false) return null;
      try {
        if (await _open(url)) return AppReviewOutcome.storeOpened;
      } catch (_) {
        /* Try the HTTPS fallback only after an explicit error. */
      }
    }
    throw StateError('Store listing could not be opened');
  }
}
