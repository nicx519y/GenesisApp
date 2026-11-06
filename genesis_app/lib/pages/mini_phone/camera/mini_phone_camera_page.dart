import 'mini_phone_camera_image.dart';
import 'mini_phone_camera_tasks.dart';
import 'mini_phone_camera_style_sheet.dart';
import '../../../utils/api_error_message.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../components/common/genesis_modal_routes.dart';
import '../../../l10n/genesis_localizations.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../../../ui/components/genesis_primary_button.dart';
import '../../../ui/components/genesis_refresh_indicator.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_toast.dart';
import '../shared/mini_phone_ui.dart';
import 'mini_phone_camera_controller.dart';
import 'mini_phone_camera_cast.dart';
import 'mini_phone_camera_models.dart';
import 'mini_phone_camera_strings.dart';
import 'mini_phone_camera_templates.dart';
import 'mini_phone_camera_widgets.dart';
import 'mini_phone_camera_preview_jobs.dart';
import 'mini_phone_camera_preview_album.dart';
import 'mini_phone_camera_ratio_picker.dart';
import 'mini_phone_camera_capture_flight.dart';

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
    this.previewJobs,
    this.tasks,
    this.onReloadOptions,
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
  final MiniPhoneCameraPreviewJobs? previewJobs;
  final MiniPhoneCameraTasks? tasks;
  final Future<void> Function()? onReloadOptions;

  @override
  State<MiniPhoneCameraPage> createState() => _MiniPhoneCameraPageState();
}

class _MiniPhoneCameraPageState extends State<MiniPhoneCameraPage> {
  final _prompt = TextEditingController();
  final _promptFocus = FocusNode();
  final _promptFieldKey = GlobalKey();
  final _scroll = ScrollController();
  final _castScroll = ScrollController();
  late Object _viewOwner;
  Object? _shownFailure;
  bool _capturePending = false;
  bool _promptRevealScheduled = false;
  double _promptLift = 0;
  final _captureStage = GlobalKey();
  final _captureFrame = GlobalKey();
  final _captureAlbum = GlobalKey();
  final _flights = <({int id, Rect from, Rect to})>[];
  int? _lastPreviewId;
  int _lastAcceptance = 0;
  String _personLabel(PhonePerson person) =>
      person.key == widget.selfPersonKey ? strings.you : person.name;

  MiniPhoneCameraController get camera => widget.controller;
  MiniPhoneCameraStrings get strings => widget.strings;

  @override
  void initState() {
    super.initState();
    _promptFocus.addListener(_promptFocusChanged);
    _attach();
    _lastAcceptance = widget.tasks?.acceptanceRevision ?? 0;
    widget.tasks?.addListener(_taskChanged);
    _lastPreviewId = widget.previewJobs?.tasks.firstOrNull?.id;
    widget.previewJobs?.addListener(_previewChanged);
  }

  void _promptFocusChanged() {
    setState(() {
      if (!_promptFocus.hasFocus) _promptLift = 0;
    });
    _schedulePromptReveal();
  }

