import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/chat/shared/chat_keyboard_inset_layout.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../network/mini_phone/mini_phone_models.dart';
import '../../platform/device/android_sdk_version.dart';
import '../../ui/components/genesis_refresh_indicator.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../chat/location_chat_scroll_coordinator.dart';
import 'mini_phone_store.dart';
import 'mini_phone_ui.dart';

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
  MiniPhoneStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    owner = store.uid;
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
    unawaited(
      store.ready.then((_) async {
        if (!mounted) return;
        await store.refreshMessages(widget.person.id);
        if (mounted) setState(() => ready = true);
      }),
    );
  }

  void _changed() {
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
        !store.busy.contains(key) &&
        !store.errors.containsKey(key)) {
      unawaited(store.refreshMessages(widget.person.id, next: true));
    }
  }

  Future<void> _send() async {
    final text = input.text;
    if (text.trim().isEmpty) return;
    _follow();
    final pending = store.pending['dm:${widget.person.id}'];
    final retry = pending != null && !pending.accepted && !pending.rejected;
    final submitted = retry ? pending.content : text;
    final result = await store.write(
      'dm',
      widget.person.id,
      submitted,
      retry: retry,
    );
    if (mounted && result && input.text == submitted) input.clear();
    // Keep focus and the existing keyboard, including while waiting for a reply.
  }

  @override
  void dispose() {
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
    final key = 'messages:${store.sessionFor(person.id)}';
    final rows = store
        .history(person.id)
        .map(
          (m) => ChatMessageVm(
            localId: 'phone:${m.id}',
            senderId: m.senderId,
            senderName: m.senderId == store.uid ? 'You' : person.name,
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
                  child: GenesisRefreshIndicator(
                    onRefresh: () async {
                      await store.refreshMessages(person.id);
                    },
                    child: LocationChatAnchoredMessageList(
                      coordinator: coordinator,
                      messages: rows,
                      topTitle: [
                        store.worldDay,
                        'Private conversation',
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
                      oldestEdgeLoading: ready && store.busy.contains(key),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                    ),
                  ),
                ),
              ),
              if (!ready) const Center(child: GenesisLoadingIndicator()),
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
                    child: const Text('New messages ↓'),
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
                if (waiting != null && !store.isPlayerChat(person.id))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            waiting.uncertain
                                ? 'Reconnecting… Waiting for confirmation'
                                : '${person.name} is typing…',
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
                      (waiting == null ||
                          waiting.uncertain && !waiting.accepted) &&
                      !store.busy.contains('dm:${person.id}') &&
                      input.text.trim().isNotEmpty,
                  sending: store.busy.contains('dm:${person.id}'),
                  sendLabel: 'Send',
                  onSend: _send,
                  hintText: 'Message ${person.name}…',
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
