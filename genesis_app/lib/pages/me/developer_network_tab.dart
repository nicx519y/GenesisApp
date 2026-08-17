part of 'developer_page.dart';

enum _DeveloperNetworkFilter { all, success, error, pending }

class _DeveloperNetworkTab extends StatefulWidget {
  const _DeveloperNetworkTab({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  State<_DeveloperNetworkTab> createState() => _DeveloperNetworkTabState();
}

class _DeveloperNetworkTabState extends State<_DeveloperNetworkTab> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedRecords = <String>{};
  final Set<String> _expandedSections = <String>{};
  var _filter = _DeveloperNetworkFilter.all;
  var _savingEnabled = false;

  @override
  void initState() {
    super.initState();
    networkCaptureController.addListener(_handleCaptureChanged);
  }

  @override
  void dispose() {
    networkCaptureController.removeListener(_handleCaptureChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleCaptureChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setCaptureEnabled(bool value) async {
    if (_savingEnabled) return;
    setState(() => _savingEnabled = true);
    try {
      await networkCaptureController.setEnabled(value);
    } catch (error) {
      if (mounted) showGenesisToast(context, 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _savingEnabled = false);
    }
  }

  void _clear() {
    networkCaptureController.clear();
    _expandedRecords.clear();
    _expandedSections.clear();
    showGenesisToast(context, 'Network records cleared');
  }

  List<NetworkCaptureRecord> _visibleRecords() {
    final query = _searchController.text.trim().toLowerCase();
    return networkCaptureController.records
        .where((record) {
          if (!_matchesFilter(record)) return false;
          if (query.isEmpty) return true;
          final searchable = <String>[
            record.method,
            record.uri.host,
            record.uri.path,
            record.uri.toString(),
            if (record.statusCode != null) '${record.statusCode}',
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  bool _matchesFilter(NetworkCaptureRecord record) {
    return switch (_filter) {
      _DeveloperNetworkFilter.all => true,
      _DeveloperNetworkFilter.success =>
        record.status == NetworkCaptureStatus.success,
      _DeveloperNetworkFilter.error =>
        record.status == NetworkCaptureStatus.error,
      _DeveloperNetworkFilter.pending =>
        record.status == NetworkCaptureStatus.pending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = networkCaptureController;
    final records = _visibleRecords();
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
                title: 'Capture network',
                totalCount: controller.records.length,
                countKey: const ValueKey<String>('developer-network-count'),
                clearKey: const ValueKey<String>('developer-network-clear'),
                switchKey: const ValueKey<String>(
                  'developer-network-capture-switch',
                ),
                enabled: controller.enabled,
                enabledControl: controller.available && !_savingEnabled,
                onClear: controller.records.isEmpty ? null : _clear,
                onEnabledChanged: _setCaptureEnabled,
              ),
              const SizedBox(height: 8),
              GenesisSearchField(
                key: const ValueKey<String>('developer-network-search'),
                controller: _searchController,
                hintText: 'Search method, host, path, status',
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in _DeveloperNetworkFilter.values) ...[
                      _DeveloperNetworkFilterChip(
                        filter: filter,
                        selected: filter == _filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                      if (filter != _DeveloperNetworkFilter.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: records.isEmpty
              ? _buildEmptyState(controller)
              : ListView.separated(
                  key: const PageStorageKey<String>(
                    'developer-network-tab-scroll',
                  ),
                  padding: EdgeInsets.fromLTRB(
                    widget.horizontalPadding,
                    0,
                    widget.horizontalPadding,
                    20,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _DeveloperNetworkRecordCard(
                      key: ValueKey<String>('network-record-${record.id}'),
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
        ),
      ],
    );
  }

  Widget _buildEmptyState(NetworkCaptureController controller) {
    final hasFilter =
        _searchController.text.trim().isNotEmpty ||
        _filter != _DeveloperNetworkFilter.all;
    final text = !controller.available
        ? 'Network capture is available in debug builds only.'
        : hasFilter && controller.records.isNotEmpty
        ? 'No matching network requests.'
        : !controller.enabled
        ? 'Turn on Capture network to record new network requests.'
        : 'No requests yet. Use another page to generate network traffic.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF888888),
          ),
        ),
      ),
    );
  }
}

class _DeveloperNetworkFilterChip extends StatelessWidget {
  const _DeveloperNetworkFilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _DeveloperNetworkFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _DeveloperNetworkFilter.all => 'All',
      _DeveloperNetworkFilter.success => 'Success',
      _DeveloperNetworkFilter.error => 'Error',
      _DeveloperNetworkFilter.pending => 'Pending',
    };
    return _DeveloperCaptureFilterChip(
      key: ValueKey<String>('developer-network-filter-${filter.name}'),
      label: label,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _DeveloperNetworkRecordCard extends StatelessWidget {
  const _DeveloperNetworkRecordCard({
    super.key,
    required this.record,
    required this.expanded,
    required this.isSectionExpanded,
    required this.onToggle,
    required this.onToggleSection,
  });

  final NetworkCaptureRecord record;
  final bool expanded;
  final bool Function(String section) isSectionExpanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onToggleSection;

  @override
  Widget build(BuildContext context) {
    final isError = record.status == NetworkCaptureStatus.error;
    final isGet = record.method == 'GET';
    final requestText = _networkRequestText(record);
    final responseText = _networkResponseText(record);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E2E5)),
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
                      _DeveloperNetworkStatusDot(status: record.status),
                      const SizedBox(width: 8),
                      Text(
                        record.method,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record.uri.path.isEmpty ? '/' : record.uri.path,
                          key: ValueKey<String>(
                            'developer-network-path-${record.id}',
                          ),
                          maxLines: isGet ? null : 1,
                          overflow: isGet ? null : TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: const Color(0xFF666666),
                      ),
                    ],
                  ),
                  if (isGet && record.uri.query.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.only(left: 50),
                      child: Text(
                        '?${record.uri.query}',
                        key: ValueKey<String>(
                          'developer-network-query-${record.id}',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _networkRecordStatusText(record),
                          style: TextStyle(
                            fontSize: 11,
                            color: _networkRecordStatusColor(record.status),
                          ),
                        ),
                      ),
                      Text(
                        _networkDurationText(record.duration),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                        ),
                      ),
                      if (record.responseBody case final responseBody?) ...[
                        const SizedBox(width: 10),
                        Text(
                          _networkByteSizeText(responseBody.byteCount),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Text(
                        _networkTimeText(record.startedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E2E5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  _DeveloperCaptureDetailSection(
                    title: 'Overview',
                    expanded: isSectionExpanded('overview'),
                    onToggle: () => onToggleSection('overview'),
                    content: _networkOverviewText(record),
                    contentKey: ValueKey<String>(
                      'developer-network-overview-content-${record.id}',
                    ),
                  ),
                  _DeveloperCaptureDetailSection(
                    title: 'Request',
                    expanded: isSectionExpanded('request'),
                    onToggle: () => onToggleSection('request'),
                    content: requestText,
                    contentKey: ValueKey<String>(
                      'developer-network-request-content-${record.id}',
                    ),
                    copyLabel: 'Request copied',
                    copyKey: const ValueKey<String>(
                      'developer-network-copy-request',
                    ),
                    selectable: true,
                  ),
                  _DeveloperCaptureDetailSection(
                    title: isError ? 'Error' : 'Response',
                    expanded: isSectionExpanded('response'),
                    onToggle: () => onToggleSection('response'),
                    content: responseText,
                    contentKey: ValueKey<String>(
                      'developer-network-response-content-${record.id}',
                    ),
                    copyLabel: isError ? 'Error copied' : 'Response copied',
                    copyKey: ValueKey<String>(
                      'developer-network-copy-${isError ? 'error' : 'response'}',
                    ),
                    selectable: true,
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

class _DeveloperNetworkStatusDot extends StatelessWidget {
  const _DeveloperNetworkStatusDot({required this.status});

  final NetworkCaptureStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == NetworkCaptureStatus.pending) {
      return const SizedBox.square(
        dimension: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _networkRecordStatusColor(status),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 10),
    );
  }
}

Color _networkRecordStatusColor(NetworkCaptureStatus status) {
  return switch (status) {
    NetworkCaptureStatus.pending => const Color(0xFFF0A000),
    NetworkCaptureStatus.success => const Color(0xFF00A67A),
    NetworkCaptureStatus.error => const Color(0xFFFF2442),
  };
}

String _networkRecordStatusText(NetworkCaptureRecord record) {
  if (record.status == NetworkCaptureStatus.pending) return 'Pending';
  if (record.errorMessage != null) return 'Error · ${record.errorType}';
  final statusCode = record.statusCode;
  return statusCode == null ? record.status.name : 'HTTP $statusCode';
}

String _networkDurationText(Duration? duration) {
  if (duration == null) return '—';
  return '${duration.inMilliseconds} ms';
}

String _networkTimeText(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  String three(int number) => number.toString().padLeft(3, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.'
      '${three(value.millisecond)}';
}

String _networkOverviewText(NetworkCaptureRecord record) {
  return <String>[
    '${record.method} ${record.uri}',
    'Status: ${_networkRecordStatusText(record)}',
    'Started: ${record.startedAt.toIso8601String()}',
    if (record.finishedAt != null)
      'Finished: ${record.finishedAt!.toIso8601String()}',
    'Duration: ${_networkDurationText(record.duration)}',
    'Protocol: ${record.httpProtocolVersion ?? 'unknown'}',
    'Request size: ${_networkByteSizeText(record.requestBody?.byteCount ?? 0)}',
    'Response size: ${_networkByteSizeText(record.responseBody?.byteCount ?? 0)}',
  ].join('\n');
}

String _networkByteSizeText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const kilobyte = 1024;
  const megabyte = 1024 * kilobyte;
  if (bytes < megabyte) return '${_compactSize(bytes / kilobyte)} KB';
  return '${_compactSize(bytes / megabyte)} MB';
}

String _compactSize(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

String _networkRequestText(NetworkCaptureRecord record) {
  return _prettyNetworkJson(<String, Object?>{
    'method': record.method,
    'url': record.uri.toString(),
    'query': record.requestQuery,
    'headers': record.requestHeaders,
    'body': _decodedNetworkBody(record.requestBody),
  });
}

String _networkResponseText(NetworkCaptureRecord record) {
  if (record.errorMessage != null) {
    return _prettyNetworkJson(<String, Object?>{
      'type': record.errorType,
      'message': record.errorMessage,
    });
  }
  if (record.status == NetworkCaptureStatus.pending) return 'Pending';
  return _prettyNetworkJson(<String, Object?>{
    'status': record.statusCode,
    'headers': record.responseHeaders,
    'body': _decodedNetworkBody(record.responseBody),
  });
}

Object? _decodedNetworkBody(NetworkCaptureBody? body) {
  if (body == null || body.text.isEmpty) return null;
  try {
    return jsonDecode(body.text);
  } catch (_) {
    return body.text;
  }
}

String _prettyNetworkJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}
