import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/debug/world_recap_debug_preview.dart';
import '../../app/membership/subscription_analytics.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/gems/gem_purchase_bottom_sheet.dart';
import '../../components/gems/pro_colors.dart';
import '../../components/gems/pro_membership_badge.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import 'world_constants.dart';
import 'world_recap_cache.dart';
import 'world_sections.dart';

/// Story recap is a Worldo Premium feature. Members read the recap; everyone
/// else sees what it offers and a way to subscribe, and nothing is fetched for
/// them. Until membership is confirmed the section shows only a skeleton, so
/// neither side glimpses the other's view.
class WorldRecapSection extends StatefulWidget {
  const WorldRecapSection({
    super.key,
    required this.cache,
    required this.load,
    required this.scrollController,
    required this.active,
    required this.checkVip,
    required this.membershipChanges,
    required this.worldId,
  });

  final WorldRecapCache cache;
  final WorldRecapLoader load;
  final ScrollController scrollController;
  final bool active;

  /// Answers, once and asynchronously, whether the user is a member: true,
  /// false, or null while that is not yet known.
  final void Function(ValueChanged<bool?> callback) checkVip;

  /// Fires whenever membership may have changed, such as after subscribing.
  final Listenable membershipChanges;
  final String worldId;

  @override
  State<WorldRecapSection> createState() => _WorldRecapSectionState();
}

class _WorldRecapSectionState extends State<WorldRecapSection> {
  /// The recap reads oldest first while the server pages newest first, so
  /// every page is fetched before it is shown: an older page arriving later
  /// would otherwise land above whatever the reader had reached. A cap keeps
  /// a very long story from fetching without end; past it, the earlier part
  /// is one tap away at the top.
  static const int _autoPageLimit = 10;
  int _autoPages = 0;
  String _autoPagesWorld = '';
  bool _earlierScheduled = false;

  /// True for members, false for everyone else, null until confirmed.
  bool? _isVip;

  /// Stand-in content for the developer preview, made only when shown.
  WorldRecapCache? _emptyPreview;
  WorldRecapCache? _samplePreview;

  @override
  void initState() {
    super.initState();
    widget.membershipChanges.addListener(_checkVip);
    worldRecapDebugPreview.addListener(_previewChanged);
    _checkVip();
  }

