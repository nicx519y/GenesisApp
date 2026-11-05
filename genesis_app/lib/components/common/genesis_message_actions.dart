import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/genesis_l10n.dart';
import 'genesis_report_actions.dart';
import 'genesis_center_toast.dart';

/// Shares the message menu and its actions across chat scenes.
/// Callers supply the scene's real report ID; null omits that action.
Future<void> showGenesisMessageActionMenu({
  required BuildContext context,
  required Offset globalPosition,
  String? copyText,
  String? reportTargetId,
}) {
  if (!context.mounted) return Future<void>.value();
  return showGenesisActionMenuAt(
    context: context,
    globalPosition: globalPosition,
    appearance: GenesisActionMenuAppearance.message,
    items: [
      if (copyText != null)
        GenesisActionMenuItem(
          label: GenesisL10n.current.chatCopy,
          iconData: Icons.copy_outlined,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: copyText));
            if (!context.mounted) return;
            showGenesisToast(
              context,
              GenesisL10n.current.chatCopied,
              brightness: Brightness.dark,
            );
          },
        ),
      if (reportTargetId != null && reportTargetId.isNotEmpty)
        GenesisActionMenuItem(
          label: GenesisL10n.current.chatReport,
          iconAsset: genesisReportIconAsset,
          onSelected: () {
            showGenesisReportDialog(
              context: context,
              targetType: 'message',
              targetId: reportTargetId,
            );
          },
        ),
    ],
  );
}
