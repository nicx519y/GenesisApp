import 'package:flutter/material.dart';
import '../../../ui/components/genesis_primary_button.dart';
import '../../../ui/components/genesis_avatar.dart';
import '../../../ui/components/genesis_character_avatar.dart';
import '../../../ui/tokens/genesis_colors.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import 'mini_phone_ui.dart';

Widget miniPhoneButton(
  String text,
  VoidCallback? action, {
  bool primary = false,
  bool isLoading = false,
  bool showLoadingIndicator = false,
}) => primary
    ? GenesisPrimaryButton(
        label: text,
        isLoading: isLoading,
        showLoadingIndicator: showLoadingIndicator,
        onPressed: action,
        fullWidth: false,
        backgroundColor: miniRed,
        foregroundColor: miniWhite,
        disabledBackgroundColor: GenesisColors.darkButtonDisabledBackground,
        disabledForegroundColor: GenesisColors.darkButtonDisabledForeground,
      )
    : TextButton(
        onPressed: action,
        style: TextButton.styleFrom(
          backgroundColor: primary ? miniRed : null,
          foregroundColor: miniPink,
          disabledBackgroundColor: primary
              ? miniRed.withValues(alpha: .35)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: miniButtonRadius),
        ),
        child: Text(
          text,
          style: miniStyle(
            14,
            FontWeight.w600,
            primary ? (action == null ? miniSecondary : miniWhite) : miniPink,
          ),
        ),
      );
Widget miniPhoneInput(
  TextEditingController controller,
  String hint, {
  int? limit = 500,
  required VoidCallback onChanged,
  int maxLines = 4,
}) => TextField(
  controller: controller,
  maxLength: limit,
  minLines: 1,
  maxLines: maxLines,
  style: miniStyle(14),
  onChanged: (_) => onChanged(),
  decoration: InputDecoration(
    hintText: hint,
    counterText: '',
    isDense: true,
    hintStyle: miniStyle(14, FontWeight.w400, miniPlaceholder),
    filled: true,
    fillColor: GenesisColors.darkFaintFill,
    border: const OutlineInputBorder(
      borderRadius: miniInputRadius,
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: miniInputRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: miniInputRadius,
      borderSide: BorderSide.none,
    ),
  ),
);
Widget miniPhoneSendButton(VoidCallback? action) => IconButton(
  tooltip: 'Send',
  onPressed: action,
  style: IconButton.styleFrom(
    backgroundColor: miniRed,
    disabledBackgroundColor: miniRed.withValues(alpha: .35),
  ),
  icon: MiniIcon(
    'send',
    size: 16,
    color: action == null ? miniSecondary : miniWhite,
  ),
);
Widget miniPhoneAllAuthorsShortcut({
  required bool selected,
  required VoidCallback onTap,
}) => Semantics(
  label: 'All authors',
  button: true,
  selected: selected,
  child: GestureDetector(
    key: const ValueKey('mini-phone-post-author-all'),
    onTap: onTap,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? miniPink : const Color(0x33FFFFFF),
            ),
          ),
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: miniRaised,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('all', style: miniStyle(16, FontWeight.w600)),
          ),
        ),
      ],
    ),
  ),
);
Widget miniPhonePostAction(
  String icon,
  String label,
  int count,
  VoidCallback action, {
  bool selected = false,
}) => Semantics(
  label: '$label, $count',
  button: true,
  toggled: icon == 'heart' ? selected : null,
  child: InkWell(
    onTap: action,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniIcon(icon, size: 15, color: selected ? miniPink : miniSecondary),
          const SizedBox(width: 6),
          Text('$count', style: miniStyle(12, FontWeight.w400, miniSecondary)),
        ],
      ),
    ),
  ),
);

class MiniPhoneUploadBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(13)),
      );
    final paint = Paint()
      ..color = const Color(0x47FFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final m in path.computeMetrics()) {
      for (double start = 0; start < m.length; start += 8) {
        canvas.drawPath(
          m.extractPath(start, (start + 4).clamp(0, m.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MiniPhoneUploadBorder oldDelegate) => false;
}

Widget miniPhonePersonAvatar(PhonePerson p, double size, {double? radius}) =>
    p.type == 2
    ? GenesisCharacterAvatar(
        url: p.avatar,
        name: p.name,
        size: size,
        borderRadius: radius ?? size / 2,
      )
    : GenesisAvatar(
        url: p.avatar,
        name: p.name,
        size: size,
        borderRadius: radius ?? size / 2,
      );
