part of 'location_chat_page.dart';

/// Captures ownership, not cancellation. Each feature still decides whether a
/// round/source is usable and which of its own loading flags may be cleared.
class _LocationChatReplyOperationScope {
  _LocationChatReplyOperationScope(this._owner)
    : _binding = _owner._replyBindingGeneration,
      _location = _owner.widget.locationId,
      _controller = _owner._replyController,
      _services = _owner._quotaServices,
      _session = _owner._quotaServices?.sessionRevision.value;

  final _LocationChatPanelState _owner;
  final int _binding;
  final String _location;
  final ChatroomReplyActionsController? _controller;
  final AppServices? _services;
  final int? _session;

  bool get ownsBinding =>
      _owner.mounted && _binding == _owner._replyBindingGeneration;

  bool get ownsReplyTarget =>
      ownsBinding &&
      _location == _owner.widget.locationId &&
      identical(_controller, _owner._replyController);

  bool get ownsQuotaSession =>
      identical(_services, _owner._quotaServices) &&
      _session == _services?.sessionRevision.value;

  bool get canApplyToReply => ownsReplyTarget && _owner.widget.active;
}
