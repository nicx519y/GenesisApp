import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/genesis_timestamp_text.dart';
import '../../../icons/my_flutter_app_icons.dart';
import '../../../ui/components/genesis_avatar.dart';
import '../../../ui/components/genesis_safe_area.dart';
import 'chat_ui_style_config.dart';

export 'chat_ui_style_config.dart';

const SystemUiOverlayStyle kChatWhiteSystemUiOverlayStyle =
    SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );

const SystemUiOverlayStyle kChatDarkHeaderSystemUiOverlayStyle =
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

final ChatUiStyleConfig kChatWhiteHeaderStyle = ChatUiStyleConfig.standard
    .copyWith(headerBackgroundColor: Colors.white);

final ChatUiStyleConfig kPrivateChatStyle = ChatUiStyleConfig.standard.copyWith(
  headerBackgroundColor: const Color(0xF2EDEDED),
  clearHeaderBackgroundGradient: true,
  headerBackdropBlurSigma: 20,
  composerBackgroundColor: const Color(0xF2F6F6F6),
  clearComposerBackgroundGradient: true,
  composerBackdropBlurSigma: 20,
);

final ChatUiStyleConfig kLocationChatStyle = ChatUiStyleConfig.standard
    .copyWith(
      headerTitleTextStyle: ChatUiStyleConfig.standard.headerTitleTextStyle
          .copyWith(color: Colors.white),
      headerSubtitleTextStyle: ChatUiStyleConfig
          .standard
          .headerSubtitleTextStyle
          .copyWith(color: Colors.white),
      headerTitleIconColor: Colors.white,
      headerStatusIconColor: Colors.white,
      headerBackdropBlurSigma: 20,
      composerBackdropBlurSigma: 20,
    );

