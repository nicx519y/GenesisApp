import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../network/json_utils.dart';

class MessageCategoryListPage extends StatefulWidget {
  const MessageCategoryListPage({
    super.key,
    required this.title,
    required this.category,
    required this.emptyText,
    this.onNotificationsRead,
  });

  final String title;
  final String category;
  final String emptyText;
  final Future<void> Function()? onNotificationsRead;

  @override
  State<MessageCategoryListPage> createState() =>
      _MessageCategoryListPageState();
}

class _MessageCategoryListPageState extends State<MessageCategoryListPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _items = <_NotificationItem>[];
  var _page = 1;
  var _total = 0;
  var _loading = true;
  var _loadingMore = false;
  Object? _error;

  bool get _hasMore => _items.length < _total;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_enterCategory());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) return;
    if (!_hasMore) return;
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _enterCategory() async {
    try {
      await AppServicesScope.read(
        context,
      ).api.v1.messages.markNotificationsRead(category: widget.category);
      await widget.onNotificationsRead?.call();
    } catch (error, stackTrace) {
      debugPrint(
        '[Messages] markNotificationsRead failed category=${widget.category}: $error',
      );
      debugPrint('[Messages] markNotificationsRead stacktrace:\n$stackTrace');
    }
    if (!mounted) return;
    await _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _page = 1;
      _total = 0;
      _items.clear();
    });
    await _loadPage(1, replace: true);
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadPage(_page + 1, replace: false);
  }

  Future<void> _loadPage(int page, {required bool replace}) async {
    try {
      final data = await AppServicesScope.read(context).api.v1.messages
          .notifications(category: widget.category, pn: page, rn: _pageSize);
      final rawItems = asJsonList(data['list']);
      final items = rawItems
          .map((item) => _NotificationItem.fromJson(asJsonMap(item)))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        if (replace) {
          _items
            ..clear()
            ..addAll(items);
        } else {
          _items.addAll(items);
        }
        _page = page;
        _total = asInt(data['total'], fallback: _items.length);
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          const Center(
            child: Text(
              'Failed to load messages.',
              style: TextStyle(
                color: Color(0xFF94979E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
          Center(
            child: Text(
              widget.emptyText,
              style: const TextStyle(
                color: Color(0xFF94979E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 18 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _NotificationCard(
          key: ValueKey(_items[index].id),
          item: _items[index],
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({super.key, required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: item.isRead ? const Color(0xFFF7F8FA) : const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!item.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5, right: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE02424),
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.createdAtText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.createdAtText,
                    style: const TextStyle(
                      color: Color(0xFF94979E),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    return _NotificationItem(
      id: asString(json['id']),
      message: asString(json['message'], fallback: 'New message'),
      isRead: asBool(json['is_read']),
      createdAt: asDateTime(json['created_at']),
    );
  }

  final String id;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  String get createdAtText {
    final value = createdAt;
    if (value == null) return '';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
