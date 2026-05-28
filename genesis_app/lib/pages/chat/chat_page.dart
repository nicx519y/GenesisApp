import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../network/direct_message_message_store.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.peerUid,
    this.peerName = '',
    this.peerAvatar = '',
    this.conversationId = '',
  });

  final String peerUid;
  final String peerName;
  final String peerAvatar;
  final String conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController _scrollController;
  final _textController = TextEditingController();
  final Map<String, DirectMessageMessageRecord> _failedLocalMessages = {};
  Timer? _pollTimer;
  late DirectMessageMessageStore _messageStore;
  bool _loadedLocalMessages = false;
  bool _syncing = false;
  bool _sending = false;
  bool _loadingOlder = false;
  String _myUid = '';

  String get _peerUid => widget.peerUid.trim();

  @override
  void initState() {
    super.initState();
    _scrollController = _createScrollController();
    _messageStore = AppServicesScope.read(context).directMessageMessages;
    unawaited(_bootstrap());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_syncLatest());
    });
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peerUid.trim() == _peerUid) return;
    _textController.clear();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _scrollController = _createScrollController();
    setState(() {
      _failedLocalMessages.clear();
      _loadedLocalMessages = false;
      _syncing = false;
      _sending = false;
      _loadingOlder = false;
    });
    unawaited(_bootstrap());
  }

  ScrollController _createScrollController() {
    return ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (!mounted) return;
    setState(() {
      _myUid = uid;
      _failedLocalMessages.clear();
    });
    try {
      await _messageStore.loadFromDb(_peerUid);
      if (!mounted) return;
      final hasCachedMessages =
          _messageStore.orderedMessageIds.value.isNotEmpty;
      if (hasCachedMessages) setState(() => _loadedLocalMessages = true);
      await _syncLatest(keepAtBottom: true);
      if (!hasCachedMessages && mounted) {
        setState(() => _loadedLocalMessages = true);
      }
    } catch (error, stackTrace) {
      debugPrint('[ChatPage][DM] bootstrap failed: $error');
      debugPrint('[ChatPage][DM] stacktrace:\n$stackTrace');
      if (mounted) setState(() => _loadedLocalMessages = true);
    }
  }

  Future<void> _syncLatest({bool keepAtBottom = false}) async {
    if (_syncing || _peerUid.isEmpty) return;
    final shouldStickToBottom = keepAtBottom || _isNearBottom();
    setState(() => _syncing = true);
    try {
      await _messageStore.syncLatest(_peerUid);
      await _markRead();
      if (shouldStickToBottom) _scrollToBottom(jump: true);
    } catch (error, stackTrace) {
      debugPrint('[ChatPage][DM] sync failed: $error');
      debugPrint('[ChatPage][DM] stacktrace:\n$stackTrace');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _markRead() async {
    if (_peerUid.isEmpty) return;
    try {
      final services = AppServicesScope.read(context);
      await services.api.v1.dm.markRead(peerUid: _peerUid);
      await services.directMessageConversations.markPeerRead(_peerUid);
    } catch (error) {
      debugPrint('[ChatPage][DM] mark read failed: $error');
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingOlder || _peerUid.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 120) return;
    if (!_messageStore.hasMoreOlder) return;
    unawaited(_loadOlder());
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    return position.pixels < 80;
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      await _messageStore.loadOlder(_peerUid);
    } catch (error, stackTrace) {
      debugPrint('[ChatPage][DM] load older failed: $error');
      debugPrint('[ChatPage][DM] stacktrace:\n$stackTrace');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _peerUid.isEmpty) return;
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sending = true);
    final senderUid = _myUid.trim().isEmpty ? '__anonymous__' : _myUid.trim();
    final localMessageId = await _messageStore.insertLocalMessage(
      peerUid: _peerUid,
      senderUid: senderUid,
      content: content,
    );
    if (!mounted) return;
    final services = AppServicesScope.read(context);
    _textController.clear();
    _scrollToBottom();

    try {
      final data = await services.api.v1.dm.send(
        peerUid: _peerUid,
        content: content,
      );
      final message = data['message'];
      if (message is Map) {
        await _messageStore.replaceLocalMessage(
          peerUid: _peerUid,
          localMessageId: localMessageId,
          serverMessage: asJsonMap(message),
        );
      }
      final conversation = data['conversation'];
      if (conversation is Map) {
        await services.directMessageConversations.mergeConversationJson(
          asJsonMap(conversation),
        );
      }
      if (!mounted) return;
      _scrollToBottom();
    } catch (error, stackTrace) {
      debugPrint('[ChatPage][DM] send failed: $error');
      debugPrint('[ChatPage][DM] stacktrace:\n$stackTrace');
      final localRecord = _messageStore.rowListenable(localMessageId)?.value;
      await _messageStore.deleteMessage(
        peerUid: _peerUid,
        messageId: localMessageId,
      );
      if (localRecord != null && mounted) {
        setState(() {
          _failedLocalMessages[localMessageId] =
              DirectMessageMessageRecord.fromJson(
                localRecord.toJson(),
                localId: localRecord.localId,
                sendStatus: DirectMessageSendStatus.failed,
              );
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.minScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  VoidCallback? _avatarTapFor(DirectMessageMessageRecord record) {
    final senderUid = record.senderUid.trim();
    final myUid = _myUid.trim();
    if (senderUid.isEmpty || (myUid.isNotEmpty && senderUid == myUid)) {
      return null;
    }
    return () {
      Navigator.of(
        context,
      ).pushNamed(RouteNames.userInfo, arguments: {'uid': senderUid});
    };
  }

  @override
  Widget build(BuildContext context) {
    final peerTitle = firstNonEmpty([
      widget.peerName,
      _peerUid,
      'Direct message',
    ]);
    return Scaffold(
      backgroundColor: const Color(0xFFE7E1E5),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          ChatHeader(
            title: peerTitle,
            subtitle: '',
            connected: !_syncing,
            connecting: _syncing,
            onBack: () => Navigator.of(context).maybePop(),
            showTitleIcon: false,
            showSubtitle: false,
            showMoreButton: false,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: _buildMessages(),
            ),
          ),
          ChatComposer(
            controller: _textController,
            inputEnabled: _peerUid.isNotEmpty,
            sendEnabled: _peerUid.isNotEmpty && !_sending,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _messageStore.orderedMessageIds,
      builder: (context, messageIds, _) {
        final renderIds = _renderMessageIds(messageIds);
        if (!_loadedLocalMessages && renderIds.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final bottomSpacerHeight = _bottomSpacerHeight(
              viewportHeight: constraints.maxHeight,
              messageIds: renderIds,
            );
            return ListView.builder(
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              itemCount: renderIds.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SizedBox(height: bottomSpacerHeight);
                }
                if (index == renderIds.length + 1) {
                  return _loadingOlder
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox.shrink();
                }
                final messageIndex = renderIds.length - index;
                final messageId = renderIds[messageIndex];
                final failedRecord = _failedLocalMessages[messageId];
                if (failedRecord != null) {
                  final previous = messageIndex == 0
                      ? null
                      : _recordForMessageId(renderIds[messageIndex - 1]);
                  return ChatMessageRow(
                    key: ValueKey(messageId),
                    message: _messageVm(failedRecord),
                    onAvatarTap: _avatarTapFor(failedRecord),
                    showDateDivider: shouldShowChatDateDivider(
                      previous?.createdAt,
                      failedRecord.createdAt,
                    ),
                  );
                }
                final listenable = _messageStore.rowListenable(messageId);
                if (listenable == null) return const SizedBox.shrink();
                return ValueListenableBuilder<DirectMessageMessageRecord>(
                  key: ValueKey(messageId),
                  valueListenable: listenable,
                  builder: (context, record, _) {
                    final previous = messageIndex == 0
                        ? null
                        : _recordForMessageId(renderIds[messageIndex - 1]);
                    return ChatMessageRow(
                      message: _messageVm(record),
                      onAvatarTap: _avatarTapFor(record),
                      showDateDivider: shouldShowChatDateDivider(
                        previous?.createdAt,
                        record.createdAt,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  double _bottomSpacerHeight({
    required double viewportHeight,
    required List<String> messageIds,
  }) {
    if (messageIds.isEmpty || !viewportHeight.isFinite) return 0;
    var estimatedContentHeight = 30.0;
    DirectMessageMessageRecord? previous;
    for (final messageId in messageIds) {
      final record = _recordForMessageId(messageId);
      if (record == null) continue;
      if (shouldShowChatDateDivider(previous?.createdAt, record.createdAt)) {
        estimatedContentHeight += 22;
      }
      estimatedContentHeight += _estimatedMessageRowHeight(record);
      previous = record;
    }
    final spacerHeight = viewportHeight - estimatedContentHeight;
    return spacerHeight > 0 ? spacerHeight : 0;
  }

  double _estimatedMessageRowHeight(DirectMessageMessageRecord record) {
    final isMe = _myUid.trim().isNotEmpty && record.senderUid == _myUid.trim();
    final width = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = width * (isMe ? 0.68 : 0.72);
    final charsPerLine = (maxBubbleWidth / 8).floor().clamp(12, 42).toInt();
    final textLength = record.content.trim().isEmpty
        ? 1
        : record.content.trim().length;
    final lineCount = (textLength / charsPerLine).ceil().clamp(1, 8).toInt();
    final bubbleHeight = 26 + lineCount * 16;
    final rowBodyHeight = isMe ? bubbleHeight : 22 + bubbleHeight;
    final rowHeight = rowBodyHeight < 40 ? 40 : rowBodyHeight;
    return rowHeight + 24;
  }

  List<String> _renderMessageIds(List<String> dbMessageIds) {
    final records = <DirectMessageMessageRecord>[];
    for (final id in dbMessageIds) {
      final record = _messageStore.rowListenable(id)?.value;
      if (record != null) records.add(record);
    }
    records.addAll(_failedLocalMessages.values);
    records.sort((a, b) {
      final byTime = a.sortValue.compareTo(b.sortValue);
      if (byTime != 0) return byTime;
      return a.messageId.compareTo(b.messageId);
    });
    return records.map((record) => record.messageId).toList(growable: false);
  }

  DirectMessageMessageRecord? _recordForMessageId(String messageId) {
    return _failedLocalMessages[messageId] ??
        _messageStore.rowListenable(messageId)?.value;
  }

  ChatMessageVm _messageVm(DirectMessageMessageRecord record) {
    final isMe = _myUid.trim().isNotEmpty && record.senderUid == _myUid.trim();
    final senderName = isMe
        ? 'Me'
        : firstNonEmpty([widget.peerName, record.senderUid, _peerUid]);
    final messageId = int.tryParse(record.messageId);
    return ChatMessageVm(
      localId: record.messageId,
      messageId: messageId,
      senderId: record.senderUid,
      senderName: senderName,
      text: record.content,
      isMe: isMe,
      status: record.sendStatus,
      createdAt: record.createdAt,
    );
  }
}
