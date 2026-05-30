import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/genesis_bottom_sheet_panel.dart';
import 'origin_character_form.dart';
import '../../network/models/origin.dart';
import '../../ui/components/genesis_character_avatar.dart';

typedef OriginRoleProfileLoader = Future<OriginCustomRoleDraft?> Function();
typedef OriginRoleAvatarResolver = String Function(String avatar);

@immutable
class OriginCustomRoleDraft {
  const OriginCustomRoleDraft({
    this.avatarUrl = '',
    this.name = '',
    this.identity = '',
    this.bio = '',
  });

  final String avatarUrl;
  final String name;
  final String identity;
  final String bio;

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'identity': identity.trim(),
    };
    final resolvedAvatar = avatarUrl.trim();
    final resolvedBio = bio.trim();
    if (resolvedAvatar.isNotEmpty) payload['avatar'] = resolvedAvatar;
    if (resolvedBio.isNotEmpty) payload['bio'] = resolvedBio;
    return payload;
  }
}

@immutable
class OriginRoleLaunchSelection {
  const OriginRoleLaunchSelection._({this.presetCharacterId, this.customRole});

  factory OriginRoleLaunchSelection.preset(String characterId) {
    return OriginRoleLaunchSelection._(presetCharacterId: characterId);
  }

  factory OriginRoleLaunchSelection.custom(OriginCustomRoleDraft role) {
    return OriginRoleLaunchSelection._(customRole: role);
  }

  final String? presetCharacterId;
  final OriginCustomRoleDraft? customRole;
}

Future<OriginRoleLaunchSelection?> showOriginRoleLaunchSheet({
  required BuildContext context,
  required List<OriginCharacter> characters,
  OriginRoleProfileLoader? onFillFromProfile,
  OriginRoleAvatarResolver? resolveAvatarUrl,
}) {
  return showModalBottomSheet<OriginRoleLaunchSelection>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height),
    builder: (context) {
      return OriginRoleLaunchSheet(
        characters: characters,
        onFillFromProfile: onFillFromProfile,
        resolveAvatarUrl: resolveAvatarUrl,
      );
    },
  );
}

class OriginRoleLaunchSheet extends StatefulWidget {
  const OriginRoleLaunchSheet({
    super.key,
    required this.characters,
    this.onFillFromProfile,
    this.resolveAvatarUrl,
  });

  final List<OriginCharacter> characters;
  final OriginRoleProfileLoader? onFillFromProfile;
  final OriginRoleAvatarResolver? resolveAvatarUrl;

  @override
  State<OriginRoleLaunchSheet> createState() => _OriginRoleLaunchSheetState();
}

class _OriginRoleLaunchSheetState extends State<OriginRoleLaunchSheet> {
  final OriginCharacterForm _customForm = OriginCharacterForm.empty(
    charId: 'custom_role',
  );
  int _tabIndex = 0;
  String _selectedPresetId = '';
  bool _fillingProfile = false;

