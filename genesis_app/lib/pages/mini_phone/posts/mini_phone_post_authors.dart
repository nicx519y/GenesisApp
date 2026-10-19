import '../../../l10n/genesis_localizations.dart';
import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';

class MiniPhonePostAuthors extends StatelessWidget {
  const MiniPhonePostAuthors({
    super.key,
    required this.authors,
    required this.me,
    required this.selectedId,
    required this.onCreate,
    required this.onSelect,
  });
  final List<PhonePerson> authors;
  final PhonePerson me;
  final String? selectedId;
  final VoidCallback onCreate;
  final ValueChanged<String?> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 62 + 7 + MediaQuery.textScalerOf(context).scale(12) * 1.5,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: authors.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 72,
              child: _authorShortcut(context, me, create: true),
            ),
          );
        }
        return SizedBox(
          width: 72,
          child: index == 1
              ? Align(
                  alignment: Alignment.topLeft,
                  child: miniPhoneAllAuthorsShortcut(
                    selected: selectedId == null,
                    onTap: () {
                      if (selectedId != null) onSelect(null);
                    },
                  ),
                )
              : _authorShortcut(context, authors[index - 2]),
        );
      },
    ),
  );
  Widget _authorShortcut(
    BuildContext context,
    PhonePerson p, {
    bool create = false,
  }) => GestureDetector(
    key: ValueKey('mini-phone-post-author-${create ? 'create' : p.id}'),
    onTap: () {
      if (create) {
        onCreate();
      } else {
        onSelect(selectedId == p.id ? null : p.id);
      }
    },
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: !create && selectedId == p.id
                      ? miniPink
                      : const Color(0x33FFFFFF),
                ),
              ),
              child: miniPhonePersonAvatar(p, 54),
            ),
            if (create)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: miniRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: MiniIcon('plus', size: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          create ? context.l10n.miniPhoneCreate : p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: miniStyle(12, FontWeight.w500),
        ),
      ],
    ),
  );
}
