import 'genesis_ugc_text.dart';

/// Metadata only: never retains or prints the original user content.
class MalformedDisplayText implements Exception {
  MalformedDisplayText({
    required this.source,
    required this.length,
    required List<int> offsets,
  }) : offsets = List.unmodifiable(offsets);

  final String source;
  final int length;
  final List<int> offsets;

  @override
  String toString() =>
      'MalformedDisplayText(source: $source, length: $length, offsets: $offsets)';
}

/// Installed by telemetry only when reporting is enabled. Callers use fixed
/// component names, not user-provided values, for [source].
void Function(MalformedDisplayText diagnostic)? onMalformedDisplayText;

String genesisSafeDisplayText(String text, {required String source}) {
  final offsets = <int>[];
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit < 0xD800 || unit > 0xDFFF) continue;
    if (unit <= 0xDBFF && i + 1 < text.length) {
      final next = text.codeUnitAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        i++;
        continue;
      }
    }
    if (offsets.length < 8) offsets.add(i);
  }
  if (offsets.isEmpty) return text;
  onMalformedDisplayText?.call(
    MalformedDisplayText(source: source, length: text.length, offsets: offsets),
  );
  return normalizeGenesisUgcTextForDisplay(text);
}
