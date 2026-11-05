/// Photo IDs are int64 values, never floating point JSON numbers.
int photoTaskId(Object? value) {
  final id = value is int
      ? value
      : value is String && RegExp(r'^[0-9]+$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  if (id == null || id <= 0) throw const FormatException('Invalid photo ID');
  return id;
}

enum PhotoTaskStatus { generating, succeeded, failed }

class PhotoTask {
  const PhotoTask({
    required this.taskId,
    required this.requestId,
    required this.status,
    this.imageUrl = '',
    this.description = '',
    this.assetId,
    this.globalMessageId,
    this.failureCode = '',
    this.failureMessage = '',
  });

  final String taskId,
      requestId,
      imageUrl,
      description,
      failureCode,
      failureMessage;
  final PhotoTaskStatus status;
  final int? assetId, globalMessageId;
  bool get terminal => status != PhotoTaskStatus.generating;

  factory PhotoTask.fromJson(
    Object? value, {
    bool requireChatMessageId = true,
  }) {
    if (value is! Map) throw const FormatException('Invalid photo');
    final task = value['task_id'];
    final request = value['client_request_id'];
    if (task is! String ||
        task.isEmpty ||
        (request != null && request is! String)) {
      throw const FormatException('Invalid photo identity');
    }
    final status = PhotoTaskStatus.values
        .where((s) => s.name == value['status'])
        .firstOrNull;
    if (status == null) throw const FormatException('Invalid photo status');
    final image = value['image'];
    final failure = value['failure'];
    if (status == PhotoTaskStatus.generating && failure != null) {
      throw const FormatException('Invalid generating photo');
    }
    if (status == PhotoTaskStatus.failed &&
        (failure is! Map ||
            failure['code'] is! String ||
            (failure['message'] != null && failure['message'] is! String))) {
      throw const FormatException('Invalid failed photo');
    }
    if (status == PhotoTaskStatus.succeeded && failure != null) {
      throw const FormatException('Invalid successful photo');
    }
    if (image != null || status == PhotoTaskStatus.succeeded) {
      if (image is! Map || image['description'] is! String) {
        throw const FormatException('Invalid photo image');
      }
      final url = image['image_url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('Invalid photo image');
      }
      return PhotoTask(
        taskId: task,
        requestId: request as String? ?? '',
        status: status,
        failureCode: failure is Map ? failure['code'] as String : '',
        failureMessage: failure is Map
            ? failure['message'] as String? ?? ''
            : '',
        imageUrl: url as String,
        description: image['description'] as String,
        assetId: photoTaskId(image['asset_id']),
        globalMessageId: requireChatMessageId
            ? photoTaskId(image['chat_global_message_id'])
            : null,
      );
    }
    return PhotoTask(
      taskId: task,
      requestId: request as String? ?? '',
      status: status,
      failureCode: failure is Map ? failure['code'] as String : '',
      failureMessage: failure is Map ? failure['message'] as String? ?? '' : '',
    );
  }

  static PhotoTask? tryParse(Object? value) {
    if (value == null) return null;
    try {
      return PhotoTask.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoTask &&
      taskId == other.taskId &&
      requestId == other.requestId &&
      status == other.status &&
      imageUrl == other.imageUrl &&
      description == other.description &&
      assetId == other.assetId &&
      globalMessageId == other.globalMessageId &&
      failureCode == other.failureCode &&
      failureMessage == other.failureMessage;
  @override
  int get hashCode => Object.hash(
    taskId,
    requestId,
    status,
    imageUrl,
    description,
    assetId,
    globalMessageId,
    failureCode,
    failureMessage,
  );

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'client_request_id': requestId,
    'status': status.name,
    'image': imageUrl.isNotEmpty
        ? {
            'asset_id': assetId,
            'image_url': imageUrl,
            'description': description,
            if (globalMessageId != null)
              'chat_global_message_id': '$globalMessageId',
          }
        : null,
    'failure': status == PhotoTaskStatus.failed
        ? {'code': failureCode, 'message': failureMessage}
        : null,
  };
}
