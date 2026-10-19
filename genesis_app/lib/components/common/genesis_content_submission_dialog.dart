import '../../l10n/genesis_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_colors.dart';
import '../../utils/api_error_message.dart';

import 'genesis_action_box.dart';
import 'genesis_center_toast.dart';
import 'genesis_modal_routes.dart';

typedef GenesisContentSubmitter = Future<void> Function(String content);

Future<bool> showGenesisContentSubmissionDialog({
  required BuildContext context,
  required String title,
  required Key contentInputKey,
  required GenesisContentSubmitter onSubmit,
  required String successMessage,
  required String failureMessage,
  Brightness? brightness,
  double widthFactor = 0.7,
  int inputLines = 3,
}) async {
  final toastBrightness = brightness ?? Theme.of(context).brightness;
  final submitted = await showGenesisDialog<bool>(
    context: context,
    barrierColor: const Color(0x52000000),
    builder: (dialogContext) {
      return _GenesisContentSubmissionDialog(
        title: title,
        widthFactor: widthFactor,
        inputLines: inputLines,
        contentInputKey: contentInputKey,
        onSubmit: onSubmit,
        successMessage: successMessage,
        failureMessage: failureMessage,
        toastBrightness: toastBrightness,
      );
    },
  );
  return submitted == true;
}

class _GenesisContentSubmissionDialog extends StatefulWidget {
  const _GenesisContentSubmissionDialog({
    required this.title,
    required this.widthFactor,
    required this.inputLines,
    required this.contentInputKey,
    required this.onSubmit,
    required this.successMessage,
    required this.failureMessage,
    required this.toastBrightness,
  });

  final String title;
  final double widthFactor;
  final int inputLines;
  final Key contentInputKey;
  final GenesisContentSubmitter onSubmit;
  final String successMessage;
  final String failureMessage;
  final Brightness toastBrightness;

  @override
  State<_GenesisContentSubmissionDialog> createState() =>
      _GenesisContentSubmissionDialogState();
}

class _GenesisContentSubmissionDialogState
    extends State<_GenesisContentSubmissionDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(content);
      if (!mounted) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      Navigator.of(context).pop(true);
      if (overlay != null) {
        showGenesisToastInOverlay(
          overlay,
          widget.successMessage,
          brightness: widget.toastBrightness,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showGenesisToast(
        context,
        apiErrorMessage(error, fallback: widget.failureMessage),
        brightness: Brightness.dark,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = GenesisFeedbackInput(
      inputKey: widget.contentInputKey,
      controller: _controller,
      focusNode: _focusNode,
      lines: widget.inputLines,
      onChanged: (_) => setState(() {}),
    );
    return GenesisActionBox<bool>(
      title: widget.title,
      widthFactor: widget.widthFactor,
      titleHeight: widget.inputLines == 3 ? 157 : 64,
      titleContentSpacing: 16,
      titleContent: widget.inputLines == 3 ? input : null,
      content: widget.inputLines == 3
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: input,
            ),
      actions: [
        GenesisActionBoxAction<bool>(
          label: GenesisL10n.current.createSubmit,
          value: true,
          enabled: !_submitting && _controller.text.trim().isNotEmpty,
        ),
      ],
      onActionSelected: (_) => unawaited(_submit()),
      onCancel: () => Navigator.of(context).pop(false),
    );
  }
}

/// Shared feedback field used by Settings and the rating dialog.
class GenesisFeedbackInput extends StatelessWidget {
  const GenesisFeedbackInput({
    super.key,
    required this.inputKey,
    required this.controller,
    this.focusNode,
    this.lines = 5,
    this.autofocus = true,
    this.hintText,
    this.enabled = true,
    this.onChanged,
  });

  final Key inputKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int lines;
  final bool autofocus;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: inputKey,
    controller: controller,
    focusNode: focusNode,
    cursorColor: GenesisColors.darkTextPrimary,
    style: const TextStyle(color: GenesisColors.darkTextPrimary),
    autofocus: autofocus,
    minLines: lines,
    maxLines: lines,
    textInputAction: TextInputAction.newline,
    decoration: InputDecoration(
      filled: true,
      fillColor: GenesisColors.darkFaintFill,
      hintText: hintText ?? GenesisL10n.current.createDescribeIssue,
      hintStyle: const TextStyle(color: GenesisColors.darkInputPlaceholder),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
    onChanged: onChanged,
    enabled: enabled,
  );
}
