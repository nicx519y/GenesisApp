import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../network/api_exception.dart';
import '../../../utils/image_upload_processing.dart';
import '../state/mini_phone_store.dart';

/// Keeps an in-flight Post independent of the phone's visible route.
class MiniPhonePostDraft extends ChangeNotifier {
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
  bool get canSubmit => !submitting && !preparing && text.trim().isNotEmpty;

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
            : 'Unable to prepare this photo. Please try again.';
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
      error = 'Phone text must not exceed 65535 UTF-8 bytes';
      notifyListeners();
      return false;
    }
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
      );
      if (!_current(generation) || !ok) return false;
      text = '';
      photo = null;
      uploadedUrl = null;
      return true;
    } catch (e) {
      if (_current(generation)) {
        error = e is ApiException
            ? e.message
            : 'Unable to upload this photo. Please try again.';
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
