import '../../../network/chatroom/world_chatroom_service.dart';
import 'location_chat_message_parse_context.dart';
import 'location_chat_message_parse_support.dart';
import 'location_chat_message_parser.dart';
import 'location_chat_parsed_message.dart';

class TextMessageParser implements LocationChatMessageParser {
  const TextMessageParser({this.senderType});

  final String? senderType;

  @override
  LocationChatParsedMessage parse(
    WorldChatroomMessage message,
    LocationChatMessageParseContext context,
  ) {
    return buildLocationChatParsedMessage(
      message: message,
      context: context,
      senderType: senderType ?? locationChatResolvedSenderType(message),
      text: locationChatMessageDisplayText(message),
    );
  }
}
