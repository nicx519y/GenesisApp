import 'dart:convert';

class MultipartBody {
  MultipartBody({
    String? boundary,
    Map<String, String> fields = const <String, String>{},
    List<MultipartFilePart> files = const <MultipartFilePart>[],
  }) : boundary = boundary ?? multipartBoundary(),
       fields = Map<String, String>.unmodifiable(fields),
       files = List<MultipartFilePart>.unmodifiable(files);

  factory MultipartBody.singleFile({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String fieldName = 'file',
    Map<String, String> fields = const <String, String>{},
    String? boundary,
  }) {
    return MultipartBody(
      boundary: boundary,
      fields: fields,
      files: [
        MultipartFilePart(
          fieldName: fieldName,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        ),
      ],
    );
  }

  final String boundary;
  final Map<String, String> fields;
  final List<MultipartFilePart> files;

  String get contentType => 'multipart/form-data; boundary=$boundary';

  List<int> toBytes() {
    final out = <int>[];
    void addText(String value) => out.addAll(utf8.encode(value));

    for (final entry in fields.entries) {
      addText('--$boundary\r\n');
      addText(
        'Content-Disposition: form-data; '
        'name="${entry.key}"\r\n\r\n',
      );
      addText('${entry.value}\r\n');
    }

    for (final file in files) {
      addText('--$boundary\r\n');
      addText(
        'Content-Disposition: form-data; '
        'name="${file.fieldName}"; '
        'filename="${file.filename}"\r\n',
      );
      addText('Content-Type: ${file.contentType}\r\n\r\n');
      out.addAll(file.bytes);
      addText('\r\n');
    }

    addText('--$boundary--\r\n');
    return out;
  }
}

class MultipartFilePart {
  const MultipartFilePart({
    required this.fieldName,
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final String fieldName;
  final List<int> bytes;
  final String filename;
  final String contentType;
}

String multipartBoundary() {
  return '----genesis-${DateTime.now().microsecondsSinceEpoch}';
}