  void _schedulePromptReveal() {
    if (_promptRevealScheduled) return;
    _promptRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptRevealScheduled = false;
      if (!mounted) return;
      if (!_promptFocus.hasFocus || !_keyboardOpen) {
        if (_promptLift != 0) setState(() => _promptLift = 0);
        return;
      }
      final field = _promptFieldKey.currentContext?.findRenderObject();
      if (field is! RenderBox || !field.hasSize || !field.attached) return;
      final keyboardTop =
          MediaQuery.sizeOf(context).height -
          MediaQuery.viewInsetsOf(context).bottom;
      final fieldBottom = field.localToGlobal(Offset(0, field.size.height)).dy;
      // Measure the field's resting position, independent of its current lift.
      final lift = math.max(0.0, fieldBottom + _promptLift + 12 - keyboardTop);
      if ((lift - _promptLift).abs() > .1) {
        setState(() => _promptLift = lift);
      }
    });
  }

  void _attach() {
    _viewOwner = camera.open();
    camera.setPeople(widget.people);
    if (widget.initialPrompt.isNotEmpty) camera.setPrompt(widget.initialPrompt);
    _syncPrompt();
    camera.addListener(_changed);
    unawaited(widget.tasks?.restoreSelections());
  }

  @override
  void didUpdateWidget(covariant MiniPhoneCameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      oldWidget.tasks?.removeListener(_taskChanged);
      _lastAcceptance = widget.tasks?.acceptanceRevision ?? 0;
      widget.tasks?.addListener(_taskChanged);
    }
    if (oldWidget.previewJobs != widget.previewJobs) {
      oldWidget.previewJobs?.removeListener(_previewChanged);
      _lastPreviewId = widget.previewJobs?.tasks.firstOrNull?.id;
      _flights.clear();
      widget.previewJobs?.addListener(_previewChanged);
    }
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

  void _taskChanged() {
    if (!mounted) return;
    final revision = widget.tasks?.acceptanceRevision ?? 0;
    if (revision != _lastAcceptance) {
      _lastAcceptance = revision;
      if (!MediaQuery.disableAnimationsOf(context) && !_keyboardOpen) {
        final stage = _captureStage.currentContext?.findRenderObject();
        final frame = _captureFrame.currentContext?.findRenderObject();
        final album = _captureAlbum.currentContext?.findRenderObject();
        if (stage is RenderBox &&
            frame is RenderBox &&
            album is RenderBox &&
            frame.hasSize &&
            album.hasSize) {
          _flights.add((
            id: revision,
            from:
                frame.localToGlobal(Offset.zero, ancestor: stage) & frame.size,
            to: album.localToGlobal(Offset.zero, ancestor: stage) & album.size,
          ));
        }
      }
    }
    setState(() {});
  }

  void _previewChanged() {
    if (!mounted) return;
    final task = widget.previewJobs?.tasks.firstOrNull;
    if (task == null) _flights.clear();
    if (task != null && task.id != _lastPreviewId) {
      _lastPreviewId = task.id;
      if (!MediaQuery.disableAnimationsOf(context) && !_keyboardOpen) {
        final stage = _captureStage.currentContext?.findRenderObject();
        final frame = _captureFrame.currentContext?.findRenderObject();
        final album = _captureAlbum.currentContext?.findRenderObject();
        if (stage is RenderBox &&
            frame is RenderBox &&
            album is RenderBox &&
            frame.hasSize &&
            album.hasSize) {
          _flights.add((
            id: task.id,
            from:
                frame.localToGlobal(Offset.zero, ancestor: stage) & frame.size,
            to: album.localToGlobal(Offset.zero, ancestor: stage) & album.size,
          ));
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    camera.removeListener(_changed);
    widget.tasks?.removeListener(_taskChanged);
    widget.previewJobs?.removeListener(_previewChanged);
    camera.close(owner: _viewOwner);
    _promptFocus.removeListener(_promptFocusChanged);
    _promptFocus.dispose();
    _prompt.dispose();
    _scroll.dispose();
    _castScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Move only the input layer after keyboard or draft-layout changes.
    _schedulePromptReveal();
    return Stack(
      key: _captureStage,
      children: [
        Positioned.fill(
          child: Material(
            color: miniBackground,
            child: miniPhonePanel(
              widget.header,
              switch (camera.phase) {
                MiniPhoneCameraPhase.compose => _compose(),
                MiniPhoneCameraPhase.generating => _generating(),
                MiniPhoneCameraPhase.result => _result(),
              },
              // Keep the photo geometry unchanged when the keyboard consumes
              // the system's bottom safe area.
              maintainBottomViewPadding: true,
              footer: Visibility(
                visible: !_keyboardOpen,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: _footer(),
              ),
            ),
          ),
        ),
        for (final flight in _flights)
          CameraCaptureFlight(
            key: ValueKey('camera-capture-flight-${flight.id}'),
            from: flight.from,
            to: flight.to,
            onEnd: () {
              if (mounted) {
                setState(() => _flights.removeWhere((f) => f.id == flight.id));
              }
            },
          ),
      ],
    );
  }

  bool get _keyboardOpen => MediaQuery.viewInsetsOf(context).bottom > 0;

  MiniPhoneCameraTemplate? get _selectedTemplate => camera.selectedTemplate;

  Widget _compose() => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
      // Keep the photo and cast geometry fixed while the input lifts separately.
      final frameHeight = math.min(
        (bounds.maxWidth - miniPageInset * 2) / (2 / 3),
        math.max(260.0, bounds.maxHeight - 74 - 34 * scale),
      );
      final ratio = camera.photoRatio.aspectRatio;
      final visibleHeight = math.min(
        frameHeight,
        (bounds.maxWidth - miniPageInset * 2) / ratio,
      );
      return SingleChildScrollView(
        key: const PageStorageKey('mini-phone-camera-compose'),
        controller: _scroll,
        // EditableText's implicit showOnScreen must not scroll the photo.
        physics: _promptFocus.hasFocus
            ? const NeverScrollableScrollPhysics()
            : null,
        // Nested input scroll notifications must not dismiss its keyboard.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: const EdgeInsets.fromLTRB(miniPageInset, 4, miniPageInset, 4),
        child: Column(
          children: [
            SizedBox(
              height: frameHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: SizedBox(
                      key: _captureFrame,
                      height: visibleHeight,
                      width: visibleHeight * ratio,
                      child: MiniPhoneCameraViewfinder(
                        imageUrl: widget.coverImageUrl,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                          child: Column(
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: MiniGlass(
                                  key: const ValueKey(
                                    'mini-phone-camera-status',
                                  ),
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
                  ),
                  Positioned(
                    bottom: 28,
                    left:
                        (bounds.maxWidth -
                                miniPageInset * 2 -
                                frameHeight * 2 / 3) /
                            2 +
                        24,
                    right:
                        (bounds.maxWidth -
                                miniPageInset * 2 -
                                frameHeight * 2 / 3) /
                            2 +
                        24,
                    child: Transform.translate(
                      offset: Offset(0, -_promptLift),
                      child: _promptField(),
                    ),
                  ),
                ],
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
    key: _promptFieldKey,
    radius: 12,
    outlined: false,
    opacity: .16,
    light: true,
    highlight: false,
    child: Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Icon(Icons.auto_awesome_outlined, size: 16, color: miniWhite),
        ),
        Expanded(
          child: Semantics(
            label: strings.describeMoment,
            child: TextField(
              controller: _prompt,
              focusNode: _promptFocus,
              minLines: 1,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
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
    key: const ValueKey('camera-participants-region'),
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
                onTap: () {
                  if (camera.selectedPeople.length >=
                          MiniPhoneCameraController.maxPeople &&
                      !camera.selectedPeople.any((p) => p.key == person.key)) {
                    showMiniPhoneToast(
                      context,
                      context.l10n.miniPhoneCameraPeopleLimit,
                    );
                    return;
                  }
                  camera.togglePerson(person);
                },
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
    if (widget.tasks case final tasks?) {
      if (tasks.options == null) {
        await widget.onReloadOptions?.call();
        return;
      }
      final label = await showGenesisModalBottomSheet<String>(
        context: context,
        backgroundColor: miniRaised,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PhoneCameraStyleSheet(
          options: tasks.options!,
          selected: tasks.selectedStyle,
        ),
      );
      if (mounted &&
          label != null &&
          controller == camera &&
          controller.scope == scope &&
          controller.requests.generation == generation) {
        tasks.selectStyle(label);
      }
      return;
    }
    final template = await showGenesisModalBottomSheet<MiniPhoneCameraTemplate>(
      context: context,
      backgroundColor: miniRaised,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => MiniPhoneCameraTemplateSheet(
        strings: strings,
        selectedTemplate: controller.selectedTemplate,
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
    controller.setTemplate(template);
  }

  Future<void> _requestCapture() async {
    if (_capturePending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if ((widget.tasks != null || widget.previewJobs != null) &&
        camera.selectedPeople.isEmpty) {
      showMiniPhoneToast(context, strings.castHint);
      return;
    }
    if (widget.onCaptureRequested case final callback?) {
      setState(() => _capturePending = true);
      final controller = camera;
      final generation = controller.requests.generation;
      try {
        await callback();
      } catch (error) {
        if (mounted &&
            camera == controller &&
            controller.requests.generation == generation) {
          showMiniPhoneToast(context, apiErrorMessage(error));
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CameraRatioPicker(
            value: camera.photoRatio,
            onChanged: camera.setPhotoRatio,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MiniPhoneCameraThumbnail(
                key: const ValueKey('mini-phone-camera-templates'),
                label:
                    widget.tasks?.style?.name ??
                    _selectedTemplate?.label(strings) ??
                    context.l10n.miniPhoneCameraStyle,
                onPressed: _chooseTemplate,
                showSwitch: true,
                imageAspectRatio: miniPhoneCameraStyleAspectRatio,
                child: _albumImage(widget.tasks?.style?.demoImageUrl),
              ),
              MiniPhoneCameraShutter(
                label: strings.takePhoto,
                onPressed:
                    !_capturePending &&
                        (widget.tasks == null ||
                            widget.tasks!.options != null &&
                                !widget.tasks!.submitting) &&
                        (widget.onCaptureRequested != null ||
                            (widget.onGenerate != null && camera.canGenerate))
                    ? () => unawaited(_requestCapture())
                    : null,
              ),
              MiniPhoneCameraThumbnail(
                key: const ValueKey('mini-phone-camera-album'),
                label:
                    (widget.tasks?.pendingCount ??
                            widget.previewJobs?.pendingCount ??
                            0) >
                        0
                    ? context.l10n.miniPhoneCameraGeneratingCount(
                        count:
                            widget.tasks?.pendingCount ??
                            widget.previewJobs!.pendingCount,
                      )
                    : widget.albumLabel ?? context.l10n.miniPhonePhotos,
                onPressed: widget.onOpenAlbum,
                child: SizedBox(
                  key: _captureAlbum,
                  child: widget.tasks != null
                      ? Stack(
                          fit: StackFit.passthrough,
                          children: [
                            _albumImage(
                              widget.tasks!.latestSuccess?.imageUrl ?? albumUrl,
                            ),
                            if (widget.tasks!.pendingCount > 0)
                              const Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.black45,
                                  child: Center(
                                    child: SizedBox.square(
                                      dimension: 18,
                                      child: GenesisLoadingIndicator(
                                        strokeWidth: 1.5,
                                        color: miniWhite,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.tasks!.unread)
                              const Positioned(
                                right: 3,
                                top: 3,
                                child: Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: miniRed,
                                ),
                              ),
                          ],
                        )
                      : widget.previewJobs != null
                      ? CameraPreviewAlbumThumbnail(
                          jobs: widget.previewJobs!,
                          fallback: _albumImage(albumUrl),
                        )
                      : _albumImage(albumUrl),
                ),
              ),
            ],
          ),
          if (widget.tasks != null || priceText != null) ...[
            const SizedBox(height: 8),
            _captureFooterNote(priceText),
          ],
        ],
      ),
    );
  }

  Widget _captureFooterNote(String? priceText) {
    final style = miniStyle(11, FontWeight.w400, miniTertiary);
    if (widget.tasks == null) {
      return Text(priceText!, textAlign: TextAlign.center, style: style);
    }
    // Reserve the localized eligibility paragraph before options arrive and
    // after eligibility changes, so the request never resizes the photo.
    return Visibility(
      visible: widget.tasks!.options?.freeAvailable == true,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Text(
        context.l10n.cameraFreeAvailable,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  Widget _albumImage(String? albumUrl) => albumUrl == null || albumUrl.isEmpty
      ? const ColoredBox(color: miniRaised)
      : MiniPhoneCameraImage(
          imageUrl: albumUrl,
          fixedSize: true,
          fit: BoxFit.cover,
          placeholder: (_) => const ColoredBox(color: miniRaised),
          errorWidget: (_, _) => const ColoredBox(color: miniRaised),
        );

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
                  miniPhoneCameraPersonAvatar(person, 28, radius: 8),
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
            child: LayoutBuilder(
              builder: (context, bounds) => GenesisImageViewerSourceAnchor(
                previewImageProvider: genesisImageViewerPreviewProvider(
                  context,
                  imageUrl: miniPhoneCameraImageUrl(
                    result.imageUrl,
                    logicalWidth: bounds.maxWidth,
                  ),
                  logicalWidth: bounds.maxWidth,
                  logicalHeight: bounds.maxWidth / request.aspectRatio,
                  fit: BoxFit.contain,
                ),
                fit: BoxFit.contain,
                onTap: (source) => _openPhoto(result, source),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: request.aspectRatio,
                    child: ColoredBox(
                      color: miniRaised,
                      child: MiniPhoneCameraImage(
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
                    miniPhoneCameraPersonAvatar(person, 28, radius: 8),
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

  void _openPhoto(
    MiniPhoneCameraResult result,
    GenesisImageViewerSource source,
  ) {
    if (widget.onOpenPhoto case final callback?) {
      source.previewImage.dispose();
      callback(result);
    } else {
      unawaited(
        showGenesisImageViewer(
          context,
          imageUrls: [result.imageUrl],
          source: source,
        ),
      );
    }
  }

  Widget _footer() {
    final price = widget.priceGems;
    final priceText =
        widget.tasks == null && price != null && price.isFinite && price >= 0
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
