import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (mounted) setState(() {});
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
        !store.busy.contains(key)) {
      unawaited(store.refreshMessages(widget.person.id, next: true));
    }
  }

  Future<void> _send() async {
    final text = input.text;
    if (text.trim().isEmpty) return;
    _follow();
    final result = await store.write('dm', widget.person.id, text);
    if (mounted && result && input.text == text) input.clear();
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
    final error =
        store.errors[key] ??
        store.errors['session:${person.id}'] ??
        store.errors['dm:${person.id}'] ??
        store.replyFailures[person.id];
    final rows = store
        .history(person.id)
        .map(
          (m) => ChatMessageVm(
            localId: 'phone:${m.id}',
            senderId: m.senderId,
            senderName: m.senderType == 'user' ? 'You' : person.name,
            avatarUrl: m.senderType == 'user'
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
                  child: LocationChatAnchoredMessageList(
                    coordinator: coordinator,
                    messages: rows,
                    topTitle: '',
                    initialContentReady: ready,
                    restoreInitialCompletedContent: true,
                    replyWaitingPositioningEnabled: false,
                    replyActionsVisible: false,
                    showDateDividers: false,
                    style: kPrivateChatStyle,
                    oldestEdgeLoading: store.busy.contains(key),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    onMessageLongPressStart: (context, message, details) {
                      final p = details.globalPosition;
                      showMenu<String>(
                        context: context,
                        color: const Color(0xFF666666),
                        position: RelativeRect.fromLTRB(p.dx, p.dy, p.dx, p.dy),
                        items: const [
                          PopupMenuItem(
                            value: 'copy',
                            child: Text(
                              'Copy',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ).then((value) {
                        if (value == 'copy') {
                          Clipboard.setData(ClipboardData(text: message.text));
                        }
                      });
                    },
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
                if (waiting != null)
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
                        if (waiting.uncertain && !waiting.accepted)
                          TextButton(
                            onPressed: store.busy.contains(waiting.key)
                                ? null
                                : () => store.write(
                                    'dm',
                                    person.id,
                                    waiting.content,
                                    retry: true,
                                  ),
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            error,
                            style: miniStyle(12, FontWeight.w400, miniPink),
                          ),
                        ),
                        TextButton(
                          onPressed: () => store.refreshMessages(person.id),
                          child: const Text('Refresh'),
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
                  sendEnabled: waiting == null && input.text.trim().isNotEmpty,
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
