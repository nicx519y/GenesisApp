import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/gems/gem_colors.dart';
import '../../network/models/gem_records.dart';
import '../../ui/components/genesis_app_bar.dart';
import '../../ui/components/genesis_state_view.dart';
import '../../ui/components/genesis_tab_bar.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

typedef GemRecordsLoader =
    Future<GemRecordList> Function({
      required String scene,
      required int pn,
      required int rn,
    });

class GemRecordsPage extends StatefulWidget {
  const GemRecordsPage({super.key, this.recordsLoader});

  final GemRecordsLoader? recordsLoader;

  @override
  State<GemRecordsPage> createState() => _GemRecordsPageState();
}

class _GemRecordsPageState extends State<GemRecordsPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;
  static const List<_GemRecordTab> _tabs = [
    _GemRecordTab(label: 'All', scene: 'all'),
    _GemRecordTab(label: 'Earned', scene: 'earned'),
    _GemRecordTab(label: 'Spent', scene: 'spent'),
    _GemRecordTab(label: 'Purchase', scene: 'purchase'),
  ];

  late final TabController _tabController;
  late final List<_GemRecordTabState> _tabStates;
  late final List<VoidCallback> _scrollListeners;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabControllerChanged);
    final states = <_GemRecordTabState>[];
    final listeners = <VoidCallback>[];
    for (var i = 0; i < _tabs.length; i += 1) {
      final index = i;
      final controller = ScrollController();
      void listener() => _handleScroll(index);
      controller.addListener(listener);
      states.add(_GemRecordTabState(scrollController: controller));
      listeners.add(listener);
    }
    _tabStates = states;
    _scrollListeners = listeners;
    unawaited(_loadFirstPage(index: _selectedIndex));
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabControllerChanged)
      ..dispose();
    for (var i = 0; i < _tabStates.length; i += 1) {
      _tabStates[i].scrollController
        ..removeListener(_scrollListeners[i])
        ..dispose();
    }
    super.dispose();
  }

  Future<GemRecordList> _loadRecords({
    required String scene,
    required int pn,
    required int rn,
  }) {
    final loader = widget.recordsLoader;
    if (loader != null) return loader(scene: scene, pn: pn, rn: rn);
    return AppServicesScope.read(
      context,
    ).api.v1.gem.records(scene: scene, pn: pn, rn: rn);
  }

  Future<void> _loadFirstPage({
    required int index,
    bool refreshing = false,
  }) async {
    if (!mounted) return;
    final state = _tabStates[index];
    setState(() {
      state.error = null;
      state.isInitialLoading = !refreshing;
      state.isRefreshing = refreshing;
      state.isLoadingMore = false;
    });
    try {
      final page = await _loadRecords(
        scene: _tabs[index].scene,
        pn: 1,
        rn: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        state.records = page.items;
        state.hasMore = page.hasMore;
        state.hasLoaded = true;
        state.isInitialLoading = false;
        state.isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        state.error = error;
        state.hasLoaded = true;
        state.isInitialLoading = false;
        state.isRefreshing = false;
      });
    }
  }

  Future<void> _loadMore(int index) async {
    final state = _tabStates[index];
    if (state.isInitialLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    setState(() => state.isLoadingMore = true);
    try {
      final nextPage = (state.records.length ~/ _pageSize) + 1;
      final page = await _loadRecords(
        scene: _tabs[index].scene,
        pn: nextPage,
        rn: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        state.records = [...state.records, ...page.items];
        state.hasMore = page.hasMore;
        state.isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => state.isLoadingMore = false);
    }
  }

  void _handleScroll(int index) {
    final controller = _tabStates[index].scrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.extentAfter < 220) unawaited(_loadMore(index));
  }

  void _handleTabControllerChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index != _selectedIndex) _selectTab(index);
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    if (!_tabStates[index].hasLoaded) {
      unawaited(_loadFirstPage(index: index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.genesisColors.pageBackground,
      appBar: const GenesisAppBar(
        title: 'Gem Records',
        variant: GenesisAppBarVariant.leadingTitle,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _GemRecordTabs(
              controller: _tabController,
              labels: _tabs.map((tab) => tab.label).toList(growable: false),
              onSelected: _selectTab,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (var i = 0; i < _tabs.length; i += 1) _buildBody(i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(int index) {
    final state = _tabStates[index];
    if (state.isInitialLoading) {
      return GenesisStateView.loading(
        progressColor: context.genesisGemColors.accent,
      );
    }
    if (state.error != null && state.records.isEmpty) {
      return GenesisStateView.error(
        message: 'Unable to load records.',
        horizontalPadding: 32,
        onAction: () => unawaited(_loadFirstPage(index: index)),
      );
    }
    if (state.records.isEmpty) {
      return RefreshIndicator(
        color: context.genesisGemColors.accent,
        onRefresh: () => _loadFirstPage(index: index, refreshing: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            GenesisStateView.empty(
              message: 'No gem records yet.',
              textStyle: TextStyle(
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w400,
                color: context.genesisColors.textPlaceholder,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: context.genesisGemColors.accent,
      onRefresh: () => _loadFirstPage(index: index, refreshing: true),
      child: ListView.separated(
        controller: state.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
        itemCount: state.records.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, _) => Divider(
          height: 1,
          thickness: 1,
          color: context.genesisColors.dividerSubtle,
        ),
        itemBuilder: (context, itemIndex) {
          if (itemIndex >= state.records.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: GenesisLoadingIndicator(
                  variant: GenesisLoadingIndicatorVariant.loadMore,
                  color: context.genesisGemColors.accent,
                ),
              ),
            );
          }
          return _GemRecordTile(record: state.records[itemIndex]);
        },
      ),
    );
  }
}

class _GemRecordTabState {
  _GemRecordTabState({required this.scrollController});

  final ScrollController scrollController;
  List<GemRecordItem> records = const <GemRecordItem>[];
  bool hasLoaded = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  Object? error;
}

class _GemRecordTab {
  const _GemRecordTab({required this.label, required this.scene});

  final String label;
  final String scene;
}

class _GemRecordTabs extends StatelessWidget {
  const _GemRecordTabs({
    required this.controller,
    required this.labels,
    required this.onSelected,
  });

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: GenesisTabBar(
            controller: controller,
            labels: labels,
            horizontalPadding: 16,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            verticalPadding: 0,
            indicatorMatchesLabelWidth: true,
            indicatorHeight: 2,
            indicatorBottomPadding: 0,
            labelColor: context.genesisColors.textPrimary,
            unselectedLabelColor: context.genesisColors.textPlaceholder,
            labelStyle: const TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
            expanded: true,
            onTap: onSelected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            height: 1,
            thickness: 1,
            color: context.genesisColors.divider,
          ),
        ),
      ],
    );
  }
}

class _GemRecordTile extends StatelessWidget {
  const _GemRecordTile({required this.record});

  final GemRecordItem record;

  @override
  Widget build(BuildContext context) {
    final isIncome = record.amount >= 0;
    final amountText =
        '${isIncome ? '+' : '-'}${_formatInteger(record.amount.abs())}';
    final detailLines = _recordDetailLines(record);
    return Container(
      key: ValueKey<String>('gem-record-item-${record.ledgerId}'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recordTitle(record),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: context.genesisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                for (var index = 0; index < detailLines.length; index += 1) ...[
                  _GemRecordDetailLine(
                    detailLines[index].text,
                    copyValue: detailLines[index].copyValue,
                    isSecondary: index > 0,
                  ),
                  if (index != detailLines.length - 1)
                    const SizedBox(height: 5),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              amountText,
              style: TextStyle(
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w800,
                color: isIncome
                    ? context.genesisGemColors.reward
                    : context.genesisColors.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GemRecordDetailLine extends StatelessWidget {
  const _GemRecordDetailLine(
    this.text, {
    this.copyValue,
    this.isSecondary = false,
  });

  final String text;
  final String? copyValue;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    final value = copyValue?.trim();
    final child = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w400,
        color: isSecondary
            ? context.genesisColors.textDisabled
            : context.genesisColors.textPlaceholder,
      ),
    );
    if (value == null || value.isEmpty) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_copyGemRecordText(context, value)),
      child: child,
    );
  }
}

String _recordTitle(GemRecordItem record) {
  return record.title.isEmpty ? _fallbackTitle(record) : record.title;
}

List<_GemRecordDetail> _recordDetailLines(GemRecordItem record) {
  final time = formatGemRecordTimestamp(record.createdAt);
  final worldId = record.worldId.trim();
  return <_GemRecordDetail>[
    if (time.isNotEmpty) _GemRecordDetail(text: time),
    if (worldId.isNotEmpty) _GemRecordDetail(text: worldId, copyValue: worldId),
  ];
}

class _GemRecordDetail {
  const _GemRecordDetail({required this.text, this.copyValue});

  final String text;
  final String? copyValue;
}

Future<void> _copyGemRecordText(BuildContext context, String text) async {
  final value = text.trim();
  if (value.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  showGenesisToast(context, 'Copied');
}

String _fallbackTitle(GemRecordItem record) {
  return switch (record.scene) {
    'purchase' => 'Gem purchase',
    'task' => 'Task reward',
    'world_tick' => 'World progress',
    'direct_message' => 'Direct message',
    _ => 'Gem record',
  };
}

String formatGemRecordTimestamp(int epochSeconds) {
  if (epochSeconds <= 0) return '';
  final time = DateTime.fromMillisecondsSinceEpoch(
    epochSeconds * 1000,
    isUtc: true,
  ).toLocal();
  return '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)} '
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatInteger(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