  @override
  void initState() {
    super.initState();
    _selectedPresetId = _firstPresetId(widget.characters);
    _customForm.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant OriginRoleLaunchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characters != widget.characters &&
        !_hasCharacterId(widget.characters, _selectedPresetId)) {
      _selectedPresetId = _firstPresetId(widget.characters);
    }
  }

  @override
  void dispose() {
    _customForm
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _customReady {
    return _customForm.name.text.trim().isNotEmpty &&
        _customForm.identity.text.trim().isNotEmpty &&
        !_fillingProfile;
  }

  bool get _canLaunch {
    if (_tabIndex == 0) return _selectedPresetId.trim().isNotEmpty;
    return _customReady;
  }

  void _selectTab(int index) {
    if (_tabIndex == index) return;
    FocusScope.of(context).unfocus();
    setState(() => _tabIndex = index);
  }

  Future<void> _fillFromProfile() async {
    final loader = widget.onFillFromProfile;
    if (loader == null || _fillingProfile) return;
    FocusScope.of(context).unfocus();
    setState(() => _fillingProfile = true);
    try {
      final draft = await loader();
      if (!mounted || draft == null) return;
      final name = draft.name.trim();
      final identity = draft.identity.trim();
      final bio = draft.bio.trim();
      final avatar = draft.avatarUrl.trim();
      if (name.isNotEmpty) _customForm.name.text = name;
      if (identity.isNotEmpty) _customForm.identity.text = identity;
      if (bio.isNotEmpty) _customForm.bio.text = bio;
      _customForm.avatarUrl.text = avatar;
      debugPrint(
        '[OriginRoleLaunch] Applied profile avatar to custom form: '
        'avatar="$avatar"',
      );
    } finally {
      if (mounted) setState(() => _fillingProfile = false);
    }
  }

  void _submit() {
    if (!_canLaunch) return;
    if (_tabIndex == 0) {
      Navigator.of(
        context,
      ).pop(OriginRoleLaunchSelection.preset(_selectedPresetId.trim()));
      return;
    }

    Navigator.of(context).pop(
      OriginRoleLaunchSelection.custom(
        OriginCustomRoleDraft(
          avatarUrl: _customForm.avatarUrl.text,
          name: _customForm.name.text,
          identity: _customForm.identity.text,
          bio: _customForm.bio.text,
        ),
      ),
    );
  }

  void _dismiss() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 18;
    final targetHeight = math.min(media.size.height * 0.7, maxHeight);

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('origin-role-scrim-dismiss'),
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: GenesisBottomSheetPanel(
                  key: const ValueKey('origin-role-sheet'),
                  title: 'Setup Your Role',
                  height: targetHeight,
                  padding: const EdgeInsets.fromLTRB(20, 21, 20, 14),
                  titleBottomSpacing: 12,
                  titleTextStyle: const TextStyle(
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                  trailing: IconButton(
                    key: const ValueKey('origin-role-sheet-close'),
                    onPressed: _dismiss,
                    icon: const Icon(
                      Icons.close,
                      size: 22,
                      color: Color(0xFF666666),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 42,
                      height: 42,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoleSegmentedControl(
                        index: _tabIndex,
                        onChanged: _selectTab,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 140),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          child: _tabIndex == 0
                              ? _PresetRoleGrid(
                                  key: const ValueKey('origin-role-preset-tab'),
                                  characters: widget.characters,
                                  selectedId: _selectedPresetId,
                                  resolveAvatarUrl: widget.resolveAvatarUrl,
                                  onSelected: (id) {
                                    setState(() => _selectedPresetId = id);
                                  },
                                )
                              : _CustomRoleForm(
                                  key: const ValueKey('origin-role-custom-tab'),
                                  form: _customForm,
                                  fillingProfile: _fillingProfile,
                                  canFillProfile:
                                      widget.onFillFromProfile != null,
                                  onChanged: _handleTextChanged,
                                  onFillFromProfile: _fillFromProfile,
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SheetActions(
                        canLaunch: _canLaunch,
                        onCancel: _dismiss,
                        onLaunch: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSegmentedControl extends StatelessWidget {
  const _RoleSegmentedControl({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDEF),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            alignment: index == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3E3E7)),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _SegmentButton(
                label: 'Preset',
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
              _SegmentButton(
                label: 'Custom',
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF111111)
                    : const Color(0xFF595959),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetRoleGrid extends StatelessWidget {
  const _PresetRoleGrid({
    super.key,
    required this.characters,
    required this.selectedId,
    required this.onSelected,
    this.resolveAvatarUrl,
  });

  final List<OriginCharacter> characters;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final OriginRoleAvatarResolver? resolveAvatarUrl;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return const Center(
        child: Text(
          'No preset role',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF777777),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: characters.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 128,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final character = characters[index];
        final id = _characterRoleId(character);
        final avatar =
            resolveAvatarUrl?.call(character.avatar) ?? character.avatar.trim();
        return _PresetRoleTile(
          character: character,
          avatarUrl: avatar,
          selected: id == selectedId,
          onTap: () => onSelected(id),
        );
      },
    );
  }
}

class _PresetRoleTile extends StatelessWidget {
  const _PresetRoleTile({
    required this.character,
    required this.avatarUrl,
    required this.selected,
    required this.onTap,
  });

  final OriginCharacter character;
  final String avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('origin-role-preset-${_characterRoleId(character)}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GenesisCharacterAvatar(
                    url: avatarUrl,
                    name: character.name,
                    size: 82,
                    borderRadius: 8,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _SelectionMark(selected: selected),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              character.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.1,
                fontWeight: FontWeight.w400,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF198B64) : Colors.white10,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 5,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: selected
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}

class _CustomRoleForm extends StatelessWidget {
  const _CustomRoleForm({
    super.key,
    required this.form,
    required this.fillingProfile,
    required this.canFillProfile,
    required this.onChanged,
    required this.onFillFromProfile,
  });

  final OriginCharacterForm form;
  final bool fillingProfile;
  final bool canFillProfile;
  final VoidCallback onChanged;
  final VoidCallback onFillFromProfile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1E1E6), width: 1.2),
            ),
            child: OriginCharacterFormFields(
              form: form,
              onChanged: onChanged,
              showPersonality: false,
              showGoal: false,
              avatarWidth: 96,
              avatarHeight: 142,
              avatarCropSize: const Size(512, 512),
              topSpacing: 0,
              fieldGap: 22,
              sectionGap: 28,
              bioMaxLines: 4,
            ),
          ),
          if (canFillProfile) ...[
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('origin-role-fill-profile'),
                onTap: fillingProfile ? null : onFillFromProfile,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  child: Text(
                    fillingProfile ? 'Filling...' : 'Fill from my profile',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF198B64),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.canLaunch,
    required this.onCancel,
    required this.onLaunch,
  });

  final bool canLaunch;
  final VoidCallback onCancel;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 32,
            child: OutlinedButton(
              key: const ValueKey('origin-role-cancel'),
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111111),
                side: const BorderSide(color: Color(0xFFD9D9DF), width: 1.2),
                textStyle: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 32,
            child: FilledButton(
              key: const ValueKey('origin-role-launch'),
              onPressed: canLaunch ? onLaunch : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF198B64),
                disabledBackgroundColor: const Color(0xFFC8D9D1),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Launch'),
            ),
          ),
        ),
      ],
    );
  }
}

String _firstPresetId(List<OriginCharacter> characters) {
  if (characters.isEmpty) return '';
  return _characterRoleId(characters.first);
}

bool _hasCharacterId(List<OriginCharacter> characters, String id) {
  if (id.trim().isEmpty) return false;
  return characters.any((character) => _characterRoleId(character) == id);
}

String _characterRoleId(OriginCharacter character) {
  final explicitId = character.characterId.trim();
  if (explicitId.isNotEmpty) return explicitId;
  if (character.id > 0) return '${character.id}';
  return character.name.trim();
}
