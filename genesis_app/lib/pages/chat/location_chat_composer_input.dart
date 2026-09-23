part of 'location_chat_page.dart';

class LocationChatComposerInput extends StatelessWidget {
  const LocationChatComposerInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.inputEnabled,
    required this.sendEnabled,
    required this.sending,
    required this.onSend,
    this.onInputTap,
    this.messageType = chatroomTextMessageType,
    this.onToggleMessageType,
    this.onHeightChanged,
    this.hintText = 'Text...',
    this.style,
    this.bottomSafeAreaInset,
    this.composerHeader,
    this.keepShortcutsVisible = false,
    this.showShortcuts = true,
    this.backdropGroupKey,
    this.animateSendButton = true,
  });

  final LocationChatMentionEditingController controller;
  final FocusNode focusNode;
  final bool inputEnabled;
  final bool sendEnabled;
  final bool sending;
  final Future<void> Function() onSend;
  final VoidCallback? onInputTap;
  final String messageType;
  final VoidCallback? onToggleMessageType;
  final ValueChanged<double>? onHeightChanged;
  final String hintText;
  final ChatUiStyleConfig? style;
  final double? bottomSafeAreaInset;
  final Widget? composerHeader;
  final bool keepShortcutsVisible;
  final bool showShortcuts;
  final BackdropKey? backdropGroupKey;
  final bool animateSendButton;

  void _insertShortcut(String shortcut) {
    controller.insertShortcut(shortcut);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? ChatUiStyleConfig.standard;
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final shortcutsVisible =
            showShortcuts &&
            inputEnabled &&
            (focusNode.hasFocus || keepShortcutsVisible);
        final shortcutsEnabled = inputEnabled && focusNode.hasFocus;
        return ChatComposer(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
          inputEnabled: inputEnabled,
          sendEnabled: sendEnabled,
          sending: sending,
          animateSendButton: animateSendButton,
          onSend: onSend,
          onInputTap: onInputTap,
          onInputTapAlwaysCalled: onInputTap != null,
          onHeightChanged: onHeightChanged,
          bottomSafeAreaInset: bottomSafeAreaInset,
          composerHeader: composerHeader,
          leadingAction: onToggleMessageType == null
              ? null
              : MergeSemantics(
                  child: Semantics(
                    toggled: messageType == chatroomNarrationMessageType,
                    child: Tooltip(
                      message: messageType == chatroomNarrationMessageType
                          ? 'Switch to character'
                          : 'Switch to narration',
                      child: ChatComposerActionButton(
                        key: const ValueKey(
                          'location-chat-message-type-toggle',
                        ),
                        active: messageType == chatroomNarrationMessageType,
                        onPressed: inputEnabled && !sending
                            ? onToggleMessageType
                            : null,
                        style: resolvedStyle,
                        animate: animateSendButton,
                        icon: SvgPicture.asset(
                          paragraphIconAsset,
                          excludeFromSemantics: true,
                          width: resolvedStyle.composerSendButtonIconSize,
                          height: resolvedStyle.composerSendButtonIconSize,
                          colorFilter: ColorFilter.mode(
                            resolvedStyle.composerSendButtonIconColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          sendIcon: ChatComposerSendIcon.arrowUp,
          pinActionsToBottom: true,
          style: style,
          leadingShortcutLabel: shortcutsVisible ? '*' : null,
          onLeadingShortcutPressed: shortcutsEnabled
              ? () => _insertShortcut('*')
              : null,
          secondaryLeadingShortcutLabel: shortcutsVisible ? '@' : null,
          onSecondaryLeadingShortcutPressed: shortcutsEnabled
              ? () => _insertShortcut('@')
              : null,
          backdropGroupKey: backdropGroupKey,
        );
      },
    );
  }
}
