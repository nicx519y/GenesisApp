import 'dart:math' as math;
import 'dart:typed_data';

import '../../utils/image_upload_processing.dart';
import '../create/create_origin_draft_store.dart';

typedef OriginDebugImageDownloader = Future<Uint8List> Function(Uri sourceUrl);
typedef OriginDebugImageUploader =
    Future<String> Function(ProcessedUploadImage image);

Future<CreateOriginDraft> uploadGeneratedOriginDebugImages({
  required CreateOriginDraft current,
  required CreateOriginDraft generated,
  required OriginDebugImageDownloader downloadImage,
  required OriginDebugImageUploader uploadImage,
  int maxConcurrentUploads = 3,
}) async {
  final currentUrls = _originDraftImageUrls(current).toSet();
  final sourceUrls = _originDraftImageUrls(
    generated,
  ).where((url) => !currentUrls.contains(url)).toSet().toList(growable: false);
  if (sourceUrls.isEmpty) return generated;

  final replacements = <String, String>{};
  var nextIndex = 0;

  Future<void> uploadNext() async {
    while (nextIndex < sourceUrls.length) {
      final imageIndex = nextIndex++;
      final sourceUrl = sourceUrls[imageIndex];
      final sourceUri = Uri.tryParse(sourceUrl);
      if (sourceUri == null ||
          !sourceUri.hasScheme ||
          !sourceUri.hasAuthority) {
        throw StateError('Invalid debug image URL: $sourceUrl');
      }

      final downloadedBytes = await downloadImage(sourceUri);
      if (downloadedBytes.isEmpty) {
        throw StateError('Debug image download returned empty bytes.');
      }
      final prepared = await prepareImageForUpload(
        bytes: downloadedBytes,
        filename: 'origin-debug-image-${imageIndex + 1}.jpg',
        contentType: 'image/jpeg',
        maxWidth: 1200,
      );
      final uploadedUrl = (await uploadImage(prepared)).trim();
      if (uploadedUrl.isEmpty) {
        throw StateError('Debug image upload returned an empty URL.');
      }
      replacements[sourceUrl] = uploadedUrl;
    }
  }

  final workerCount = math.min(
    math.max(1, maxConcurrentUploads),
    sourceUrls.length,
  );
  await Future.wait(
    List<Future<void>>.generate(workerCount, (_) => uploadNext()),
  );

  String replace(String value) => replacements[value.trim()] ?? value;
  return generated.copyWith(
    basics: generated.basics.copyWith(
      coverImageUrl: replace(generated.basics.coverImageUrl),
    ),
    characters: generated.characters
        .map(
          (character) =>
              character.copyWith(avatarUrl: replace(character.avatarUrl)),
        )
        .toList(growable: false),
    locations: generated.locations
        .map(
          (location) => location.copyWith(imageUrl: replace(location.imageUrl)),
        )
        .toList(growable: false),
    opening: OpeningDraft(
      locationId: generated.opening.locationId,
      locationName: generated.opening.locationName,
      dialogue: generated.opening.dialogue
          .map(
            (item) => OpeningDialogueDraft(
              type: item.type,
              content: item.type == OpeningDialogueDraft.imageType
                  ? replace(item.content)
                  : item.content,
              characterId: item.characterId,
            ),
          )
          .toList(growable: false),
    ),
  );
}

Iterable<String> _originDraftImageUrls(CreateOriginDraft draft) sync* {
  final coverUrl = draft.basics.coverImageUrl.trim();
  if (coverUrl.isNotEmpty) yield coverUrl;

  for (final character in draft.characters) {
    final avatarUrl = character.avatarUrl.trim();
    if (avatarUrl.isNotEmpty) yield avatarUrl;
  }
  for (final location in draft.locations) {
    final imageUrl = location.imageUrl.trim();
    if (imageUrl.isNotEmpty) yield imageUrl;
  }
  for (final item in draft.opening.dialogue) {
    if (item.type != OpeningDialogueDraft.imageType) continue;
    final imageUrl = item.content.trim();
    if (imageUrl.isNotEmpty) yield imageUrl;
  }
}
