part of 'mini_phone_page.dart';

extension _MiniPhoneConversations on _MiniPhonePageState {
  Widget _messages() => _panel(
    'Messages',
    ListView(children: [for (final p in miniDemoPeople) _contactRow(p)]),
  );
  Widget _contactRow(MiniDemoPerson p) {
    final history = store.chats[p.id]!;
    final modified = history.length > (p == miniDemoPeople.first ? 4 : 1);
    final preview = modified
        ? '${history.last.mine ? 'You: ' : ''}${history.last.text}'
        : p.preview;
    return InkWell(
      onTap: () => _openChat(p),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: miniPageInset,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    '$miniPhoneAssets${p.image}',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                if (store.unread(p) > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: MiniBadge(store.unread(p)),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.short,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: miniStyle(14, FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: Text(
                          modified ? 'now' : p.time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: miniStyle(11, FontWeight.w400, miniTertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 60),
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chat() => SafeArea(
    child: Column(
      children: [
        _navigation(contact.name),
        Expanded(
          child: ListView(
            controller: chatScroll,
            padding: const EdgeInsets.all(miniPageInset),
            children: [
              Center(
                child: Text(
                  'Day 2 · Private conversation',
                  style: miniStyle(11, FontWeight.w400, miniTertiary),
                ),
              ),
              const SizedBox(height: 22),
              for (final m in store.chats[contact.id]!) _message(m),
              if (typing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${contact.short} is typing…',
                    style: miniStyle(12, FontWeight.w400, miniSecondary),
                  ),
                ),
            ],
          ),
        ),
        ChatComposer(
          controller: messageInput,
          inputEnabled: true,
          sendEnabled: messageInput.text.trim().isNotEmpty,
          sending: false,
          sendLabel: 'Send',
          onSend: () async => _sendChat(),
          hintText: 'Message ${contact.short}…',
          style: kPrivateChatStyle,
          bottomSafeAreaInset: 0,
        ),
      ],
    ),
  );
  Widget _message(MiniDemoMessage m) => ChatMessageRow(
    message: ChatMessageVm(
      localId: 'mini-${contact.id}-${store.chats[contact.id]!.indexOf(m)}',
      senderId: m.mine ? miniDemoMe.id : contact.id,
      senderName: m.mine ? miniDemoMe.short : contact.short,
      avatarUrl: '$miniPhoneAssets${m.mine ? miniDemoMe.image : contact.image}',
      text: m.text,
      currentTime: m.time,
      isMe: m.mine,
      status: 'sent',
    ),
    showDateDivider: false,
    style: kPrivateChatStyle,
  );
  void _sendChat() {
    if (messageInput.text.trim().isEmpty) return;
    final person = contact;
    store.send(person, messageInput.text);
    messageInput.clear();
    _update(() => typing = true);
    _scrollToEnd(chatScroll);
    _replyTimers.add(
      Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        store.reply(person);
        if (screen == MiniPhoneScreen.chat && contact == person) {
          _update(() => typing = false);
          _scrollToEnd(chatScroll);
        }
      }),
    );
  }
}
