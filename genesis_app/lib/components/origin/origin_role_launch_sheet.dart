import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../common/genesis_center_toast.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import '../common/genesis_modal_routes.dart';
import '../world_details_shell.dart';
import 'origin_character_form.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/models/origin.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_edge_swipe_back.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_colors.dart';

typedef OriginRoleProfileLoader = Future<OriginCustomRoleDraft?> Function();
typedef OriginRoleAvatarResolver = String Function(String avatar);
typedef OriginLaunchedWorldsLoader =
    Future<List<OriginLaunchedWorldRole>> Function();

@immutable
class OriginLaunchedWorldRole {
  const OriginLaunchedWorldRole({
    required this.worldId,
    required this.roleName,
    required this.avatarUrl,
    required this.tickCount,
    required this.currentTime,
  });

  final String worldId;
  final String roleName;
  final String avatarUrl;
  final int tickCount;
  final String currentTime;
}

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
  const OriginRoleLaunchSelection._({
    this.presetCharacterId,
    this.customRole,
    this.existingWorldId,
  });

  factory OriginRoleLaunchSelection.preset(String characterId) {
    return OriginRoleLaunchSelection._(presetCharacterId: characterId);
  }

  factory OriginRoleLaunchSelection.custom(OriginCustomRoleDraft role) {
    return OriginRoleLaunchSelection._(customRole: role);
  }

  factory OriginRoleLaunchSelection.enter(String worldId) {
    return OriginRoleLaunchSelection._(existingWorldId: worldId);
  }

  final String? presetCharacterId;
  final OriginCustomRoleDraft? customRole;
  final String? existingWorldId;
}

Future<OriginRoleLaunchSelection?> showOriginRoleLaunchSheet({
  required BuildContext context,
  required List<OriginCharacter> characters,
  OriginRoleProfileLoader? onFillFromProfile,
  OriginRoleAvatarResolver? resolveAvatarUrl,
  OriginLaunchedWorldsLoader? launchedWorldsLoader,
  List<OriginLaunchedWorldRole>? initialLaunchedWorlds,
}) {
  return WorldDetailsStatusBarOverride.runWithStyle(
    kGenesisDefaultSystemUiOverlayStyle,
    () => GenesisSystemUiChrome.runWithModalChrome(
      Colors.white,
      () => Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<OriginRoleLaunchSelection>(
          opaque: false,
          barrierDismissible: false,
          barrierColor: kGenesisSubtleModalBarrierColor,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true,
              body: OriginRoleLaunchSheet(
                characters: characters,
                onFillFromProfile: onFillFromProfile,
                resolveAvatarUrl: resolveAvatarUrl,
                launchedWorldsLoader: launchedWorldsLoader,
                initialLaunchedWorlds: initialLaunchedWorlds,
              ),
            );
          },
        ),
      ),
    ),
  );
}

class OriginRoleLaunchSheet extends StatefulWidget {
  const OriginRoleLaunchSheet({
    super.key,
    required this.characters,
    this.onFillFromProfile,
    this.resolveAvatarUrl,
    this.launchedWorldsLoader,
    this.initialLaunchedWorlds,
  });

