import 'dart:collection';
import '../../../network/models/world_history.dart';

// Only structural metadata survives body eviction.
class _Entry {
  _Entry(WorldHistoryMessage message)
    : id = message.id,
      type = message.type,
      version = message.minAppVersion,
      locations = message.locationRefs.isEmpty
          ? const ['']
          : message.locationRefs.toSet().toList().reversed.toList();
  final String id, type;
  final int version;
  final List<String> locations;
}

class HistoryLocationSection {
  HistoryLocationSection._(this.location);
  final String location;
  final messageIds = <String>[];
  bool hasUser = false;
}

/// Tick refs are parallel memberships, not successive location visits. Keep
/// each matching section open across a shared Tick; ordinary refs still mark
/// successive visits. Both admission and display use this same fold plan.
class HistoryLocationSections {
  HistoryLocationSections(Iterable<WorldHistoryMessage> newestFirst)
    : this._(newestFirst.map(_Entry.new));

  HistoryLocationSections._(Iterable<_Entry> entries) {
    var active = <String, int>{};
    void append(_Entry entry, Iterable<String> locations) {
      final next = <String, int>{};
      for (final location in locations) {
        final run = active[location] ?? sections.length;
        if (run == sections.length) {
          sections.add(HistoryLocationSection._(location));
        }
        next[location] = run;
        sections[run].messageIds.add(entry.id);
        if (entry.type == 'user') sections[run].hasUser = true;
        if (entry.type == 'tick') _ticks[(entry.id, location)] = run;
      }
      if (_first.isEmpty) _first = Map.of(next);
      active = next;
    }

    for (final entry in entries) {
      if (entry.type == 'tick') {
        append(entry, entry.locations);
      } else {
        for (final location in entry.locations) {
          append(entry, [location]);
        }
      }
    }
    _last = active;
  }

  final sections = <HistoryLocationSection>[];
  final _ticks = <(String, String), int>{};
  Map<String, int> _first = {}, _last = {};
}

class _Page {
  _Page(this.entries);
  final List<_Entry> entries;
  late HistoryLocationSections plan;
}

/// Only sections touching the range edges can continue across another page.
/// Shared Ticks can leave several locations open at either edge.
class _Summary {
  const _Summary(this.first, this.last, this.through);
  final Map<String, bool> first, last;
  final Set<String> through;

  static _Summary? from(HistoryLocationSections plan) => plan.sections.isEmpty
      ? null
      : _Summary(
          {
            for (final e in plan._first.entries)
              e.key: plan.sections[e.value].hasUser,
          },
          {
            for (final e in plan._last.entries)
              e.key: plan.sections[e.value].hasUser,
          },
          {
            for (final e in plan._first.entries)
              if (plan._last[e.key] == e.value) e.key,
          },
        );

  static _Summary? join(_Summary? a, _Summary? b) {
    if (a == null) return b;
    if (b == null) return a;
    return _Summary(
      {
        for (final e in a.first.entries)
          e.key: e.value || a.through.contains(e.key) && b.first[e.key] == true,
      },
      {
        for (final e in b.last.entries)
          e.key: e.value || b.through.contains(e.key) && a.last[e.key] == true,
      },
      a.through.intersection(b.through),
    );
  }
}

class _Node {
  _Node? left, right;
  _Summary? summary;
}

/// Replaceable page summaries. A sparse range tree makes cross-page section
/// queries and page updates bounded by tree depth, not visited history length.
class HistorySectionParticipation {
  HistorySectionParticipation({required this.appVersion});
  final int appVersion;
  final _pages = <_Page>[];
  final _owners = <String, SplayTreeSet<int>>{};
  _Node? _root;
  static const _capacity = 1 << 30;
  int examinedMessages = 0;
  int summaryNodeVisits = 0;

  void appendOlder(Iterable<WorldHistoryMessage> messages) =>
      replacePage(_pages.length, messages);

  void replacePage(int index, Iterable<WorldHistoryMessage> messages) {
    assert(index >= 0 && index <= _pages.length);
    final entries = messages.map(_Entry.new).toList();
    final ids = <String>{
      if (index < _pages.length) ..._pages[index].entries.map((e) => e.id),
      ...entries.map((e) => e.id),
    };
    final affected = <int>{index};
    for (final id in ids) {
      final owner = _owners[id]?.firstOrNull;
      if (owner != null) affected.add(owner);
    }
    if (index < _pages.length) {
      for (final entry in _pages[index].entries) {
        _owners[entry.id]?.remove(index);
      }
      _pages[index] = _Page(entries);
    } else {
      _pages.add(_Page(entries));
    }
    for (final entry in entries) {
      (_owners[entry.id] ??= SplayTreeSet<int>()).add(index);
    }
    for (final id in ids) {
      final owners = _owners[id];
      if (owners == null || owners.isEmpty) {
        _owners.remove(id);
      } else {
        affected.add(owners.first);
      }
    }
    for (final page in affected) {
      _rebuild(page);
    }
  }

  void truncate(int length) {
    // Removing older pages cannot transfer ownership to a newer page.
    while (_pages.length > length) {
      final index = _pages.length - 1;
      final page = _pages.removeLast();
      for (final id in page.entries.map((entry) => entry.id).toSet()) {
        final owners = _owners[id]!;
        owners.remove(index);
        if (owners.isEmpty) _owners.remove(id);
      }
      _root = _put(_root, 0, _capacity, index, null);
    }
  }

  void _rebuild(int index) {
    final page = _pages[index];
    final seen = <String>{};
    page.plan = HistoryLocationSections._(
      page.entries.where((entry) {
        examinedMessages++;
        return _owners[entry.id]!.first == index &&
            seen.add(entry.id) &&
            entry.version <= appVersion;
      }),
    );
    _root = _put(_root, 0, _capacity, index, _Summary.from(page.plan));
  }

  _Node? _put(_Node? node, int lo, int hi, int index, _Summary? value) {
    summaryNodeVisits++;
    node ??= _Node();
    if (hi - lo == 1) {
      node.summary = value;
    } else {
      final mid = (lo + hi) ~/ 2;
      if (index < mid) {
        node.left = _put(node.left, lo, mid, index, value);
      } else {
        node.right = _put(node.right, mid, hi, index, value);
      }
      node.summary = _Summary.join(node.left?.summary, node.right?.summary);
    }
    return node.summary == null ? null : node;
  }

  _Summary? _range(_Node? node, int lo, int hi, int from, int to) {
    if (node == null || hi <= from || lo >= to) return null;
    if (from <= lo && hi <= to) return node.summary;
    final mid = (lo + hi) ~/ 2;
    return _Summary.join(
      _range(node.left, lo, mid, from, to),
      _range(node.right, mid, hi, from, to),
    );
  }

  bool includesTick(String id, String location) {
    if (location.isEmpty) return false;
    final index = _owners[id]?.firstOrNull;
    if (index == null) return false;
    final plan = _pages[index].plan;
    final run = plan._ticks[(id, location)];
    if (run == null) return false;
    if (plan.sections[run].hasUser) return true;
    if (plan._first[location] == run) {
      final newer = _range(_root, 0, _capacity, 0, index);
      if (newer?.last[location] == true) return true;
    }
    if (plan._last[location] == run) {
      final older = _range(_root, 0, _capacity, index + 1, _pages.length);
      if (older?.first[location] == true) return true;
    }
    return false;
  }

  void clear() {
    _pages.clear();
    _owners.clear();
    _root = null;
  }
}
