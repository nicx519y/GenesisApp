import 'package:flutter/material.dart';

import '../../../ui/tokens/genesis_avatar_radii.dart';
import '../../../ui/tokens/genesis_colors.dart';

class ChatUiStyleConfig {
  const ChatUiStyleConfig({
    // 聊天页面整体背景色。
    required this.conversationBackgroundColor,
    // 顶部聊天栏高度，不包含系统安全区。
    required this.headerHeight,
    // 顶部聊天栏背景色。
    required this.headerBackgroundColor,
    // 顶部聊天栏背景渐变；存在时优先于纯色背景。
    this.headerBackgroundGradient,
    // 顶部聊天栏背景模糊半径。
    this.headerBackdropBlurSigma = 0,
    // 顶部聊天栏主标题文字样式。
    required this.headerTitleTextStyle,
    // 顶部聊天栏副标题文字样式。
    required this.headerSubtitleTextStyle,
    // 顶部标题左侧位置图标颜色。
    required this.headerTitleIconColor,
    // 顶部标题左侧位置图标尺寸。
    required this.headerTitleIconSize,
    // 顶部副标题状态图标颜色。
    required this.headerStatusIconColor,
    // 顶部副标题状态图标尺寸。
    required this.headerStatusIconSize,
    // 顶部右侧更多按钮图标尺寸。
    required this.headerMoreIconSize,
    // 顶部左侧返回按钮图标尺寸。
    required this.headerBackIconSize,
    // 顶部标题图标和标题文字之间的间距。
    required this.headerTitleIconGap,
    // 顶部标题和副标题之间的垂直间距。
    required this.headerSubtitleTopGap,
    // 顶部状态图标和副标题文字之间的间距。
    required this.headerStatusIconGap,
    // 隐藏更多按钮时右侧占位宽度，用来保持标题居中。
    required this.headerTrailingPlaceholderWidth,
    // 底部输入栏背景色。
    required this.composerBackgroundColor,
    // 底部输入栏背景渐变；存在时优先于纯色背景。
    this.composerBackgroundGradient,
    // 底部输入栏背景模糊半径。
    this.composerBackdropBlurSigma = 0,
    // 底部输入栏外边距。
    required this.composerPadding,
    // 输入栏图标按钮点击区域尺寸。
    required this.composerIconButtonSize,
    // 输入栏图标视觉尺寸。
    required this.composerIconSize,
    // 输入栏图标颜色。
    required this.composerIconColor,
    // 是否显示输入框左侧的语音按钮。
    required this.showComposerVoiceButton,
    // 是否显示输入框右侧的表情按钮。
    required this.showComposerStickerButton,
    // 是否显示输入框右侧的加号按钮。
    required this.showComposerAddButton,
    // 是否显示最右侧的发送按钮。
    required this.showComposerSendButton,
    // 发送按钮宽度。
    required this.composerSendButtonWidth,
    // 发送按钮高度。
    required this.composerSendButtonHeight,
    // 发送按钮圆角。
    required this.composerSendButtonBorderRadius,
    // 发送按钮背景色。
    required this.composerSendButtonColor,
    // 发送按钮禁用背景色。
    required this.composerSendButtonDisabledColor,
    // 发送按钮图标颜色。
    required this.composerSendButtonIconColor,
    // 发送按钮图标尺寸。
    required this.composerSendButtonIconSize,
    // 发送按钮 loading 圆环尺寸。
    required this.composerSendButtonLoadingSize,
    // 发送按钮 loading 圆环线宽。
    required this.composerSendButtonLoadingStrokeWidth,
    // 语音按钮和输入框之间的间距。
    required this.composerLeadingGap,
    // 输入框右侧操作按钮之间的间距。
    required this.composerActionGap,
    // 输入框最小高度。
    required this.inputMinHeight,
    // 输入框最小行数。
    required this.inputMinLines,
    // 输入框最大行数，超过后输入框内部滚动。
    required this.inputMaxLines,
    // 输入框单行文字高度。
    required this.inputLineHeight,
    // 输入框文字左右内边距。
    required this.inputHorizontalPadding,
    // 输入框文字上下内边距。
    required this.inputVerticalPadding,
    // 输入框背景色。
    required this.inputBackgroundColor,
    // 输入框圆角。
    required this.inputBorderRadius,
    // 输入框文字样式。
    required this.inputTextStyle,
    // 消息列表内边距。
    required this.messageListPadding,
    // 没有顶部标题时保留的顶部高度。
    required this.topTitleEmptyHeight,
    // 顶部标题底部间距。
    required this.topTitleBottomPadding,
    // 顶部标题文字样式。
    required this.topTitleTextStyle,
    // 每条消息行底部间距。
    required this.rowBottomPadding,
    // 自己消息气泡最大宽度占屏幕宽度的比例。
    required this.selfBubbleMaxWidthFactor,
    // 对方消息气泡最大宽度占屏幕宽度的比例。
    required this.otherBubbleMaxWidthFactor,
    // loading/失败徽标和气泡之间的间距。
    required this.badgeBubbleGap,
    // 头像和气泡之间的间距。
    required this.avatarBubbleGap,
    // 发送者名字和气泡之间的垂直间距。
    required this.senderNameBottomGap,
    // 状态文字和气泡之间的垂直间距。
    required this.statusTextTopGap,
    // 非 sending/failed 的状态文字样式。
    required this.statusTextStyle,
    // 对方消息顶部发送者名字样式。
    required this.senderNameTextStyle,
    // 是否在对方气泡上方显示发送者名字。
    required this.showSenderNameAboveOtherBubble,
    // 消息气泡内边距。
    required this.bubblePadding,
    // 消息气泡圆角。
    required this.bubbleBorderRadius,
    // 自己消息气泡颜色。
    required this.selfBubbleColor,
    // 对方消息气泡颜色。
    required this.otherBubbleColor,
    // 消息气泡文字样式。
    required this.bubbleTextStyle,
    // 头像尺寸。
    required this.avatarSize,
    // 头像圆角。
    required this.avatarBorderRadius,
    // 自己头像渐变色。
    required this.selfAvatarColors,
    // 对方头像渐变色。
    required this.otherAvatarColors,
    // 头像内文字样式。
    required this.avatarTextStyle,
    // AI 标识尺寸。
    required this.aiBadgeSize,
    // AI 标识颜色。
    required this.aiBadgeColor,
    // sending loading 徽标尺寸。
    required this.sendingBadgeSize,
    // sending loading 徽标内边距。
    required this.sendingBadgePadding,
    // sending loading 圆环线宽。
    required this.sendingBadgeStrokeWidth,
    // sending loading 圆环颜色。
    required this.sendingBadgeColor,
    // failed 红色感叹号徽标尺寸。
    required this.failedBadgeSize,
    // failed 红色感叹号徽标背景色。
    required this.failedBadgeColor,
    // failed 感叹号图标颜色。
    required this.failedBadgeIconColor,
    // failed 感叹号图标尺寸。
    required this.failedBadgeIconSize,
    // 日期分割线底部间距。
    required this.dateDividerBottomPadding,
    // 日期分割线文字样式。
    required this.dateDividerTextStyle,
    // 系统消息外边距。
    required this.systemMessageMargin,
    // 系统消息内边距。
    required this.systemMessagePadding,
    // 系统消息背景色。
    required this.systemMessageBackgroundColor,
    // 系统消息圆角。
    required this.systemMessageBorderRadius,
    // 系统消息文字样式。
    required this.systemMessageTextStyle,
  });

