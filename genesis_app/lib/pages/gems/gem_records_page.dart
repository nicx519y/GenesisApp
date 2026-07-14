import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../network/models/gem_records.dart';
import '../../ui/components/secend_tabs.dart';

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
      backgroundColor: Colors.white,
      appBar: GenesisBackAppBar(
        pageName: 'Gem Records',
        titleStyle: const TextStyle(color: Color(0xFF333333), fontSize: 22),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 13),
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
    if (state.isInitialLoading) return const _GemRecordsLoading();
    if (state.error != null && state.records.isEmpty) {
      return _GemRecordsMessage(
        title: 'Unable to load records.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_loadFirstPage(index: index)),
      );
    }
    if (state.records.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFFF2D4F),
        onRefresh: () => _loadFirstPage(index: index, refreshing: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 180), _GemRecordsEmpty()],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFFF2D4F),
      onRefresh: () => _loadFirstPage(index: index, refreshing: true),
      child: ListView.separated(
        controller: state.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: state.records.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, index) {
          if (index >= state.records.length - 1) return const SizedBox.shrink();
          return const Divider(height: 1, color: Color(0xFFF0F0F0));
        },
        itemBuilder: (context, itemIndex) {
          if (itemIndex >= state.records.length) {
            return const _GemRecordsMoreLoading();
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
    return SecendTabs(
      controller: controller,
      labels: labels,
      horizontalPadding: 8,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      verticalPadding: 0,
      expanded: true,
      onTap: onSelected,
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
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF4F6),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/custom-icons/svg/ruby.svg',
              width: 21,
              height: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  record.title.isEmpty ? _fallbackTitle(record) : record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _recordSubtitle(record),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 15 / 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 16,
                  height: 20 / 16,
                  fontWeight: FontWeight.w800,
                  color: isIncome
                      ? const Color(0xFFF42C47)
                      : const Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 3),
              SvgPicture.asset(
                'assets/custom-icons/svg/ruby.svg',
                width: 14,
                height: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GemRecordsLoading extends StatelessWidget {
  const _GemRecordsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFFFF2D4F),
        ),
      ),
    );
  }
}

class _GemRecordsMoreLoading extends StatelessWidget {
  const _GemRecordsMoreLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF2D4F),
          ),
        ),
      ),
    );
  }
}

class _GemRecordsEmpty extends StatelessWidget {
  const _GemRecordsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No gem records yet.',
        style: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
        ),
      ),
    );
  }
}

class _GemRecordsMessage extends StatelessWidget {
  const _GemRecordsMessage({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _recordSubtitle(GemRecordItem record) {
  final parts = [
    formatGemRecordTimestamp(record.createdAt),
    record.subtitle.trim(),
    if (record.expiresAt > 0) 'Expires ${_formatRecordDate(record.expiresAt)}',
  ].where((part) => part.isNotEmpty);
  return parts.join(' · ');
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

String formatGemRecordTimestamp(int epochSeconds, {DateTime? now}) {
  if (epochSeconds <= 0) return '';
  final time = DateTime.fromMillisecondsSinceEpoch(
    epochSeconds * 1000,
    isUtc: true,
  ).toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final date = DateTime(time.year, time.month, time.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final dayDifference = today.difference(date).inDays;
  final clock = '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
  if (dayDifference == 0) return 'Today $clock';
  if (dayDifference == 1) return 'Yesterday $clock';
  return '${_recordMonthNames[time.month - 1]} ${time.day}, ${time.year}';
}

const List<String> _recordMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatRecordDate(int epochSeconds) {
  if (epochSeconds <= 0) return '';
  final time = DateTime.fromMillisecondsSinceEpoch(
    epochSeconds * 1000,
    isUtc: true,
  ).toLocal();
  return '${_twoDigits(time.month)}/${_twoDigits(time.day)}';
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
