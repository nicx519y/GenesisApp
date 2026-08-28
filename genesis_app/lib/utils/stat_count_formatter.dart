String formatStatCount(num value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();
  const units = [
    (threshold: 1000000000000, suffix: 'T'),
    (threshold: 1000000000, suffix: 'B'),
    (threshold: 1000000, suffix: 'M'),
    (threshold: 1000, suffix: 'K'),
  ];

  for (final unit in units) {
    if (absValue >= unit.threshold) {
      final shifted = absValue / unit.threshold;
      return '$sign${_trimDecimal(shifted.toStringAsFixed(1))}${unit.suffix}';
    }
  }

  if (value is int) return '$value';
  return _trimDecimal(value.toStringAsFixed(1));
}

String formatMessageCountLabel(num value) {
  final unit = value == 0 || value == 1 ? 'Message' : 'Messages';
  return '${formatStatCount(value)} $unit';
}

String formatPlayerCountLabel(num value) {
  final unit = value == 0 || value == 1 ? 'Player' : 'Players';
  return '${formatStatCount(value)} $unit';
}

String formatWorldStatsLabel({
  required int tickNo,
  required int subTickNo,
  required int messageCount,
  required int playerCount,
}) {
  final subTickLabel = subTickNo > 0 ? '-$subTickNo' : '';
  final parts = <String>[
    'Tick $tickNo$subTickLabel',
    formatMessageCountLabel(messageCount),
    if (playerCount >= 2) formatPlayerCountLabel(playerCount),
  ];
  return parts.join(' · ');
}

String _trimDecimal(String value) {
  return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
}
