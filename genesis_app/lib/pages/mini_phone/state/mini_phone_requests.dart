import '../../../l10n/genesis_l10n.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../network/api_exception.dart';

String miniPhoneErrorText(Object error) => error is ApiException
    ? error.message
    : GenesisL10n.current.miniPhoneLoadFailed;

/// Internal cancellation: no partial data or user-facing error is published.
class MiniPhoneRequestCancelled implements Exception {
  const MiniPhoneRequestCancelled();
}

/// Shared account identity, request versions and in-flight coalescing.
/// Feature controllers use the same gate; no feature creates its own transport.
class MiniPhoneRequests {
  MiniPhoneRequests(this.notify);
  final VoidCallback notify;
  String? uid;
  bool disposed = false, foreground = true, phoneVisible = false;
  int generation = 0;
  final pages = <String, int>{};
  final hasMore = <String, bool>{};
  final errors = <String, String>{};
  final busy = <String>{};
  final versions = <String, int>{};
  final _loads = <String, ({int version, Future<bool> future})>{};
  bool isCurrent(int value) => !disposed && generation == value;
  void reset() {
    generation++;
    uid = null;
    pages.clear();
    hasMore.clear();
    errors.clear();
    busy.clear();
    versions.clear();
    _loads.clear();
  }

  Future<bool> load<T>(
    String key,
    Future<T> Function() fetch,
    void Function(T) apply, {
    String requestKey = '',
    bool deduplicate = true,
    bool allowBackground = false,
  }) {
    if (disposed || uid == null || (!foreground && !allowBackground)) {
      return Future.value(false);
    }
    final flightKey = '$key:$requestKey';
    final existing = _loads[flightKey];
    if (deduplicate && existing != null && existing.version == versions[key]) {
      return existing.future;
    }
    final g = generation, v = (versions[key] ?? 0) + 1;
    versions[key] = v;
    // Register before notifying listeners; equivalent requests share dispatch
    // and application, but superseded parameters never reuse an obsolete flight.
    late final Future<bool> task;
    task = Future<bool>.microtask(() async {
      try {
        if (!isCurrent(g) || (!foreground && !allowBackground)) return false;
        final result = await fetch();
        if (!isCurrent(g) || versions[key] != v) return false;
        apply(result);
        return true;
      } on MiniPhoneRequestCancelled {
        return false;
      } catch (e) {
        if (isCurrent(g) && versions[key] == v) {
          errors[key] = miniPhoneErrorText(e);
        }
        return false;
      } finally {
        if (isCurrent(g)) {
          if (identical(_loads[flightKey]?.future, task)) {
            _loads.remove(flightKey);
          }
          if (versions[key] == v) {
            busy.remove(key);
            notify();
          }
        }
      }
    });
    _loads[flightKey] = (version: v, future: task);
    busy.add(key);
    errors.remove(key);
    notify();
    return task;
  }
}