class ChatMessageVm {
  ChatMessageVm({
    required this.localId,
    this.clientMsgId = '',
    this.messageId,
    this.roundId = '',
    this.tickNo = 0,
    required this.senderId,
    required this.senderName,
    this.avatarUrl = '',
    required this.text,
    required this.isMe,
    required this.status,
    this.senderType = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatMessageVm.system(String text) {
    return ChatMessageVm(
      localId: 'system-${DateTime.now().microsecondsSinceEpoch}',
      senderId: '',
      senderName: '',
      text: text,
      isMe: false,
      status: 'system',
      senderType: 'system',
    );
  }

  final String localId;
  final String clientMsgId;
  int? messageId;
  String roundId;
  int tickNo;
  final String senderId;
  String senderName;
  String avatarUrl;
  String text;
  final bool isMe;
  String status;
  final String senderType;
  String? error;
  final DateTime createdAt;

  bool get isSystem => senderType == 'system' || isNarrator || isTick;

  bool get isNarrator => senderType == 'narrator';

  bool get isTick => senderType == 'tick';
}

typedef ChatMessageLongPressStart =
    void Function(
      BuildContext context,
      ChatMessageVm message,
      LongPressStartDetails details,
    );

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.connecting,
    required this.onBack,
    this.showTitleIcon = true,
    this.showSubtitle = true,
    this.showMoreButton = true,
    this.style,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool connecting;
  final VoidCallback onBack;
  final bool showTitleIcon;
  final bool showSubtitle;
  final bool showMoreButton;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final topInset = GenesisSafeAreaInsets.top(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.headerBackdropBlurSigma,
          sigmaY: style.headerBackdropBlurSigma,
        ),
        child: Container(
          height: topInset + style.headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: style.headerBackgroundGradient == null
                ? style.headerBackgroundColor
                : null,
            gradient: style.headerBackgroundGradient,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: style.headerBackIconSize,
                      color: style.headerTitleTextStyle.color,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: style.headerTrailingPlaceholderWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showTitleIcon) ...[
                              Icon(
                                Icons.location_on,
                                size: style.headerTitleIconSize,
                                color: style.headerTitleIconColor,
                              ),
                              SizedBox(width: style.headerTitleIconGap),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style.headerTitleTextStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showSubtitle) ...[
                        SizedBox(height: style.headerSubtitleTopGap),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                connected
                                    ? Icons.groups_2
                                    : connecting
                                    ? Icons.sync
                                    : Icons.cloud_off,
                                size: style.headerStatusIconSize,
                                color: style.headerStatusIconColor,
                              ),
                              SizedBox(width: style.headerStatusIconGap),
                              Flexible(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: style.headerSubtitleTextStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showMoreButton)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.more_horiz,
                        size: style.headerMoreIconSize,
                        color: style.headerTitleTextStyle.color,
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: style.headerTrailingPlaceholderWidth,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.inputEnabled,
    required this.sendEnabled,
    required this.sending,
    required this.onSend,
    this.onHeightChanged,
    this.sendLabel,
    this.style,
    this.bottomSafeAreaInset,
    this.focusNode,
  });

  final TextEditingController controller;
  final bool inputEnabled;
  final bool sendEnabled;
  final bool sending;
  final Future<void> Function() onSend;
  final ValueChanged<double>? onHeightChanged;
  final String? sendLabel;
  final ChatUiStyleConfig? style;
  final double? bottomSafeAreaInset;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final submitFromKeyboard = !style.showComposerSendButton;
    final bottomInset =
        bottomSafeAreaInset ?? GenesisSafeAreaInsets.bottom(context);
    return _ChatComposerHeightObserver(
      onHeightChanged: onHeightChanged,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: style.composerBackdropBlurSigma,
            sigmaY: style.composerBackdropBlurSigma,
          ),
          child: Container(
            padding: style.composerPadding.copyWith(
              bottom: style.composerPadding.bottom + bottomInset,
            ),
            decoration: BoxDecoration(
              color: style.composerBackgroundGradient == null
                  ? style.composerBackgroundColor
                  : null,
              gradient: style.composerBackgroundGradient,
            ),
            child: TextFieldTapRegion(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (style.showComposerVoiceButton) ...[
                    _ComposerIconButton(
                      icon: MyFlutterApp.voice,
                      onPressed: inputEnabled ? () {} : null,
                      style: style,
                    ),
                    SizedBox(width: style.composerLeadingGap),
                  ],
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: style.inputMinHeight,
                        maxHeight: style.inputMaxHeight,
                      ),
                      decoration: BoxDecoration(
                        color: style.inputBackgroundColor,
                        borderRadius: BorderRadius.circular(
                          style.inputBorderRadius,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: inputEnabled,
                        minLines: style.inputMinLines,
                        maxLines: style.inputMaxLines,
                        keyboardType: submitFromKeyboard
                            ? TextInputType.text
                            : TextInputType.multiline,
                        textInputAction: submitFromKeyboard
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onSubmitted: submitFromKeyboard
                            ? (_) {
                                if (sendEnabled) unawaited(onSend());
                              }
                            : null,
                        style: style.inputTextStyle,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: style.inputHorizontalPadding,
                            vertical: style.inputVerticalPadding,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (style.showComposerStickerButton) ...[
                    SizedBox(width: style.composerActionGap),
                    _ComposerIconButton(
                      icon: MyFlutterApp.sticker,
                      onPressed: inputEnabled ? () {} : null,
                      style: style,
                    ),
                  ],
                  if (style.showComposerAddButton) ...[
                    SizedBox(width: style.composerActionGap),
                    _ComposerIconButton(
                      icon: MyFlutterApp.add2,
                      onPressed: inputEnabled ? () {} : null,
                      style: style,
                    ),
                  ],
                  if (style.showComposerSendButton) ...[
                    SizedBox(width: style.composerActionGap),
                    _ComposerSendButton(
                      sending: sending,
                      onPressed: sendEnabled ? onSend : null,
                      label: sendLabel,
                      style: style,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatComposerHeightObserver extends StatefulWidget {
  const _ChatComposerHeightObserver({
    required this.child,
    required this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double>? onHeightChanged;

  @override
  State<_ChatComposerHeightObserver> createState() =>
      _ChatComposerHeightObserverState();
}

class _ChatComposerHeightObserverState
    extends State<_ChatComposerHeightObserver> {
  double? _lastHeight;

  @override
  void initState() {
    super.initState();
    _scheduleReportHeight();
  }

  @override
  void didUpdateWidget(covariant _ChatComposerHeightObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReportHeight();
  }

  void _scheduleReportHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = context.size?.height;
      if (height == null || height == _lastHeight) return;
      _lastHeight = height;
      widget.onHeightChanged?.call(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReportHeight();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReportHeight();
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onPressed,
    required this.style,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: style.composerIconButtonSize,
      height: style.composerIconButtonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: style.composerIconColor,
          size: style.composerIconSize,
        ),
      ),
    );
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.sending,
    required this.onPressed,
    required this.style,
    this.label,
  });

  final bool sending;
  final VoidCallback? onPressed;
  final ChatUiStyleConfig style;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !sending;
    final background = enabled || sending
        ? style.composerSendButtonColor
        : style.composerSendButtonDisabledColor;
    return SizedBox(
      key: const ValueKey('chat-composer-send-button'),
      width: style.composerSendButtonWidth,
      height: style.composerSendButtonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(
            style.composerSendButtonBorderRadius,
          ),
        ),
        child: TextButton(
          style: TextButton.styleFrom(
            fixedSize: Size(
              style.composerSendButtonWidth,
              style.composerSendButtonHeight,
            ),
            minimumSize: Size(
              style.composerSendButtonWidth,
              style.composerSendButtonHeight,
            ),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: style.composerSendButtonIconColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                style.composerSendButtonBorderRadius,
              ),
            ),
          ),
          onPressed: enabled ? onPressed : null,
          child: sending
              ? SizedBox(
                  width: style.composerSendButtonLoadingSize,
                  height: style.composerSendButtonLoadingSize,
                  child: CircularProgressIndicator(
                    strokeWidth: style.composerSendButtonLoadingStrokeWidth,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      style.composerSendButtonIconColor,
                    ),
                  ),
                )
              : label == null
              ? Icon(
                  Icons.send,
                  color: style.composerSendButtonIconColor,
                  size: style.composerSendButtonIconSize,
                )
              : Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: style.composerSendButtonIconColor,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.topTitle,
    this.onMessageLongPressStart,
    this.style,
  });

  final ScrollController controller;
  final List<ChatMessageVm> messages;
  final String topTitle;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: style.messageListPadding,
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _ChatTopTitle(name: topTitle, style: style);
        }

        final messageIndex = messages.length - 1 - index;
        final current = messages[messageIndex];
        final previous = messageIndex == 0 ? null : messages[messageIndex - 1];
        return ChatMessageRow(
          key: ValueKey(current.localId),
          message: current,
          style: style,
          onMessageLongPressStart: onMessageLongPressStart,
          showDateDivider: shouldShowChatDateDivider(
            previous?.createdAt,
            current.createdAt,
          ),
        );
      },
    );
  }
}

