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

class _Run {
  _Run(this.location);
  final String location;
  bool hasUser = false;
}

class _Page {
  _Page(this.entries);
  final List<_Entry> entries;
  final runs = <_Run>[];
  final ticks = <(String, String), int>{};
}

/// First/last continuous runs are sufficient to compose adjacent ranges.
class _Summary {
  const _Summary(
    this.first,
    this.last,
    this.firstUser,
    this.lastUser,
    this.single,
  );
  final String first, last;
  final bool firstUser, lastUser, single;
  static _Summary? join(_Summary? a, _Summary? b) {
    if (a == null) return b;
    if (b == null) return a;
    final linked = a.last == b.first;
    return _Summary(
      a.first,
      b.last,
      a.firstUser || (a.single && linked && b.firstUser),
      b.lastUser || (b.single && linked && a.lastUser),
      a.single && b.single && linked,
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
    page.runs.clear();
    page.ticks.clear();
    final seen = <String>{};
    for (final entry in page.entries) {
      examinedMessages++;
      if (_owners[entry.id]!.first != index ||
          !seen.add(entry.id) ||
          entry.version > appVersion) {
        continue;
      }
      for (final location in entry.locations) {
        if (page.runs.isEmpty || page.runs.last.location != location) {
          page.runs.add(_Run(location));
        }
        if (entry.type == 'user') page.runs.last.hasUser = true;
        if (entry.type == 'tick') {
          page.ticks[(entry.id, location)] = page.runs.length - 1;
        }
      }
    }
    final runs = page.runs;
    _root = _put(
      _root,
      0,
      _capacity,
      index,
      runs.isEmpty
          ? null
          : _Summary(
              runs.first.location,
              runs.last.location,
              runs.first.hasUser,
              runs.last.hasUser,
              runs.length == 1,
            ),
    );
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
    final page = _pages[index];
    final run = page.ticks[(id, location)];
    if (run == null) return false;
    if (page.runs[run].hasUser) return true;
    if (run == 0) {
      final newer = _range(_root, 0, _capacity, 0, index);
      if (newer?.last == location && newer!.lastUser) return true;
    }
    if (run == page.runs.length - 1) {
      final older = _range(_root, 0, _capacity, index + 1, _pages.length);
      if (older?.first == location && older!.firstUser) return true;
    }
    return false;
  }

  void clear() {
    _pages.clear();
    _owners.clear();
    _root = null;
  }
}
