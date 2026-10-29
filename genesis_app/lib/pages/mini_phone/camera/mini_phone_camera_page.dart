import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../components/common/genesis_modal_routes.dart';
import '../../../l10n/genesis_localizations.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../../../ui/components/genesis_primary_button.dart';
import '../../../ui/tokens/genesis_origin_card_geometry.dart';
import '../../../ui/components/genesis_static_network_image.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_toast.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_camera_controller.dart';
import 'mini_phone_camera_cast.dart';
import 'mini_phone_camera_models.dart';
import 'mini_phone_camera_strings.dart';
import 'mini_phone_camera_templates.dart';
import 'mini_phone_camera_widgets.dart';

/// Camera presentation only. Header/navigation and real generation are injected
/// by the parent. With no adapter the draft remains editable and generation is
/// unavailable. The parent owns and disposes the controller.
class MiniPhoneCameraPage extends StatefulWidget {
  const MiniPhoneCameraPage({
    super.key,
    required this.header,
    required this.people,
    required this.strings,
    required this.controller,
    this.initialPrompt = '',
    this.onGenerate,
    this.priceGems,
    this.selfPersonKey,
    this.onUseInPost,
    this.onOpenPhoto,
    this.onOpenAlbum,
    this.albumLabel,
    this.onCaptureRequested,
    this.albumThumbnailUrl,
    this.coverImageUrl = '',
  });

  final Widget header;
  final List<PhonePerson> people;
  final MiniPhoneCameraStrings strings;
  final MiniPhoneCameraController controller;
  final String initialPrompt;
  final MiniPhoneCameraGenerate? onGenerate;
  final double? priceGems;
  final String? selfPersonKey;
  final ValueChanged<MiniPhoneCameraResult>? onUseInPost, onOpenPhoto;
  final VoidCallback? onOpenAlbum;
  final String? albumLabel;
  final Future<void> Function()? onCaptureRequested;
  final String? albumThumbnailUrl;
  final String coverImageUrl;

  @override
  State<MiniPhoneCameraPage> createState() => _MiniPhoneCameraPageState();
}

class _MiniPhoneCameraPageState extends State<MiniPhoneCameraPage> {
  final _prompt = TextEditingController();
  final _scroll = ScrollController();
  final _castScroll = ScrollController();
  late Object _viewOwner;
  Object? _shownFailure;
  bool _capturePending = false;
  String _personLabel(PhonePerson person) =>
      person.key == widget.selfPersonKey ? strings.you : person.name;

