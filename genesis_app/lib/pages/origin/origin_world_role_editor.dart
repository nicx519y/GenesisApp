part of 'origin_world_page.dart';

const Color _originRoleEditorTextColor = GenesisColors.darkTextPrimary;
const Color _originRoleEditorMutedLabelColor = Color(0x99FFFFFF);
const Color _originRoleEditorCountColor = GenesisColors.darkTextTertiary;
const Color _originRoleEditorCancelColor = GenesisColors.darkTextSecondary;
const Color _originRoleEditorDoneDisabledColor = Color(0x59FFFFFF);
const Color _originRoleEditorDividerColor = Color(0x14FFFFFF);
const Color _originRoleEditorFieldColor = Color(0x14FFFFFF);
const Color _originRoleEditorFieldFocusedColor = Color(0x24FFFFFF);
const Color _originRoleEditorFieldInvalidColor = Color(0x1FFF2442);
const Duration _originRoleEditorFieldTransition = Duration(milliseconds: 150);

// Keep the compact form's existing line boxes while using shared typography.
final _originRoleEditorSupportingStyle = GenesisTypography.supporting.copyWith(
  height: 16 / 12,
  letterSpacing: 0,
  decoration: TextDecoration.none,
);

const String _originRoleEditorCameraGlyph =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/>'
    '<path d="M12 10a3 3 0 1 0 0 6 3 3 0 1 0 0-6z"/></svg>';

/// Whether the player's role is being edited on the opening sheet or on a
/// location page. The form itself lives in [_OriginRoleEditorHost].
class _OriginRoleEditorInteractionController extends ChangeNotifier {
  _OriginRoleEditorInteractionController({required this.onCommit});

  final ValueChanged<OriginCustomRoleDraft> onCommit;
  var _editing = false;
  var _disposed = false;

  bool get editing => _editing;

  void beginEditing() => _setEditing(true);

  void cancelEditing() => _setEditing(false);

  void reset() => _setEditing(false);

  void confirmEditing(OriginCustomRoleDraft draft) {
    if (!_editing) return;
    onCommit(draft);
    _setEditing(false);
  }

  void _setEditing(bool editing) {
    if (_editing == editing) return;
    _editing = editing;
    // An account change resets the editor while its host is rebuilding.
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Turns the surface it fills into the persona form while editing: the opening
/// sheet on the map, or the whole page on a location.
class _OriginRoleEditorHost extends StatefulWidget {
  const _OriginRoleEditorHost({
    required this.interaction,
    required this.role,
    required this.stableId,
    required this.isPreset,
    required this.busy,
    this.topInset = 0,
  });

  final _OriginRoleEditorInteractionController interaction;
  final OriginCustomRoleDraft? role;
  final String stableId;
  final bool isPreset;
  final bool busy;

  /// Space above the header, for the host that reaches the top of the screen.
  final double topInset;

  @override
  State<_OriginRoleEditorHost> createState() => _OriginRoleEditorHostState();
}

class _OriginRoleEditorHostState extends State<_OriginRoleEditorHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _visibility;
  late final Animation<double> _surfaceOpacity = CurvedAnimation(
    parent: _visibility,
    curve: const Interval(0, 180 / 280),
  );
  late final Animation<double> _formOpacity = CurvedAnimation(
    parent: _visibility,
    curve: const Interval(60 / 280, 260 / 280),
  );
  late final Animation<Offset> _formOffset =
      Tween<Offset>(begin: const Offset(0, 16), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _visibility,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
        ),
      );

  OriginCustomRoleDraft? _editedRole;
  var _session = 0;
  var _open = false;

