const int gemCentPerGem = 100;

int requireGemCent(Object? value, {required String fieldName}) {
  if (value is int) return value;
  throw FormatException('$fieldName must be an integer Gem cent value');
}

String formatGemCent(int value) {
  final negative = value < 0;
  final absolute = value.abs();
  final roundedTenths = (absolute + 5) ~/ 10;
  final whole = roundedTenths ~/ 10;
  final fraction = roundedTenths % 10;
  final groupedWhole = _formatGroupedInteger(whole);
  final sign = negative && roundedTenths != 0 ? '-' : '';
  return '$sign$groupedWhole.$fraction';
}

String _formatGroupedInteger(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index += 1) {
    final remaining = text.length - index;
    buffer.write(text[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
