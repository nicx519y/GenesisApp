import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/config/genesis_image_config.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../components/common/genesis_generation_wait_overlay.dart';
import '../../../components/common/genesis_timestamp_text.dart';
import '../../../components/ai_content_disclaimer.dart';
import '../../../icons/custom_icon_assets.dart';
import '../../../icons/my_flutter_app_icons.dart';
import '../../../ui/components/genesis_avatar.dart';
import '../../../ui/components/genesis_list_image.dart';
import '../../../ui/components/genesis_safe_area.dart';
import '../../../ui/components/genesis_soft_italic_text.dart';
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
part 'chat_ui_ai_content_disclaimer_message_bubble.dart';
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
const double _npcChatAvatarSize = 40;
const Color _npcChatAvatarBackgroundColor = Color(0xFF4A5F7A);
const Color _locationChatBackgroundColor = Color(0xFF151517);
const Color _locationChatSurfaceColor = Colors.transparent;
const double _locationChatSurfaceBlurSigma = 4;
const double _chatHeaderTrailingWidth = 96;

ChatUiStyleConfig get kLocationChatStyle => ChatUiStyleConfig.standard.copyWith(
  conversationBackgroundColor: _locationChatBackgroundColor,
  headerHeight: 50,
  headerBackgroundColor: _locationChatSurfaceColor,
  clearHeaderBackgroundGradient: true,
  headerTitleTextStyle: ChatUiStyleConfig.standard.headerTitleTextStyle
      .copyWith(color: Colors.white),
  headerSubtitleTextStyle: ChatUiStyleConfig.standard.headerSubtitleTextStyle
      .copyWith(color: Colors.white),
  headerTitleIconColor: Colors.white,
  headerStatusIconColor: Colors.white,
  headerBackdropBlurSigma: _locationChatSurfaceBlurSigma,
  composerBackgroundColor: _locationChatSurfaceColor,
  clearComposerBackgroundGradient: true,
  composerBackdropBlurSigma: _locationChatSurfaceBlurSigma,
  composerSendButtonWidth: 40,
  composerSendButtonHeight: 40,
  composerSendButtonBorderRadius: 8,
  composerSendButtonColor: const Color(0xFFFF2442),
  composerSendButtonDisabledColor: const Color(0x21FFFFFF),
  composerSendButtonBackdropBlurSigma: 14,
  composerSendButtonIconSize: 17,
  composerActionGap: 9,
  inputBackgroundColor: const Color(0x1FFFFFFF),
  inputBackdropBlurSigma: 4,
  inputBorderRadius: 8,
  inputTextStyle: ChatUiStyleConfig.standard.inputTextStyle.copyWith(
    color: Colors.white,
    fontSize: 14,
    height: 1.4,
  ),
  messageListPadding: ChatUiStyleConfig.standard.messageListPadding.copyWith(
    left: _locationChatOuterPadding,
    right: _locationChatOuterPadding,
  ),
  rowBottomPadding: 14,
  avatarSideSpacerWidth: _locationChatAvatarOneThird,
  senderNameBottomGap: 6,
  senderNameTextStyle: const TextStyle(
    color: Color(0xFFF4F3F6),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1,
  ),
  bubblePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
  bubbleBorderRadius: 14,
  selfBubbleColor: const Color(0x99C41F2E),
  otherBubbleColor: const Color(0x993A3942),
  bubbleTextStyle: const TextStyle(
    color: Color(0xFFF4F3F6),
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  ),
  useScenePlateBubbleGeometry: true,
  bubbleBackdropBlurSigma: 14,
  systemMessageMargin: const EdgeInsets.only(bottom: 14),
  systemMessagePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  systemMessageBackgroundColor: const Color(0x14FFFFFF),
  systemMessageBorderRadius: 8,
  systemMessageTextStyle: const TextStyle(
    color: Color(0x99FFFFFF),
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w400,
  ),
);
