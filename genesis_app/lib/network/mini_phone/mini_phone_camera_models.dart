import '../models/photo_task.dart';

class PhoneCameraStyle {
  const PhoneCameraStyle(this.name, this.label, this.demoImageUrl);
  factory PhoneCameraStyle.fromJson(Map value) {
    if (value['name'] is! String ||
        value['label'] is! String ||
        (value['name'] as String).isEmpty ||
        (value['label'] as String).isEmpty ||
        value['demo_image_url'] is! String) {
      throw const FormatException('Invalid camera style');
    }
    return PhoneCameraStyle(
      value['name'],
      value['label'],
      value['demo_image_url'],
    );
  }
  final String name, label, demoImageUrl;
}

class PhoneCameraOptions {
  PhoneCameraOptions.fromJson(Map value)
    : worldId = value['world_id'] as String,
      priceCent = value['price_cent'] as int,
      freeStatus = value['free_status'] as String,
      styles = List.unmodifiable(
        (value['styles'] as List).map(
          (v) => PhoneCameraStyle.fromJson(v as Map),
        ),
      ) {
    if (worldId.isEmpty ||
        priceCent < 0 ||
        !const {'available', 'used'}.contains(freeStatus) ||
        styles.isEmpty ||
        styles.map((s) => s.label).toSet().length != styles.length) {
      throw const FormatException('Invalid camera options');
    }
  }
  final String worldId, freeStatus;
  final int priceCent;
  final List<PhoneCameraStyle> styles;
  bool get freeAvailable => freeStatus == 'available';
}

class PhoneCameraRequest {
  PhoneCameraRequest({
    required this.requestId,
    required this.worldId,
    required Iterable<String> characterIds,
    required this.aspectRatio,
    required this.style,
    this.prompt = '',
  }) : characterIds = List.unmodifiable(characterIds) {
    if (requestId.isEmpty ||
        requestId.length > 128 ||
        worldId.isEmpty ||
        this.characterIds.isEmpty ||
        this.characterIds.length > 4 ||
        this.characterIds.any((id) => id.isEmpty || id.trim() != id) ||
        this.characterIds.toSet().length != this.characterIds.length ||
        aspectRatio.length > 32 ||
        !RegExp(r'^[1-9][0-9]*:[1-9][0-9]*$').hasMatch(aspectRatio) ||
        style.isEmpty) {
      throw ArgumentError('Invalid camera request');
    }
  }
  factory PhoneCameraRequest.fromJson(Map value) => PhoneCameraRequest(
    requestId: value['client_request_id'] as String,
    worldId: value['world_id'] as String,
    characterIds: (value['character_ids'] as List).cast<String>(),
    aspectRatio: value['aspect_ratio'] as String,
    style: value['style'] as String,
    prompt: value['prompt'] as String? ?? '',
  );
  final String requestId, worldId, aspectRatio, style, prompt;
  final List<String> characterIds;
  Map<String, dynamic> toJson() => {
    'client_request_id': requestId,
    'world_id': worldId,
    'character_ids': characterIds,
    'aspect_ratio': aspectRatio,
    'style': style,
    if (prompt.isNotEmpty) 'prompt': prompt,
  };
}

class PhoneCameraReceipt {
  PhoneCameraReceipt.fromJson(Map value)
    : worldId = value['world_id'] as String,
      photo = PhotoTask.fromJson(value['photo'], requireChatMessageId: false) {
    if (value['source'] != 'camera' || worldId.isEmpty) {
      throw const FormatException('Invalid camera receipt');
    }
  }
  final String worldId;
  final PhotoTask photo;
}

/// Navigation identity, never a chat message or a fabricated album asset.
class PhoneCameraTarget {
  const PhoneCameraTarget({
    required this.worldId,
    required this.taskId,
    required this.assetId,
  });
  final String worldId, taskId;
  final int assetId;
  static PhoneCameraTarget? tryParse(
    Object? value, {
    required String worldId,
    required String taskId,
  }) {
    if (value is! Map ||
        value['source'] != 'camera' ||
        worldId.isEmpty ||
        taskId.isEmpty) {
      return null;
    }
    try {
      return PhoneCameraTarget(
        worldId: worldId,
        taskId: taskId,
        assetId: photoTaskId(value['asset_id']),
      );
    } on FormatException {
      return null;
    }
  }
}