class _ChatTopTitle extends StatelessWidget {
  const _ChatTopTitle({required this.name, required this.style});

  final String name;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    if (name.trim().isEmpty) return SizedBox(height: style.topTitleEmptyHeight);
    return Padding(
      padding: EdgeInsets.only(bottom: style.topTitleBottomPadding),
      child: Center(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.topTitleTextStyle,
        ),
      ),
    );
  }
}

class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({
    super.key,
    required this.message,
    required this.showDateDivider,
    this.onAvatarTap,
    this.onMessageLongPressStart,
    this.style,
  });

  final ChatMessageVm message;
  final bool showDateDivider;
  final VoidCallback? onAvatarTap;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    if (message.isSystem) {
      return ChatSystemMessage(
        text: message.isTick ? _tickAdvanceText(message) : message.text,
        fullWidth: message.isTick,
        singleLine: message.isTick,
        textAlign: message.isTick || message.isNarrator
            ? TextAlign.left
            : TextAlign.center,
        bubbleKey: message.isTick
            ? const ValueKey('chat-tick-message-bubble')
            : const ValueKey('chat-system-message-bubble'),
        style: style,
        onLongPressStart: onMessageLongPressStart == null
            ? null
            : (details) => onMessageLongPressStart!(context, message, details),
      );
    }

    final row = message.isMe
        ? _buildMe(context, style)
        : _buildOther(context, style);
    if (!showDateDivider) return row;

    return Column(
      children: [
        ChatDateDivider(time: message.createdAt, style: style),
        row,
      ],
    );
  }

  Widget _buildMe(BuildContext context, ChatUiStyleConfig style) {
    final maxBubbleWidth = _normalBubbleMaxWidth(context, style);
    final showFailedBadge = message.status == 'failed';
    final showSendingBadge = message.status == 'sending';
    final showStatusText =
        message.status != 'sent' && !showFailedBadge && !showSendingBadge;
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatAvatarSideSpacer(style: style),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showFailedBadge) ...[
                      ChatFailedBadge(style: style),
                      SizedBox(width: style.badgeBubbleGap),
                    ] else if (showSendingBadge) ...[
                      ChatSendingBadge(style: style),
                      SizedBox(width: style.badgeBubbleGap),
                    ],
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                        child: ChatMessageBubble(
                          message: message,
                          style: style,
                          onLongPressStart: onMessageLongPressStart == null
                              ? null
                              : (details) => onMessageLongPressStart!(
                                  context,
                                  message,
                                  details,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showStatusText) ...[
                  SizedBox(height: style.statusTextTopGap),
                  Text(message.status, style: style.statusTextStyle),
                ],
              ],
            ),
          ),
          SizedBox(width: style.avatarBubbleGap),
          ChatAvatar(
            label: chatInitials(message.senderName),
            imageUrl: message.avatarUrl,
            colors: style.selfAvatarColors,
            seed: message.senderName,
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _buildOther(BuildContext context, ChatUiStyleConfig style) {
    final maxBubbleWidth = _normalBubbleMaxWidth(context, style);
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAvatarTap,
                child: ChatAvatar(
                  label: chatInitials(message.senderName),
                  imageUrl: message.avatarUrl,
                  colors: style.otherAvatarColors,
                  seed: message.senderName,
                  style: style,
                ),
              ),
            ],
          ),
          SizedBox(width: style.avatarBubbleGap),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (style.showSenderNameAboveOtherBubble) ...[
                  Text(
                    message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.senderNameTextStyle,
                  ),
                  SizedBox(height: style.senderNameBottomGap),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: ChatMessageBubble(
                    message: message,
                    style: style,
                    onLongPressStart: onMessageLongPressStart == null
                        ? null
                        : (details) => onMessageLongPressStart!(
                            context,
                            message,
                            details,
                          ),
                  ),
                ),
              ],
            ),
          ),
          _ChatAvatarSideSpacer(style: style),
        ],
      ),
    );
  }
}

