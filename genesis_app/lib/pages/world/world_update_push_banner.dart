import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../network/chatroom/world_chatroom_service.dart';
import '../../ui/tokens/genesis_typography.dart';

class WorldUpdatePushBannerQueue extends StatefulWidget {
  const WorldUpdatePushBannerQueue({
    super.key,
    required this.top,
    required this.revision,
    required this.notices,
    this.displayDuration = const Duration(seconds: 4),
    this.transitionDuration = const Duration(milliseconds: 220),
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

class _WorldUpdatePushBannerQueueState
    extends State<WorldUpdatePushBannerQueue> {
  final Queue<WorldContentUpdateNotice> _pending =
      Queue<WorldContentUpdateNotice>();
  final Set<String> _acceptedOccurrences = <String>{};
  WorldContentUpdateNotice? _activeNotice;
  Timer? _dismissTimer;
  var _lastRevision = 0;

  @override
  void initState() {
    super.initState();
    _lastRevision = widget.revision;
    if (widget.revision > 0) _accept(widget.notices);
    _scheduleDismissAfterBuild();
  }

  @override
  void didUpdateWidget(WorldUpdatePushBannerQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision == _lastRevision) return;
    _lastRevision = widget.revision;
    if (widget.revision > 0) _accept(widget.notices);
    _scheduleDismissAfterBuild();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _accept(List<WorldContentUpdateNotice> notices) {
    for (final notice in notices) {
      if (_acceptedOccurrences.add(notice.occurrenceKey)) {
        _pending.add(notice);
      }
    }
    _activeNotice ??= _pending.isEmpty ? null : _pending.removeFirst();
  }

  void _scheduleDismissAfterBuild() {
    if (_activeNotice == null || _dismissTimer?.isActive == true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _activeNotice == null ||
          _dismissTimer?.isActive == true) {
        return;
      }
      _dismissTimer = Timer(widget.displayDuration, _showNextNotice);
    });
  }

  void _showNextNotice() {
    if (!mounted) return;
    _dismissTimer = null;
    setState(() {
      _activeNotice = _pending.isEmpty ? null : _pending.removeFirst();
    });
    _scheduleDismissAfterBuild();
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
          child: AnimatedSwitcher(
            duration: widget.transitionDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0, -0.45),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: notice == null
                ? const SizedBox.shrink(
                    key: ValueKey<String>('world-update-push-empty'),
                  )
                : _WorldUpdatePushBanner(
                    key: ValueKey<String>(notice.occurrenceKey),
                    notice: notice,
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
        ? (isLocation ? 'New location' : 'New character')
        : notice.name.trim();
    final category = isLocation ? 'New location' : 'New character';
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$category: $name',
      child: Material(
        key: const ValueKey<String>('world-update-push-banner'),
        color: const Color(0xFF1F1D24),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
          child: Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2442),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 38,
                  child: Icon(
                    isLocation
                        ? Icons.location_on_outlined
                        : Icons.person_outline,
                    size: 21,
                    color: const Color(0xF2FFFFFF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: GenesisTypography.fontFamily,
                        fontFamilyFallback:
                            GenesisTypography.fontFamilyFallback,
                        color: Color(0xF2FFFFFF),
                        fontSize: 15,
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
}
