part of 'developer_page.dart';

class _DeveloperWebSocketTab extends StatefulWidget {
  const _DeveloperWebSocketTab({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  State<_DeveloperWebSocketTab> createState() => _DeveloperWebSocketTabState();
}

class _DeveloperWebSocketTabState extends State<_DeveloperWebSocketTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedRecords = <String>{};
  final Set<String> _expandedSections = <String>{};
  List<WebSocketCaptureRecord> _displayedRecords =
      const <WebSocketCaptureRecord>[];
  bool _savingEnabled = false;
  bool _refreshForSettings = false;
  int _newFrameCount = 0;

  @override
  void initState() {
    super.initState();
    _displayedRecords = webSocketCaptureController.filteredRecords();
    webSocketCaptureController.addListener(_handleCaptureChanged);
  }

  @override
  void dispose() {
    webSocketCaptureController.removeListener(_handleCaptureChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCaptureChanged() {
    if (!mounted) return;
    final latest = _filteredRecords();
    final nearTop =
        !_scrollController.hasClients || _scrollController.offset <= 24;
    final recordsRemoved = latest.length < _displayedRecords.length;
    if (_refreshForSettings || nearTop || recordsRemoved) {
      setState(() {
        _displayedRecords = latest;
        _newFrameCount = 0;
      });
      return;
    }
    final displayedIds = _displayedRecords.map((record) => record.id).toSet();
    final newCount = latest
        .where((record) => !displayedIds.contains(record.id))
        .length;
    setState(() => _newFrameCount = newCount);
  }

  List<WebSocketCaptureRecord> _filteredRecords() {
    return webSocketCaptureController.filteredRecords(
      query: _searchController.text,
    );
  }

  void _refreshDisplayed({bool jumpToTop = false}) {
    setState(() {
      _displayedRecords = _filteredRecords();
      _newFrameCount = 0;
    });
    if (jumpToTop && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _setCaptureEnabled(bool value) async {
    if (_savingEnabled) return;
    setState(() => _savingEnabled = true);
    try {
      await webSocketCaptureController.setEnabled(value);
    } catch (error) {
      if (mounted) showGenesisToast(context, 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _savingEnabled = false);
    }
  }

  Future<void> _setDirection(WebSocketCaptureDirection? direction) async {
    _refreshForSettings = true;
    try {
      await webSocketCaptureController.setDirectionFilter(direction);
    } catch (error) {
      if (mounted) showGenesisToast(context, 'Save failed: $error');
    } finally {
      _refreshForSettings = false;
      if (mounted) _refreshDisplayed(jumpToTop: true);
    }
  }

  void _clear() {
    webSocketCaptureController.clear();
    _expandedRecords.clear();
    _expandedSections.clear();
    _refreshDisplayed();
    showGenesisToast(context, 'WebSocket records cleared');
  }

  Future<void> _openTypeFilter() async {
    final result = await showGenesisModalBottomSheet<_WebSocketTypeFilterValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.78,
        child: _DeveloperWebSocketTypeFilterSheet(
          counts: webSocketCaptureController.typeCounts(),
          initialMode: webSocketCaptureController.filterMode,
          initialSelectedTypes: webSocketCaptureController.selectedTypes,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _refreshForSettings = true;
    try {
      await webSocketCaptureController.setTypeFilter(
        mode: result.mode,
        selectedTypes: result.selectedTypes,
      );
    } catch (error) {
      if (mounted) showGenesisToast(context, 'Save failed: $error');
    } finally {
      _refreshForSettings = false;
      if (mounted) _refreshDisplayed(jumpToTop: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = webSocketCaptureController;
    final currentVisibleCount = _filteredRecords().length;
    final typeFilterCount = controller.selectedTypes.length;
    final typeLabel = typeFilterCount == 0
        ? 'Type: All'
        : 'Type: ${controller.filterMode == WebSocketCaptureFilterMode.hide ? 'Hide' : 'Only show'} $typeFilterCount';
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            8,
            widget.horizontalPadding,
            0,
          ),
          child: Column(
            children: [
              _DeveloperCaptureHeader(
                title: 'Capture websocket',
                totalCount: controller.records.length,
                visibleCount: currentVisibleCount,
                countKey: const ValueKey<String>('developer-websocket-count'),
                clearKey: const ValueKey<String>('developer-websocket-clear'),
                switchKey: const ValueKey<String>(
                  'developer-websocket-capture-switch',
                ),
                enabled: controller.enabled,
                enabledControl: controller.available && !_savingEnabled,
                onClear: controller.records.isEmpty ? null : _clear,
                onEnabledChanged: _setCaptureEnabled,
              ),
              const SizedBox(height: 8),
              GenesisSearchField(
                key: const ValueKey<String>('developer-websocket-search'),
                controller: _searchController,
                hintText: 'Search type, stream_type, ID or content',
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onChanged: (_) => _refreshDisplayed(jumpToTop: true),
                onClear: () {
                  _searchController.clear();
                  _refreshDisplayed(jumpToTop: true);
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GenesisFilterChip(
                      key: const ValueKey<String>(
                        'developer-websocket-direction-all',
                      ),
                      label: 'All',
                      selected: controller.directionFilter == null,
                      onPressed: () => _setDirection(null),
                    ),
                    const SizedBox(width: 8),
                    GenesisFilterChip(
                      key: const ValueKey<String>(
                        'developer-websocket-direction-receive',
                      ),
                      label: 'Receive',
                      selected:
                          controller.directionFilter ==
                          WebSocketCaptureDirection.receive,
                      onPressed: () =>
                          _setDirection(WebSocketCaptureDirection.receive),
                    ),
                    const SizedBox(width: 8),
                    GenesisFilterChip(
                      key: const ValueKey<String>(
                        'developer-websocket-direction-send',
                      ),
                      label: 'Send',
                      selected:
                          controller.directionFilter ==
                          WebSocketCaptureDirection.send,
                      onPressed: () =>
                          _setDirection(WebSocketCaptureDirection.send),
                    ),
                    const SizedBox(width: 8),
                    GenesisFilterChip(
                      key: const ValueKey<String>(
                        'developer-websocket-type-filter',
                      ),
                      label: typeLabel,
                      selected: typeFilterCount > 0,
                      onPressed: _openTypeFilter,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (_displayedRecords.isEmpty)
                _buildEmptyState(controller)
              else
                ListView.separated(
                  key: const PageStorageKey<String>(
                    'developer-websocket-tab-scroll',
                  ),
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    widget.horizontalPadding,
                    0,
                    widget.horizontalPadding,
                    20,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _displayedRecords.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = _displayedRecords[index];
                    return _DeveloperWebSocketRecordCard(
                      key: ValueKey<String>('websocket-record-${record.id}'),
                      record: record,
                      expanded: _expandedRecords.contains(record.id),
                      isSectionExpanded: (section) =>
                          _expandedSections.contains('${record.id}|$section'),
                      onToggle: () {
                        setState(() {
                          if (!_expandedRecords.add(record.id)) {
                            _expandedRecords.remove(record.id);
                          }
                        });
                      },
                      onToggleSection: (section) {
                        final key = '${record.id}|$section';
                        setState(() {
                          if (!_expandedSections.add(key)) {
                            _expandedSections.remove(key);
                          }
                        });
                      },
                    );
                  },
                ),
              if (_newFrameCount > 0)
                SafeArea(
                  minimum: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    key: const ValueKey<String>(
                      'developer-websocket-new-frames',
                    ),
                    onTap: () => _refreshDisplayed(jumpToTop: true),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.genesisColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: context.genesisColors.shadow,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        child: Text(
                          '$_newFrameCount new frames',
                          style: TextStyle(
                            color: context.genesisColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(WebSocketCaptureController controller) {
    final hasFilter =
        _searchController.text.trim().isNotEmpty ||
        controller.directionFilter != null ||
        controller.selectedTypes.isNotEmpty;
    final text = !controller.available
        ? 'WebSocket capture is available in debug builds only.'
        : hasFilter && controller.records.isNotEmpty
        ? 'No matching WebSocket frames.'
        : !controller.enabled
        ? 'Turn on Capture websocket to record new text frames.'
        : 'No frames yet. Open a chat to generate WebSocket traffic.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: context.genesisColors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _DeveloperWebSocketRecordCard extends StatelessWidget {
  const _DeveloperWebSocketRecordCard({
    super.key,
    required this.record,
    required this.expanded,
    required this.isSectionExpanded,
    required this.onToggle,
    required this.onToggleSection,
  });

  final WebSocketCaptureRecord record;
  final bool expanded;
  final bool Function(String section) isSectionExpanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onToggleSection;

  @override
  Widget build(BuildContext context) {
    final directionLabel = record.direction == WebSocketCaptureDirection.receive
        ? 'RECV'
        : 'SEND';
    final typeLabel = record.typeKey;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.genesisColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.genesisColors.borderNeutral),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              record.direction ==
                                  WebSocketCaptureDirection.receive
                              ? const Color(0xFF00A67A)
                              : const Color(0xFF3478F6),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 10),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        directionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (record.streamType.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.genesisColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            record.streamType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.genesisColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: context.genesisColors.iconMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _webSocketRecordSummary(record),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.genesisColors.textSubtle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _networkTimeText(record.recordedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.genesisColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: context.genesisColors.borderNeutral),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  _DeveloperCaptureDetailSection(
                    title: 'Overview',
                    expanded: isSectionExpanded('overview'),
                    onToggle: () => onToggleSection('overview'),
                    content: _webSocketOverviewText(record),
                    contentKey: ValueKey<String>(
                      'developer-websocket-overview-content-${record.id}',
                    ),
                  ),
                  _DeveloperCaptureDetailSection(
                    title: 'Message',
                    expanded: isSectionExpanded('message'),
                    onToggle: () => onToggleSection('message'),
                    content: _prettyWebSocketMessage(record),
                    contentKey: ValueKey<String>(
                      'developer-websocket-message-content-${record.id}',
                    ),
                    copyLabel: 'Message copied',
                    copyKey: const ValueKey<String>(
                      'developer-websocket-copy-message',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebSocketTypeFilterValue {
  const _WebSocketTypeFilterValue({
    required this.mode,
    required this.selectedTypes,
  });

  final WebSocketCaptureFilterMode mode;
  final Set<String> selectedTypes;
}

class _DeveloperWebSocketTypeFilterSheet extends StatefulWidget {
  const _DeveloperWebSocketTypeFilterSheet({
    required this.counts,
    required this.initialMode,
    required this.initialSelectedTypes,
  });

  final Map<String, int> counts;
  final WebSocketCaptureFilterMode initialMode;
  final Set<String> initialSelectedTypes;

  @override
  State<_DeveloperWebSocketTypeFilterSheet> createState() =>
      _DeveloperWebSocketTypeFilterSheetState();
}

class _DeveloperWebSocketTypeFilterSheetState
    extends State<_DeveloperWebSocketTypeFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  late WebSocketCaptureFilterMode _mode;
  late Set<String> _selectedTypes;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _selectedTypes = Set<String>.of(widget.initialSelectedTypes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _visibleTypes() {
    final query = _searchController.text.trim().toLowerCase();
    final missingSelected =
        _selectedTypes
            .where((type) => !widget.counts.containsKey(type))
            .toList()
          ..sort();
    final observed = widget.counts.keys.toList()
      ..sort((left, right) {
        final countOrder = widget.counts[right]!.compareTo(
          widget.counts[left]!,
        );
        return countOrder != 0 ? countOrder : left.compareTo(right);
      });
    return <String>[...missingSelected, ...observed]
        .where((type) => query.isEmpty || type.contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final types = _visibleTypes();
    return GenesisBottomSheetPanel(
      title: 'Filter by type',
      height: double.infinity,
      titleBottomSpacing: 12,
      trailing: GestureDetector(
        key: const ValueKey<String>('developer-websocket-type-reset'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _mode = WebSocketCaptureFilterMode.hide;
            _selectedTypes.clear();
            _searchController.clear();
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Reset',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.genesisColors.primary,
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GenesisFilterChip(
                  key: const ValueKey<String>(
                    'developer-websocket-type-mode-only-show',
                  ),
                  label: 'Only show',
                  selected: _mode == WebSocketCaptureFilterMode.onlyShow,
                  fullWidth: true,
                  onPressed: () => setState(
                    () => _mode = WebSocketCaptureFilterMode.onlyShow,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GenesisFilterChip(
                  key: const ValueKey<String>(
                    'developer-websocket-type-mode-hide',
                  ),
                  label: 'Hide',
                  selected: _mode == WebSocketCaptureFilterMode.hide,
                  fullWidth: true,
                  onPressed: () =>
                      setState(() => _mode = WebSocketCaptureFilterMode.hide),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GenesisSearchField(
            key: const ValueKey<String>('developer-websocket-type-search'),
            controller: _searchController,
            hintText: 'Search type',
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onChanged: (_) => setState(() {}),
            onClear: () {
              _searchController.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: types.isEmpty
                ? Center(
                    child: Text(
                      'No message types yet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.genesisColors.textFaint,
                      ),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: types.length,
                    itemBuilder: (context, index) {
                      final type = types[index];
                      return CheckboxListTile(
                        key: ValueKey<String>(
                          'developer-websocket-type-option-$type',
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selectedTypes.contains(type),
                        onChanged: (selected) {
                          setState(() {
                            if (selected ?? false) {
                              _selectedTypes.add(type);
                            } else {
                              _selectedTypes.remove(type);
                            }
                          });
                        },
                        title: Text(type, style: const TextStyle(fontSize: 13)),
                        secondary: Text(
                          '${widget.counts[type] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.genesisColors.textSubtle,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GenesisButton(
                  key: const ValueKey<String>(
                    'developer-websocket-type-cancel',
                  ),
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  variant: GenesisButtonVariant.secondary,
                  size: GenesisButtonSize.compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GenesisButton(
                  key: const ValueKey<String>('developer-websocket-type-apply'),
                  label: 'Apply',
                  onPressed: () => Navigator.of(context).pop(
                    _WebSocketTypeFilterValue(
                      mode: _mode,
                      selectedTypes: Set<String>.of(_selectedTypes),
                    ),
                  ),
                  size: GenesisButtonSize.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _webSocketRecordSummary(WebSocketCaptureRecord record) {
  final ids = <String>[
    if (record.locationId.isNotEmpty) record.locationId,
    if (record.globalMessageId.isNotEmpty)
      'msg ${record.globalMessageId}'
    else if (record.locationMessageId.isNotEmpty)
      'msg ${record.locationMessageId}'
    else if (record.messageId.isNotEmpty)
      'msg ${record.messageId}',
    if (record.clientMessageId.isNotEmpty) record.clientMessageId,
    if (record.worldId.isNotEmpty) record.worldId,
  ];
  if (ids.isEmpty) return '${record.byteCount} bytes · ${record.connectionId}';
  return ids.take(2).join(' · ');
}

String _webSocketOverviewText(WebSocketCaptureRecord record) {
  return <String>[
    'Direction: ${record.direction.name.toUpperCase()}',
    'Type: ${record.typeKey}',
    'Stream type: ${record.streamType.isEmpty ? '—' : record.streamType}',
    'Connection: ${record.connectionId}',
    'Sequence: ${record.sequence}',
    'URI: ${record.uri}',
    'Time: ${record.recordedAt.toIso8601String()}',
    'Bytes: ${record.byteCount}',
    'JSON: ${record.isJson}',
    'Omitted: ${record.omitted}',
    if (record.worldId.isNotEmpty) 'World ID: ${record.worldId}',
    if (record.locationId.isNotEmpty) 'Location ID: ${record.locationId}',
    if (record.globalMessageId.isNotEmpty)
      'Global message ID: ${record.globalMessageId}',
    if (record.locationMessageId.isNotEmpty)
      'Location message ID: ${record.locationMessageId}',
    if (record.messageId.isNotEmpty) 'Message ID: ${record.messageId}',
    if (record.clientMessageId.isNotEmpty)
      'Client message ID: ${record.clientMessageId}',
  ].join('\n');
}

String _prettyWebSocketMessage(WebSocketCaptureRecord record) {
  if (!record.isJson) return record.bodyText;
  try {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(record.bodyText));
  } catch (_) {
    return record.bodyText;
  }
}
