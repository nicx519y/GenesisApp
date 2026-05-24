import 'dart:async';

import 'package:flutter/material.dart';

import '../../../icons/my_flutter_app_icons.dart';

class LocationChatComposer extends StatelessWidget {
  const LocationChatComposer({
    super.key,
    required this.controller,
    required this.inputEnabled,
    required this.sendEnabled,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool inputEnabled;
  final bool sendEnabled;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 16 + bottomInset),
      color: const Color(0xFFF1EFF1).withValues(alpha: 0.98),
      child: Row(
        children: [
          _ComposerIconButton(
            icon: MyFlutterApp.voice,
            onPressed: inputEnabled ? () {} : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: TextField(
                controller: controller,
                enabled: inputEnabled,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (sendEnabled) unawaited(onSend());
                },
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ComposerIconButton(
            icon: MyFlutterApp.sticker,
            onPressed: inputEnabled ? () {} : null,
          ),
          const SizedBox(width: 10),
          _ComposerIconButton(
            icon: sending ? Icons.hourglass_top : MyFlutterApp.add2,
            onPressed: sendEnabled ? onSend : null,
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 30),
      ),
    );
  }
}