  @override
  void initState() {
    super.initState();
    _visibility = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 180),
    )..addStatusListener(_handleVisibilityStatus);
    widget.interaction.addListener(_syncWithInteraction);
    _syncWithInteraction();
  }

  @override
  void didUpdateWidget(covariant _OriginRoleEditorHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interaction == widget.interaction) return;
    oldWidget.interaction.removeListener(_syncWithInteraction);
    widget.interaction.addListener(_syncWithInteraction);
    _syncWithInteraction();
  }

  void _syncWithInteraction() {
    final editing = widget.interaction.editing && widget.role != null;
    if (editing == _open) return;
    _open = editing;
    if (editing) {
      _editedRole = widget.role;
      _session += 1;
      _visibility.forward();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      _visibility.reverse();
    }
    if (mounted) setState(() {});
  }

  void _handleVisibilityStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    setState(() => _editedRole = null);
  }

  @override
  void dispose() {
    widget.interaction.removeListener(_syncWithInteraction);
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = _editedRole;
    if (role == null) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !_open,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            key: const ValueKey<String>('origin-role-editor-surface'),
            opacity: _surfaceOpacity,
            child: const ColoredBox(
              color: originWorldDetailSheetBackgroundColor,
            ),
          ),
          FadeTransition(
            opacity: _formOpacity,
            child: AnimatedBuilder(
              animation: _formOffset,
              builder: (context, child) =>
                  Transform.translate(offset: _formOffset.value, child: child),
              child: _OriginRoleEditorPanel(
                key: ValueKey<int>(_session),
                role: role,
                stableId: widget.stableId,
                isPreset: widget.isPreset,
                busy: widget.busy,
                topInset: widget.topInset,
                onCancel: widget.interaction.cancelEditing,
                onDone: widget.interaction.confirmEditing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginRoleEditorPanel extends StatefulWidget {
  const _OriginRoleEditorPanel({
    super.key,
    required this.role,
    required this.stableId,
    required this.isPreset,
    required this.busy,
    required this.topInset,
    required this.onCancel,
    required this.onDone,
  });

  final OriginCustomRoleDraft role;
  final String stableId;
  final bool isPreset;
  final bool busy;
  final double topInset;
  final VoidCallback onCancel;
  final ValueChanged<OriginCustomRoleDraft> onDone;

  @override
  State<_OriginRoleEditorPanel> createState() => _OriginRoleEditorPanelState();
}

class _OriginRoleEditorPanelState extends State<_OriginRoleEditorPanel>
    with WidgetsBindingObserver {
  static const double _headerHeight = 48;
  static const double _avatarSize = 62;
  static const double _avatarGap = 12;
  static const double _overflowFadeHeight = 56;
  static const double _scrollEndTolerance = 6;

  final OriginCharacterForm _form = OriginCharacterForm.empty(
    charId: 'current_user_custom_role',
  );
  final ScrollController _scrollController = ScrollController();
  late final Uint8List? _initialAvatarPreview;
  Uint8List? _editedAvatarPreview;
  bool _avatarInteractionActive = false;
  var _keyboardOverlap = 0.0;
  var _hasContentBelow = false;

  Iterable<FocusNode> get _focusNodes sync* {
    final nodes = _form.focusNodes;
    yield nodes.name;
    yield nodes.identity;
    yield nodes.personality;
    yield nodes.bio;
  }

  bool get _nameEmpty => _form.name.text.trim().isEmpty;
  bool get _doneEnabled =>
      !_nameEmpty && !widget.busy && !_avatarInteractionActive;

  int get _nameMaxLength =>
      widget.isPreset ? 128 : originCharacterNameMaxLength;
  int get _identityMaxLength =>
      widget.isPreset ? 255 : originCharacterIdentityMaxLength;
  int get _personalityMaxLength =>
      widget.isPreset ? 512 : originCharacterPersonalityMaxLength;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final role = widget.role;
    _editedAvatarPreview = role.avatarPreviewBytes;
    _initialAvatarPreview =
        _editedAvatarPreview ??
        AppServicesScope.maybeRead(
          context,
        )?.profileAvatarCache?.bytesFor(_resolveAssetUrl(role.avatarUrl));
    _seed(_form.avatarUrl, role.avatarUrl.trim());
    _seed(_form.name, role.name.trim(), maxLength: _nameMaxLength);
    _seed(_form.identity, role.identity.trim(), maxLength: _identityMaxLength);
    _seed(
      _form.personality,
      role.personality.trim(),
      maxLength: _personalityMaxLength,
    );
    _seed(_form.bio, role.bio, maxLength: originCharacterBioMaxLength);
    // Preserve the goal, which has no editor here.
    _seed(_form.goal, role.goal);
    _form.addListener(_handleFormChanged);
    for (final focusNode in _focusNodes) {
      focusNode.addListener(_handleFormChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _form.focusNodes.name.requestFocus();
    });
  }

  void _seed(TextEditingController controller, String text, {int? maxLength}) {
    final initialText = maxLength == null
        ? text
        : text.characters.take(maxLength).toString();
    controller.value = TextEditingValue(
      text: initialText,
      selection: TextSelection.collapsed(offset: initialText.length),
    );
  }

  void _handleFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    if (mounted) _syncKeyboardOverlap();
    // The host may be resized by the same metrics; measure again once it is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncKeyboardOverlap();
    });
  }

  void _syncKeyboardOverlap() {
    final overlap = _readKeyboardOverlap();
    if ((overlap - _keyboardOverlap).abs() < 0.5) return;
    setState(() => _keyboardOverlap = overlap);
  }

  double _readKeyboardOverlap() {
    final view = View.of(context);
    final keyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (keyboardInset <= 0.5) return 0;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return keyboardInset;
    final keyboardTop =
        view.physicalSize.height / view.devicePixelRatio - keyboardInset;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    return math.max(0.0, bottom - keyboardTop);
  }

  bool _handleScrollMetrics(ScrollMetrics metrics) {
    final hasContentBelow =
        metrics.maxScrollExtent - metrics.pixels >= _scrollEndTolerance;
    if (hasContentBelow != _hasContentBelow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasContentBelow = hasContentBelow);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    // The sheet must not treat the form's scrolling as its own drag.
    return true;
  }

  void _complete() {
    if (!_doneEnabled) return;
    widget.onDone(
      OriginCustomRoleDraft(
        avatarUrl: _form.avatarUrl.text,
        avatarPreviewBytes: _editedAvatarPreview,
        name: _form.name.text,
        identity: _form.identity.text,
        personality: _form.personality.text,
        bio: _form.bio.text,
        goal: _form.goal.text,
      ),
    );
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final focusNode in _focusNodes) {
      focusNode.removeListener(_handleFormChanged);
    }
    _scrollController.dispose();
    _form
      ..removeListener(_handleFormChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOverflowFade =
        _keyboardOverlap > 0 &&
        _hasContentBelow &&
        !_form.focusNodes.bio.hasFocus;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: widget.topInset),
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: _keyboardOverlap),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildBody(context)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _overflowFadeHeight,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        key: const ValueKey<String>(
                          'origin-role-editor-overflow-fade',
                        ),
                        opacity: showOverflowFade ? 1 : 0,
                        duration: _originRoleEditorFieldTransition,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00151517),
                                originWorldDetailSheetBackgroundColor,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final doneEnabled = _doneEnabled;
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _originRoleEditorDividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _OriginRoleEditorHeaderAction(
            actionKey: ValueKey<String>(
              'origin-role-editor-cancel-${widget.stableId}',
            ),
            label: GenesisL10n.current.cancelAction,
            color: _originRoleEditorCancelColor,
            fontWeight: FontWeight.w500,
            onTap: widget.onCancel,
          ),
          Flexible(
            child: Text(
              GenesisL10n.current.worldoLaunchProfile,
              key: const ValueKey<String>('origin-role-editor-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GenesisTypography.bodyStrong.copyWith(
                fontSize: 15,
                height: 20 / 15,
                letterSpacing: 0,
                color: _originRoleEditorTextColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          _OriginRoleEditorHeaderAction(
            actionKey: ValueKey<String>(
              'origin-role-editor-done-${widget.stableId}',
            ),
            label: GenesisL10n.current.worldoLaunchDone,
            color: doneEnabled
                ? GenesisColors.redSecondary
                : _originRoleEditorDoneDisabledColor,
            fontWeight: FontWeight.w600,
            onTap: doneEnabled ? _complete : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final stableId = widget.stableId;
    final focusNodes = _form.focusNodes;
    final bottomInset = _keyboardOverlap > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handleScrollMetrics(notification.metrics),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) =>
            _handleScrollMetrics(notification.metrics),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismissKeyboard,
          child: AbsorbPointer(
            absorbing: widget.busy,
            child: SingleChildScrollView(
              key: ValueKey<String>(
                'origin-setup-role-inline-editor-scroll-$stableId',
              ),
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottomInset),
              child: Column(
                key: ValueKey<String>(
                  'origin-setup-role-inline-editor-$stableId',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: _avatarGap),
                      Expanded(
                        child: _OriginRoleEditorField(
                          fieldKey: ValueKey<String>(
                            'origin-setup-role-inline-name-$stableId',
                          ),
                          label: GenesisL10n.current.worldoLaunchName,
                          controller: _form.name,
                          focusNode: focusNodes.name,
                          nextFocusNode: focusNodes.identity,
                          maxLength: _nameMaxLength,
                          multiline: false,
                          invalid: _nameEmpty,
                          onDismiss: _dismissKeyboard,
                        ),
                      ),
                    ],
                  ),
                  if (_nameEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 6,
                        left: _avatarSize + _avatarGap,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          GenesisL10n.current.enterNameValidation,
                          key: const ValueKey<String>(
                            'origin-role-editor-name-error',
                          ),
                          style: _originRoleEditorSupportingStyle.copyWith(
                            color: GenesisColors.redSecondary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _OriginRoleEditorField(
                    fieldKey: ValueKey<String>(
                      'origin-setup-role-inline-identity-$stableId',
                    ),
                    label: GenesisL10n.current.worldoLaunchIdentity,
                    controller: _form.identity,
                    focusNode: focusNodes.identity,
                    nextFocusNode: focusNodes.personality,
                    maxLength: _identityMaxLength,
                    onDismiss: _dismissKeyboard,
                  ),
                  const SizedBox(height: 16),
                  _OriginRoleEditorField(
                    fieldKey: ValueKey<String>(
                      'origin-setup-role-inline-brief-$stableId',
                    ),
                    label: GenesisL10n.current.worldoLaunchPersonality,
                    controller: _form.personality,
                    focusNode: focusNodes.personality,
                    nextFocusNode: focusNodes.bio,
                    maxLength: _personalityMaxLength,
                    onDismiss: _dismissKeyboard,
                  ),
                  const SizedBox(height: 16),
                  _OriginRoleEditorField(
                    fieldKey: ValueKey<String>(
                      'origin-setup-role-inline-setting-$stableId',
                    ),
                    label: GenesisL10n.current.worldoLaunchSetting,
                    controller: _form.bio,
                    focusNode: focusNodes.bio,
                    maxLength: originCharacterBioMaxLength,
                    minLines: 4,
                    onDismiss: _dismissKeyboard,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar = _form.avatarUrl.text.trim().isNotEmpty;
    return SizedBox(
      width: _avatarSize,
      height: _avatarSize,
      child: Stack(
        children: [
          CreateUploadBox(
            key: ValueKey<String>(
              'origin-setup-role-inline-avatar-${widget.stableId}',
            ),
            controller: _form.avatarUrl,
            label: '',
            onChanged: _handleFormChanged,
            onInteractionActiveChanged: (active) {
              if (active) _dismissKeyboard();
              setState(() => _avatarInteractionActive = active);
            },
            initialPreviewBytes: _initialAvatarPreview,
            onPreviewBytesChanged: (bytes) => _editedAvatarPreview = bytes,
            optimisticCropPreview: true,
            width: _avatarSize,
            height: _avatarSize,
            previewUrlBuilder: (url) => _originRoleAvatarUrl(url, _avatarSize),
            iconSize: 24,
            borderRadius: GenesisAvatarRadii.character,
            cropSize: originCharacterAvatarUploadSize,
            maxOutputSize: originCharacterAvatarUploadSize,
            previewAlignment: Alignment.topCenter,
            showRemoveLinkWhenFilled: false,
            emptyLabelFontWeight: FontWeight.w600,
            emptyLabelFontSize: 1,
            emptyIconLabelGap: 0,
            emptyBackgroundColor: GenesisColors.darkFaintFill,
            emptyBorderColor: hasAvatar
                ? Colors.transparent
                : originWorldDetailSheetTertiaryTextColor,
            emptyIconColor: GenesisColors.createAdd,
            emptyLabelColor: originWorldDetailSheetTertiaryTextColor,
            previewMaxDevicePixelRatio:
                originWorldOpeningRoleAvatarMaxDevicePixelRatio,
          ),
          if (hasAvatar)
            Positioned(
              right: 3,
              bottom: 3,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey<String>('origin-role-editor-avatar-hint'),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xAD000000),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.string(
                    _originRoleEditorCameraGlyph,
                    width: 13,
                    height: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OriginRoleEditorHeaderAction extends StatelessWidget {
  const _OriginRoleEditorHeaderAction({
    required this.actionKey,
    required this.label,
    required this.color,
    required this.fontWeight,
    required this.onTap,
  });

  final Key actionKey;
  final String label;
  final Color color;
  final FontWeight fontWeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        key: actionKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            maxLines: 1,
            style: GenesisTypography.body.copyWith(
              height: 1.2,
              fontWeight: fontWeight,
              letterSpacing: 0,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginRoleEditorField extends StatelessWidget {
  const _OriginRoleEditorField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.onDismiss,
    this.nextFocusNode,
    this.multiline = true,
    this.minLines = 1,
    this.invalid = false,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final int maxLength;
  final VoidCallback onDismiss;
  final bool multiline;
  final int minLines;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    final fieldColor = invalid
        ? _originRoleEditorFieldInvalidColor
        : focused
        ? _originRoleEditorFieldFocusedColor
        : _originRoleEditorFieldColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: _originRoleEditorFieldTransition,
                style: DefaultTextStyle.of(context).style.merge(
                  _originRoleEditorSupportingStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: focused
                        ? _originRoleEditorTextColor
                        : _originRoleEditorMutedLabelColor,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: _originRoleEditorFieldTransition,
              child: Text(
                '${controller.text.characters.length}/$maxLength',
                style: _originRoleEditorSupportingStyle.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: _originRoleEditorCountColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: _originRoleEditorFieldTransition,
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            minLines: minLines,
            maxLines: multiline ? null : 1,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            keyboardType: multiline
                ? TextInputType.multiline
                : TextInputType.text,
            textInputAction: nextFocusNode == null
                ? TextInputAction.done
                : TextInputAction.next,
            onEditingComplete: () {
              final next = nextFocusNode;
              if (next == null) {
                onDismiss();
              } else {
                next.requestFocus();
              }
            },
            cursorColor: Colors.white,
            // Keep the field's label in view above a caret on its first line.
            scrollPadding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            style: GenesisTypography.body.copyWith(
              height: 20 / 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: _originRoleEditorTextColor,
              decoration: TextDecoration.none,
            ),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
