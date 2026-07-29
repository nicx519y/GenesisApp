import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _supportedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

void main(List<String> args) async {
  late final _Config config;
  try {
    config = _Config.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('');
    _printUsage(toStdErr: true);
    exitCode = 2;
    return;
  }

  if (config.showHelp) {
    _printUsage();
    return;
  }

  final error = config.validate();
  if (error != null) {
    stderr.writeln(error);
    stderr.writeln('');
    _printUsage(toStdErr: true);
    exitCode = 2;
    return;
  }

  final inputType = FileSystemEntity.typeSync(config.inputPath!);
  if (inputType == FileSystemEntityType.notFound) {
    stderr.writeln('Input does not exist: ${config.inputPath}');
    exitCode = 2;
    return;
  }

  final outputDir = Directory(config.outputPath!);
  if (!config.dryRun) {
    await outputDir.create(recursive: true);
  }

  final files = _findInputFiles(
    inputPath: config.inputPath!,
    inputType: inputType,
    recursive: config.recursive,
  );

  if (files.isEmpty) {
    stderr.writeln('No supported image files found.');
    exitCode = 1;
    return;
  }

  final inputRoot = inputType == FileSystemEntityType.directory
      ? Directory(config.inputPath!).absolute.path
      : File(config.inputPath!).absolute.parent.path;
  var processed = 0;
  var skipped = 0;
  var failed = 0;
  var inputBytesTotal = 0;
  var outputBytesTotal = 0;

  for (final file in files) {
    try {
      final result = await _processFile(
        file: file,
        inputRoot: inputRoot,
        outputDir: outputDir,
        config: config,
      );
      inputBytesTotal += result.inputBytes;
      outputBytesTotal += result.outputBytes;
      if (result.skipped) {
        skipped += 1;
      } else {
        processed += 1;
      }
      stdout.writeln(result.message);
    } on Object catch (error) {
      failed += 1;
      stderr.writeln('FAIL ${file.path}: $error');
    }
  }

  final before = _formatBytes(inputBytesTotal);
  final after = _formatBytes(outputBytesTotal);
  stdout.writeln(
    'Done: $processed processed, $skipped skipped, $failed failed. '
    'Input $before, output $after.',
  );

  if (failed > 0) {
    exitCode = 1;
  }
}

Future<_ProcessResult> _processFile({
  required File file,
  required String inputRoot,
  required Directory outputDir,
  required _Config config,
}) async {
  final inputBytes = await file.readAsBytes();
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    throw StateError('decode failed');
  }

  var image = img.bakeOrientation(decoded);
  final originalWidth = image.width;
  final originalHeight = image.height;
  final target = _targetSize(
    width: image.width,
    height: image.height,
    scale: config.scale,
    maxWidth: config.maxWidth,
    maxHeight: config.maxHeight,
  );

  if (target.width != image.width || target.height != image.height) {
    image = img.copyResize(
      image,
      width: target.width,
      height: target.height,
      interpolation: img.Interpolation.average,
    );
  }

  final relativePath = _relativePath(file.absolute.path, inputRoot);
  final outputPath = _targetOutputPath(
    outputDir: outputDir.absolute.path,
    relativeInputPath: relativePath,
    format: config.format,
    width: image.width,
    height: image.height,
    appendSize: config.appendSize,
  );
  final outputFile = File(outputPath);

  if (!config.overwrite && outputFile.existsSync()) {
    return _ProcessResult(
      inputBytes: inputBytes.length,
      outputBytes: outputFile.lengthSync(),
      skipped: true,
      message: 'SKIP exists ${outputFile.path}',
    );
  }

  final outputBytes = _encodeImage(
    image: image,
    sourcePath: file.path,
    format: config.format,
    jpegQuality: config.quality,
    pngLevel: config.pngLevel,
  );

  if (!config.dryRun) {
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(outputBytes, flush: true);
  }

  final ratio = inputBytes.isEmpty
      ? '0.0%'
      : '${(outputBytes.length / inputBytes.length * 100).toStringAsFixed(1)}%';
  final action = config.dryRun ? 'DRY' : 'OK';
  return _ProcessResult(
    inputBytes: inputBytes.length,
    outputBytes: outputBytes.length,
    skipped: false,
    message:
        '$action ${file.path} -> ${outputFile.path} '
        '$originalWidth x $originalHeight => ${image.width} x ${image.height}, '
        '${_formatBytes(inputBytes.length)} => ${_formatBytes(outputBytes.length)} '
        '($ratio)',
  );
}

