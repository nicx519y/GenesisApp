part of '../chat/location_chat_page.dart';

class _WorldHistoryFold {
  const _WorldHistoryFold(this.id, this.locationId, this.messages);
  final String id;
  final String locationId;
  final List<ChatMessageVm> messages;
}

/// A view-only fold plan: canonical messages and reply state stay untouched.
/// Separate visits to the same place remain separate chronological sections.
class _WorldHistoryFolds {
  _WorldHistoryFolds(this.owner);
  final _WorldChatHistorySectionState owner;
  final expanded = <String>{};
  Map<String, _WorldHistoryFold> _byMessage = {};
  Map<String, _WorldHistoryFold> _byId = {};
  Map<String, _WorldHistoryFold> _latestByLocation = {};
  Set<String> hidden = {};
  final _collapsedMessages = <String>{};
  List<ChatMessageVm>? _lastMessages;
  Map<String, String> _expandedHeaders = {};
  ({int generation, String localId})? reveal;

  void reset() {
    expanded.clear();
    _collapsedMessages.clear();
    _lastMessages = null;
    _expandedHeaders = {};
    _byMessage.clear();
    _byId.clear();
    _latestByLocation.clear();
    hidden = {};
    reveal = null;
  }

  void project(List<ChatMessageVm> messages) {
    if (!owner._worldHistory.ready || identical(messages, _lastMessages)) {
      return;
    }
    _lastMessages = messages;
    final nextByMessage = <String, _WorldHistoryFold>{};
    final nextById = <String, _WorldHistoryFold>{};
    final nextHidden = <String>{};
    var start = 0;
    while (start < messages.length) {
      final first = messages[start];
      final room = owner._worldHistory.locationFor(first);
      var end = start + 1;
      while (end < messages.length &&
          !messages[end].isAiContentDisclaimer &&
          owner._worldHistory.locationFor(messages[end]) == room) {
        end++;
      }
      if (!first.isAiContentDisclaimer && room.isNotEmpty) {
        final rows = messages.sublist(start, end);
        // Earlier pagination can prepend rows to an existing visit. Keep its
        // identity/expansion by overlap instead of re-keying by array index.
        final retained = rows
            .map((m) => _byMessage[m.localId])
            .whereType<_WorldHistoryFold>()
            .where((s) => s.locationId == room && !nextById.containsKey(s.id))
            .firstOrNull;
        final section = _WorldHistoryFold(
          retained?.id ?? 'history-section:${rows.last.localId}',
          room,
          rows,
        );
        // Open newly discovered visits, including older pages. Rebuilds keep
        // the user's explicit collapse choice for an existing visit.
        if (retained == null &&
            !_byId.containsKey(section.id) &&
            !rows.any((m) => _collapsedMessages.contains(m.localId))) {
          expanded.add(section.id);
        }
        nextById[section.id] = section;
        for (final row in rows) {
          nextByMessage[row.localId] = section;
        }
        if (!expanded.contains(section.id)) {
          nextHidden.addAll(rows.skip(1).map((m) => m.localId));
        }
      }
      start = end;
    }
    _byMessage = nextByMessage;
    _byId = nextById;
    _latestByLocation = {
      for (final section in nextById.values) section.locationId: section,
    };
    hidden = Set.unmodifiable(nextHidden);
    expanded.removeWhere((id) => !nextById.containsKey(id));
    _updateHeaders();
  }

  _WorldHistoryFold? headerFor(ChatMessageVm message) {
    final section = _byMessage[message.localId];
    return section?.messages.first.localId == message.localId ? section : null;
  }

  String? continueLocationFor(ChatMessageVm message) {
    final section = _byMessage[message.localId];
    if (section == null ||
        !expanded.contains(section.id) ||
        !owner._worldHistory.projection.metadata.locations.containsKey(
          section.locationId,
        ) ||
        _latestByLocation[section.locationId]?.id != section.id ||
        section.messages.last.localId != message.localId) {
      return null;
    }
    return section.locationId;
  }

  Map<String, String> get expandedHeaders => _expandedHeaders;
  void _updateHeaders() {
    _expandedHeaders = {
      for (final section in _byId.values)
        if (expanded.contains(section.id))
          for (final message in section.messages)
            message.localId: section.messages.first.localId,
    };
  }

  Widget pinnedHeader(String headerId) {
    final section = _byMessage[headerId];
    if (section == null || !expanded.contains(section.id)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kLocationChatStyle.messageListPadding.left,
      ),
      child: owner._locationPathDivider(
        owner._locationPathParts(section.locationId),
        trailing: button(section),
      ),
    );
  }

  void reading(String? localId) {
    // Even a collapsed header pins its page while the reader crosses it.
    owner._worldHistory.reading(localId);
  }

  void toggle(_WorldHistoryFold section) {
    // Cached header widgets can outlive a pagination update to this segment.
    final current = _byId[section.id];
    if (current == null) return;
    final generation = owner._scrollCoordinator.beginHistoryNavigation();
    owner._update(() {
      final opening = expanded.add(section.id);
      if (!opening) expanded.remove(section.id);
      final ids = current.messages.map((m) => m.localId);
      if (opening) {
        _collapsedMessages.removeAll(ids);
      } else {
        _collapsedMessages.addAll(ids);
      }
      hidden = Set.of(hidden);
      if (opening) {
        hidden.removeAll(ids);
      } else {
        hidden.addAll(ids.skip(1));
      }
      _updateHeaders();
      reveal = (
        generation: generation,
        localId: current.messages.first.localId,
      );
    });
    owner._worldHistory.reading(current.messages.first.localId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!owner.mounted || reveal?.generation != generation) return;
      // Shared coordinator retains the navigation anchor through layout.
      reveal = null;
    });
  }

  Widget button(_WorldHistoryFold section, {Key? key}) {
    final isExpanded = expanded.contains(section.id);
    return Semantics(
      key: key,
      button: true,
      expanded: isExpanded,
      label: owner._locationPathParts(section.locationId).join(' > '),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => toggle(section),
          child: Container(
            constraints: const BoxConstraints(minHeight: 24),
            padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpanded
                      ? owner.context.l10n.chatHistoryCollapse
                      : owner.context.l10n.chatHistoryExpand,
                  style: kLocationChatStyle.bubbleTextStyle.copyWith(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: GenesisColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: GenesisColors.darkTextPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
