import 'package:flutter/material.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../shared/mini_phone_panel.dart';
import '../shared/mini_phone_list_requests.dart';

class MiniPhoneMessagesPage extends StatelessWidget {
  MiniPhoneMessagesPage({
    super.key,
    required this.store,
    required this.header,
    required this.onOpenChat,
  });
  final MiniPhoneStore store;
  final Widget header;
  final ValueChanged<PhonePerson> onOpenChat;
  late final _lists = MiniPhoneListRequests(store);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) => miniPhonePanel(
    header,
    _lists.build(
      'sessions',
      () => store.refreshSessions(next: true),
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final s in store.conversations)
            InkWell(
              key: ValueKey('mini-phone-conversation-${s.person.id}'),
              onTap: () => onOpenChat(s.person),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        miniPhonePersonAvatar(s.person, 48, radius: 8),
                        if (s.unreadCount > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: MiniBadge(s.unreadCount),
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
                                  s.person.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(14, FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 112,
                                ),
                                child: Text(
                                  s.lastMessage?.currentTime ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: miniStyle(
                                    11,
                                    FontWeight.w400,
                                    miniTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 60),
                            child: Text(
                              '${s.lastMessage?.senderId == store.uid ? 'You: ' : ''}${s.lastMessage?.content ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
