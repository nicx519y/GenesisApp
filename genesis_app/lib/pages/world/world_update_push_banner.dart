import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../components/chat/shared/chat_scene_plate_tokens.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/tokens/genesis_typography.dart';

const worldUpdatePushDisplayDuration = Duration(seconds: 3);
const worldUpdatePushTransitionDuration = Duration(milliseconds: 220);
const _worldUpdatePushLeadingSize = 48.0;

class WorldUpdatePushBannerQueue extends StatefulWidget {
  const WorldUpdatePushBannerQueue({
    super.key,
    required this.top,
    required this.revision,
    required this.notices,
    this.canShowNotice,
    this.onNoticeTap,
    this.displayDuration = worldUpdatePushDisplayDuration,
    this.transitionDuration = worldUpdatePushTransitionDuration,
  });

  final double top;
  final int revision;
  final List<WorldContentUpdateNotice> notices;
  final bool Function(WorldContentUpdateNotice notice)? canShowNotice;
  final ValueChanged<WorldContentUpdateNotice>? onNoticeTap;
  final Duration displayDuration;
  final Duration transitionDuration;

  @override
  State<WorldUpdatePushBannerQueue> createState() =>
      _WorldUpdatePushBannerQueueState();
}

class _WorldUpdatePushBannerQueueState extends State<WorldUpdatePushBannerQueue>
    with SingleTickerProviderStateMixin {
  final Queue<WorldContentUpdateNotice> _pending =
      Queue<WorldContentUpdateNotice>();
  final Set<String> _acceptedOccurrences = <String>{};
  late final AnimationController _transitionController;
  late final CurvedAnimation _transitionAnimation;
  late final Animation<Offset> _slideAnimation;
  WorldContentUpdateNotice? _activeNotice;
  Timer? _dismissTimer;
  var _activationScheduled = false;
  var _isDismissing = false;
  var _activeNoticeTapHandled = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    )..addStatusListener(_handleTransitionStatus);
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(_transitionAnimation);
    if (widget.revision > 0) {
      _accept(widget.notices);
      _scheduleActivationAfterBuild();
    }
  }

  @override
  void didUpdateWidget(WorldUpdatePushBannerQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transitionDuration != oldWidget.transitionDuration) {
      _transitionController.duration = widget.transitionDuration;
    }
    if (widget.revision > 0) _accept(widget.notices);
    final activeNotice = _activeNotice;
    if (activeNotice != null && !_canShow(activeNotice)) {
      _dismissActiveNotice();
    }
    _scheduleActivationAfterBuild();
    _scheduleDismissAfterBuild();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _transitionController.removeStatusListener(_handleTransitionStatus);
    _transitionAnimation.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _accept(List<WorldContentUpdateNotice> notices) {
    for (final notice in notices) {
      if (!_canShow(notice)) continue;
      if (_acceptedOccurrences.add(notice.occurrenceKey)) {
        _pending.add(notice);
      }
    }
  }

  bool _canShow(WorldContentUpdateNotice notice) {
    return widget.canShowNotice?.call(notice) ?? true;
  }

  WorldContentUpdateNotice? _takeNextEligibleNotice() {
    while (_pending.isNotEmpty) {
      final notice = _pending.removeFirst();
      if (_canShow(notice)) return notice;
    }
    return null;
  }

  void _scheduleActivationAfterBuild() {
    if (_activationScheduled ||
        _isDismissing ||
        _activeNotice != null ||
        _pending.isEmpty) {
      return;
    }
    _activationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activationScheduled = false;
      if (!mounted ||
          _isDismissing ||
          _activeNotice != null ||
          _pending.isEmpty) {
        return;
      }
      final nextNotice = _takeNextEligibleNotice();
      if (nextNotice == null) return;
      setState(() {
        _activeNotice = nextNotice;
        _activeNoticeTapHandled = false;
      });
      _transitionController.forward(from: 0);
      _scheduleDismissAfterBuild();
    });
  }

  void _scheduleDismissAfterBuild() {
    if (_isDismissing ||
        _activeNotice == null ||
        _dismissTimer?.isActive == true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isDismissing ||
          _activeNotice == null ||
          _dismissTimer?.isActive == true) {
        return;
      }
      _dismissTimer = Timer(widget.displayDuration, _dismissActiveNotice);
    });
  }

  void _dismissActiveNotice() {
    if (!mounted || _activeNotice == null || _isDismissing) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _isDismissing = true;
    _transitionController.reverse();
  }

  void _handleActiveNoticeTap() {
    final notice = _activeNotice;
    final onNoticeTap = widget.onNoticeTap;
    if (notice == null ||
        onNoticeTap == null ||
        _isDismissing ||
        _activeNoticeTapHandled) {
      return;
    }
    _activeNoticeTapHandled = true;
    _dismissActiveNotice();
    onNoticeTap(notice);
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (!mounted || status != AnimationStatus.dismissed || !_isDismissing) {
      return;
    }
    _isDismissing = false;
    setState(() => _activeNotice = null);
    _scheduleActivationAfterBuild();
  }

  @override
  Widget build(BuildContext context) {
    final notice = _activeNotice;
    return Positioned(
      left: kLocationChatOuterPadding,
      top: widget.top,
      right: kLocationChatOuterPadding,
      child: notice == null
          ? const SizedBox.shrink(
              key: ValueKey<String>('world-update-push-empty'),
            )
          : FadeTransition(
              opacity: _transitionAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _WorldUpdatePushBanner(
                  key: ValueKey<String>(notice.occurrenceKey),
                  notice: notice,
                  onTap: widget.onNoticeTap == null
                      ? null
                      : _handleActiveNoticeTap,
                ),
              ),
            ),
    );
  }
}

