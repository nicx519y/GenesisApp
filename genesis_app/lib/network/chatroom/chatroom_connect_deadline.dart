/// Produced only by the deadline around a complete chatroom connection attempt.
/// A lower-level TimeoutException is an explicit failure, not this deadline.
class ChatroomConnectDeadlineExceeded implements Exception {
  const ChatroomConnectDeadlineExceeded(this.timeout);
  final Duration timeout;
  @override
  String toString() =>
      'ChatroomConnectDeadlineExceeded: no connection result within ${timeout.inMilliseconds}ms';
}
