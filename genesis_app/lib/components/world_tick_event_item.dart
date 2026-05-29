import 'package:flutter/material.dart';

class WorldTickEventItem extends StatelessWidget {
  const WorldTickEventItem({
    super.key,
    required this.tick,
    required this.tickNumber,
    required this.fallbackBody,
    this.locationsById = const <String, Map<String, dynamic>>{},
    this.isLast = true,
    this.dateLabel,
    this.timeAgoLabel,
  });

  final Map<String, dynamic> tick;
  final int tickNumber;
  final String fallbackBody;
  final Map<String, Map<String, dynamic>> locationsById;
  final bool isLast;
  final String? dateLabel;
  final String? timeAgoLabel;

  @override
  Widget build(BuildContext context) {
    final tickResult = _tickResult(tick);
    final hasTickResult = tick['tick_result'] is Map;
    final createdAt = _tickDateTime(
      tickResult['created_at'] ?? tick['created_at'],
    );
    final date = dateLabel ?? _formatShortDate(createdAt);
    final timeAgo = timeAgoLabel ?? _relativeTime(createdAt);
    final body = _mapString(tickResult, const [
      'narrator',
    ], fallback: hasTickResult ? '' : fallbackBody);
    final paragraphs = _tickParagraphs(tickResult);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TickHeader(tickNumber: tickNumber, date: date, timeAgo: timeAgo),
          const SizedBox(height: 6),
          _GlobalEventCard(body: body),
          const SizedBox(height: 6),
          for (final paragraph in paragraphs) ...[
            _TickParagraphRow(
              paragraph: paragraph,
              locationsById: locationsById,
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

int worldTickEventNumber(Map<String, dynamic> tick, {int fallback = 0}) {
  return _mapInt(tick, const ['tick_index'], fallback: fallback);
}

class _TickHeader extends StatelessWidget {
  const _TickHeader({
    required this.tickNumber,
    required this.date,
    required this.timeAgo,
  });

  final int tickNumber;
  final String date;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tick $tickNumber${date.isEmpty ? '' : ' · $date'}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeAgo.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              timeAgo,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8F8F8F),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlobalEventCard extends StatelessWidget {
  const _GlobalEventCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 82,
            child: Text(
              'Global',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w400,
                color: Color(0xFF3B3B3B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickParagraphRow extends StatelessWidget {
  const _TickParagraphRow({
    required this.paragraph,
    required this.locationsById,
  });

  final Map<String, dynamic> paragraph;
  final Map<String, Map<String, dynamic>> locationsById;

  @override
  Widget build(BuildContext context) {
    final locationId = _mapString(paragraph, const ['location_id']);
    final mappedName = _locationName(locationId, locationsById);
    final name = mappedName.isEmpty
        ? _mapString(paragraph, const ['label'], fallback: locationId)
        : mappedName;
    final body = _mapString(paragraph, const [
      'text',
    ], fallback: _mapString(paragraph, const ['content', 'summary']));
    final characterDetails = _characterDetails(paragraph);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              name.isEmpty ? 'Location' : name,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF3B3B3B),
                  ),
                ),
                if (characterDetails.isNotEmpty) ...[
                  const SizedBox(height: 19.2),
                  Text(
                    characterDetails,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF3B3B3B),
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

String _formatShortDate(DateTime? value) {
  if (value == null) return '';
  return value.toLocal().toIso8601String().split('T').first;
}

String _relativeTime(DateTime? value) {
  if (value == null) return '';
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return '1 day ago';
  return '${diff.inDays} days ago';
}

DateTime? _tickDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}

List<Map<String, dynamic>> _tickParagraphs(Map<String, dynamic> tick) {
  final raw = tick['paragraphs'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}

Map<String, dynamic> _tickResult(Map<String, dynamic> tick) {
  final raw = tick['tick_result'];
  if (raw is Map) return raw.cast<String, dynamic>();
  return tick;
}

String _locationName(
  String locationId,
  Map<String, Map<String, dynamic>> locationsById,
) {
  final location = locationsById[locationId];
  if (location == null) return '';
  return _mapString(location, const ['location_name', 'name']);
}

String _characterDetails(Map<String, dynamic> paragraph) {
  final raw = paragraph['character_details'] ?? paragraph['character_deltas'];
  if (raw is! List) return '';
  final lines = raw
      .whereType<Map>()
      .map((item) {
        final detail = item.cast<String, dynamic>();
        final name = _mapString(detail, const ['name']);
        final delta = _mapString(detail, const ['delta']);
        return [name, delta].where((part) => part.isNotEmpty).join(' ');
      })
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return lines.join('\n');
}

int _mapInt(Map<String, dynamic> map, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

String _mapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}
