import '../../../l10n/genesis_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../components/common/genesis_center_toast.dart';
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

class _MiniPhoneLiveChatState extends State<MiniPhoneLiveChat> {
  final coordinator = LocationChatScrollCoordinator();
  final input = TextEditingController();
  final focus = FocusNode();
  final panelKey = GlobalKey();
  int? sdk;
  bool ready = false;
  String? owner;
  String? _shownError;
  bool _loadingHistory = false;
  int _accountGeneration = 0;
  int _latestMessageId = 0;
  final _seenMessages = <int>{};
  final _revealQueue = <int>[];
  Timer? _revealTimer;
  MiniPhoneStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    owner = store.uid;
    _accountGeneration = store.accountGeneration;
    coordinator.enter();
    store.addListener(_changed);
    coordinator.addListener(_changed);
    coordinator.controller.addListener(_scroll);
    input.addListener(_changed);
    focus.addListener(_focus);
    input.text = store.drafts[widget.person.id] ?? '';
    final draft = store.waiting(widget.person.id);
    if (draft != null && !draft.accepted) input.text = draft.content;
    unawaited(
      loadAndroidSdkInt().then((v) {
        if (mounted) setState(() => sdk = v);
      }),
    );
    unawaited(_loadInitialMessages(_accountGeneration));
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
      setState(() => ready = true);
    }
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
      input.clear();
      final generation = _accountGeneration;
      // The account-change notification precedes replacement of store.ready.
      scheduleMicrotask(() {
        if (mounted) unawaited(_loadInitialMessages(generation));
      });
    }
    _syncReplies();
    if (store.uid != owner) {
      owner = store.uid;
      input.clear();
    }
    if (mounted) {
      final error = _error;
      if (error != _shownError) {
        _shownError = error;
        if (error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _error == error &&
                store.phoneVisible &&
                store.foreground) {
              showGenesisToast(context, error);
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

  String? get _error {
    final id = widget.person.id;
    return store.errors['messages:${store.sessionFor(id)}'] ??
        store.errors['request:${store.waiting(id)?.id}'] ??
        store.errors['session:$id'] ??
        store.errors['dm:$id'] ??
        store.replyFailures[id];
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
        text.trim().isEmpty ||
        _revealQueue.isNotEmpty ||
        store.busy.contains('dm:${widget.person.id}') ||
        waiting != null && !(waiting.uncertain && !waiting.accepted)) {
      return;
    }
    final generation = store.accountGeneration;
    _follow();
    final pending = store.pending['dm:${widget.person.id}'];
    final retry = pending != null && !pending.accepted && !pending.rejected;
    final submitted = retry ? pending.content : text;
    // Show the outgoing row at submission time, preserving a newer retry draft.
    if (input.text == submitted) input.clear();
    final result = await store.write(
      'dm',
      widget.person.id,
      submitted,
      retry: retry,
    );
    if (mounted &&
        generation == store.accountGeneration &&
        !result &&
        input.text.isEmpty) {
      input.text = submitted;
    }
    // Keep focus and the existing keyboard, including while waiting for a reply.
  }

  @override
  void dispose() {
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
    final visibleMessages = store
        .history(person.id)
        .where((m) => !_revealQueue.contains(m.id))
        .toList();
    final rows = visibleMessages
        .map(
          (m) => ChatMessageVm(
            localId:
                m.senderType == 'user' &&
                    m.senderId == store.uid &&
                    m.requestId != null
                ? 'phone:request:${m.requestId}'
                : 'phone:${m.id}',
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
            status: 'sent',
          ),
        )
        .toList();
    for (final outgoing in store.outgoingDm(person.id)) {
      final row = ChatMessageVm(
        localId: 'phone:request:${outgoing.id}',
        clientMsgId: outgoing.id,
        senderId: store.uid ?? '',
        senderName: context.l10n.miniPhoneYou,
        avatarUrl: store.person(store.uid ?? '', type: 1).avatar,
        text: outgoing.content,
        isMe: true,
        status: outgoing.accepted
            ? 'sent'
            : outgoing.uncertain
            ? context.l10n.miniPhoneAwaitingConfirmation
            : 'sending',
      );
      final reply = visibleMessages
          .where((m) => m.requestId == outgoing.id)
          .firstOrNull;
      final replyIndex = reply == null
          ? -1
          : rows.indexWhere((m) => m.localId == 'phone:${reply.id}');
      rows.insert(replyIndex < 0 ? rows.length : replyIndex, row);
    }
    final managed =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android &&
            (sdk ?? 0) >= 30;
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
                      topTitleTextStyle: miniStyle(
                        11,
                        FontWeight.w400,
                        miniTertiary,
                      ),
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