  MiniPhoneCameraController get camera => widget.controller;
  MiniPhoneCameraStrings get strings => widget.strings;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _viewOwner = camera.open();
    camera.setPeople(widget.people);
    if (widget.initialPrompt.isNotEmpty) camera.setPrompt(widget.initialPrompt);
    _syncPrompt();
    camera.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant MiniPhoneCameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != camera) {
      oldWidget.controller.removeListener(_changed);
      oldWidget.controller.close(owner: _viewOwner);
      _attach();
    } else {
      camera.setPeople(widget.people);
      if (oldWidget.initialPrompt != widget.initialPrompt &&
          widget.initialPrompt.isNotEmpty) {
        camera.setPrompt(widget.initialPrompt);
      }
      _syncPrompt();
    }
  }

  void _syncPrompt() {
    if (_prompt.text == camera.prompt) return;
    _prompt.value = TextEditingValue(
      text: camera.prompt,
      selection: TextSelection.collapsed(offset: camera.prompt.length),
    );
  }

  void _changed() {
    if (!mounted) return;
    _syncPrompt();
    setState(() {});
    final failure = camera.failure;
    if (failure == null) {
      _shownFailure = null;
    } else if (!identical(failure, _shownFailure)) {
      _shownFailure = failure;
      showMiniPhoneToast(
        context,
        camera.failureMessage ?? strings.generationFailed,
      );
    }
  }

  @override
  void dispose() {
    camera.removeListener(_changed);
    camera.close(owner: _viewOwner);
    _prompt.dispose();
    _scroll.dispose();
    _castScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: miniBackground,
    child: miniPhonePanel(
      widget.header,
      switch (camera.phase) {
        MiniPhoneCameraPhase.compose => _compose(),
        MiniPhoneCameraPhase.generating => _generating(),
        MiniPhoneCameraPhase.result => _result(),
      },
      footer: Visibility(
        visible: !_keyboardOpen,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: _footer(),
      ),
    ),
  );

  bool get _keyboardOpen => MediaQuery.viewInsetsOf(context).bottom > 0;

  MiniPhoneCameraTemplate? get _selectedTemplate => MiniPhoneCameraTemplate
      .values
      .where((template) => camera.prompt == template.prompt(strings))
      .firstOrNull;

  Widget _compose() => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
      // Reserve the same status/cast space while editing; only the scroll
      // viewport reveals the field, rather than lifting the camera controls.
      final frameHeight = math.min(
        (bounds.maxWidth - miniPageInset * 2) / genesisOriginCoverAspectRatio,
        math.max(260.0, bounds.maxHeight - 110 - 34 * scale),
      );
      return SingleChildScrollView(
        key: const PageStorageKey('mini-phone-camera-compose'),
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          miniPageInset,
          4,
          miniPageInset,
          4 + (_keyboardOpen ? MediaQuery.viewInsetsOf(context).bottom : 0),
        ),
        child: Column(
          children: [
            SizedBox(
              height: frameHeight,
              width: frameHeight * genesisOriginCoverAspectRatio,
              child: MiniPhoneCameraViewfinder(
                imageUrl: widget.coverImageUrl,
                footer: _promptField(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: MiniGlass(
                          key: const ValueKey('mini-phone-camera-status'),
                          light: true,
                          outlined: false,
                          opacity: .12,
                          radius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: camera.selectedPeople.isEmpty
                                      ? miniTertiary
                                      : miniRed,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  strings.selectedCount(
                                    camera.selectedPeople.length,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(11, FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _focusedPeople()),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Visibility(
              visible: !_keyboardOpen,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: _participants(),
            ),
          ],
        ),
      );
    },
  );

  Widget _promptField() => MiniGlass(
    radius: 12,
    outlined: false,
    opacity: .5,
    tint: miniBackground,
    highlight: false,
    child: Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Icon(Icons.auto_awesome_outlined, size: 16, color: miniRed),
        ),
        Expanded(
          child: Semantics(
            label: strings.describeMoment,
            child: TextField(
              controller: _prompt,
              minLines: 1,
              maxLines: 3,
              style: miniStyle(12),
              onChanged: camera.setPrompt,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: strings.promptHint,
                hintMaxLines: 1,
                hintStyle: miniStyle(12, FontWeight.w400, miniSecondary),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _focusedPeople() {
    final selected = camera.selectedPeople;
    if (selected.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            key: const ValueKey('mini-phone-camera-add-person'),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPhoneCameraAddPerson(),
                const SizedBox(height: 10),
                Text(
                  strings.castHint,
                  textAlign: TextAlign.center,
                  style: miniStyle(11, FontWeight.w400, miniSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return MiniPhoneCameraFocusedCast(people: selected, label: _personLabel);
  }

  Widget _participants() => Align(
    alignment: Alignment.centerLeft,
    child: SingleChildScrollView(
      controller: _castScroll,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final person in widget.people)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MiniPhoneCameraCastChoice(
                person: person,
                label: _personLabel(person),
                order:
                    camera.selectedPeople.indexWhere(
                      (p) => p.key == person.key,
                    ) +
                    1,
                onTap: () => camera.togglePerson(person),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _chooseTemplate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = camera;
    final scope = controller.scope;
    final generation = controller.requests.generation;
    final template = await showGenesisModalBottomSheet<MiniPhoneCameraTemplate>(
      context: context,
      backgroundColor: miniRaised,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => MiniPhoneCameraTemplateSheet(
        strings: strings,
        prompt: controller.prompt,
        onSelected: (value) => Navigator.of(sheetContext).pop(value),
      ),
    );
    if (!mounted ||
        template == null ||
        controller != camera ||
        controller.scope != scope ||
        controller.requests.generation != generation) {
      return;
    }
    controller.setPrompt(template.prompt(strings));
  }

  Future<void> _requestCapture() async {
    if (_capturePending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onCaptureRequested case final callback?) {
      setState(() => _capturePending = true);
      final controller = camera;
      final generation = controller.requests.generation;
      try {
        await callback();
      } catch (_) {
        if (mounted &&
            camera == controller &&
            controller.requests.generation == generation) {
          showMiniPhoneToast(context, strings.generationFailed);
        }
      } finally {
        if (mounted) setState(() => _capturePending = false);
      }
    } else {
      await camera.generate(widget.onGenerate);
    }
  }

  Widget _captureControls(String? priceText) {
    final albumUrl = widget.albumThumbnailUrl?.trim();
    final template = _selectedTemplate ?? MiniPhoneCameraTemplate.values.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MiniPhoneCameraThumbnail(
                key: const ValueKey('mini-phone-camera-templates'),
                label:
                    _selectedTemplate?.label(strings) ??
                    context.l10n.miniPhoneCameraStyle,
                onPressed: _chooseTemplate,
                showSwitch: true,
                child: Image.asset(
                  template.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: miniRaised),
                ),
              ),
              MiniPhoneCameraShutter(
                label: strings.takePhoto,
                onPressed:
                    !_capturePending &&
                        (widget.onCaptureRequested != null ||
                            (widget.onGenerate != null && camera.canGenerate))
                    ? () => unawaited(_requestCapture())
                    : null,
              ),
              MiniPhoneCameraThumbnail(
                key: const ValueKey('mini-phone-camera-album'),
                label: widget.albumLabel ?? context.l10n.miniPhonePhotos,
                onPressed: widget.onOpenAlbum,
                child: albumUrl == null || albumUrl.isEmpty
                    ? const ColoredBox(color: miniRaised)
                    : GenesisStaticNetworkImage(
                        imageUrl: albumUrl,
                        fit: BoxFit.cover,
                        placeholder: (_) => const ColoredBox(color: miniRaised),
                        errorWidget: (_, _) =>
                            const ColoredBox(color: miniRaised),
                      ),
              ),
            ],
          ),
          if (priceText != null) ...[
            const SizedBox(height: 8),
            Text(
              priceText,
              textAlign: TextAlign.center,
              style: miniStyle(11, FontWeight.w400, miniTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _generating() => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (bounds.maxHeight - 40).clamp(0, double.infinity),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: (bounds.maxHeight * .55).clamp(120, 340),
              width: double.infinity,
              decoration: BoxDecoration(
                color: miniRaised,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Semantics(
                liveRegion: true,
                label: strings.creatingPhoto,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (MediaQuery.disableAnimationsOf(context))
                      const Icon(
                        Icons.photo_camera_outlined,
                        color: miniSecondary,
                        size: 30,
                      )
                    else
                      const SizedBox.square(
                        dimension: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: miniWhite,
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      strings.creatingPhoto,
                      textAlign: TextAlign.center,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              strings.creatingTitle,
              textAlign: TextAlign.center,
              style: miniPageTitle,
            ),
            const SizedBox(height: 9),
            Text(
              strings.creatingBody,
              textAlign: TextAlign.center,
              style: miniStyle(12, FontWeight.w400, miniTertiary),
            ),
            const SizedBox(height: 17),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                for (final person in camera.selectedPeople)
                  miniPhonePersonAvatar(person, 28, radius: 8),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _result() {
    final result = camera.result;
    final request = camera.resultRequest;
    if (result == null || request == null) return const SizedBox.shrink();
    final status = switch (result.photosStatus) {
      MiniPhoneCameraPhotosStatus.none => null,
      MiniPhoneCameraPhotosStatus.syncing => strings.syncingPhotos,
      MiniPhoneCameraPhotosStatus.saved => strings.savedToPhotos,
      MiniPhoneCameraPhotosStatus.failed => strings.photoSyncFailed,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(miniPageInset, 10, miniPageInset, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: strings.openPhoto,
            child: InkWell(
              onTap: () => _openPhoto(result),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: request.aspectRatio,
                  child: ColoredBox(
                    color: miniRaised,
                    child: GenesisStaticNetworkImage(
                      key: ValueKey(result.imageUrl),
                      imageUrl: result.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            strings.imageUnavailable,
                            textAlign: TextAlign.center,
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in request.participants)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    miniPhonePersonAvatar(person, 28, radius: 8),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        person.key == widget.selfPersonKey
                            ? strings.you
                            : person.name,
                        style: miniStyle(14, FontWeight.w600),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 5),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                style: miniStyle(12, FontWeight.w400, miniTertiary),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            request.prompt,
            style: miniStyle(12, FontWeight.w400, miniSecondary),
          ),
        ],
      ),
    );
  }

  void _openPhoto(MiniPhoneCameraResult result) {
    if (widget.onOpenPhoto case final callback?) {
      callback(result);
    } else {
      unawaited(showGenesisImageViewer(context, imageUrls: [result.imageUrl]));
    }
  }

  Widget _footer() {
    final price = widget.priceGems;
    final priceText = price != null && price.isFinite && price >= 0
        ? strings.pricePerPhoto(price)
        : null;
    if (camera.phase == MiniPhoneCameraPhase.compose) {
      return _captureControls(priceText);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(miniPageInset, 13, miniPageInset, 20),
      decoration: const BoxDecoration(
        color: miniBackground,
        border: Border(top: BorderSide(color: miniDivider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (camera.phase) {
          MiniPhoneCameraPhase.compose => [],
          MiniPhoneCameraPhase.generating => [
            _secondary(strings.cancel, camera.cancel),
          ],
          MiniPhoneCameraPhase.result => [
            GenesisPrimaryButton(
              label: strings.takeAnother,
              leadingIcon: const Icon(Icons.photo_camera_outlined, size: 19),
              onPressed: camera.takeAnother,
              height: 48,
              fontSize: 14,
              backgroundColor: miniRed,
              foregroundColor: miniWhite,
            ),
            const SizedBox(height: 9),
            _secondary(
              strings.useInPost,
              widget.onUseInPost != null && camera.result != null
                  ? () => widget.onUseInPost!(camera.result!)
                  : null,
            ),
          ],
        },
      ),
    );
  }

  Widget _secondary(String label, VoidCallback? onPressed) =>
      GenesisSecondaryButton(
        label: label,
        onPressed: onPressed,
        height: 48,
        foregroundColor: miniSecondary,
        disabledForegroundColor: miniTertiary,
        side: const BorderSide(color: miniLine),
      );
}
