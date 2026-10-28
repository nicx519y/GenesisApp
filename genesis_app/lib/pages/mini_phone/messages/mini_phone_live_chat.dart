import '../../../l10n/genesis_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../shared/mini_phone_toast.dart';
import '../../../components/chat/shared/chat_keyboard_inset_layout.dart';
import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../../../platform/device/android_sdk_version.dart';
import '../../../ui/components/genesis_safe_area.dart';
import '../../chat/location_chat_scroll_coordinator.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';

class MiniPhoneLiveChat extends StatefulWidget {
  const MiniPhoneLiveChat({
    super.key,
    required this.store,
    required this.person,
    required this.header,
  });
  final MiniPhoneStore store;
  final PhonePerson person;
  final Widget header;
  @override
  State<MiniPhoneLiveChat> createState() => _MiniPhoneLiveChatState();
}

class _MiniPhoneLiveChatState extends State<MiniPhoneLiveChat>
    with WidgetsBindingObserver {
  final coordinator = LocationChatScrollCoordinator();
  final input = TextEditingController();
  final focus = FocusNode();
  final panelKey = GlobalKey();
  int? sdk;
  bool ready = false;
  // Latch only after an empty conversation has loaded successfully. New
  // messages append below these local opening rows instead of replacing them.
  bool _showOpeningRows = false;
  String? owner;
  ({String message, String? replyRequestId})? _shownError;
  bool _loadingHistory = false;
  bool _resendingFailedMessage = false;
  int _accountGeneration = 0;
  int _latestMessageId = 0;
  final _seenMessages = <int>{};
  final _revealQueue = <int>[];
  Timer? _revealTimer;
  MiniPhoneStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    owner = store.uid;
    _accountGeneration = store.accountGeneration;
    coordinator.enter();
    store.addListener(_changed);
    coordinator.addListener(_changed);
    coordinator.controller.addListener(_scroll);
    input.addListener(_inputChanged);
    focus.addListener(_focus);
    input.text = store.drafts[widget.person.id] ?? '';
    store.messagesController.restoredBalanceDrafts.remove(widget.person.id);
    final draft = store.waiting(widget.person.id);
    if (draft != null && !draft.accepted) input.text = draft.content;
    unawaited(
      loadAndroidSdkInt().then((v) {
        if (mounted) setState(() => sdk = v);
      }),
    );
    unawaited(_loadInitialMessages(_accountGeneration));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register for route visibility changes, including returning from settings.
    ModalRoute.isCurrentOf(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _changed();
  }

  Future<void> _loadInitialMessages(int generation) async {
    await store.localReady;
    if (!mounted || generation != store.accountGeneration) return;
    if (store.history(widget.person.id).isNotEmpty) {
      _syncReplies();
      setState(() => ready = true);
    }
    final id = store.sessionFor(widget.person.id);
    if (id != null &&
        store.foreground &&
        store.phoneVisible &&
        store.activeCharId == widget.person.id) {
      unawaited(store.markSessionRead(id));
    }
    await store.refreshMessages(widget.person.id);
    if (mounted && generation == store.accountGeneration) {
      setState(() {
        ready = true;
        if (_error == null &&
            store.history(widget.person.id).isEmpty &&
            store.outgoingDm(widget.person.id).isEmpty &&
            store.waiting(widget.person.id) == null) {
          _showOpeningRows = true;
        }
      });
    }
  }

  void _inputChanged() {
    store.drafts[widget.person.id] = input.text;
    _changed();
  }

  void _changed() {
    if (_accountGeneration != store.accountGeneration) {
      _accountGeneration = store.accountGeneration;
      _revealTimer?.cancel();
      _revealTimer = null;
      _revealQueue.clear();
      _seenMessages.clear();
      _latestMessageId = 0;
      _loadingHistory = false;
      ready = false;
      _showOpeningRows = false;
      input.clear();
      final generation = _accountGeneration;
      // The account-change notification precedes replacement of store.ready.
      scheduleMicrotask(() {
        if (mounted) unawaited(_loadInitialMessages(generation));
      });
    }
    final restored = store.messagesController.restoredBalanceDrafts.remove(
      widget.person.id,
    );
    if (restored != null && input.text.isEmpty) {
      input.value = TextEditingValue(
        text: restored,
        selection: TextSelection.collapsed(offset: restored.length),
      );
    }
    _syncReplies();
    if (store.uid != owner) {
      owner = store.uid;
      input.clear();
    }
    if (mounted) {
      final error = _errorNotice;
      if (error != _shownError) {
        if (error == null) {
          _shownError = null;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _errorNotice == error &&
                _shownError != error &&
                store.phoneVisible &&
                store.foreground &&
                ModalRoute.of(context)?.isCurrent != false) {
              showMiniPhoneToast(context, error.message);
              _shownError = error;
              if (error.replyRequestId case final requestId?) {
                store.acknowledgeReplyFailure(widget.person.id, requestId);
              }
            }
          });
        }
      }
      setState(() {});
    }
  }

  void _syncReplies() {
    final history = store.history(widget.person.id);
    final fresh = history
        .where(
          (m) =>
              ready &&
              m.id > _latestMessageId &&
              !_seenMessages.contains(m.id) &&
              !(m.senderType == 'user' && m.senderId == store.uid),
        )
        .toList();
    for (final message in history) {
      _seenMessages.add(message.id);
      if (message.id > _latestMessageId) _latestMessageId = message.id;
    }
    // Existing history appears immediately. Only live tail additions are paced.
    if (fresh.isEmpty) return;
    if (_revealTimer == null) fresh.removeAt(0);
    _revealQueue.addAll(fresh.map((m) => m.id));
    _revealQueue.sort();
    if (_revealQueue.isEmpty || _revealTimer != null) return;
    _revealTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _revealQueue.removeAt(0);
      if (_revealQueue.isEmpty) {
        _revealTimer?.cancel();
        _revealTimer = null;
      }
      if (mounted) setState(() {});
    });
  }

  String? get _error => _errorNotice?.message;

  ({String message, String? replyRequestId})? get _errorNotice {
    final id = widget.person.id;
    final sendError = store.errors['dm:$id'];
    if (sendError != null && !store.hasDmBalanceFailure(id)) {
      return (message: sendError, replyRequestId: null);
    }
    // A new send owns its feedback. Do not let an old history/recovery error
    // mask it or keep the previous attempt's toast marked as already shown.
    if (store.busy.contains('dm:$id')) return null;
    final error =
        store.errors['messages:${store.sessionFor(id)}'] ??
        store.errors['request:${store.waiting(id)?.id}'] ??
        store.errors['session:$id'];
    if (error != null) return (message: error, replyRequestId: null);
    final failure = store.replyFailureNotice(id);
    return failure == null
        ? null
        : (message: failure.message, replyRequestId: failure.requestId);
  }

  void _focus() {
    if (focus.hasFocus) _follow();
    _changed();
  }

  void _follow() => coordinator.requestBottom(
    reason: LocationChatBottomReason.composerFocus,
    behavior: LocationChatBottomBehavior.jump,
  );
  void _scroll() {
    final id = store.sessionFor(widget.person.id);
    if (id == null || !coordinator.controller.hasClients) return;
    final key = 'messages:$id';
    if (coordinator.isReadingHistory &&
        coordinator.controller.position.pixels <= 64 &&
        store.hasMore[key] == true &&
        !_loadingHistory &&
        !store.busy.contains(key) &&
        !store.errors.containsKey(key)) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    final generation = store.accountGeneration;
    setState(() => _loadingHistory = true);
    try {
      await store.refreshMessages(widget.person.id, next: true);
    } finally {
      if (mounted && generation == store.accountGeneration) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _send() async {
    final text = input.text;
    final waiting = store.waiting(widget.person.id);
    if (!ready ||
        _resendingFailedMessage ||
        text.trim().isEmpty ||
        _revealQueue.isNotEmpty ||
        store.busy.contains('dm:${widget.person.id}') ||
        waiting != null && !(waiting.uncertain && !waiting.accepted)) {
      return;
    }
    final generation = store.accountGeneration;
    final pending = store.pending['dm:${widget.person.id}'];
    final retry =
        pending != null &&
        !pending.sendReleased &&
        !pending.accepted &&
        !pending.rejected;
    final submitted = retry ? pending.content : text;
    var clearedDraft = false;
    final result = await store.write(
      'dm',
      widget.person.id,
      submitted,
      retry: retry,
      onPrepared: () {
        if (!mounted || generation != store.accountGeneration) return;
        _follow();
        // Keep the draft throughout preflight; clear only when dispatch starts.
        if (input.text == submitted) {
          input.clear();
          clearedDraft = true;
        }
      },
    );
    if (mounted &&
        generation == store.accountGeneration &&
        clearedDraft &&
        !result &&
        input.text.isEmpty) {
      input.text = submitted;
    }
    // Keep focus and the existing keyboard, including while waiting for a reply.
  }

  Future<void> _resendFailedMessage(ChatMessageVm message) async {
    final charId = widget.person.id;
    if (!ready ||
        _resendingFailedMessage ||
        _revealQueue.isNotEmpty ||
        store.busy.contains('dm:$charId') ||
        store.waiting(charId) != null) {
      return;
    }
    final source = store
        .history(charId)
        .where(
          (m) =>
              m.requestId == message.clientMsgId &&
              m.senderType == 'user' &&
              m.senderId == store.uid &&
              m.replyStatus == 'failed',
        )
        .firstOrNull;
    final rejected = store.pending.values
        .where(
          (w) =>
              w.kind == 'dm' &&
              w.target == charId &&
              w.id == message.clientMsgId &&
              w.rejected,
        )
        .firstOrNull;
    final failedAttempt =
        rejected?.id == message.clientMsgId && rejected!.rejected
        ? rejected
        : null;
    if (source == null && failedAttempt == null) return;
    _resendingFailedMessage = true;
    try {
      _follow();
      await store.write(
        'dm',
        charId,
        source?.content ?? failedAttempt!.content,
        retryRootId: store.messagesController.bubbleRequestId(
          message.clientMsgId,
        ),
      );
    } finally {
      _resendingFailedMessage = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealTimer?.cancel();
    store.removeListener(_changed);
    coordinator.removeListener(_changed);
    coordinator.controller.removeListener(_scroll);
    coordinator.dispose();
    if (store.uid == owner) store.drafts[widget.person.id] = input.text;
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person, waiting = store.waiting(person.id);
    final visibleMessages = store.messagesController
        .displayHistory(person.id)
        .where((m) => !_revealQueue.contains(m.id))
        .toList();
    final rows = visibleMessages.map((m) {
      final replyStatus = store.messagesController.replyStatusFor(
        m.requestId,
        m.replyStatus,
      );
      return ChatMessageVm(
        localId:
            m.senderType == 'user' &&
                m.senderId == store.uid &&
                m.requestId != null
            ? 'phone:request:${store.messagesController.bubbleRequestId(m.requestId!)}'
            : 'phone:${m.id}',
        clientMsgId: m.requestId ?? '',
        senderId: m.senderId,
        senderName: m.senderId == store.uid
            ? context.l10n.miniPhoneYou
            : person.name,
        avatarUrl: m.senderId == store.uid
            ? store.person(m.senderId, type: 1).avatar
            : person.avatar,
        text: m.content,
        currentTime: m.currentTime,
        isMe: m.senderType == 'user' && m.senderId == store.uid,
        status:
            m.senderType == 'user' &&
                m.senderId == store.uid &&
                replyStatus == 'failed'
            ? 'failed'
            : m.senderType == 'user' &&
                  m.senderId == store.uid &&
                  (replyStatus == 'pending' || replyStatus == 'generating')
            ? (store.messagesController.sendReleasedFor(m.requestId)
                  ? context.l10n.miniPhoneAwaitingConfirmation
                  : 'sending')
            : 'sent',
      );
    }).toList();
    for (final outgoing in store.outgoingDm(person.id)) {
      final row = ChatMessageVm(
        localId:
            'phone:request:${store.messagesController.bubbleRequestId(outgoing.id)}',
        clientMsgId: outgoing.id,
        senderId: store.uid ?? '',
        senderName: context.l10n.miniPhoneYou,
        avatarUrl: store.person(store.uid ?? '', type: 1).avatar,
        text: outgoing.content,
        isMe: true,
        status: outgoing.rejected
            ? 'failed'
            : store.messagesController.replyStatusFor(outgoing.id, null) ==
                  'completed'
            ? 'sent'
            : outgoing.sendReleased
            ? context.l10n.miniPhoneAwaitingConfirmation
            : outgoing.accepted
            ? (store.messagesController.isPlayerChat(person.id)
                  ? 'sent'
                  : 'sending')
            : outgoing.uncertain
            ? context.l10n.miniPhoneAwaitingConfirmation
            : 'sending',
      );
      final existingIndex = rows.indexWhere((m) => m.localId == row.localId);
      if (existingIndex >= 0) {
        rows[existingIndex] = row;
      } else {
        final reply = visibleMessages
            .where((m) => m.requestId == outgoing.id)
            .firstOrNull;
        final replyIndex = reply == null
            ? -1
            : rows.indexWhere((m) => m.localId == 'phone:${reply.id}');
        rows.insert(replyIndex < 0 ? rows.length : replyIndex, row);
      }
    }
    // These opening rows stay above subsequent messages for this open chat.
    // They never enter message storage, unread counts or World History.
    if (_showOpeningRows) {
      rows.insertAll(0, [
        ChatMessageVm(
          localId: 'phone:empty-contact:${person.id}',
          isMe: false,
          senderId: '',
          senderName: '',
          senderType: 'system',
          text: context.l10n.miniPhoneContactAdded(name: person.name),
          status: 'sent',
        ),
        ChatMessageVm(
          localId: 'phone:empty-introduction:${person.id}',
          isMe: false,
          senderId: person.id,
          senderName: person.name,
          avatarUrl: person.avatar,
          senderType: 'char',
          text: context.l10n.miniPhoneCharacterIntroduction(name: person.name),
          status: 'sent',
        ),
      ]);
    }
    final managed =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android &&
            (sdk ?? 0) >= 30;
    final noticeStyle = miniStyle(11, FontWeight.w400, miniTertiary);
    return SizedBox.expand(
      key: panelKey,
      child: Scaffold(
        backgroundColor: miniBackground,
        resizeToAvoidBottomInset: !managed && focus.hasFocus,
        body: ChatKeyboardInsetLayout(
          unobscuredPanelKey: panelKey,
          managesKeyboardInset: managed,
          freezeKeyboardInset: false,
          frozenKeyboardInset: 0,
          onFrozenKeyboardInsetRestored: () {},
          bottomSafeAreaInset: GenesisSafeAreaInsets.bottom(context),
          header: SafeArea(bottom: false, child: widget.header),
          messageViewport: Stack(
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: coordinator.handleScrollNotification,
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    messages: rows,
                    onFailedMessageTap: _resendFailedMessage,
                    messageDecorator: (message, previous, child) {
                      if (message.localId !=
                          'phone:empty-contact:${person.id}') {
                        return child;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Center(
                          child: Text(
                            message.text,
                            textAlign: TextAlign.center,
                            style: noticeStyle,
                          ),
                        ),
                      );
                    },
                    topTitle: [
                      store.worldDay,
                      context.l10n.miniPhonePrivateConversation,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    initialContentReady: ready,
                    restoreInitialCompletedContent: true,
                    replyWaitingPositioningEnabled: false,
                    replyActionsVisible: false,
                    showDateDividers: false,
                    style: kPrivateChatStyle.copyWith(
                      messageListPadding: const EdgeInsets.all(miniPageInset),
                      topTitleBottomPadding: 22,
                      topTitleTextStyle: noticeStyle,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                  ),
                ),
              ),
              if (coordinator.isReadingHistory &&
                  coordinator.hasMessageContentBelowViewport)
                Positioned(
                  right: 16,
                  bottom: 8,
                  child: TextButton(
                    onPressed: () => coordinator.requestBottom(
                      reason: LocationChatBottomReason.unseenMessageNotice,
                      behavior: LocationChatBottomBehavior.animate,
                    ),
                    child: Text(context.l10n.miniPhoneNewMessages),
                  ),
                ),
            ],
          ),
          composer: SafeArea(
            top: false,
            maintainBottomViewPadding: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((waiting != null || _revealQueue.isNotEmpty) &&
                    !store.isPlayerChat(person.id))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            waiting?.uncertain == true
                                ? context.l10n.miniPhoneReconnecting
                                : context.l10n.miniPhoneTyping(
                                    name: person.name,
                                  ),
                            style: miniStyle(
                              12,
                              FontWeight.w400,
                              miniSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ChatComposer(
                  controller: input,
                  focusNode: focus,
                  onInputTap: _follow,
                  onInputTapAlwaysCalled: true,
                  inputEnabled: true,
                  sendEnabled:
                      ready &&
                      _revealQueue.isEmpty &&
                      (waiting == null ||
                          waiting.uncertain && !waiting.accepted) &&
                      !store.busy.contains('dm:${person.id}') &&
                      input.text.trim().isNotEmpty,
                  sending: false,
                  sendLabel: context.l10n.miniPhoneSend,
                  onSend: _send,
                  hintText: context.l10n.miniPhoneMessageHint(
                    name: person.name,
                  ),
                  style: kPrivateChatStyle,
                  bottomSafeAreaInset: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
