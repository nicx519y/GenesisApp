import '../../l10n/genesis_l10n.dart';
import 'dart:async';

import '../../l10n/language_data_refresh.dart';

import 'package:flutter/material.dart';

import '../../app/debug/world_recap_debug_preview.dart';
import '../../app/membership/subscription_analytics.dart';
import '../../components/gems/pro_subscription_content.dart';
import '../../components/gems/subscription_tracking_scope.dart';
import '../../components/world_memory/world_memory_tick_tile.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'world_constants.dart';
import 'world_recap_cache.dart';
import 'world_sections.dart';

/// Story recap is a Worldo Premium feature. Members read the recap; everyone
/// else sees the subscription content, and nothing is fetched for them. Until
/// membership is confirmed the section shows only a skeleton.
class WorldRecapSection extends StatefulWidget {
  const WorldRecapSection({
    super.key,
    required this.cache,
    required this.load,
    required this.scrollController,
    required this.expandedContentHeight,
    this.onBenefitsPullDown,
    required this.active,
    required this.checkVip,
    required this.membershipChanges,
    required this.worldId,
    this.padding,
  });

  /// Replaces the sheet's own list inset when hosted beside other tabs.
  final EdgeInsets? padding;

  final WorldRecapCache cache;
  final WorldRecapLoader load;
  final ScrollController scrollController;
  final double expandedContentHeight;
  final ValueChanged<double>? onBenefitsPullDown;
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

class _WorldRecapSectionState extends State<WorldRecapSection>
    with LanguageDataRefresh<WorldRecapSection> {
  @override
  bool get languageSectionVisible => widget.active;
  @override
  bool get languageDataLoading => widget.cache.refreshing;
  @override
  bool get languageRefreshSucceeded => widget.cache.refreshError == null;
  @override
  Future<void> refreshLanguageData() async {
    widget.cache.clear();
    _autoPages = 0;
    if ((worldRecapForcedMembership ?? _isVip) == true) {
      await widget.cache.refresh(widget.worldId, widget.load);
    }
    if (mounted) setState(() {});
  }

  final _subscriptionTracking = SubscriptionPageTracking(
    source: SubscriptionSource.worldRecap,
  );

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
      widget.padding ??
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
      if (isVip == null) return _list(const [_RecapSkeleton()]);
      return KeyedSubtree(
        key: const ValueKey<String>('world-recap-locked'),
        child: SubscriptionTrackingScope(
          page: _subscriptionTracking,
          child: ProSubscriptionContent(
            refreshMembershipOnOpen: false,
            headingSuffix: GenesisL10n.current.recapUnlockHeading,
            tagline: GenesisL10n.current.recapUpsellDescription,
            sheetScrollController: widget.scrollController,
            sheetExpandedContentHeight: widget.expandedContentHeight,
            includeBottomSafeArea: true,
            onBenefitsPullDown: widget.onBenefitsPullDown,
            topSpacing: worldSheetVisibleContentTopGap,
            headingTopSpacing: 0,
            horizontalInset: 12,
          ),
        ),
      );
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
                  child: Text(GenesisL10n.current.homeRetry),
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
                  cache.loadingMore
                      ? GenesisL10n.current.chatLoading
                      : GenesisL10n.current.recapShowEarlier,
                ),
              ),
            ),
          for (final (index, (tickNo, bodies)) in ticks.indexed)
            WorldMemoryTickTile(
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
      Text(
        GenesisL10n.current.recapEmpty,
        key: ValueKey<String>('world-recap-empty'),
        textAlign: TextAlign.center,
        style: _recapNoteStyle,
      ),
    if (cache.refreshError != null)
      Center(
        child: TextButton(
          onPressed: () => unawaited(cache.refresh(cache.worldId, widget.load)),
          child: Text(GenesisL10n.current.homeRetry),
        ),
      )
    else if (cache.loadMoreError != null)
      Center(
        child: TextButton(
          onPressed: () => unawaited(cache.loadMore(widget.load, retry: true)),
          child: Text(GenesisL10n.current.homeRetry),
        ),
      ),
  ];
}

/// Notes that stand where the recap will be: set at the recap's own size and
/// from the top of the list, as its first paragraph would be, rather than as a
/// small empty state floating part way down the sheet.
const TextStyle _recapNoteStyle = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: GenesisColors.darkTextSecondary,
);

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
