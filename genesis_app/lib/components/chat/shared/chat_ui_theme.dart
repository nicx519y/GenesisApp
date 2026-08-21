import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

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
    required this.locationBackgroundOverlayGradient,
    required this.tickBackground,
    required this.tickAccent,
    required this.tickClue,
    required this.tickLocation,
    required this.tickHeader,
    required this.tickBorder,
    required this.tickDivider,
    required this.tickBlurSigma,
    required this.npcAvatarBackground,
    required this.npcAvatarForeground,
    required this.npcAvatarBorder,
    required this.aiRoleBubbleBackground,
    required this.aiRoleBubbleBlurSigma,
    required this.enterLocationBackground,
    required this.enterLocationForeground,
    required this.enterLocationIcon,
    required this.narratorBackground,
    required this.narratorForeground,
    required this.narratorIcon,
    required this.newMessageNoticeBackground,
    required this.newMessageNoticeForeground,
  });

  factory GenesisChatTheme.worldoLight() => GenesisChatTheme(
    standard: _worldoLightChatStyle(ChatUiStyleConfig.standard),
    whiteHeader: _worldoLightChatStyle(kChatWhiteHeaderStyle),
    privateChat: _worldoLightChatStyle(kPrivateChatStyle),
    privateHeaderBackground: GenesisPalette.redesignPaper,
    // Location chat is drawn over scene artwork, so its optical overlay colors
    // remain content-owned while its geometry stays identical in both modes.
    locationChat: _worldoRedesignLocationChatStyle(kLocationChatStyle),
    locationBackgroundOverlayGradient: _locationBackgroundOverlayGradient,
    tickBackground: GenesisPalette.redesignInk60,
    tickAccent: GenesisPalette.redesignAccent,
    tickClue: GenesisPalette.redesignAccentDark,
    tickLocation: GenesisPalette.redesignAccentSoft,
    tickHeader: GenesisPalette.white,
    tickBorder: GenesisPalette.redesignWhite20,
    tickDivider: GenesisPalette.redesignWhite16,
    tickBlurSigma: 14,
    npcAvatarBackground: GenesisPalette.redesignWhite14,
    npcAvatarForeground: GenesisPalette.white,
    npcAvatarBorder: GenesisPalette.redesignWhite18,
    aiRoleBubbleBackground: GenesisPalette.redesignWhite20,
    aiRoleBubbleBlurSigma: 14,
    enterLocationBackground: GenesisPalette.redesignWhite13,
    enterLocationForeground: GenesisPalette.white,
    enterLocationIcon: GenesisPalette.redesignWhite60,
    narratorBackground: GenesisPalette.transparent,
    narratorForeground: GenesisPalette.redesignWhite85,
    narratorIcon: GenesisPalette.redesignWhite60,
    newMessageNoticeBackground: GenesisPalette.redesignSkeletonHighlight,
    newMessageNoticeForeground: GenesisPalette.white,
  );

  factory GenesisChatTheme.worldoDark() => GenesisChatTheme(
    standard: _worldoRedesignChatStyle(ChatUiStyleConfig.standard),
    whiteHeader: _worldoRedesignChatStyle(kChatWhiteHeaderStyle),
    privateChat: _worldoRedesignChatStyle(kPrivateChatStyle),
    privateHeaderBackground: GenesisPalette.redesignBackground,
    locationChat: _worldoRedesignLocationChatStyle(kLocationChatStyle),
    locationBackgroundOverlayGradient: _locationBackgroundOverlayGradient,
    tickBackground: GenesisPalette.redesignInk60,
    tickAccent: GenesisPalette.redesignAccent,
    tickClue: GenesisPalette.redesignAccentDark,
    tickLocation: GenesisPalette.redesignAccentSoft,
    tickHeader: GenesisPalette.white,
    tickBorder: GenesisPalette.redesignWhite20,
    tickDivider: GenesisPalette.redesignWhite16,
    tickBlurSigma: 14,
    npcAvatarBackground: GenesisPalette.redesignWhite14,
    npcAvatarForeground: GenesisPalette.white,
    npcAvatarBorder: GenesisPalette.redesignWhite18,
    aiRoleBubbleBackground: GenesisPalette.redesignWhite20,
    aiRoleBubbleBlurSigma: 14,
    enterLocationBackground: GenesisPalette.redesignWhite13,
    enterLocationForeground: GenesisPalette.white,
    enterLocationIcon: GenesisPalette.redesignWhite60,
    narratorBackground: GenesisPalette.transparent,
    narratorForeground: GenesisPalette.redesignWhite85,
    narratorIcon: GenesisPalette.redesignWhite60,
    newMessageNoticeBackground: GenesisPalette.redesignSkeletonHighlight,
    newMessageNoticeForeground: GenesisPalette.white,
  );

  final ChatUiStyleConfig standard;
  final ChatUiStyleConfig whiteHeader;
  final ChatUiStyleConfig privateChat;
  final Color privateHeaderBackground;
  final ChatUiStyleConfig locationChat;
  final Gradient locationBackgroundOverlayGradient;
  final Color tickBackground;
  final Color tickAccent;
  final Color tickClue;
  final Color tickLocation;
  final Color tickHeader;
  final Color tickBorder;
  final Color tickDivider;
  final double tickBlurSigma;
  final Color npcAvatarBackground;
  final Color npcAvatarForeground;
  final Color npcAvatarBorder;
  final Color aiRoleBubbleBackground;
  final double aiRoleBubbleBlurSigma;
  final Color enterLocationBackground;
  final Color enterLocationForeground;
  final Color enterLocationIcon;
  final Color narratorBackground;
  final Color narratorForeground;
  final Color narratorIcon;
  final Color newMessageNoticeBackground;
  final Color newMessageNoticeForeground;

  static GenesisChatTheme forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? GenesisChatTheme.worldoDark()
      : GenesisChatTheme.worldoLight();

  static GenesisChatTheme of(BuildContext context) {
    return Theme.of(context).extension<GenesisChatTheme>() ??
        GenesisChatTheme.forBrightness(Theme.of(context).brightness);
  }

  @override
  GenesisChatTheme copyWith({
    ChatUiStyleConfig? standard,
    ChatUiStyleConfig? whiteHeader,
    ChatUiStyleConfig? privateChat,
    Color? privateHeaderBackground,
    ChatUiStyleConfig? locationChat,
    Gradient? locationBackgroundOverlayGradient,
    Color? tickBackground,
    Color? tickAccent,
    Color? tickClue,
    Color? tickLocation,
    Color? tickHeader,
    Color? tickBorder,
    Color? tickDivider,
    double? tickBlurSigma,
    Color? npcAvatarBackground,
    Color? npcAvatarForeground,
    Color? npcAvatarBorder,
    Color? aiRoleBubbleBackground,
    double? aiRoleBubbleBlurSigma,
    Color? enterLocationBackground,
    Color? enterLocationForeground,
    Color? enterLocationIcon,
    Color? narratorBackground,
    Color? narratorForeground,
    Color? narratorIcon,
    Color? newMessageNoticeBackground,
    Color? newMessageNoticeForeground,
  }) {
    return GenesisChatTheme(
      standard: standard ?? this.standard,
      whiteHeader: whiteHeader ?? this.whiteHeader,
      privateChat: privateChat ?? this.privateChat,
      privateHeaderBackground:
          privateHeaderBackground ?? this.privateHeaderBackground,
      locationChat: locationChat ?? this.locationChat,
      locationBackgroundOverlayGradient:
          locationBackgroundOverlayGradient ??
          this.locationBackgroundOverlayGradient,
      tickBackground: tickBackground ?? this.tickBackground,
      tickAccent: tickAccent ?? this.tickAccent,
      tickClue: tickClue ?? this.tickClue,
      tickLocation: tickLocation ?? this.tickLocation,
      tickHeader: tickHeader ?? this.tickHeader,
      tickBorder: tickBorder ?? this.tickBorder,
      tickDivider: tickDivider ?? this.tickDivider,
      tickBlurSigma: tickBlurSigma ?? this.tickBlurSigma,
      npcAvatarBackground: npcAvatarBackground ?? this.npcAvatarBackground,
      npcAvatarForeground: npcAvatarForeground ?? this.npcAvatarForeground,
      npcAvatarBorder: npcAvatarBorder ?? this.npcAvatarBorder,
      aiRoleBubbleBackground:
          aiRoleBubbleBackground ?? this.aiRoleBubbleBackground,
      aiRoleBubbleBlurSigma:
          aiRoleBubbleBlurSigma ?? this.aiRoleBubbleBlurSigma,
      enterLocationBackground:
          enterLocationBackground ?? this.enterLocationBackground,
      enterLocationForeground:
          enterLocationForeground ?? this.enterLocationForeground,
      enterLocationIcon: enterLocationIcon ?? this.enterLocationIcon,
      narratorBackground: narratorBackground ?? this.narratorBackground,
      narratorForeground: narratorForeground ?? this.narratorForeground,
      narratorIcon: narratorIcon ?? this.narratorIcon,
      newMessageNoticeBackground:
          newMessageNoticeBackground ?? this.newMessageNoticeBackground,
      newMessageNoticeForeground:
          newMessageNoticeForeground ?? this.newMessageNoticeForeground,
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

const LinearGradient _locationBackgroundOverlayGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: <double>[0, 0.32, 0.64, 1],
  colors: <Color>[
    GenesisPalette.redesignInk80,
    GenesisPalette.redesignInk42,
    GenesisPalette.redesignInk50,
    GenesisPalette.redesignInk88,
  ],
);

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

ChatUiStyleConfig _worldoRedesignLocationChatStyle(ChatUiStyleConfig base) {
  final themed = _worldoRedesignChatStyle(base);
  return themed.copyWith(
    headerHeight: 54,
    headerBackgroundColor: GenesisPalette.transparent,
    headerBackdropBlurSigma: 0,
    headerTitleTextStyle: themed.headerTitleTextStyle.copyWith(
      color: GenesisPalette.white,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    headerSubtitleTextStyle: themed.headerSubtitleTextStyle.copyWith(
      color: GenesisPalette.redesignWhite72,
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    headerSubtitleTopGap: 3,
    senderNameTextStyle:
        GenesisTypography.withFallback(themed.senderNameTextStyle).copyWith(
          color: GenesisPalette.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
    composerBackgroundColor: GenesisPalette.transparent,
    composerBackdropBlurSigma: 0,
    composerSendButtonWidth: 46,
    composerSendButtonHeight: 46,
    composerSendButtonBorderRadius: 14,
    composerSendButtonBorderColor: GenesisPalette.redesignWhite18,
    composerSendButtonBorderWidth: 1,
    composerSendButtonColor: GenesisPalette.redesignWhite13,
    composerSendButtonDisabledColor: GenesisPalette.redesignWhite13,
    composerSendButtonIconSize: 17,
    composerActionGap: 9,
    inputMinHeight: 46,
    inputBackgroundColor: GenesisPalette.redesignWhite12,
    inputBorderRadius: 14,
    inputBorderColor: GenesisPalette.redesignWhite18,
    inputBorderWidth: 1.5,
    useScenePlateBubbleGeometry: true,
  );
}

ChatUiStyleConfig _worldoLightChatStyle(ChatUiStyleConfig base) {
  final themed = _worldoRedesignChatStyle(base);
  return themed.copyWith(
    conversationBackgroundColor: GenesisPalette.redesignPaper,
    headerBackgroundColor: GenesisPalette.redesignPaper,
    composerBackgroundColor: GenesisPalette.redesignPaper,
    headerTitleTextStyle: themed.headerTitleTextStyle.copyWith(
      color: GenesisPalette.redesignInk,
    ),
    headerSubtitleTextStyle: themed.headerSubtitleTextStyle.copyWith(
      color: GenesisPalette.redesignInk60,
    ),
    headerTitleIconColor: GenesisPalette.redesignInk,
    headerStatusIconColor: GenesisPalette.redesignInk60,
    composerIconColor: GenesisPalette.redesignInk80,
    composerSendButtonColor: GenesisPalette.redesignAccent,
    composerSendButtonDisabledColor: GenesisPalette.redesignAccent40,
    inputBackgroundColor: GenesisPalette.white,
    inputTextStyle: themed.inputTextStyle.copyWith(
      color: GenesisPalette.redesignInk,
    ),
    topTitleTextStyle: themed.topTitleTextStyle.copyWith(
      color: GenesisPalette.redesignInk80,
    ),
    statusTextStyle: themed.statusTextStyle.copyWith(
      color: GenesisPalette.redesignInk42,
    ),
    senderNameTextStyle: themed.senderNameTextStyle.copyWith(
      color: GenesisPalette.redesignInk60,
    ),
    selfBubbleColor: GenesisPalette.redesignAccent14,
    otherBubbleColor: GenesisPalette.white,
    bubbleTextStyle: themed.bubbleTextStyle.copyWith(
      color: GenesisPalette.redesignInk,
    ),
    avatarTextStyle: themed.avatarTextStyle.copyWith(
      color: GenesisPalette.redesignInk,
    ),
    sendingBadgeColor: GenesisPalette.redesignInk42,
    failedBadgeColor: GenesisPalette.redesignAccent,
    dateDividerTextStyle: themed.dateDividerTextStyle.copyWith(
      color: GenesisPalette.redesignInk42,
    ),
    systemMessageBackgroundColor: GenesisPalette.surfaceMuted,
    systemMessageTextStyle: themed.systemMessageTextStyle.copyWith(
      color: GenesisPalette.redesignInk60,
    ),
  );
}

extension GenesisChatThemeContext on BuildContext {
  GenesisChatTheme get genesisChatTheme => GenesisChatTheme.of(this);
}
