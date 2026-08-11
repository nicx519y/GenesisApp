import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../components/common/genesis_generation_wait_overlay.dart';
import '../../../components/common/genesis_timestamp_text.dart';
import '../../../components/ai_content_disclaimer.dart';
import '../../../icons/custom_icon_assets.dart';
import '../../../icons/my_flutter_app_icons.dart';
import '../../../ui/components/genesis_avatar.dart';
import '../../../ui/components/genesis_list_image.dart';
import '../../../ui/components/genesis_safe_area.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../../../ui/system/genesis_system_ui.dart';
import '../../../ui/tokens/genesis_colors.dart';
import '../../../ui/tokens/genesis_typography.dart';
import '../../../ui/text/genesis_text_input_formatters.dart';
import '../../../utils/genesis_message_image.dart';
import 'chat_ui_style_config.dart';

export 'chat_ui_style_config.dart';

part 'chat_ui_message_model.dart';
part 'chat_ui_header.dart';
part 'chat_ui_composer.dart';
part 'chat_ui_message_lists.dart';
part 'chat_ui_message_row.dart';
part 'chat_ui_self_message_bubble.dart';
part 'chat_ui_other_message_bubble.dart';
part 'chat_ui_system_message_bubble.dart';
part 'chat_ui_narrator_message_bubble.dart';
part 'chat_ui_tick_message_bubble.dart';
part 'chat_ui_image_message_bubble.dart';
part 'chat_ui_user_enter_location_message_bubble.dart';
part 'chat_ui_story_events_message_bubble.dart';
part 'chat_ui_characters_moved_message_bubble.dart';
part 'chat_ui_media.dart';
part 'chat_ui_bubbles.dart';
part 'chat_ui_system_markdown.dart';

const SystemUiOverlayStyle kChatTransparentLightSystemUiOverlayStyle =
    kGenesisDefaultSystemUiOverlayStyle;

const SystemUiOverlayStyle kChatDarkHeaderSystemUiOverlayStyle =
    kGenesisLightStatusIconsSystemUiOverlayStyle;

final ChatUiStyleConfig kChatWhiteHeaderStyle = ChatUiStyleConfig.standard
    .copyWith(headerBackgroundColor: Colors.white);

final ChatUiStyleConfig kPrivateChatStyle = ChatUiStyleConfig.standard.copyWith(
  headerBackgroundColor: Colors.white,
  clearHeaderBackgroundGradient: true,
  headerBackdropBlurSigma: 0,
  composerBackgroundColor: const Color(0xF2F6F6F6),
  clearComposerBackgroundGradient: true,
  composerBackdropBlurSigma: 20,
  senderNameTextStyle: ChatUiStyleConfig.standard.senderNameTextStyle.copyWith(
    color: const Color(0xFF111111),
  ),
  showSenderNameAboveOtherBubble: false,
);

const double _locationChatOuterPadding = 10;
const double _locationChatAvatarOneThird = 40 / 3;
const double _npcChatAvatarSize = 36;
const Color _npcChatAvatarBackgroundColor = Color(0xFF4A5F7A);
const Color _locationChatBackgroundColor = Color(0xFF111111);
const Color _locationChatChromeStrong = Color(0xF2111111);
const Color _locationChatChromeSoft = Color(0x80111111);
const Color _locationChatHeaderGlassTop = Color(0xA6111111);
const Color _locationChatHeaderGlassBottom = Color(0x33111111);
const double _chatHeaderTrailingWidth = 96;

ChatUiStyleConfig get kLocationChatStyle => ChatUiStyleConfig.standard.copyWith(
  conversationBackgroundColor: _locationChatBackgroundColor,
  headerBackgroundGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_locationChatHeaderGlassTop, _locationChatHeaderGlassBottom],
  ),
  headerTitleTextStyle: ChatUiStyleConfig.standard.headerTitleTextStyle
      .copyWith(color: Colors.white),
  headerSubtitleTextStyle: ChatUiStyleConfig.standard.headerSubtitleTextStyle
      .copyWith(color: Colors.white),
  headerTitleIconColor: Colors.white,
  headerStatusIconColor: Colors.white,
  headerBackdropBlurSigma: 20,
  composerBackgroundGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_locationChatChromeSoft, _locationChatChromeStrong],
  ),
  composerBackdropBlurSigma: 20,
  messageListPadding: ChatUiStyleConfig.standard.messageListPadding.copyWith(
    left: _locationChatOuterPadding,
    right: _locationChatOuterPadding,
  ),
  avatarSideSpacerWidth: _locationChatAvatarOneThird,
  systemMessageMargin: EdgeInsets.only(
    left: _locationChatAvatarOneThird,
    right: _locationChatAvatarOneThird,
    bottom: 18,
  ),
);