class _WorldUpdatePushBanner extends StatelessWidget {
  const _WorldUpdatePushBanner({super.key, required this.notice, this.onTap});

  final WorldContentUpdateNotice notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLocation = notice.kind == WorldContentUpdateKind.location;
    final name = notice.name.trim().isEmpty
        ? (isLocation ? 'Unknown location' : 'Unknown character')
        : notice.name.trim();
    final contextLabel = notice.contextLabel.trim();
    final detail = contextLabel.isEmpty ? name : '$name · $contextLabel';
    final category = isLocation
        ? 'New location available'
        : 'New character joined';
    final detailText = Text.rich(
      TextSpan(
        text: name,
        children: contextLabel.isEmpty
            ? const <InlineSpan>[]
            : <InlineSpan>[
                TextSpan(
                  text: ' · $contextLabel',
                  style: const TextStyle(
                    color: Color(0xB8FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
      ),
      key: const ValueKey<String>('world-update-push-detail'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: GenesisTypography.fontFamily,
        fontFamilyFallback: GenesisTypography.fontFamilyFallback,
        color: Color(0xF2FFFFFF),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$category: $detail',
      child: Material(
        key: const ValueKey<String>('world-update-push-banner'),
        color: const Color(0xFF1F1D24),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey<String>('world-update-push-tap-target'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(isLocation ? 16 : 8, 8, 12, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _worldUpdatePushLeadingSize,
              ),
              child: Row(
                children: [
                  if (!isLocation) ...[
                    GenesisCharacterAvatar(
                      key: const ValueKey<String>(
                        'world-update-push-character-avatar',
                      ),
                      url: notice.avatarUrl,
                      name: name,
                      size: _worldUpdatePushLeadingSize,
                      borderRadius: 8,
                      showFallbackWhileLoading: true,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: GenesisTypography.fontFamily,
                            fontFamilyFallback:
                                GenesisTypography.fontFamilyFallback,
                            color: Color(0xB8FFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (isLocation)
                          Row(
                            children: [
                              const ExcludeSemantics(
                                child: Icon(
                                  Icons.place_outlined,
                                  key: ValueKey<String>(
                                    'world-update-push-location-name-icon',
                                  ),
                                  size: 14,
                                  color: Color(0xF2FFFFFF),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(child: detailText),
                            ],
                          )
                        else
                          detailText,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
