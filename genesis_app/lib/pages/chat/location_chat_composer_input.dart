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
    this.selfName = '',
    this.selfAvatarUrl = '',
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

  /// Shown when the player's character is not yet known.
  final String hintText;

  /// The character the player speaks as, which the toggle and hint name.
  final String selfName;
  final String selfAvatarUrl;
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
    final narrating = messageType == chatroomNarrationMessageType;
    final name = selfName.trim();
    // The hint says who the next message speaks as, and changes with the toggle.
    final resolvedHint = narrating
        ? 'Message as the Narrator'
        : name.isEmpty
        ? hintText
        : 'Message as $name';
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
          hintText: resolvedHint,
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
          inputLeading: onToggleMessageType == null
              ? null
              : _SpeakerToggle(
                  narrating: narrating,
                  selfName: name,
                  selfAvatarUrl: selfAvatarUrl,
                  plateColor: (style ?? ChatUiStyleConfig.standard)
                      .composerSendButtonDisabledColor,
                  onPressed: inputEnabled && !sending
                      ? onToggleMessageType
                      : null,
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

/// Who the next message speaks as, shown inside the input: the player's
/// character by default, the narrator once toggled. The hint names the same
/// choice in words, so the mark itself needs no label.
class _SpeakerToggle extends StatelessWidget {
  const _SpeakerToggle({
    required this.narrating,
    required this.selfName,
    required this.selfAvatarUrl,
    required this.plateColor,
    required this.onPressed,
  });

  final bool narrating;
  final String selfName;
  final String selfAvatarUrl;

  /// The grey the composer's other controls rest on.
  final Color plateColor;
  final VoidCallback? onPressed;

  /// The input's single-line height, so the mark centres on that line and the
  /// whole slot is a comfortable tap target.
  static const double _slot = 40;
  static const double _mark = 26;
  static const double _radius = 6;

  @override
  Widget build(BuildContext context) {
    final speaker = narrating
        ? 'the Narrator'
        : (selfName.isEmpty ? 'your character' : selfName);
    return MergeSemantics(
      child: Semantics(
        toggled: narrating,
        label: 'Speaking as $speaker',
        child: Tooltip(
          message: narrating ? 'Switch to character' : 'Switch to narration',
          // A real button, as the toggle was before it moved inside the
          // input: it takes keyboard focus and reports when it is disabled.
          child: TextButton(
            key: const ValueKey('location-chat-message-type-toggle'),
            onPressed: onPressed,
            style:
                TextButton.styleFrom(
                  fixedSize: const Size.square(_slot),
                  minimumSize: const Size.square(_slot),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ).copyWith(
                  // No ripple or wash over the mark inside the input.
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  splashFactory: NoSplash.splashFactory,
                ),
            child: Opacity(
              opacity: onPressed == null ? 0.45 : 1,
              child: SizedBox.square(
                dimension: _slot,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: narrating
                        ? Container(
                            key: const ValueKey('speaker-narrator'),
                            width: _mark,
                            height: _mark,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: plateColor,
                              borderRadius: BorderRadius.circular(_radius),
                            ),
                            child: SvgPicture.asset(
                              paragraphIconAsset,
                              excludeFromSemantics: true,
                              width: 14,
                              height: 14,
                              colorFilter: const ColorFilter.mode(
                                GenesisColors.darkTextPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          )
                        : GenesisCharacterAvatar(
                            key: const ValueKey('speaker-character'),
                            url: selfAvatarUrl,
                            name: selfName,
                            size: _mark,
                            borderRadius: _radius,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
