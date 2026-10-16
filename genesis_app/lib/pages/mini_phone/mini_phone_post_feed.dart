import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../network/mini_phone/mini_phone_models.dart';
import '../../ui/components/genesis_static_network_image.dart';
import 'mini_phone_post_thumbnail.dart';
import 'mini_phone_ui.dart';

/// Variable-height rows are built only around the viewport. Image prefetching
/// observes laid-out row bounds, independently of the sliver's cache area.
class MiniPhonePostFeed extends StatefulWidget {
  const MiniPhonePostFeed({
    super.key,
    required this.posts,
    required this.header,
    required this.footer,
    required this.itemBuilder,
    required this.resetKey,
    this.active = true,
  });

  final List<PhonePost> posts;
  final Widget header, footer;
  final Widget Function(PhonePost post) itemBuilder;
  final Object resetKey;
  final bool active;

  @override
  State<MiniPhonePostFeed> createState() => _MiniPhonePostFeedState();
}

class _MiniPhonePostFeedState extends State<MiniPhonePostFeed> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _rows = <int, GlobalKey>{};
  var _indices = <int, int>{};
  final _inFlight = <GenesisStaticNetworkImageProvider>{};
  final _attempted = <GenesisStaticNetworkImageProvider>{};
  var _desired = <GenesisStaticNetworkImageProvider>[];
  var _scheduled = false;
  var _resetScroll = false;
  var _active = false;
  double _thumbnailWidth = miniPhonePostThumbnailMaxWidth;

  @override
  void initState() {
    super.initState();
    _indexPosts();
    _scroll.addListener(_scheduleMeasurement);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = widget.active && TickerMode.valuesOf(context).enabled;
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant MiniPhonePostFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.posts, widget.posts)) _indexPosts();
    _active = widget.active && TickerMode.valuesOf(context).enabled;
    if (oldWidget.resetKey != widget.resetKey) _resetScroll = true;
    _scheduleMeasurement();
  }

  void _indexPosts() {
    _indices = {
      for (var i = 0; i < widget.posts.length; i++) widget.posts[i].id: i,
    };
  }

  void _scheduleMeasurement() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measureViewport();
    });
  }

  void _measureViewport() {
    if (_resetScroll && _scroll.hasClients) {
      _resetScroll = false;
      _desired = [];
      _attempted.clear();
      if (_scroll.offset != 0) {
        _scroll.jumpTo(0);
        return;
      }
    }
    _rows.removeWhere((_, key) => key.currentContext == null);
    final viewport = _viewport.currentContext?.findRenderObject();
    if (!_active || viewport is! RenderBox || !viewport.hasSize) {
      _desired = [];
      _attempted.clear();
      return;
    }
    int? lastVisible;
    for (final entry in _rows.entries) {
      final row = entry.value.currentContext?.findRenderObject();
      final index = _indices[entry.key];
      if (row is! RenderBox || !row.hasSize || index == null) continue;
      final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top < viewport.size.height && top + row.size.height > 0) {
        lastVisible = math.max(lastVisible ?? index, index);
      }
    }
    _desired = [
      if (lastVisible != null)
        for (final post in widget.posts.skip(lastVisible + 1).take(5))
          if (post.image.isNotEmpty)
            miniPhonePostThumbnailProvider(
              post.image,
              width: _thumbnailWidth,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
    ];
    _attempted.removeWhere((provider) => !_desired.contains(provider));
    _prefetch();
  }

  void _prefetch() {
    if (!mounted || !_active) return;
    for (final provider in _desired) {
      if (_inFlight.length >= 5) break;
      if (_inFlight.contains(provider) || !_attempted.add(provider)) continue;
      _inFlight.add(provider);
      unawaited(
        precacheImage(provider, context, onError: (_, _) {}).whenComplete(() {
          _inFlight.remove(provider);
          _prefetch();
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      _thumbnailWidth = (bounds.maxWidth - miniPageInset * 2 - 50).clamp(
        1.0,
        miniPhonePostThumbnailMaxWidth,
      );
      _scheduleMeasurement();
      return ListView.builder(
        key: _viewport,
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        scrollCacheExtent: const ScrollCacheExtent.pixels(200),
        addAutomaticKeepAlives: false,
        itemCount: widget.posts.length + 2,
        findChildIndexCallback: (key) {
          if (key == const ValueKey('post-feed-header')) return 0;
          if (key == const ValueKey('post-feed-footer')) {
            return widget.posts.length + 1;
          }
          for (final entry in _rows.entries) {
            if (entry.value == key) {
              final index = _indices[entry.key];
              return index == null ? null : index + 1;
            }
          }
          return null;
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return KeyedSubtree(
              key: const ValueKey('post-feed-header'),
              child: widget.header,
            );
          }
          if (index == widget.posts.length + 1) {
            return KeyedSubtree(
              key: const ValueKey('post-feed-footer'),
              child: widget.footer,
            );
          }
          final post = widget.posts[index - 1];
          return KeyedSubtree(
            key: _rows.putIfAbsent(post.id, GlobalKey.new),
            child: widget.itemBuilder(post),
          );
        },
      );
    },
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}
