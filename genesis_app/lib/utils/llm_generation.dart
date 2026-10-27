import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Wire identity. Message IDs are deliberately absent: a retry replaces every
/// output position in this generation, not just the next arriving bubble.
@immutable
class LlmGenerationId {
  const LlmGenerationId(
    this.world,
    this.location,
    this.round,
    this.request, [
    this.card,
  ]);
  final String world, location, round, request;
  final int? card;
  String get key => jsonEncode([world, location, round, card, request]);
  @override
  bool operator ==(Object other) =>
      other is LlmGenerationId && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

/// Transient provenance shared by the reducer and presentation. A presentation
/// lease retains only an outgoing visual; it never delays data invalidation.
class LlmAttempt extends ChangeNotifier {
  LlmAttempt(this.generation, this.number);
  final LlmGenerationId generation;
  final int number;
  bool invalidated = false;
  bool animateRetraction = false;
  bool terminal = false;
  bool waitingExpired = false;
  int _leases = 0;
  VoidCallback? onPresentationChanged;
  bool get presentationPending => _leases > 0;
  Object get identity => (generation.key, number);
  VoidCallback retainPresentation() {
    _leases++;
    onPresentationChanged?.call();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _leases--;
      onPresentationChanged?.call();
    };
  }

  void retract({required bool animate}) {
    if (invalidated) return;
    invalidated = true;
    animateRetraction = animate;
    notifyListeners();
  }
}

class LlmGenerationState {
  LlmGenerationState(this.id);
  final LlmGenerationId id;
  int latest = 0;
  int? expected;
  bool closed = false;
  bool failed = false;
  final attempts = <int, LlmAttempt>{};
  final invalidated = <int>{};
  final endedMessages = <(int, int)>{};

  LlmAttempt? accept(int number, int messageId, {required bool end}) {
    if (closed ||
        number < latest ||
        invalidated.contains(number) ||
        endedMessages.contains((number, messageId))) {
      return null;
    }
    if (number > latest) {
      for (final entry in attempts.entries) {
        if (entry.key < number) entry.value.retract(animate: true);
      }
      latest = number;
    }
    final attempt = attempts.putIfAbsent(number, () => LlmAttempt(id, number));
    if (end) endedMessages.add((number, messageId));
    return attempt;
  }

  bool retract(int number, {required bool retrying, int? next}) {
    if (closed) return false;
    invalidated.add(number);
    attempts[number]?.retract(animate: retrying);
    if (number < latest) return false;
    if (retrying) {
      if (expected != null && next! <= expected!) return false;
      expected = next;
    } else {
      closed = true;
      failed = true;
      for (final attempt in attempts.values) {
        attempt.terminal = true;
      }
    }
    return true;
  }

  void close() {
    closed = true;
    for (final attempt in attempts.values) {
      attempt.terminal = true;
    }
  }
}
