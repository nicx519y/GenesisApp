import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/page_header.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';

class DiscussPage extends StatefulWidget {
  const DiscussPage({super.key, required this.oid, this.originId = 0});

  final String oid;
  final int originId;

  @override
  State<DiscussPage> createState() => _DiscussPageState();
}

class _DiscussPageState extends State<DiscussPage> {
  static const double _loadMoreThreshold = 600;

  late final OriginDiscussListController _discussController;
  final ScrollController _scrollController = ScrollController();
  Future<OriginDetail>? _future;
  OriginDetail? _origin;

  @override
  void initState() {
    super.initState();
    _discussController = OriginDiscussListController();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _loadOriginDetail();
  }

  @override
  void didUpdateWidget(covariant DiscussPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid) {
      _origin = null;
      _future = _loadOriginDetail();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _discussController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > _loadMoreThreshold) return;
    unawaited(_discussController.loadNextPage());
  }

  Future<OriginDetail> _loadOriginDetail({
    bool forceDiscussRefresh = false,
  }) async {
    final api = AppServicesScope.read(context).api;
    final origin = await api.getOrigin(widget.oid);
    if (!mounted) return origin;
    _origin = origin;
    _discussController.configure(
      oid: origin.oid,
      loader: ({required String oid, required int pn, required int rn}) async {
        return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
      },
    );
    if (forceDiscussRefresh) {
      await _discussController.refreshFirstPage();
    } else {
      await _discussController.loadInitialIfNeeded();
    }
    return origin;
  }

  Future<void> _refresh() async {
    final future = _loadOriginDetail(forceDiscussRefresh: true);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Discuss'),
      body: FutureBuilder<OriginDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              origin == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && origin == null) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _future = _loadOriginDetail();
                }),
                child: const Text('Retry'),
              ),
            );
          }

          final data = snapshot.data ?? origin;
          if (data == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                _DiscussOriginSummary(origin: data),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEDEDED),
                  ),
                ),
                OriginDiscussList(
                  controller: _discussController,
                  showHeader: false,
                  collapseInitialItems: false,
                  enableViewMore: false,
                ),
                AnimatedBuilder(
                  animation: _discussController,
                  builder: (context, _) {
                    if (!_discussController.isLoadingMore) {
                      return const SizedBox.shrink();
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: origin == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: DiscussPostInput(
                  bizId: origin.oid,
                  onSubmitted: () =>
                      unawaited(_discussController.refreshFirstPage()),
                ),
              ),
            ),
    );
  }
}

class _DiscussOriginSummary extends StatelessWidget {
  const _DiscussOriginSummary({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final originator = origin.originator.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _OriginCover(url: origin.mapImage),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F4F7A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OID: ${origin.oid}${originator.isEmpty ? '' : ' · Originator: $originator'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8B8B8B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginCover extends StatelessWidget {
  const _OriginCover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveAssetUrl(url);
    final fallback = Container(
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: Color(0xFF999999),
      ),
    );
    final image = imageUrl.isEmpty
        ? fallback
        : imageUrl.startsWith('assets/')
        ? Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => fallback,
            errorWidget: (context, url, error) => fallback,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(width: 48, height: 48, child: image),
    );
  }
}
