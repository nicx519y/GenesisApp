part of 'mini_phone_page.dart';

extension _MiniPhoneConversations on _MiniPhonePageState {
  Widget _messages() => _panel(
    'Messages',
    ListView(children: [for (final p in miniDemoPeople) _contactRow(p)]),
  );
  Widget _contacts() => _panel(
    'New message',
    Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
          child: TextField(
            onChanged: (v) => _update(() => search = v),
            style: miniStyle(14),
            decoration: InputDecoration(
              hintText: 'Search characters',
              hintStyle: miniStyle(14, FontWeight.w400, miniPlaceholder),
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: MiniIcon('search', size: 18),
              ),
              filled: true,
              fillColor: GenesisColors.darkFaintFill,
              border: OutlineInputBorder(
                borderRadius: miniInputRadius,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  'Characters · 4',
                  style: miniStyle(12, FontWeight.w400, miniSecondary),
                ),
              ),
              for (final p in miniDemoPeople.where(
                (p) => p.name.toLowerCase().contains(search.toLowerCase()),
              ))
                _contactRow(p, contacts: true),
              if (!miniDemoPeople.any(
                (p) => p.name.toLowerCase().contains(search.toLowerCase()),
              ))
                Padding(
                  padding: const EdgeInsets.all(miniPageInset),
                  child: Text('No characters found.', style: miniStyle(14)),
                ),
              Padding(
                padding: const EdgeInsets.all(miniPageInset),
                child: Text(
                  'This conversation is between you and the character.',
                  style: miniStyle(12, FontWeight.w400, miniSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    subtitle: 'Choose someone from this world.',
  );
  Widget _contactRow(MiniDemoPerson p, {bool contacts = false}) {
    final history = store.chats[p.id]!;
    final modified = history.length > (p == miniDemoPeople.first ? 4 : 1);
    final preview = contacts
        ? p.role
        : modified
        ? '${history.last.mine ? 'You: ' : ''}${history.last.text}'
        : p.preview;
    return InkWell(
      onTap: () => _openChat(p),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: miniPageInset,
          vertical: 16,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: miniDivider, width: .5)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MiniAvatar(p, size: 48),
                if (!contacts && store.unread(p) > 0)
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
                  Text(p.short, style: miniStyle(14, FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: miniStyle(12, FontWeight.w400, miniSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (contacts)
              const MiniIcon('reply', size: 18, color: miniSecondary)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    modified ? 'now' : p.time,
                    style: miniStyle(12, FontWeight.w400, miniSecondary),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chat() => SafeArea(
    child: Column(
      children: [
        _navigation(contact.name, person: contact),
        Expanded(
          child: ListView(
            controller: chatScroll,
            padding: const EdgeInsets.all(miniPageInset),
            children: [
              Center(
                child: Text(
                  'Day 2 · Private conversation',
                  style: miniStyle(12, FontWeight.w400, miniSecondary),
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
              if (store.chats[contact.id]!.length < 5)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final s in ["I'll be there.", 'What happened?'])
                        _button(s, () => _update(() => messageInput.text = s)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            miniPageInset,
            10,
            miniPageInset,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _input(
                  messageInput,
                  'Message ${contact.short}…',
                  limit: 1000,
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(messageInput.text.trim().isEmpty ? null : _sendChat),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _message(MiniDemoMessage m) => Align(
    alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .75,
      ),
      margin: const EdgeInsets.only(bottom: kLocationChatMessageBottomGap),
      padding: kChatScenePlateBubblePadding,
      decoration: BoxDecoration(
        color: m.mine ? kChatSelfBubbleColor : kChatScenePlateAiBubbleColor,
        borderRadius: BorderRadius.circular(kChatBubbleRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(m.text, style: miniStyle(14)),
          const SizedBox(height: 4),
          Text(m.time, style: miniStyle(12, FontWeight.w400, miniTertiary)),
        ],
      ),
    ),
  );
  void _sendChat() {
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
