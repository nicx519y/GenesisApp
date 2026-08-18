import 'package:flutter/material.dart';

import '../../../ui/tokens/genesis_palette.dart';
import 'chat_ui_library.dart';

/// Chat visual variants supplied by the active app skin.
@immutable
class GenesisChatTheme extends ThemeExtension<GenesisChatTheme> {
  const GenesisChatTheme({
    required this.standard,
    required this.whiteHeader,
    required this.privateChat,
    required this.privateHeaderBackground,
    required this.locationChat,
    required this.tickBackground,
    required this.tickAccent,
    required this.tickHeader,
    required this.npcAvatarBackground,
    required this.newMessageNoticeBackground,
  });

  factory GenesisChatTheme.light() => GenesisChatTheme(
    standard: ChatUiStyleConfig.standard,
    whiteHeader: kChatWhiteHeaderStyle,
    privateChat: kPrivateChatStyle,
    privateHeaderBackground: const Color(0xFFEDEDED),
    locationChat: kLocationChatStyle,
    tickBackground: const Color(0xF0182430),
    tickAccent: const Color(0xFF709BC2),
    tickHeader: const Color(0xFFC4DBEF),
    npcAvatarBackground: const Color(0xFF4A5F7A),
    newMessageNoticeBackground: const Color(0xCC1E1E24),
  );

  factory GenesisChatTheme.worldoRedesign() => GenesisChatTheme(
    standard: _worldoRedesignChatStyle(ChatUiStyleConfig.standard),
    whiteHeader: _worldoRedesignChatStyle(kChatWhiteHeaderStyle),
    privateChat: _worldoRedesignChatStyle(kPrivateChatStyle),
    privateHeaderBackground: GenesisPalette.redesignBackground,
    locationChat: _worldoRedesignChatStyle(kLocationChatStyle),
    tickBackground: GenesisPalette.redesignInk90,
    tickAccent: GenesisPalette.redesignAccentSoft,
    tickHeader: GenesisPalette.white,
    npcAvatarBackground: GenesisPalette.redesignRaised,
    newMessageNoticeBackground: GenesisPalette.redesignRaised90,
  );

  final ChatUiStyleConfig standard;
  final ChatUiStyleConfig whiteHeader;
  final ChatUiStyleConfig privateChat;
  final Color privateHeaderBackground;
  final ChatUiStyleConfig locationChat;
  final Color tickBackground;
  final Color tickAccent;
  final Color tickHeader;
  final Color npcAvatarBackground;
  final Color newMessageNoticeBackground;

  static GenesisChatTheme of(BuildContext context) {
    return Theme.of(context).extension<GenesisChatTheme>() ??
        GenesisChatTheme.light();
  }

  @override
  GenesisChatTheme copyWith({
    ChatUiStyleConfig? standard,
    ChatUiStyleConfig? whiteHeader,
    ChatUiStyleConfig? privateChat,
    Color? privateHeaderBackground,
    ChatUiStyleConfig? locationChat,
    Color? tickBackground,
    Color? tickAccent,
    Color? tickHeader,
    Color? npcAvatarBackground,
    Color? newMessageNoticeBackground,
  }) {
    return GenesisChatTheme(
      standard: standard ?? this.standard,
      whiteHeader: whiteHeader ?? this.whiteHeader,
      privateChat: privateChat ?? this.privateChat,
      privateHeaderBackground:
          privateHeaderBackground ?? this.privateHeaderBackground,
      locationChat: locationChat ?? this.locationChat,
      tickBackground: tickBackground ?? this.tickBackground,
      tickAccent: tickAccent ?? this.tickAccent,
      tickHeader: tickHeader ?? this.tickHeader,
      npcAvatarBackground: npcAvatarBackground ?? this.npcAvatarBackground,
      newMessageNoticeBackground:
          newMessageNoticeBackground ?? this.newMessageNoticeBackground,
    );
  }

  @override
  GenesisChatTheme lerp(
    covariant ThemeExtension<GenesisChatTheme>? other,
    double t,
  ) {
    if (other is! GenesisChatTheme || t < 0.5) return this;
    return other;
  }
}

ChatUiStyleConfig _worldoRedesignChatStyle(ChatUiStyleConfig base) {
  return base.copyWith(
    conversationBackgroundColor: GenesisPalette.redesignBackground,
    headerBackgroundColor: GenesisPalette.redesignBackground,
    clearHeaderBackgroundGradient: true,
    composerBackgroundColor: GenesisPalette.redesignBackground,
    clearComposerBackgroundGradient: true,
    headerTitleTextStyle: base.headerTitleTextStyle.copyWith(
      color: GenesisPalette.white,
    ),
    headerSubtitleTextStyle: base.headerSubtitleTextStyle.copyWith(
      color: GenesisPalette.redesignWhite72,
    ),
    headerTitleIconColor: GenesisPalette.white,
    headerStatusIconColor: GenesisPalette.redesignWhite72,
    composerIconColor: GenesisPalette.redesignWhite82,
    composerSendButtonColor: GenesisPalette.redesignAccent,
    composerSendButtonDisabledColor: GenesisPalette.redesignAccent40,
    composerSendButtonIconColor: GenesisPalette.white,
    inputBackgroundColor: GenesisPalette.redesignWhite07,
    inputTextStyle: base.inputTextStyle.copyWith(color: GenesisPalette.white),
    topTitleTextStyle: base.topTitleTextStyle.copyWith(
      color: GenesisPalette.redesignWhite82,
    ),
    statusTextStyle: base.statusTextStyle.copyWith(
      color: GenesisPalette.redesignWhite45,
    ),
    senderNameTextStyle: base.senderNameTextStyle.copyWith(
      color: GenesisPalette.redesignWhite72,
    ),
    selfBubbleColor: GenesisPalette.redesignAccent42,
    otherBubbleColor: GenesisPalette.redesignWhite13,
    bubbleTextStyle: base.bubbleTextStyle.copyWith(color: GenesisPalette.white),
    avatarTextStyle: base.avatarTextStyle.copyWith(color: GenesisPalette.white),
    aiBadgeColor: GenesisPalette.redesignAccent,
    sendingBadgeColor: GenesisPalette.redesignWhite45,
    failedBadgeColor: GenesisPalette.redesignAccent,
    failedBadgeIconColor: GenesisPalette.white,
    dateDividerTextStyle: base.dateDividerTextStyle.copyWith(
      color: GenesisPalette.redesignWhite45,
    ),
    systemMessageBackgroundColor: GenesisPalette.redesignWhite08,
    systemMessageTextStyle: base.systemMessageTextStyle.copyWith(
      color: GenesisPalette.redesignWhite60,
    ),
  );
}

extension GenesisChatThemeContext on BuildContext {
  GenesisChatTheme get genesisChatTheme => GenesisChatTheme.of(this);
}