double _normalBubbleMaxWidth(BuildContext context, ChatUiStyleConfig style) {
  return _normalBubbleMaxWidthForWidth(MediaQuery.sizeOf(context).width, style);
}

double _normalBubbleMaxWidthForWidth(double width, ChatUiStyleConfig style) {
  final sideReservation = style.avatarSize + style.avatarBubbleGap;
  final rowAvailableWidth = width - sideReservation * 2;
  return rowAvailableWidth > 0 ? rowAvailableWidth : width;
}

class _ChatAvatarSideSpacer extends StatelessWidget {
  const _ChatAvatarSideSpacer({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: style.avatarSize + style.avatarBubbleGap);
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onLongPressStart,
    this.style,
  });

  final ChatMessageVm message;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final background = message.isMe
        ? style.selfBubbleColor
        : style.otherBubbleColor;
    final text = message.error == null
        ? message.text
        : '${message.text}\n${message.error}';
    return GestureDetector(
      onLongPressStart: onLongPressStart,
      child: Container(
        padding: style.bubblePadding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(style.bubbleBorderRadius),
        ),
        child: _InlineMarkdownText(
          text: text.isEmpty ? '...' : text,
          style: style.bubbleTextStyle,
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.label,
    required this.colors,
    this.imageUrl = '',
    this.seed,
    this.style,
  });

  final String label;
  final List<Color> colors;
  final String imageUrl;
  final String? seed;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final seed = this.seed?.trim();
    final imageUrl = this.imageUrl.trim();
    return SizedBox(
      width: style.avatarSize,
      height: style.avatarSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(style.avatarBorderRadius),
              ),
            ),
          ),
          Positioned.fill(
            child: GenesisAvatar(
              name: seed == null || seed.isEmpty ? label : seed,
              url: imageUrl,
              size: style.avatarSize,
              borderRadius: style.avatarBorderRadius,
              textStyle: style.avatarTextStyle,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(style.avatarBorderRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatAiBadge extends StatelessWidget {
  const ChatAiBadge({super.key, this.style});

  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return Icon(
      MyFlutterApp.redstarCharIcon,
      size: style.aiBadgeSize,
      color: style.aiBadgeColor,
    );
  }
}

class ChatSendingBadge extends StatelessWidget {
  const ChatSendingBadge({super.key, this.style});

  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return SizedBox.square(
      dimension: style.sendingBadgeSize,
      child: Padding(
        padding: EdgeInsets.all(style.sendingBadgePadding),
        child: CircularProgressIndicator(
          strokeWidth: style.sendingBadgeStrokeWidth,
          color: style.sendingBadgeColor,
        ),
      ),
    );
  }
}

class ChatFailedBadge extends StatelessWidget {
  const ChatFailedBadge({super.key, this.style});

  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return Container(
      width: style.failedBadgeSize,
      height: style.failedBadgeSize,
      decoration: BoxDecoration(
        color: style.failedBadgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.priority_high,
          size: style.failedBadgeIconSize,
          color: style.failedBadgeIconColor,
        ),
      ),
    );
  }
}

