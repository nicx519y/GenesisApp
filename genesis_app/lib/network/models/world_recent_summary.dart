/// One complete P5 generation. Its position is determined by the server.
class WorldRecentSummary {
  const WorldRecentSummary({required this.body, required this.tickNo});

  final String body;
  final int tickNo;
}

class WorldRecentSummaryPage {
  const WorldRecentSummaryPage({
    required this.items,
    required this.hasMore,
    required this.cursor,
  });

  final List<WorldRecentSummary> items;
  final bool hasMore;
  final String cursor;

  factory WorldRecentSummaryPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final hasMore = json['has_more'];
    final cursor = json['cursor'];
    if (items is! List ||
        hasMore is! bool ||
        cursor is! String ||
        (hasMore && cursor.isEmpty)) {
      throw const FormatException('Invalid recent summary page');
    }
    return WorldRecentSummaryPage(
      items: List.unmodifiable(
        items.map((item) {
          if (item is! Map ||
              item['body'] is! String ||
              item['tick_no'] is! int) {
            throw const FormatException('Invalid recent summary item');
          }
          return WorldRecentSummary(
            body: item['body'] as String,
            tickNo: item['tick_no'] as int,
          );
        }),
      ),
      hasMore: hasMore,
      cursor: cursor,
    );
  }
}
