import '../../../network/chatroom/world_chatroom_service.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_parsed_message.dart';

abstract interface class LocationChatMessageParser {
  const LocationChatMessageParser();

  LocationChatParsedMessage? parse(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  );
}
