part of 'location_chat_page.dart';

class _LocationChatHistorySection {
  const _LocationChatHistorySection(this.id, this.locationId, this.messages);
  final String id;
  final String locationId;
  final List<ChatMessageVm> messages;
}

/// A view-only fold plan: canonical messages and reply state stay untouched.
/// Separate visits to the same place remain separate chronological sections.
class _LocationChatHistorySections {
  _LocationChatHistorySections(this.owner);
  final _LocationChatPanelState owner;
  final expanded = <String>{};
  Map<String, _LocationChatHistorySection> _byMessage = {};
  Map<String, _LocationChatHistorySection> _byId = {};
  Set<String> hidden = {};
  ({int generation, String localId})? reveal;

  void reset() {
    expanded.clear();
    _byMessage.clear();
    _byId.clear();
    hidden = {};
    reveal = null;
  }

  void project(List<ChatMessageVm> messages) {
    if (!owner._worldHistory.ready) return;
    final nextByMessage = <String, _LocationChatHistorySection>{};
    final nextById = <String, _LocationChatHistorySection>{};
    final nextHidden = <String>{};
    var start = 0;
    while (start < messages.length) {
      final first = messages[start];
      final room = owner._worldHistory.locationFor(first);
      var end = start + 1;
      while (end < messages.length &&
          !messages[end].isAiContentDisclaimer &&
          messages[end].localId != owner._entrySectionMessageId &&
          owner._worldHistory.locationFor(messages[end]) == room) {
        end++;
      }
      if (!first.isAiContentDisclaimer && room != owner.widget.locationId) {
        final rows = messages.sublist(start, end);
        // Earlier pagination can prepend rows to an existing visit. Keep its
        // identity/expansion by overlap instead of re-keying by array index.
        final retained = rows
            .map((m) => _byMessage[m.localId])
            .whereType<_LocationChatHistorySection>()
            .where((s) => s.locationId == room && !nextById.containsKey(s.id))
            .firstOrNull;
        final section = _LocationChatHistorySection(
          retained?.id ?? 'history-section:${rows.last.localId}',
          room,
          rows,
        );
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
    hidden = Set.unmodifiable(nextHidden);
    expanded.removeWhere((id) => !nextById.containsKey(id));
  }

  _LocationChatHistorySection? headerFor(ChatMessageVm message) {
    final section = _byMessage[message.localId];
    return section?.messages.first.localId == message.localId ? section : null;
  }

  Map<String, String> get expandedHeaders => {
    for (final section in _byId.values)
      if (expanded.contains(section.id))
        for (final message in section.messages)
          message.localId: section.messages.first.localId,
  };

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
    final section = _byMessage[localId];
    // A folded path is navigation, not a location being read.
    owner._worldHistory.reading(
      localId,
      useJoinedLocation:
          expanded.isEmpty ||
          (section != null && !expanded.contains(section.id)),
    );
  }

  void toggle(_LocationChatHistorySection section) {
    // Cached header widgets can outlive a pagination update to this segment.
    final current = _byId[section.id];
    if (current == null) return;
    final generation = owner._scrollCoordinator.beginHistoryNavigation();
    owner._setLocationChatState(() {
      final opening = expanded.add(section.id);
      if (!opening) expanded.remove(section.id);
      reveal = (
        generation: generation,
        localId: current.messages.first.localId,
      );
    });
  }

  Widget button(_LocationChatHistorySection section, {Key? key}) {
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
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
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