  final List<OriginCharacter> characters;
  final OriginRoleProfileLoader? onFillFromProfile;
  final OriginRoleAvatarResolver? resolveAvatarUrl;
  final OriginLaunchedWorldsLoader? launchedWorldsLoader;
  final List<OriginLaunchedWorldRole>? initialLaunchedWorlds;

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
  bool _loadingLaunchedWorlds = false;
  List<OriginLaunchedWorldRole> _launchedWorlds =
      const <OriginLaunchedWorldRole>[];
  String _selectedLaunchedWorldId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(kGenesisDefaultSystemUiOverlayStyle);
    });
    _customForm.addListener(_handleTextChanged);
    final initialLaunchedWorlds = widget.initialLaunchedWorlds;
    if (initialLaunchedWorlds != null) {
      _launchedWorlds = initialLaunchedWorlds;
      if (initialLaunchedWorlds.isNotEmpty) _tabIndex = 2;
    } else {
      _loadLaunchedWorlds();
    }
  }

  @override
  void didUpdateWidget(covariant OriginRoleLaunchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characters != widget.characters &&
        !_hasCharacterId(widget.characters, _selectedPresetId)) {
      _selectedPresetId = '';
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
    if (_tabIndex == 2) return _selectedLaunchedWorldId.trim().isNotEmpty;
    return _customReady;
  }

  Future<void> _loadLaunchedWorlds() async {
    final loader = widget.launchedWorldsLoader;
    if (loader == null) return;
    setState(() => _loadingLaunchedWorlds = true);
    try {
      final worlds = await loader();
      if (!mounted) return;
      setState(() {
        _launchedWorlds = worlds;
        if (worlds.isNotEmpty) _tabIndex = 2;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[OriginRoleLaunchSheet] launched worlds load failed: '
        '$error\n$stackTrace',
      );
    } finally {
      if (mounted) setState(() => _loadingLaunchedWorlds = false);
    }
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
      if (name.isNotEmpty) {
        _customForm.name.text = _limitProfileFill(
          name,
          originCharacterNameMaxLength,
        );
      }
      if (identity.isNotEmpty) {
        _customForm.identity.text = _limitProfileFill(
          identity,
          originCharacterIdentityMaxLength,
        );
      }
      if (bio.isNotEmpty) {
        _customForm.bio.text = _limitProfileFill(
          bio,
          originCharacterBioMaxLength,
        );
      }
      _customForm.avatarUrl.text = avatar;
    } finally {
      if (mounted) setState(() => _fillingProfile = false);
    }
  }

  void _submit() {
    if (!_canLaunch) {
      showGenesisToast(context, _launchValidationMessage);
      return;
    }
    if (_tabIndex == 0) {
      Navigator.of(
        context,
      ).pop(OriginRoleLaunchSelection.preset(_selectedPresetId.trim()));
      return;
    }
    if (_tabIndex == 2) {
      Navigator.of(
        context,
      ).pop(OriginRoleLaunchSelection.enter(_selectedLaunchedWorldId.trim()));
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

  String get _launchValidationMessage {
    if (_tabIndex == 0) return 'Please select a preset role';
    if (_tabIndex == 2) return 'Please select a launched World';
    if (_customForm.name.text.trim().isEmpty) return 'Please enter a name';
    if (_customForm.identity.text.trim().isEmpty) {
      return 'Please enter an identity';
    }
    return 'Please wait for the profile to finish loading.';
  }

  void _dismiss() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = math.max(
          0.0,
          constraints.maxHeight - media.padding.top - 18,
        );
        final targetHeight = math.min(media.size.height * 0.78, maxHeight);

        return GenesisEdgeSwipeBack(
          onBack: _dismiss,
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('origin-role-scrim-dismiss'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismiss,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: GenesisBottomSheetPanel(
                      key: const ValueKey('origin-role-sheet'),
                      title: 'Setup Your Role',
                      height: targetHeight,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                      trailing: GenesisBottomSheetCloseButton(
                        buttonKey: const ValueKey('origin-role-sheet-close'),
                        onPressed: _dismiss,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RoleSegmentedControl(
                            index: _tabIndex,
                            onChanged: _selectTab,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _tabIndex == 0
                                ? _PresetRoleGrid(
                                    key: const ValueKey(
                                      'origin-role-preset-tab',
                                    ),
                                    characters: widget.characters,
                                    selectedId: _selectedPresetId,
                                    resolveAvatarUrl: widget.resolveAvatarUrl,
                                    onSelected: (id) {
                                      setState(() => _selectedPresetId = id);
                                    },
                                  )
                                : _tabIndex == 1
                                ? _CustomRoleForm(
                                    key: const ValueKey(
                                      'origin-role-custom-tab',
                                    ),
                                    form: _customForm,
                                    fillingProfile: _fillingProfile,
                                    canFillProfile:
                                        widget.onFillFromProfile != null,
                                    onChanged: _handleTextChanged,
                                    onFillFromProfile: _fillFromProfile,
                                  )
                                : _LaunchedWorldGrid(
                                    worlds: _launchedWorlds,
                                    loading: _loadingLaunchedWorlds,
                                    selectedWorldId: _selectedLaunchedWorldId,
                                    onSelected: (worldId) => setState(
                                      () => _selectedLaunchedWorldId = worldId,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          _SheetActions(
                            canLaunch: _canLaunch,
                            launchLabel: _tabIndex == 2 ? 'Enter' : 'Launch',
                            onCancel: _dismiss,
                            onLaunch: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            alignment: switch (index) {
              0 => Alignment.centerLeft,
              1 => Alignment.center,
              _ => Alignment.centerRight,
            },
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
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
              _SegmentButton(
                label: 'Launched',
                selected: index == 2,
                onTap: () => onChanged(2),
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w600,
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
        mainAxisExtent: 116,
        crossAxisSpacing: 8,
        mainAxisSpacing: 2,
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
                    borderRadius: GenesisAvatarRadii.character,
                    showFallbackWhileLoading: false,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _SelectionMark(selected: selected),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
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
        color: selected ? GenesisColors.brand : Colors.white10,
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

class _LaunchedWorldGrid extends StatelessWidget {
  const _LaunchedWorldGrid({
    required this.worlds,
    required this.loading,
    required this.selectedWorldId,
    required this.onSelected,
  });

  final List<OriginLaunchedWorldRole> worlds;
  final bool loading;
  final String selectedWorldId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (worlds.isEmpty) {
      return const Center(
        child: Text(
          'No launched World',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF777777),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: worlds.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 144,
        crossAxisSpacing: 8,
        mainAxisSpacing: 0,
      ),
      itemBuilder: (context, index) {
        final world = worlds[index];
        return _LaunchedWorldRoleTile(
          world: world,
          selected: world.worldId == selectedWorldId,
          onTap: () => onSelected(world.worldId),
        );
      },
    );
  }
}

class _LaunchedWorldRoleTile extends StatelessWidget {
  const _LaunchedWorldRoleTile({
    required this.world,
    required this.selected,
    required this.onTap,
  });

  final OriginLaunchedWorldRole world;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('origin-role-launched-${world.worldId}'),
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
                    url: world.avatarUrl,
                    name: world.roleName,
                    size: 82,
                    borderRadius: GenesisAvatarRadii.character,
                    showFallbackWhileLoading: false,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _SelectionMark(selected: selected),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              world.roleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              world.worldId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
            ),
            Text(
              'Tick ${world.tickCount} · ${world.currentTime}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1E1E6), width: 1.2),
            ),
            child: OriginCharacterFormFields(
              form: form,
              onChanged: onChanged,
              showPersonality: false,
              showGoal: false,
              avatarCropSize: const Size(512, 512),
              showAvatarRemoveLink: true,
              labelFontWeight: FontWeight.w600,
              avatarEmptyLabelFontWeight: FontWeight.w600,
              avatarRemoveLinkFontWeight: FontWeight.w600,
              avatarEmptyIconLabelGap: 6,
              identityBelowAvatarRow: true,
              showPlaceholders: false,
              textFieldScrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              topSpacing: 0,
              bioMaxLines: 3,
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
                      fontWeight: FontWeight.w600,
                      color: GenesisColors.brand,
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
    required this.launchLabel,
    required this.onCancel,
    required this.onLaunch,
  });

  final bool canLaunch;
  final String launchLabel;
  final VoidCallback onCancel;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GenesisSecondaryButton(
            key: const ValueKey('origin-role-cancel'),
            label: 'Cancel',
            onPressed: onCancel,
            height: 35,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GenesisPrimaryButton(
            key: const ValueKey('origin-role-launch'),
            label: launchLabel,
            leadingIcon: launchLabel == 'Launch'
                ? SvgPicture.asset(
                    launchIconAsset,
                    key: const ValueKey<String>('origin-role-launch-icon'),
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  )
                : null,
            iconGap: 6,
            onPressed: onLaunch,
            height: 35,
            backgroundColor: canLaunch
                ? GenesisColors.brand
                : const Color(0xFFC8D9D1),
            foregroundColor: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
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

String _limitProfileFill(String value, int maxLength) {
  final characters = value.characters;
  if (characters.length <= maxLength) return value;
  return characters.take(maxLength).toString();
}