  void _previewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(WorldRecapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.membershipChanges, widget.membershipChanges)) {
      oldWidget.membershipChanges.removeListener(_checkVip);
      widget.membershipChanges.addListener(_checkVip);
      _checkVip();
    }
  }

  @override
  void dispose() {
    widget.membershipChanges.removeListener(_checkVip);
    worldRecapDebugPreview.removeListener(_previewChanged);
    _emptyPreview?.dispose();
    _samplePreview?.dispose();
    super.dispose();
  }

  void _checkVip() {
    widget.checkVip((isVip) {
      if (!mounted || isVip == _isVip) return;
      // Entering the tab loads the recap for members already. Load here only
      // when someone becomes one while looking at it, having just subscribed.
      final justSubscribed = _isVip == false && isVip == true;
      setState(() => _isVip = isVip);
      if (justSubscribed) {
        unawaited(widget.cache.refresh(widget.worldId, widget.load));
      }
    });
  }

  bool get _settling {
    final cache = widget.cache;
    return cache.hasMore &&
        cache.loadMoreError == null &&
        _autoPages < _autoPageLimit;
  }

  /// Fetches the next older page while the recap is still settling.
  void _scheduleEarlierPages(WorldRecapCache cache) {
    if (!identical(cache, widget.cache)) return;
    if (_autoPagesWorld != cache.worldId) {
      _autoPagesWorld = cache.worldId;
      _autoPages = 0;
    }
    if (_earlierScheduled ||
        !widget.active ||
        !cache.hasLoaded ||
        cache.refreshing ||
        cache.loadingMore ||
        !_settling) {
      return;
    }
    _earlierScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _earlierScheduled = false;
      if (!mounted || !widget.active || !_settling) return;
      _autoPages += 1;
      unawaited(widget.cache.loadMore(widget.load));
    });
  }

  EdgeInsets get _padding =>
      const EdgeInsets.fromLTRB(12, worldSheetVisibleContentTopGap, 12, 32);

  @override
  Widget build(BuildContext context) {
    // The developer preview stands in for membership and content alike, so
    // every state can be looked at without a subscription.
    final preview = activeWorldRecapDebugPreview;
    final isVip = worldRecapForcedMembership ?? _isVip;
    final shown = switch (preview) {
      WorldRecapDebugPreview.memberEmpty =>
        _emptyPreview ??= WorldRecapCache()..hasLoaded = true,
      WorldRecapDebugPreview.memberSample =>
        _samplePreview ??= WorldRecapCache()
          ..items = worldRecapDebugSample
          ..hasLoaded = true,
      _ => widget.cache,
    };
    if (isVip != true) {
      // Still a list on the sheet's controller, so dragging the sheet feels
      // the same whichever view is showing.
      return _list([
        if (isVip == null)
          const _RecapSkeleton()
        else
          const _RecapLockedNotice(),
      ]);
    }
    return ListenableBuilder(
      listenable: shown,
      builder: (context, _) {
        final cache = shown;
        _scheduleEarlierPages(cache);
        final live = identical(cache, widget.cache);
        if (!cache.hasLoaded) {
          // Cold: a skeleton until the first page lands, with Retry under it
          // should that first request fail.
          return _list([
            const _RecapSkeleton(),
            if (cache.refreshError != null)
              Center(
                child: TextButton(
                  onPressed: () =>
                      unawaited(cache.refresh(cache.worldId, widget.load)),
                  child: const Text('Retry'),
                ),
              ),
          ]);
        }
        if (live && _settling) return _list(const [_RecapSkeleton()]);
        // Oldest first, reading down to the latest, as the Events tab runs.
        final items = cache.items.reversed.toList(growable: false);
        final ticks = <(int, List<String>)>[];
        for (final item in items) {
          if (ticks.isNotEmpty && ticks.last.$1 == item.tickNo) {
            ticks.last.$2.add(item.body);
          } else {
            ticks.add((item.tickNo, [item.body]));
          }
        }
        return _list([
          if (live && cache.hasMore && cache.loadMoreError == null)
            Center(
              child: TextButton(
                key: const ValueKey<String>('world-recap-earlier'),
                onPressed: cache.loadingMore
                    ? null
                    : () => unawaited(cache.loadMore(widget.load)),
                child: Text(
                  cache.loadingMore ? 'Loading…' : 'Show earlier recap',
                ),
              ),
            ),
          for (final (index, (tickNo, bodies)) in ticks.indexed)
            _RecapTimelineTick(
              key: ValueKey<String>('world-recap-tick-$tickNo-$index'),
              tickNo: tickNo,
              bodies: bodies,
              isFirst: index == 0,
              isLast: index == ticks.length - 1,
            ),
          ..._footer(cache),
        ]);
      },
    );
  }

  Widget _list(List<Widget> children) => ListView(
    key: const PageStorageKey<String>('world-recap-list'),
    controller: widget.scrollController,
    padding: _padding,
    children: children,
  );

  List<Widget> _footer(WorldRecapCache cache) => [
    if (cache.items.isEmpty && cache.refreshError == null)
      const Text(
        'Story recap will appear here as the story moves forward.',
        key: ValueKey<String>('world-recap-empty'),
        textAlign: TextAlign.center,
        style: _recapNoteStyle,
      ),
    if (cache.refreshError != null)
      Center(
        child: TextButton(
          onPressed: () => unawaited(cache.refresh(cache.worldId, widget.load)),
          child: const Text('Retry'),
        ),
      )
    else if (cache.loadMoreError != null)
      Center(
        child: TextButton(
          onPressed: () => unawaited(cache.loadMore(widget.load, retry: true)),
          child: const Text('Retry'),
        ),
      ),
  ];
}

/// One tick of the recap on a timeline. A rail on the left strings the ticks
/// into one story, read downward in the order it happened; each tick is named
/// as the Events tab names it, beside its node, and only the latest node takes
/// the accent, so the red marks where the story now stands.
class _RecapTimelineTick extends StatelessWidget {
  const _RecapTimelineTick({
    super.key,
    required this.tickNo,
    required this.bodies,
    required this.isFirst,
    required this.isLast,
  });

  final int tickNo;
  final List<String> bodies;
  final bool isFirst;
  final bool isLast;

  static const double _railWidth = 16;
  static const double _railGap = 10;
  static const double _gapAfterTick = 22;

