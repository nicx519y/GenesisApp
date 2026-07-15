import '../json_utils.dart';

class GemRecordList {
  const GemRecordList({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory GemRecordList.fromJson(Map<String, dynamic> json) {
    final items = json['list'] is List
        ? (json['list'] as List)
              .whereType<Map>()
              .map((item) => GemRecordItem.fromJson(asJsonMap(item)))
              .toList(growable: false)
        : const <GemRecordItem>[];
    return GemRecordList(
      items: items,
      total: asInt(json['total']),
      page: asInt(json['pn'], fallback: 1),
      pageSize: asInt(json['rn'], fallback: items.length),
    );
  }

  final List<GemRecordItem> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;
}

class GemRecordItem {
  const GemRecordItem({
    required this.ledgerId,
    required this.amount,
    required this.scene,
    required this.reasonCode,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.expiresAt,
    this.worldName = '',
    this.worldId = '',
    this.orderId = '',
  });

  factory GemRecordItem.fromJson(Map<String, dynamic> json) {
    final world = json['world'] is Map
        ? asJsonMap(json['world'])
        : const <String, dynamic>{};
    return GemRecordItem(
      ledgerId: asString(json['ledger_id']),
      amount: asInt(json['amount']),
      scene: asString(json['scene']),
      reasonCode: asString(json['reason_code']),
      title: asString(json['title']),
      subtitle: asString(json['subtitle']),
      createdAt: asInt(json['created_at']),
      expiresAt: asInt(json['expires_at']),
      worldName: asString(
        json['world_name'],
        fallback: asString(
          json['worldName'],
          fallback: asString(
            world['world_name'],
            fallback: asString(world['name']),
          ),
        ),
      ),
      worldId: asString(
        json['world_id'],
        fallback: asString(
          json['wid'],
          fallback: asString(
            world['world_id'],
            fallback: asString(world['wid']),
          ),
        ),
      ),
      orderId: asString(
        json['order_id'],
        fallback: asString(
          json['order_no'],
          fallback: asString(
            json['orderNo'],
            fallback: asString(
              json['transaction_id'],
              fallback: asString(json['trade_no']),
            ),
          ),
        ),
      ),
    );
  }

  final String ledgerId;
  final int amount;
  final String scene;
  final String reasonCode;
  final String title;
  final String subtitle;
  final int createdAt;
  final int expiresAt;
  final String worldName;
  final String worldId;
  final String orderId;
}
