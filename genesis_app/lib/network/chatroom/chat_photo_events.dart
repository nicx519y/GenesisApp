part of 'chatroom_models.dart';

class ChatroomLivePhotoMessage extends ChatroomEvent {
  ChatroomLivePhotoMessage(this.message)
    : photo = ChatPhoto.fromJson(message.payload['photo']);
  final ChatroomV2Message message;
  final ChatPhoto photo;
}

class ChatroomPhotoResult extends ChatroomEvent {
  ChatroomPhotoResult(this.message)
    : source = asString(message.payload['source']),
      eventId = asString(message.payload['event_id']),
      title = asString(message.payload['title']),
      summary = asString(message.payload['summary']),
      photo = const {'chat', 'camera'}.contains(message.payload['source'])
          ? ChatPhoto.fromJson(
              message.payload['photo'],
              requireChatMessageId: message.payload['source'] == 'chat',
            )
          : null;
  final ChatroomV2Message message;
  final String source, eventId, title, summary;
  final ChatPhoto? photo;
}