List<File> _findInputFiles({
  required String inputPath,
  required FileSystemEntityType inputType,
  required bool recursive,
}) {
  if (inputType == FileSystemEntityType.file) {
    final file = File(inputPath);
    return _isSupportedImage(file.path) ? [file] : const [];
  }

  final dir = Directory(inputPath);
  return dir
      .listSync(recursive: recursive, followLinks: false)
      .whereType<File>()
      .where((file) => _isSupportedImage(file.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

bool _isSupportedImage(String path) {
  return _supportedExtensions.contains(_extension(path).toLowerCase());
}

_ImageSize _targetSize({
  required int width,
  required int height,
  required double? scale,
  required int? maxWidth,
  required int? maxHeight,
}) {
  var ratio = scale ?? 1.0;
  if (maxWidth != null && width > maxWidth) {
    ratio = math.min(ratio, maxWidth / width);
  }
  if (maxHeight != null && height > maxHeight) {
    ratio = math.min(ratio, maxHeight / height);
  }
  ratio = math.min(ratio, 1.0);

  return _ImageSize(
    width: math.max(1, (width * ratio).round()),
    height: math.max(1, (height * ratio).round()),
  );
}

Uint8List _encodeImage({
  required img.Image image,
  required String sourcePath,
  required _OutputFormat format,
  required int jpegQuality,
  required int pngLevel,
}) {
  final resolvedFormat = format == _OutputFormat.same
      ? _formatForExtension(_extension(sourcePath))
      : format;

  switch (resolvedFormat) {
    case _OutputFormat.jpg:
      return img.encodeJpg(image, quality: jpegQuality);
    case _OutputFormat.png:
      return img.encodePng(image, level: pngLevel);
    case _OutputFormat.webp:
      return img.encodeWebP(image);
    case _OutputFormat.same:
      throw StateError('unresolved output format');
  }
}

_OutputFormat _formatForExtension(String extension) {
  switch (extension.toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return _OutputFormat.jpg;
    case '.png':
      return _OutputFormat.png;
    case '.webp':
      return _OutputFormat.webp;
    default:
      throw StateError('unsupported extension: $extension');
  }
}

String _targetOutputPath({
  required String outputDir,
  required String relativeInputPath,
  required _OutputFormat format,
  required int width,
  required int height,
  required bool appendSize,
}) {
  final extension = format == _OutputFormat.same
      ? _extension(relativeInputPath)
      : format.extension;
  final targetRelative = _replaceExtension(
    relativeInputPath,
    extension,
    suffix: appendSize ? '_${width}_$height' : '',
  );
  return _joinPath(outputDir, targetRelative);
}

String _relativePath(String absolutePath, String rootPath) {
  final normalizedRoot = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  if (absolutePath.startsWith(normalizedRoot)) {
    return absolutePath.substring(normalizedRoot.length);
  }
  return _basename(absolutePath);
}

String _replaceExtension(String path, String extension, {String suffix = ''}) {
  final lastSeparator = math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
  final lastDot = path.lastIndexOf('.');
  if (lastDot > lastSeparator) {
    return '${path.substring(0, lastDot)}$suffix$extension';
  }
  return '$path$suffix$extension';
}

String _extension(String path) {
  final base = _basename(path);
  final dot = base.lastIndexOf('.');
  if (dot < 0) return '';
  return base.substring(dot);
}

String _basename(String path) {
  final lastSeparator = math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
  return lastSeparator < 0 ? path : path.substring(lastSeparator + 1);
}

String _joinPath(String left, String right) {
  if (left.endsWith('/') || left.endsWith('\\')) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KiB';
  final mib = kib / 1024;
  return '${mib.toStringAsFixed(2)} MiB';
}

void _printUsage({bool toStdErr = false}) {
  final output = '''
Usage:
  scripts/compress_images.sh --input <file-or-dir> --output <dir> [options]

Options:
  -i, --input <path>       Source image file or directory.
  -o, --output <dir>      Directory to write compressed images.
      --scale <ratio>     Proportional shrink ratio, greater than 0 and no more than 1.
      --max-width <px>    Maximum output width. Never upscales.
      --max-height <px>   Maximum output height. Never upscales.
      --format <format>   same, jpg, jpeg, png, or webp. Default: same.
      --quality <1-100>   JPEG quality. Default: 85.
      --png-level <0-9>   PNG compression level. Default: 9.
      --append-size       Add processed image dimensions before the extension.
      --recursive         Read input directories recursively.
      --overwrite         Replace existing output files.
      --dry-run           Print planned work without writing files.
  -h, --help              Show this help.
''';
  if (toStdErr) {
    stderr.write(output);
  } else {
    stdout.write(output);
  }
}

class _Config {
  _Config({
    required this.showHelp,
    required this.inputPath,
    required this.outputPath,
    required this.scale,
    required this.maxWidth,
    required this.maxHeight,
    required this.format,
    required this.quality,
    required this.pngLevel,
    required this.appendSize,
    required this.recursive,
    required this.overwrite,
    required this.dryRun,
  });

  final bool showHelp;
  final String? inputPath;
  final String? outputPath;
  final double? scale;
  final int? maxWidth;
  final int? maxHeight;
  final _OutputFormat format;
  final int quality;
  final int pngLevel;
  final bool appendSize;
  final bool recursive;
  final bool overwrite;
  final bool dryRun;

  static _Config parse(List<String> args) {
    var showHelp = false;
    String? inputPath;
    String? outputPath;
    double? scale;
    int? maxWidth;
    int? maxHeight;
    var format = _OutputFormat.same;
    var quality = 85;
    var pngLevel = 9;
    var appendSize = false;
    var recursive = false;
    var overwrite = false;
    var dryRun = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      String requireValue() {
        if (index + 1 >= args.length) {
          throw FormatException('Missing value for $arg');
        }
        index += 1;
        return args[index];
      }

      switch (arg) {
        case '-h':
        case '--help':
          showHelp = true;
          break;
        case '-i':
        case '--input':
          inputPath = requireValue();
          break;
        case '-o':
        case '--output':
          outputPath = requireValue();
          break;
        case '--scale':
          scale = _parseDouble(requireValue(), arg);
          break;
        case '--max-width':
          maxWidth = _parseInt(requireValue(), arg);
          break;
        case '--max-height':
          maxHeight = _parseInt(requireValue(), arg);
          break;
        case '--format':
          format = _parseFormat(requireValue());
          break;
        case '--quality':
          quality = _parseInt(requireValue(), arg);
          break;
        case '--png-level':
          pngLevel = _parseInt(requireValue(), arg);
          break;
        case '--append-size':
          appendSize = true;
          break;
        case '--recursive':
          recursive = true;
          break;
        case '--overwrite':
          overwrite = true;
          break;
        case '--dry-run':
          dryRun = true;
          break;
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }

    return _Config(
      showHelp: showHelp,
      inputPath: inputPath,
      outputPath: outputPath,
      scale: scale,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      format: format,
      quality: quality,
      pngLevel: pngLevel,
      appendSize: appendSize,
      recursive: recursive,
      overwrite: overwrite,
      dryRun: dryRun,
    );
  }

  String? validate() {
    if (showHelp) return null;
    if (inputPath == null || inputPath!.trim().isEmpty) {
      return 'Missing required --input path.';
    }
    if (outputPath == null || outputPath!.trim().isEmpty) {
      return 'Missing required --output directory.';
    }
    if (scale != null && (scale! <= 0 || scale! > 1)) {
      return '--scale must be greater than 0 and no more than 1.';
    }
    if (maxWidth != null && maxWidth! <= 0) {
      return '--max-width must be greater than 0.';
    }
    if (maxHeight != null && maxHeight! <= 0) {
      return '--max-height must be greater than 0.';
    }
    if (quality < 1 || quality > 100) {
      return '--quality must be between 1 and 100.';
    }
    if (pngLevel < 0 || pngLevel > 9) {
      return '--png-level must be between 0 and 9.';
    }
    return null;
  }
}

double _parseDouble(String value, String option) {
  final parsed = double.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid value for $option: $value');
  }
  return parsed;
}

int _parseInt(String value, String option) {
  final parsed = int.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid value for $option: $value');
  }
  return parsed;
}

_OutputFormat _parseFormat(String value) {
  switch (value.trim().toLowerCase()) {
    case 'same':
      return _OutputFormat.same;
    case 'jpg':
    case 'jpeg':
      return _OutputFormat.jpg;
    case 'png':
      return _OutputFormat.png;
    case 'webp':
      return _OutputFormat.webp;
    default:
      throw FormatException('Unsupported format: $value');
  }
}

enum _OutputFormat {
  same(''),
  jpg('.jpg'),
  png('.png'),
  webp('.webp');

  const _OutputFormat(this.extension);

  final String extension;
}

class _ImageSize {
  const _ImageSize({required this.width, required this.height});

  final int width;
  final int height;
}

class _ProcessResult {
  const _ProcessResult({
    required this.inputBytes,
    required this.outputBytes,
    required this.skipped,
    required this.message,
  });

  final int inputBytes;
  final int outputBytes;
  final bool skipped;
  final String message;
}
