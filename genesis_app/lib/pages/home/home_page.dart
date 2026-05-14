import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../components/genesis_logo.dart';
import '../../components/origin/origin_card.dart';
import '../../components/secend_tabs.dart';
import '../../components/search_bar.dart';
import '../../models/origin_item.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../routers/app_router.dart';
import '../../app/bootstrap/app_services_scope.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<String> categories = [
    'For you',
    'Billionare',
    'Destroyed',
    'End World',
    'Vam',
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: categories.length,
      child: Column(
        children: [
          const _HomeHeader(),
          const SizedBox(height: 4),
          SecendTabs(labels: categories),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                for (final label in categories) _HomeFeed(category: label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            const GenesisLogo(height: 26.2, width: 97.2),
            const SizedBox(width: 12),
            Expanded(
              child: SearchBarPlaceholder(
                hintText: 'Search origins, worlds, users...',
                onTap: () {
                  Navigator.of(context).pushNamed(RouteNames.search);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFeed extends StatefulWidget {
  const _HomeFeed({required this.category});

  final String category;

  @override
  State<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<_HomeFeed> {
  late Future<List<_OriginCardVm>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchItems();
  }

  @override
  void didUpdateWidget(covariant _HomeFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _future = _fetchItems();
    }
  }

  Future<List<_OriginCardVm>> _fetchItems() async {
    if (const bool.fromEnvironment('FLUTTER_TEST')) {
      return _itemsForCategory(widget.category)
          .map((e) => _OriginCardVm(item: e, originId: 0, oid: ''))
          .toList(growable: false);
    }

    final page = await AppServicesScope.of(
      context,
    ).api.getMyLaunchedOrigins(limit: 20, offset: 0);
    return page.data
        .map(
          (o) =>
              _OriginCardVm(item: _toOriginItem(o), originId: o.id, oid: o.oid),
        )
        .toList(growable: false);
  }

  OriginItem _toOriginItem(OriginSummary origin) {
    final hash = origin.oid.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    final coverHeight = (160 + (hash % 120)).clamp(140, 260).toDouble();

    final name = origin.name.trim().isEmpty ? origin.oid : origin.name.trim();
    final badgeText = _badgeText(name);

    final mapImageUrl = resolveAssetUrl(origin.mapImage);

    return OriginItem(
      title: '#$name',
      subtitle: origin.description,
      tags: origin.tags,
      readCount: '${origin.interactCount}',
      likeCount: '${origin.copyCount}',
      gradient: _gradientFor(origin.oid),
      badgeText: badgeText,
      coverHeight: coverHeight,
      coverImageUrl: mapImageUrl,
    );
  }

  String _badgeText(String name) {
    final cleaned = name.replaceAll('#', '').trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 'ENTER\nWORLD';
    return words.take(4).map((e) => e.toUpperCase()).join('\n');
  }

  List<Color> _gradientFor(String seed) {
    final hash = seed.codeUnits.fold<int>(
      0,
      (a, b) => (a * 131 + b) & 0x7fffffff,
    );
    int tint(int v) => 0xFF000000 | (v & 0x00FFFFFF) | 0x00303030;
    return [Color(tint(hash)), Color(tint(hash * 17))];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_OriginCardVm>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => setState(() {
                    _future = _fetchItems();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data ?? const <_OriginCardVm>[];
        if (items.isEmpty) {
          return const Center(child: Text('No data'));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MasonryGridView.builder(
            primary: false,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            mainAxisSpacing: 10,
            crossAxisSpacing: 11,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final vm = items[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pushNamed(
                  RouteNames.originWorld,
                  arguments: {'originId': vm.originId, 'oid': vm.oid},
                ),
                child: OriginCard(item: vm.item),
              );
            },
          ),
        );
      },
    );
  }

  List<OriginItem> _itemsForCategory(String category) {
    final base = demoOriginItems;
    final salt = category.codeUnits.fold<int>(0, (a, b) => a + b);
    return List<OriginItem>.generate(12, (i) {
      final item = base[(i + salt) % base.length];
      final h = item.coverHeight + ((i % 3) - 1) * 18;
      return item.copyWith(coverHeight: h.clamp(140, 260).toDouble());
    });
  }
}

class _OriginCardVm {
  const _OriginCardVm({
    required this.item,
    required this.originId,
    required this.oid,
  });

  final OriginItem item;
  final int originId;
  final String oid;
}
