import '../../../network/chatroom/world_chatroom_service.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class ImageMessageParser implements LocationChatMessageParser {
  const ImageMessageParser();

  @override
  LocationChatParsedMessage parse(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    final text = locationChatMessageDisplayText(message);
    return buildLocationChatParsedMessage(
      message: message,
      context: context,
      senderType: 'image',
      text: text,
      imageUrl: text.trim(),
    );
  }
}
