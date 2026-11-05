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
  int? get cardId => message.payload['card_id'] == null
      ? null
      : chatPhotoId(message.payload['card_id']);
  int? get roundId =>
      message.conversationRoundId ??
      (message.payload['conversation_round_id'] == null
          ? null
          : chatPhotoId(message.payload['conversation_round_id']));
  String get locationId => message.locationId.isNotEmpty
      ? message.locationId
      : asString(message.payload['location_id']);
}
