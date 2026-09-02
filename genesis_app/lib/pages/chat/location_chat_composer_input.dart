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
    this.onHeightChanged,
    this.hintText = 'Text...',
    this.style,
    this.bottomSafeAreaInset,
    this.composerHeader,
    this.keepShortcutsVisible = false,
    this.backdropGroupKey,
  });

  final LocationChatMentionEditingController controller;
  final FocusNode focusNode;
  final bool inputEnabled;
  final bool sendEnabled;
  final bool sending;
  final Future<void> Function() onSend;
  final ValueChanged<double>? onHeightChanged;
  final String hintText;
  final ChatUiStyleConfig? style;
  final double? bottomSafeAreaInset;
  final Widget? composerHeader;
  final bool keepShortcutsVisible;
  final BackdropKey? backdropGroupKey;

  void _insertShortcut(String shortcut) {
    controller.insertShortcut(shortcut);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final showShortcuts =
            inputEnabled && (focusNode.hasFocus || keepShortcutsVisible);
        final shortcutsEnabled = inputEnabled && focusNode.hasFocus;
        return ChatComposer(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
          inputEnabled: inputEnabled,
          sendEnabled: sendEnabled,
          sending: sending,
          onSend: onSend,
          onHeightChanged: onHeightChanged,
          bottomSafeAreaInset: bottomSafeAreaInset,
          composerHeader: composerHeader,
          sendIcon: ChatComposerSendIcon.arrowUp,
          pinActionsToBottom: true,
          style: style,
          leadingShortcutLabel: showShortcuts ? '*' : null,
          onLeadingShortcutPressed: shortcutsEnabled
              ? () => _insertShortcut('*')
              : null,
          secondaryLeadingShortcutLabel: showShortcuts ? '@' : null,
          onSecondaryLeadingShortcutPressed: shortcutsEnabled
              ? () => _insertShortcut('@')
              : null,
          backdropGroupKey: backdropGroupKey,
        );
      },
    );
  }
}
