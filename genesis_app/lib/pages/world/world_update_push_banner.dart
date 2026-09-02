import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../network/chatroom/world_chatroom_service.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../ui/tokens/genesis_typography.dart';

const worldUpdatePushDisplayDuration = Duration(seconds: 3);
const worldUpdatePushTransitionDuration = Duration(milliseconds: 220);
const _worldUpdatePushLeadingSize = 48.0;
const _worldUpdatePushLocationImageRadius = 10.0;

class WorldUpdatePushBannerQueue extends StatefulWidget {
  const WorldUpdatePushBannerQueue({
    super.key,
    required this.top,
    required this.revision,
    required this.notices,
    this.displayDuration = worldUpdatePushDisplayDuration,
    this.transitionDuration = worldUpdatePushTransitionDuration,
  });

  final double top;
  final int revision;
  final List<WorldContentUpdateNotice> notices;
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
  var _lastRevision = 0;

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
    _lastRevision = widget.revision;
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
    if (widget.revision == _lastRevision) return;
    _lastRevision = widget.revision;
    if (widget.revision > 0) _accept(widget.notices);
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
      if (_acceptedOccurrences.add(notice.occurrenceKey)) {
        _pending.add(notice);
      }
    }
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
      setState(() => _activeNotice = _pending.removeFirst());
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
    _dismissTimer = null;
    _isDismissing = true;
    _transitionController.reverse();
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
      left: 12,
      top: widget.top,
      right: 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
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
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _WorldUpdatePushBanner extends StatelessWidget {
  const _WorldUpdatePushBanner({super.key, required this.notice});

  final WorldContentUpdateNotice notice;

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
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$category: $detail',
      child: Material(
        key: const ValueKey<String>('world-update-push-banner'),
        color: const Color(0xFF1F1D24),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              if (isLocation)
                _buildLocationImage()
              else
                GenesisCharacterAvatar(
                  key: const ValueKey<String>(
                    'world-update-push-character-avatar',
                  ),
                  url: notice.avatarUrl,
                  name: name,
                  size: _worldUpdatePushLeadingSize,
                  borderRadius: _worldUpdatePushLeadingSize / 2,
                  showFallbackWhileLoading: true,
                ),
              const SizedBox(width: 10),
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
                    Text.rich(
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
                        fontFamilyFallback:
                            GenesisTypography.fontFamilyFallback,
                        color: Color(0xF2FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationImage() {
    final imageUrl = notice.avatarUrl.trim();
    if (imageUrl.isEmpty) return _buildLocationImageFallback();
    final image = imageUrl.startsWith('assets/')
        ? Image.asset(
            imageUrl,
            width: _worldUpdatePushLeadingSize,
            height: _worldUpdatePushLeadingSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildLocationImageFallback(),
          )
        : GenesisStaticNetworkImage(
            key: const ValueKey<String>(
              'world-update-push-location-network-image',
            ),
            imageUrl: imageUrl,
            width: _worldUpdatePushLeadingSize,
            height: _worldUpdatePushLeadingSize,
            fit: BoxFit.cover,
            placeholder: (_) => _buildLocationImageFallback(),
            errorWidget: (_, _) => _buildLocationImageFallback(),
          );
    return ClipRRect(
      key: const ValueKey<String>('world-update-push-location-image'),
      borderRadius: BorderRadius.circular(_worldUpdatePushLocationImageRadius),
      child: SizedBox.square(
        dimension: _worldUpdatePushLeadingSize,
        child: image,
      ),
    );
  }

  Widget _buildLocationImageFallback() {
    return DecoratedBox(
      key: const ValueKey<String>('world-update-push-location-icon'),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2442),
        borderRadius: BorderRadius.circular(
          _worldUpdatePushLocationImageRadius,
        ),
      ),
      child: const SizedBox.square(
        dimension: _worldUpdatePushLeadingSize,
        child: Icon(
          Icons.location_on_outlined,
          size: 22,
          color: Color(0xF2FFFFFF),
        ),
      ),
    );
  }
}
