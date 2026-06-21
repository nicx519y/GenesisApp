import 'dart:async';

import 'package:flutter/material.dart';

import 'origin_discuss_list.dart';

typedef OriginDiscussPreviewItem = OriginDiscussListItem;

typedef OriginDiscussPreviewLoader =
    Future<List<OriginDiscussPreviewItem>> Function(String oid);

Future<List<OriginDiscussPreviewItem>> loadOriginDiscussPreviewItems(
  BuildContext context,
  String oid,
) async {
  final page = await loadOriginDiscussPage(
    context,
    oid,
    pn: 1,
    rn: originDiscussPageSize,
  );
  return page.items.take(2).toList(growable: false);
}

class OriginDiscussPreviewList extends StatefulWidget {
  const OriginDiscussPreviewList({
    super.key,
    required this.oid,
    required this.count,
    this.showHeader = true,
    this.initialItems,
    this.loader,
    this.onPreviewTap,
  });

  final String oid;
  final int count;
  final bool showHeader;
  final List<OriginDiscussPreviewItem>? initialItems;
  final OriginDiscussPreviewLoader? loader;
  final Future<void> Function()? onPreviewTap;

  @override
  State<OriginDiscussPreviewList> createState() =>
      _OriginDiscussPreviewListState();
}

class _OriginDiscussPreviewListState extends State<OriginDiscussPreviewList> {
  late final OriginDiscussListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OriginDiscussListController();
    _seedInitialItemsIfAvailable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialItems == null) _configureAndLoad();
  }

  @override
  void didUpdateWidget(covariant OriginDiscussPreviewList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != null) {
      if (oldWidget.oid != widget.oid ||
          oldWidget.count != widget.count ||
          oldWidget.initialItems != widget.initialItems) {
        _seedInitialItemsIfAvailable();
      }
      return;
    }
    if (oldWidget.oid != widget.oid ||
        oldWidget.loader != widget.loader ||
        oldWidget.initialItems != null) {
      _configureAndLoad();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _configureAndLoad() {
    _controller.configure(oid: widget.oid, loader: _loadPage);
    unawaited(_controller.loadInitialIfNeeded());
  }

  void _seedInitialItemsIfAvailable() {
    final items = widget.initialItems;
    if (items == null) return;
    _controller.seedItems(
      oid: widget.oid,
      items: items,
      totalAll: items.length,
    );
  }

  Future<OriginDiscussPage> _loadPage({
    required String oid,
    required int pn,
    required int rn,
  }) async {
    final loader = widget.loader;
    if (loader == null) {
      return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
    }
    final items = await loader(oid);
    return OriginDiscussPage(
      items: items,
      topTotal: items.length,
      totalAll: items.length,
      pn: pn,
      rn: rn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OriginDiscussList(
      controller: _controller,
      count: widget.count,
      showHeader: widget.showHeader,
      enableViewMore: false,
      onAuthorTap: widget.onPreviewTap == null
          ? null
          : (_) => unawaited(widget.onPreviewTap!()),
      onItemReplyTap: widget.onPreviewTap == null
          ? null
          : (_) => unawaited(widget.onPreviewTap!()),
      onViewMoreTap: widget.onPreviewTap,
    );
  }
}
