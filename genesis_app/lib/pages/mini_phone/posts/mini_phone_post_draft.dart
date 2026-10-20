import '../../../l10n/genesis_l10n.dart';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../network/api_exception.dart';
import '../../../utils/image_upload_processing.dart';
import '../state/mini_phone_store.dart';

/// Keeps an in-flight Post independent of the phone's visible route.
class MiniPhonePostDraft extends ChangeNotifier {
  static const maxCharacters = 500;
  MiniPhonePostDraft(this.store) : _generation = store.accountGeneration {
    store.addListener(_accountChanged);
    store.ready.then((_) {
      if (_disposed || text.isNotEmpty) return;
      final pending = store.pending['post:new'];
      if (pending != null && !pending.rejected) {
        text = pending.content;
        uploadedUrl = pending.image;
        notifyListeners();
      }
    });
  }

  final MiniPhoneStore store;
  int _generation;
  bool _disposed = false;
  String text = '';
  ProcessedUploadImage? photo;
  String? uploadedUrl;
  String? error;
  bool preparing = false;
  bool submitting = false;

  bool get locked => submitting || store.unresolved('post:new');
  bool get canSubmit =>
      !submitting &&
      !preparing &&
      text.trim().isNotEmpty &&
      // An already submitted request must retry its original, unmodified body.
      (text.characters.length <= maxCharacters ||
          store.pending['post:new']?.rejected == false);

  bool _current(int generation) =>
      !_disposed && generation == store.accountGeneration;

  void _accountChanged() {
    if (_generation == store.accountGeneration) return;
    _generation = store.accountGeneration;
    text = '';
    photo = null;
    uploadedUrl = error = null;
    preparing = submitting = false;
    notifyListeners();
  }

  void setText(String value) {
    if (!locked) text = value;
  }

  void removePhoto() {
    if (locked || preparing) return;
    photo = null;
    uploadedUrl = null;
    error = null;
    notifyListeners();
  }

  Future<void> choose(Future<ProcessedUploadImage?> Function() prepare) async {
    if (locked || preparing) return;
    final generation = store.accountGeneration;
    preparing = true;
    error = null;
    notifyListeners();
    try {
      final selected = await prepare();
      if (!_current(generation) || selected == null) return;
      photo = selected;
      uploadedUrl = null;
    } catch (e) {
      if (_current(generation)) {
        error = e is ApiException
            ? e.message
            : GenesisL10n.current.miniPhonePreparePhotoFailed;
      }
    } finally {
      if (_current(generation)) {
        preparing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submit(
    Future<String> Function(ProcessedUploadImage photo) upload,
  ) async {
    if (!canSubmit) return false;
    final generation = store.accountGeneration;
    final pending = store.pending['post:new'];
    final retry = pending != null && !pending.rejected;
    final content = retry ? pending.content : text;
    if (utf8.encode(content).length > 65535) {
      error = GenesisL10n.current.miniPhoneTextTooLong;
      notifyListeners();
      return false;
    }
    final reusesRequest =
        pending != null &&
        (retry ||
            pending.content == content &&
                pending.image == uploadedUrl &&
                pending.replyTo == null &&
                (photo == null || uploadedUrl != null));
    final attempt = store.analytics.beginAttempt(
      'post_publish',
      target: 'new',
      source: 'create',
      data: {
        'has_image': retry
            ? pending.image?.isNotEmpty == true
            : photo != null || uploadedUrl != null,
        'is_retry': reusesRequest,
        if (reusesRequest) 'client_request_id': pending.id,
      },
    );
    submitting = true;
    error = null;
    store.errors.remove('post:new');
    notifyListeners();
    try {
      if (!retry && photo != null && uploadedUrl == null) {
        final url = await upload(photo!);
        if (!_current(generation)) return false;
        if (url.isEmpty) {
          throw const FormatException('Missing uploaded image URL');
        }
        uploadedUrl = url;
      }
      if (!_current(generation)) return false;
      final ok = await store.write(
        'post',
        'new',
        content,
        image: retry ? pending.image : uploadedUrl,
        retry: retry,
        analyticsAttempt: attempt,
      );
      if (!_current(generation) || !ok) return false;
      text = '';
      photo = null;
      uploadedUrl = null;
      return true;
    } catch (e) {
      attempt.fail(e, sent: false, errorStage: 'upload');
      if (_current(generation)) {
        error = e is ApiException
            ? e.message
            : GenesisL10n.current.miniPhoneUploadPhotoFailed;
      }
      return false;
    } finally {
      if (_current(generation)) {
        submitting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_accountChanged);
    super.dispose();
  }
}