  static final TextStyle _body = GenesisTypography.body.copyWith(
    color: GenesisColors.darkTextSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final hasLabel = tickNo > 0;
    // The node centres on the first line beside it, measured at the reader's
    // own text scale so it stays level whatever size they read at.
    final firstLine = TextPainter(
      text: TextSpan(text: 'M', style: hasLabel ? chatTickLabelStyle : _body),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    final nodeCentre = firstLine.height / 2;
    firstLine.dispose();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: CustomPaint(
              painter: _RecapRailPainter(
                nodeCentre: nodeCentre,
                lineAbove: !isFirst,
                lineBelow: !isLast,
                latest: isLast,
              ),
            ),
          ),
          const SizedBox(width: _railGap),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : _gapAfterTick),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasLabel) ...[
                    // Named as the Events tab names a tick.
                    Text('Tick $tickNo', style: chatTickLabelStyle),
                    const SizedBox(height: 8),
                  ],
                  for (final (index, body) in bodies.indexed) ...[
                    if (index > 0) const SizedBox(height: 10),
                    Text(body, style: _body),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapRailPainter extends CustomPainter {
  const _RecapRailPainter({
    required this.nodeCentre,
    required this.lineAbove,
    required this.lineBelow,
    required this.latest,
  });

  final double nodeCentre;
  final bool lineAbove;
  final bool lineBelow;
  final bool latest;

  static const Color _line = Color(0x1FFFFFFF);
  static const double _nodeRadius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final line = Paint()
      ..color = _line
      ..strokeWidth = 1;
    if (lineAbove) {
      canvas.drawLine(Offset(x, 0), Offset(x, nodeCentre), line);
    }
    if (lineBelow) {
      canvas.drawLine(Offset(x, nodeCentre), Offset(x, size.height), line);
    }
    canvas.drawCircle(
      Offset(x, nodeCentre),
      _nodeRadius,
      Paint()
        ..color = latest
            ? GenesisColors.redPrimary
            : GenesisColors.darkTextTertiary,
    );
  }

  @override
  bool shouldRepaint(_RecapRailPainter old) =>
      old.nodeCentre != nodeCentre ||
      old.lineAbove != lineAbove ||
      old.lineBelow != lineBelow ||
      old.latest != latest;
}

/// Notes that stand where the recap will be: set at the recap's own size and
/// from the top of the list, as its first paragraph would be, rather than as a
/// small empty state floating part way down the sheet.
const TextStyle _recapNoteStyle = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: GenesisColors.darkTextSecondary,
);

/// What the recap offers, for anyone without Worldo Premium, and the way in.
class _RecapLockedNotice extends StatelessWidget {
  const _RecapLockedNotice();

  void _subscribe(BuildContext context) => unawaited(
    showSubscriptionPurchaseBottomSheet(
      context,
      source: SubscriptionSource.worldRecap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('world-recap-locked'),
      children: [
        const Text(
          'Catch up on your story with a full recap of every twist, '
          'choice, and character along the way.',
          textAlign: TextAlign.center,
          style: _recapNoteStyle,
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Available with '),
              // The plan's name in the crown and gold it carries on the
              // profile's membership card.
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ProMembershipBadge.beside(
                    fontSize: _recapNoteStyle.fontSize!,
                  ),
                ),
              ),
              const WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _PremiumName(),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: _recapNoteStyle,
        ),
        const SizedBox(height: 4),
        Semantics(
          button: true,
          child: GestureDetector(
            key: const ValueKey<String>('world-recap-subscribe'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _subscribe(context),
            // Padding widens the tap target beyond the words themselves.
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Subscribe to Unlock',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: GenesisColors.redSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: GenesisColors.redSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Worldo Premium" under the gold sweep of the membership card's wordmark,
/// at the size of the sentence it sits in.
class _PremiumName extends StatelessWidget {
  const _PremiumName();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => proTitleGradient.createShader(bounds),
      child: Text(
        'Worldo Premium',
        style: _recapNoteStyle.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.07,
        ),
      ),
    );
  }
}

class _RecapSkeleton extends StatelessWidget {
  const _RecapSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey<String>('world-recap-skeleton'),
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorldTickPendingSkeletonLine(widthFactor: .24, height: 10),
          SizedBox(height: 16),
          WorldTickPendingSkeletonLine(widthFactor: .96),
          SizedBox(height: 10),
          WorldTickPendingSkeletonLine(widthFactor: .88),
          SizedBox(height: 10),
          WorldTickPendingSkeletonLine(widthFactor: .64),
        ],
      ),
    );
  }
}
