import '../../../network/chatroom/world_chatroom_service.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class NarratorMessageParser implements LocationChatMessageParser {
  const NarratorMessageParser();

  @override
  LocationChatParsedMessage parse(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    return buildLocationChatParsedMessage(
      message: message,
      context: context,
      senderType: 'narrator',
      text: locationChatMessageDisplayText(message),
    );
  }
}