class ChatDateDivider extends StatelessWidget {
  ChatDateDivider({super.key, DateTime? time, this.style})
    : time = time ?? DateTime.now();

  final DateTime time;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return Padding(
      padding: EdgeInsets.only(bottom: style.dateDividerBottomPadding),
      child: Center(
        child: GenesisTimestampText(
          timestamp: time,
          style: style.dateDividerTextStyle,
        ),
      ),
    );
  }
}

bool shouldShowChatDateDivider(DateTime? previous, DateTime current) {
  if (previous == null) return true;
  return current.difference(previous) > const Duration(minutes: 30);
}

class ChatSystemMessage extends StatelessWidget {
  const ChatSystemMessage({
    super.key,
    required this.text,
    this.fullWidth = false,
    this.singleLine = false,
    this.textAlign = TextAlign.center,
    this.bubbleKey = const ValueKey('chat-system-message-bubble'),
    this.onLongPressStart,
    this.style,
  });

  final String text;
  final bool fullWidth;
  final bool singleLine;
  final TextAlign textAlign;
  final Key bubbleKey;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = fullWidth
            ? constraints.maxWidth
            : _normalBubbleMaxWidthForWidth(constraints.maxWidth, style);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: fullWidth ? maxBubbleWidth : 0,
              maxWidth: maxBubbleWidth,
            ),
            child: GestureDetector(
              onLongPressStart: onLongPressStart,
              child: Container(
                key: bubbleKey,
                margin: style.systemMessageMargin,
                padding: style.systemMessagePadding,
                decoration: BoxDecoration(
                  color: style.systemMessageBackgroundColor,
                  borderRadius: BorderRadius.circular(
                    style.systemMessageBorderRadius,
                  ),
                ),
                child: _InlineMarkdownText(
                  text: text,
                  maxLines: singleLine ? 1 : null,
                  overflow: singleLine ? TextOverflow.ellipsis : null,
                  textAlign: textAlign,
                  style: style.systemMessageTextStyle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InlineMarkdownText extends StatelessWidget {
  const _InlineMarkdownText({
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: style, children: _inlineMarkdownSpans(text, style)),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

List<InlineSpan> _inlineMarkdownSpans(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  var index = 0;

  void flushPlain() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString()));
    buffer.clear();
  }

  while (index < text.length) {
    final marker = text[index];
    if (marker == '\\' && index + 1 < text.length) {
      buffer.write(text[index + 1]);
      index += 2;
      continue;
    }
    if ((marker == '*' || marker == '_') &&
        !_isRepeatedMarker(text, index, marker)) {
      final end = _findInlineItalicEnd(text, index + 1, marker);
      if (end != -1 && end > index + 1) {
        flushPlain();
        spans.add(
          TextSpan(
            text: text.substring(index + 1, end),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        index = end + 1;
        continue;
      }
    }
    buffer.write(marker);
    index += 1;
  }

  flushPlain();
  return spans;
}

bool _isRepeatedMarker(String text, int index, String marker) {
  return (index > 0 && text[index - 1] == marker) ||
      (index + 1 < text.length && text[index + 1] == marker);
}

int _findInlineItalicEnd(String text, int start, String marker) {
  for (var index = start; index < text.length; index += 1) {
    if (text[index] == '\\') {
      index += 1;
      continue;
    }
    if (text[index] == marker && !_isRepeatedMarker(text, index, marker)) {
      return index;
    }
  }
  return -1;
}

String _tickAdvanceText(ChatMessageVm message) {
  final tick = message.tickNo > 0 ? '${message.tickNo}' : '';
  final time = message.text.trim();
  final prefix = tick.isEmpty ? 'Tick' : 'Tick $tick';
  return time.isEmpty ? prefix : '$prefix · $time';
}

String chatInitials(String value) {
  return initialsForAvatarName(value);
}

String firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}