  static const standard = ChatUiStyleConfig(
    conversationBackgroundColor: Color(0xFFEDEDED), // 聊天页面整体背景色。
    headerHeight: 50, // 顶部聊天栏高度，不包含系统安全区。
    headerBackgroundColor: Color(0xF5F2EFF2), // 顶部聊天栏背景色。
    headerBackgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xF2111111), Color(0x00111111)],
    ), // 顶部聊天栏背景渐变。
    headerTitleTextStyle: TextStyle(
      fontSize: 16, // 顶部主标题字号。
      fontWeight: FontWeight.w600, // 顶部主标题字重。
      color: Colors.black, // 顶部主标题颜色。
    ),
    headerSubtitleTextStyle: TextStyle(
      fontSize: 16, // 顶部副标题字号。
      fontWeight: FontWeight.w400, // 顶部副标题字重。
      color: Colors.black87, // 顶部副标题颜色。
    ),
    headerTitleIconColor: Color(0xFF526A9F), // 顶部标题位置图标颜色。
    headerTitleIconSize: 16, // 顶部标题位置图标尺寸。
    headerStatusIconColor: Colors.black87, // 顶部副标题状态图标颜色。
    headerStatusIconSize: 17, // 顶部副标题状态图标尺寸。
    headerMoreIconSize: 17, // 顶部右侧更多按钮图标尺寸。
    headerBackIconSize: 17, // 顶部左侧返回按钮图标尺寸。
    headerTitleIconGap: 4, // 顶部标题图标和文字间距。
    headerSubtitleTopGap: 4, // 顶部标题和副标题垂直间距。
    headerStatusIconGap: 5, // 顶部状态图标和文字间距。
    headerTrailingPlaceholderWidth: 48, // 隐藏更多按钮时右侧占位宽度。
    composerBackgroundColor: Color(0xFAF1EFF1), // 底部输入栏背景色。
    composerBackgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00111111), Color(0xF2111111)],
    ), // 底部输入栏背景渐变。
    composerPadding: EdgeInsets.fromLTRB(10, 8, 10, 16), // 底部输入栏内边距。
    composerIconButtonSize: 32, // 输入栏图标按钮点击区域尺寸。
    composerIconSize: 30, // 输入栏图标视觉尺寸。
    composerIconColor: Colors.black, // 输入栏图标颜色。
    showComposerVoiceButton: false, // 是否显示输入框左侧语音按钮。
    showComposerStickerButton: false, // 是否显示输入框右侧表情按钮。
    showComposerAddButton: false, // 是否显示输入框右侧加号按钮。
    showComposerSendButton: true, // 是否显示最右侧发送按钮。
    composerSendButtonWidth: 64, // 发送按钮宽度。
    composerSendButtonHeight: 36, // 发送按钮高度。
    composerSendButtonBorderRadius: 8, // 发送按钮圆角。
    composerSendButtonColor: GenesisColors.brand, // 发送按钮背景色。
    composerSendButtonDisabledColor: GenesisColors.brandSoft, // 发送按钮禁用背景色。
    composerSendButtonIconColor: Colors.white, // 发送按钮图标颜色。
    composerSendButtonIconSize: 18, // 发送按钮图标尺寸。
    composerSendButtonLoadingSize: 18, // 发送按钮 loading 圆环尺寸。
    composerSendButtonLoadingStrokeWidth: 2, // 发送按钮 loading 圆环线宽。
    composerLeadingGap: 12, // 语音按钮和输入框之间的间距。
    composerActionGap: 10, // 输入框右侧按钮之间的间距。
    inputMinHeight: 40, // 输入框最小高度。
    inputMinLines: 1, // 输入框最小行数。
    inputMaxLines: 10, // 输入框最大行数，超过后内部滚动。
    inputLineHeight: 20, // 输入框单行文字高度。
    inputHorizontalPadding: 14, // 输入框文字左右内边距。
    inputVerticalPadding: 10, // 输入框文字上下内边距。
    inputBackgroundColor: Colors.white, // 输入框背景色。
    inputBorderRadius: 8, // 输入框圆角。
    inputTextStyle: TextStyle(
      color: Colors.black, // 输入框文字颜色。
      fontSize: 14, // 输入框文字字号。
      height: 20 / 14, // 输入框文字行高。
    ),
    messageListPadding: EdgeInsets.fromLTRB(18, 18, 18, 12), // 消息列表内边距。
    topTitleEmptyHeight: 16, // 没有顶部标题时保留的顶部高度。
    topTitleBottomPadding: 16, // 顶部标题底部间距。
    topTitleTextStyle: TextStyle(
      fontSize: 14, // 顶部标题字号。
      height: 1.2, // 顶部标题行高。
      fontWeight: FontWeight.w600, // 顶部标题字重。
      color: Colors.black87, // 顶部标题颜色。
    ),
    rowBottomPadding: 24, // 每条消息行底部间距。
    selfBubbleMaxWidthFactor: 0.68, // 自己消息气泡最大宽度比例。
    otherBubbleMaxWidthFactor: 0.72, // 对方消息气泡最大宽度比例。
    badgeBubbleGap: 8, // loading/失败徽标和气泡之间的间距。
    avatarBubbleGap: 10, // 头像和气泡之间的间距。
    senderNameBottomGap: 4, // 对方名字和气泡之间的垂直间距。
    statusTextTopGap: 4, // 状态文字和气泡之间的垂直间距。
    statusTextStyle: TextStyle(color: Colors.white70, fontSize: 11), // 状态文字样式。
    senderNameTextStyle: TextStyle(
      color: Colors.white, // 对方名字文字颜色。
      fontSize: 12, // 对方名字字号。
      fontWeight: FontWeight.w400, // 对方名字字重。
    ),
    showSenderNameAboveOtherBubble: true, // 是否在对方气泡上方显示发送者名字。
    bubblePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 气泡内边距。
    bubbleBorderRadius: 8, // 气泡圆角。
    selfBubbleColor: Color(0xFF95EC69), // 自己消息气泡颜色。
    otherBubbleColor: Colors.white, // 对方消息气泡颜色。
    bubbleTextStyle: TextStyle(
      color: Colors.black, // 气泡文字颜色。
      fontSize: 14, // 气泡文字字号。
      height: 20 / 14, // 气泡文字行高。
      fontWeight: FontWeight.w400, // 气泡文字字重。
    ),
    avatarSize: 40, // 头像尺寸。
    avatarBorderRadius: GenesisAvatarRadii.user, // 头像圆角。
    selfAvatarColors: [Color(0xFFFFE7B0), Color(0xFF9ED7FF)], // 自己头像渐变色。
    otherAvatarColors: [Color(0xFFBFD7F2), Color(0xFF4F6D94)], // 对方头像渐变色。
    avatarTextStyle: TextStyle(
      color: Colors.white, // 头像内文字颜色。
      fontSize: 13, // 头像内文字字号。
      fontWeight: FontWeight.w400, // 头像内文字字重。
    ),
    aiBadgeSize: 16, // AI 标识尺寸。
    aiBadgeColor: Color(0xFFFF2344), // AI 标识颜色。
    sendingBadgeSize: 22, // sending loading 徽标尺寸。
    sendingBadgePadding: 2, // sending loading 徽标内边距。
    sendingBadgeStrokeWidth: 2, // sending loading 圆环线宽。
    sendingBadgeColor: Color(0xFF777777), // sending loading 圆环颜色。
    failedBadgeSize: 22, // failed 红色感叹号徽标尺寸。
    failedBadgeColor: Color(0xFFFF2344), // failed 红色感叹号徽标背景色。
    failedBadgeIconColor: Colors.white, // failed 感叹号图标颜色。
    failedBadgeIconSize: 17, // failed 感叹号图标尺寸。
    dateDividerBottomPadding: 12, // 日期分割线底部间距。
    dateDividerTextStyle: TextStyle(
      color: Color(0xFF777777), // 日期分割线文字颜色。
      fontSize: 10, // 日期分割线文字字号。
      fontWeight: FontWeight.w400, // 日期分割线文字字重。
    ),
    systemMessageMargin: EdgeInsets.only(bottom: 18), // 系统消息外边距。
    systemMessagePadding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 6,
    ), // 系统消息内边距。
    systemMessageBackgroundColor: Color(0xE6111111), // 系统消息背景色。
    systemMessageBorderRadius: 8, // 系统消息圆角。
    systemMessageTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 13,
    ), // 系统消息文字样式。
  );

  // 聊天页面整体背景色。
  final Color conversationBackgroundColor;
  // 顶部聊天栏高度，不包含系统安全区。
  final double headerHeight;
  // 顶部聊天栏背景色。
  final Color headerBackgroundColor;
  // 顶部聊天栏背景渐变；存在时优先于纯色背景。
  final Gradient? headerBackgroundGradient;
  // 顶部聊天栏背景模糊半径。
  final double headerBackdropBlurSigma;
  // 顶部聊天栏主标题文字样式。
  final TextStyle headerTitleTextStyle;
  // 顶部聊天栏副标题文字样式。
  final TextStyle headerSubtitleTextStyle;
  // 顶部标题左侧位置图标颜色。
  final Color headerTitleIconColor;
  // 顶部标题左侧位置图标尺寸。
  final double headerTitleIconSize;
  // 顶部副标题状态图标颜色。
  final Color headerStatusIconColor;
  // 顶部副标题状态图标尺寸。
  final double headerStatusIconSize;
  // 顶部右侧更多按钮图标尺寸。
  final double headerMoreIconSize;
  // 顶部左侧返回按钮图标尺寸。
  final double headerBackIconSize;
  // 顶部标题图标和标题文字之间的间距。
  final double headerTitleIconGap;
  // 顶部标题和副标题之间的垂直间距。
  final double headerSubtitleTopGap;
  // 顶部状态图标和副标题文字之间的间距。
  final double headerStatusIconGap;
  // 隐藏更多按钮时右侧占位宽度，用来保持标题居中。
  final double headerTrailingPlaceholderWidth;
  // 底部输入栏背景色。
  final Color composerBackgroundColor;
  // 底部输入栏背景渐变；存在时优先于纯色背景。
  final Gradient? composerBackgroundGradient;
  // 底部输入栏背景模糊半径。
  final double composerBackdropBlurSigma;
  // 底部输入栏外边距。
  final EdgeInsets composerPadding;
  // 输入栏图标按钮点击区域尺寸。
  final double composerIconButtonSize;
  // 输入栏图标视觉尺寸。
  final double composerIconSize;
  // 输入栏图标颜色。
  final Color composerIconColor;
  // 是否显示输入框左侧的语音按钮。
  final bool showComposerVoiceButton;
  // 是否显示输入框右侧的表情按钮。
  final bool showComposerStickerButton;
  // 是否显示输入框右侧的加号按钮。
  final bool showComposerAddButton;
  // 是否显示最右侧的发送按钮。
  final bool showComposerSendButton;
  // 发送按钮宽度。
  final double composerSendButtonWidth;
  // 发送按钮高度。
  final double composerSendButtonHeight;
  // 发送按钮圆角。
  final double composerSendButtonBorderRadius;
  // 发送按钮背景色。
  final Color composerSendButtonColor;
  // 发送按钮禁用背景色。
  final Color composerSendButtonDisabledColor;
  // 发送按钮图标颜色。
  final Color composerSendButtonIconColor;
  // 发送按钮图标尺寸。
  final double composerSendButtonIconSize;
  // 发送按钮 loading 圆环尺寸。
  final double composerSendButtonLoadingSize;
  // 发送按钮 loading 圆环线宽。
  final double composerSendButtonLoadingStrokeWidth;
  // 语音按钮和输入框之间的间距。
  final double composerLeadingGap;
  // 输入框右侧操作按钮之间的间距。
  final double composerActionGap;
  // 输入框最小高度。
  final double inputMinHeight;
  // 输入框最小行数。
  final int inputMinLines;
  // 输入框最大行数，超过后输入框内部滚动。
  final int inputMaxLines;
  // 输入框单行文字高度。
  final double inputLineHeight;
  // 输入框文字左右内边距。
  final double inputHorizontalPadding;
  // 输入框文字上下内边距。
  final double inputVerticalPadding;
  // 输入框背景色。
  final Color inputBackgroundColor;
  // 输入框圆角。
  final double inputBorderRadius;
  // 输入框文字样式。
  final TextStyle inputTextStyle;
  // 消息列表内边距。
  final EdgeInsets messageListPadding;
  // 没有顶部标题时保留的顶部高度。
  final double topTitleEmptyHeight;
  // 顶部标题底部间距。
  final double topTitleBottomPadding;
  // 顶部标题文字样式。
  final TextStyle topTitleTextStyle;
  // 每条消息行底部间距。
  final double rowBottomPadding;
  // 自己消息气泡最大宽度占屏幕宽度的比例。
  final double selfBubbleMaxWidthFactor;
  // 对方消息气泡最大宽度占屏幕宽度的比例。
  final double otherBubbleMaxWidthFactor;
  // loading/失败徽标和气泡之间的间距。
  final double badgeBubbleGap;
  // 头像和气泡之间的间距。
  final double avatarBubbleGap;
  // 发送者名字和气泡之间的垂直间距。
  final double senderNameBottomGap;
  // 状态文字和气泡之间的垂直间距。
  final double statusTextTopGap;
  // 非 sending/failed 的状态文字样式。
  final TextStyle statusTextStyle;
  // 对方消息顶部发送者名字样式。
  final TextStyle senderNameTextStyle;
  // 是否在对方气泡上方显示发送者名字。
  final bool showSenderNameAboveOtherBubble;
  // 消息气泡内边距。
  final EdgeInsets bubblePadding;
  // 消息气泡圆角。
  final double bubbleBorderRadius;
  // 自己消息气泡颜色。
  final Color selfBubbleColor;
  // 对方消息气泡颜色。
  final Color otherBubbleColor;
  // 消息气泡文字样式。
  final TextStyle bubbleTextStyle;
  // 头像尺寸。
  final double avatarSize;
  // 头像圆角。
  final double avatarBorderRadius;
  // 自己头像渐变色。
  final List<Color> selfAvatarColors;
  // 对方头像渐变色。
  final List<Color> otherAvatarColors;
  // 头像内文字样式。
  final TextStyle avatarTextStyle;
  // AI 标识尺寸。
  final double aiBadgeSize;
  // AI 标识颜色。
  final Color aiBadgeColor;
  // sending loading 徽标尺寸。
  final double sendingBadgeSize;
  // sending loading 徽标内边距。
  final double sendingBadgePadding;
  // sending loading 圆环线宽。
  final double sendingBadgeStrokeWidth;
  // sending loading 圆环颜色。
  final Color sendingBadgeColor;
  // failed 红色感叹号徽标尺寸。
  final double failedBadgeSize;
  // failed 红色感叹号徽标背景色。
  final Color failedBadgeColor;
  // failed 感叹号图标颜色。
  final Color failedBadgeIconColor;
  // failed 感叹号图标尺寸。
  final double failedBadgeIconSize;
  // 日期分割线底部间距。
  final double dateDividerBottomPadding;
  // 日期分割线文字样式。
  final TextStyle dateDividerTextStyle;
  // 系统消息外边距。
  final EdgeInsets systemMessageMargin;
  // 系统消息内边距。
  final EdgeInsets systemMessagePadding;
  // 系统消息背景色。
  final Color systemMessageBackgroundColor;
  // 系统消息圆角。
  final double systemMessageBorderRadius;
  // 系统消息文字样式。
  final TextStyle systemMessageTextStyle;

  ChatUiStyleConfig copyWith({
    Color? conversationBackgroundColor,
    Color? headerBackgroundColor,
    Gradient? headerBackgroundGradient,
    bool clearHeaderBackgroundGradient = false,
    double? headerBackdropBlurSigma,
    Color? composerBackgroundColor,
    Gradient? composerBackgroundGradient,
    bool clearComposerBackgroundGradient = false,
    double? composerBackdropBlurSigma,
    TextStyle? headerTitleTextStyle,
    TextStyle? headerSubtitleTextStyle,
    Color? headerTitleIconColor,
    Color? headerStatusIconColor,
    double? headerStatusIconSize,
    double? headerSubtitleTopGap,
    EdgeInsets? messageListPadding,
    bool? showComposerSendButton,
  }) {
    return ChatUiStyleConfig(
      conversationBackgroundColor:
          conversationBackgroundColor ?? this.conversationBackgroundColor,
      headerHeight: headerHeight,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      headerBackgroundGradient: clearHeaderBackgroundGradient
          ? null
          : headerBackgroundGradient ?? this.headerBackgroundGradient,
      headerBackdropBlurSigma:
          headerBackdropBlurSigma ?? this.headerBackdropBlurSigma,
      composerBackgroundGradient: clearComposerBackgroundGradient
          ? null
          : composerBackgroundGradient ?? this.composerBackgroundGradient,
      composerBackdropBlurSigma:
          composerBackdropBlurSigma ?? this.composerBackdropBlurSigma,
      headerTitleTextStyle: headerTitleTextStyle ?? this.headerTitleTextStyle,
      headerSubtitleTextStyle:
          headerSubtitleTextStyle ?? this.headerSubtitleTextStyle,
      headerTitleIconColor: headerTitleIconColor ?? this.headerTitleIconColor,
      headerTitleIconSize: headerTitleIconSize,
      headerStatusIconColor:
          headerStatusIconColor ?? this.headerStatusIconColor,
      headerStatusIconSize: headerStatusIconSize ?? this.headerStatusIconSize,
      headerMoreIconSize: headerMoreIconSize,
      headerBackIconSize: headerBackIconSize,
      headerTitleIconGap: headerTitleIconGap,
      headerSubtitleTopGap: headerSubtitleTopGap ?? this.headerSubtitleTopGap,
      headerStatusIconGap: headerStatusIconGap,
      headerTrailingPlaceholderWidth: headerTrailingPlaceholderWidth,
      composerBackgroundColor:
          composerBackgroundColor ?? this.composerBackgroundColor,
      composerPadding: composerPadding,
      composerIconButtonSize: composerIconButtonSize,
      composerIconSize: composerIconSize,
      composerIconColor: composerIconColor,
      showComposerVoiceButton: showComposerVoiceButton,
      showComposerStickerButton: showComposerStickerButton,
      showComposerAddButton: showComposerAddButton,
      showComposerSendButton:
          showComposerSendButton ?? this.showComposerSendButton,
      composerSendButtonWidth: composerSendButtonWidth,
      composerSendButtonHeight: composerSendButtonHeight,
      composerSendButtonBorderRadius: composerSendButtonBorderRadius,
      composerSendButtonColor: composerSendButtonColor,
      composerSendButtonDisabledColor: composerSendButtonDisabledColor,
      composerSendButtonIconColor: composerSendButtonIconColor,
      composerSendButtonIconSize: composerSendButtonIconSize,
      composerSendButtonLoadingSize: composerSendButtonLoadingSize,
      composerSendButtonLoadingStrokeWidth:
          composerSendButtonLoadingStrokeWidth,
      composerLeadingGap: composerLeadingGap,
      composerActionGap: composerActionGap,
      inputMinHeight: inputMinHeight,
      inputMinLines: inputMinLines,
      inputMaxLines: inputMaxLines,
      inputLineHeight: inputLineHeight,
      inputHorizontalPadding: inputHorizontalPadding,
      inputVerticalPadding: inputVerticalPadding,
      inputBackgroundColor: inputBackgroundColor,
      inputBorderRadius: inputBorderRadius,
      inputTextStyle: inputTextStyle,
      messageListPadding: messageListPadding ?? this.messageListPadding,
      topTitleEmptyHeight: topTitleEmptyHeight,
      topTitleBottomPadding: topTitleBottomPadding,
      topTitleTextStyle: topTitleTextStyle,
      rowBottomPadding: rowBottomPadding,
      selfBubbleMaxWidthFactor: selfBubbleMaxWidthFactor,
      otherBubbleMaxWidthFactor: otherBubbleMaxWidthFactor,
      badgeBubbleGap: badgeBubbleGap,
      avatarBubbleGap: avatarBubbleGap,
      senderNameBottomGap: senderNameBottomGap,
      statusTextTopGap: statusTextTopGap,
      statusTextStyle: statusTextStyle,
      senderNameTextStyle: senderNameTextStyle,
      showSenderNameAboveOtherBubble: showSenderNameAboveOtherBubble,
      bubblePadding: bubblePadding,
      bubbleBorderRadius: bubbleBorderRadius,
      selfBubbleColor: selfBubbleColor,
      otherBubbleColor: otherBubbleColor,
      bubbleTextStyle: bubbleTextStyle,
      avatarSize: avatarSize,
      avatarBorderRadius: avatarBorderRadius,
      selfAvatarColors: selfAvatarColors,
      otherAvatarColors: otherAvatarColors,
      avatarTextStyle: avatarTextStyle,
      aiBadgeSize: aiBadgeSize,
      aiBadgeColor: aiBadgeColor,
      sendingBadgeSize: sendingBadgeSize,
      sendingBadgePadding: sendingBadgePadding,
      sendingBadgeStrokeWidth: sendingBadgeStrokeWidth,
      sendingBadgeColor: sendingBadgeColor,
      failedBadgeSize: failedBadgeSize,
      failedBadgeColor: failedBadgeColor,
      failedBadgeIconColor: failedBadgeIconColor,
      failedBadgeIconSize: failedBadgeIconSize,
      dateDividerBottomPadding: dateDividerBottomPadding,
      dateDividerTextStyle: dateDividerTextStyle,
      systemMessageMargin: systemMessageMargin,
      systemMessagePadding: systemMessagePadding,
      systemMessageBackgroundColor: systemMessageBackgroundColor,
      systemMessageBorderRadius: systemMessageBorderRadius,
      systemMessageTextStyle: systemMessageTextStyle,
    );
  }

  // 输入框最大高度，由最大行数、行高和上下内边距共同计算。
  double get inputMaxHeight {
    return inputLineHeight * inputMaxLines + inputVerticalPadding * 2;
  }

  // 气泡单行文字高度，由字号和 TextStyle.height 共同计算。
  double get bubbleLineHeight {
    return (bubbleTextStyle.fontSize ?? 14) * (bubbleTextStyle.height ?? 1);
  }
}
