import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const MethodChannel _nativeDiscussImagePickerChannel = MethodChannel(
  'com.genesis.ai/discuss_image_picker',
);

class DiscussPickedImage {
  const DiscussPickedImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

Future<List<DiscussPickedImage>> pickGenesisImages({required int limit}) async {
  final picked = await pickGenesisImageFiles(limit: limit);
  final images = <DiscussPickedImage>[];
  Object? readError;
  StackTrace? readStackTrace;
  for (final file in picked.take(limit)) {
    try {
      images.add(
        DiscussPickedImage(
          bytes: await file.readAsBytes(),
          filename: imageFilename(file),
          contentType: file.mimeType ?? guessImageContentType(file.name),
        ),
      );
    } catch (error, stackTrace) {
      readError = error;
      readStackTrace = stackTrace;
      debugPrint('Image read failed: $error\n$stackTrace');
    }
  }
  if (images.isEmpty && picked.isNotEmpty && readError != null) {
    Error.throwWithStackTrace(
      StateError('Selected images could not be read: $readError'),
      readStackTrace ?? StackTrace.current,
    );
  }
  return images;
}

Future<List<XFile>> pickGenesisImageFiles({required int limit}) async {
  if (limit <= 1) {
    final file = await _pickSingleImageFile();
    return file == null ? const <XFile>[] : <XFile>[file];
  }
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final paths = await _nativeDiscussImagePickerChannel
          .invokeListMethod<String>('pickImages', <String, Object>{
            'limit': limit,
          });
      return (paths ?? const <String>[])
          .where((path) => path.trim().isNotEmpty)
          .map((path) => XFile(path))
          .toList(growable: false);
    } on MissingPluginException {
      return ImagePicker().pickMultiImage(limit: limit);
    }
  }

  return ImagePicker().pickMultiImage(limit: limit);
}

Future<XFile?> _pickSingleImageFile() async {
  if (!Platform.isIOS) {
    return ImagePicker().pickImage(source: ImageSource.gallery);
  }

  try {
    final paths = await _nativeDiscussImagePickerChannel
        .invokeListMethod<String>('pickImages', const <String, Object>{
          'limit': 1,
        });
    String? path;
    for (final item in paths ?? const <String>[]) {
      if (item.trim().isNotEmpty) {
        path = item;
        break;
      }
    }
    return path == null ? null : XFile(path);
  } on MissingPluginException {
    return ImagePicker().pickImage(source: ImageSource.gallery);
  }
}

String imageFilename(XFile file) {
  final name = file.name.trim();
  if (name.isNotEmpty) return name;
  final path = file.path.trim();
  if (path.isEmpty) return 'upload.jpg';
  final parts = path.split(RegExp(r'[/\\]'));
  final last = parts.isEmpty ? '' : parts.last.trim();
  return last.isEmpty ? 'upload.jpg' : last;
}

String guessImageContentType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
