/// Recoverable Mock content must overflow the viewport so browsing proves a
/// real content scroll, rather than dragging the sheet above a one-line event.
String tickEventContent(String attempt) => List.generate(
  64,
  (index) => 'Isolated world event $attempt; passage ${index + 1}.',
).join('\n');
