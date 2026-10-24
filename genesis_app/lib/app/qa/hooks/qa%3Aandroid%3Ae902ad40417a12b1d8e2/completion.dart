import 'dart:async';
import 'dart:convert';

/// Copy only the fields the production API mapper consumes. Never mutate the
/// source snapshot or confuse info.tick_cnt with stats.tick_cnt.
Map<String, dynamic> completedResponse(
  Map<String, dynamic> before,
  int round,
  String time,
  Map<String, dynamic> event,
) {
  if (round <= 0 ||
      time.isEmpty ||
      before['info'] is! Map ||
      before['stats'] is! Map ||
      !(before['stats'] as Map).containsKey('tick_cnt')) {
    throw StateError('World completion response lacks required fields');
  }
  final next = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
  next['info']['current_time'] = time;
  next['stats']['tick_cnt'] = round;
  if ((next['stats'] as Map).containsKey('sub_tick_no'))
    next['stats']['sub_tick_no'] = 0;
  for (final key in ['tick_list', 'ticks']) {
    if (next[key] is List) next[key] = [jsonDecode(jsonEncode(event))];
  }
  return next;
}

/// Count every transport submission, including duplicates. The mock must not
/// implement the App's duplicate-submit guard for it.
class TickAttempt {
  TickAttempt({required this.finish, this.delay = const Duration(seconds: 6)});
  final Future<void> Function() finish;
  final Duration delay;
  int submissions = 0;
  bool completed = false, released = false;
  Object? failure;
  StackTrace? failureStack;
  Timer? _timer;
  Future<void>? _mutation;
  void submit() {
    if (released) throw StateError('Tick attempt released');
    submissions++;
    _timer ??= Timer(delay, () {
      _mutation = _complete();
    });
  }

  Future<void> _complete() async {
    try {
      await finish();
      completed = true;
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
  }

  Future<void> close() async {
    released = true;
    _timer?.cancel();
    await _mutation;
  }
}
