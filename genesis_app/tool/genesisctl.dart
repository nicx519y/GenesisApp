import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  try {
    final options = _CliOptions.parse(args);
    final command = _buildCommand(options.rest);
    if (command.method == 'agent.world_chat') {
      final ok = await _runAgentWorldChatWithProgress(options, command);
      exitCode = ok ? 0 : 2;
      return;
    }
    final response = await _rpc(_effectiveOptions(options, command), command);
    const encoder = JsonEncoder.withIndent('  ');
    stdout.writeln(encoder.convert(response));
    final ok = response['ok'] == true;
    exitCode = ok ? 0 : 2;
  } catch (error) {
    stderr.writeln(error);
    stderr.writeln('');
    _printUsage();
    exitCode = 1;
  }
}

class _CliOptions {
  const _CliOptions({
    required this.host,
    required this.port,
    required this.token,
    required this.timeoutMs,
    required this.dryRun,
    required this.rest,
  });

  factory _CliOptions.parse(List<String> args) {
    var host = '127.0.0.1';
    var port = 17317;
    var token = Platform.environment['GENESIS_AGENT_CONTROL_TOKEN'] ?? '';
    var timeoutMs = 10000;
    var dryRun = false;
    final rest = <String>[];

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--host':
          host = _requiredOptionValue(args, ++index, arg);
          break;
        case '--port':
          port = int.parse(_requiredOptionValue(args, ++index, arg));
          break;
        case '--token':
          token = _requiredOptionValue(args, ++index, arg);
          break;
        case '--timeout-ms':
          timeoutMs = int.parse(_requiredOptionValue(args, ++index, arg));
          break;
        case '--dry-run':
          dryRun = true;
          break;
        default:
          rest.add(arg);
      }
    }

    if (token.trim().isEmpty) {
      throw const FormatException(
        'Missing --token or GENESIS_AGENT_CONTROL_TOKEN.',
      );
    }
    return _CliOptions(
      host: host,
      port: port,
      token: token.trim(),
      timeoutMs: timeoutMs,
      dryRun: dryRun,
      rest: rest,
    );
  }

  final String host;
  final int port;
  final String token;
  final int timeoutMs;
  final bool dryRun;
  final List<String> rest;

  _CliOptions withTimeoutMs(int timeoutMs) {
    return _CliOptions(
      host: host,
      port: port,
      token: token,
      timeoutMs: timeoutMs,
      dryRun: dryRun,
      rest: rest,
    );
  }
}

class _Command {
  const _Command(this.method, this.params);

  final String method;
  final Map<String, Object?> params;
}

_Command _buildCommand(List<String> args) {
  if (args.length < 2) {
    throw const FormatException('Command group and action are required.');
  }
  final group = args[0];
  final action = args[1];
  final tail = args.skip(2).toList();
  switch ('$group $action') {
    case 'app ping':
      return const _Command('app.ping', {});
    case 'app state':
      return const _Command('app.state', {});
    case 'app back':
      return const _Command('app.back', {});
    case 'app navigate':
      return _navigateCommand(tail);
    case 'auth state':
      return const _Command('auth.state', {});
    case 'auth clear':
      return const _Command('auth.clear', {});
    case 'world locations':
      return _worldLocationsCommand(tail);
    case 'agent world-chat':
      return _agentWorldChatCommand(tail);
    case 'config endpoint':
      return _endpointCommand(tail);
    case 'cache clear':
      return _cacheCommand(tail);
    case 'diagnostics snapshot':
      return const _Command('diagnostics.snapshot', {});
  }
  throw FormatException('Unknown command: ${args.join(' ')}');
}

_Command _navigateCommand(List<String> args) {
  if (args.isEmpty) {
    throw const FormatException('Route is required for app navigate.');
  }
  final params = <String, Object?>{'route': args[0]};
  for (var index = 1; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--replace':
        params['replace'] = true;
        break;
      case '--clear-stack':
        params['clearStack'] = true;
        break;
      case '--arg':
        final pair = _requiredOptionValue(args, ++index, arg);
        final split = pair.indexOf('=');
        if (split <= 0) {
          throw const FormatException('--arg must be key=value.');
        }
        params[pair.substring(0, split)] = pair.substring(split + 1);
        break;
      default:
        throw FormatException('Unknown app navigate option: $arg');
    }
  }
  return _Command('app.navigate', params);
}

_Command _worldLocationsCommand(List<String> args) {
  final params = <String, Object?>{};
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--wid':
      case '--world-id':
        params['wid'] = _requiredOptionValue(args, ++index, arg);
        break;
      default:
        throw FormatException('Unknown world locations option: $arg');
    }
  }
  if ((params['wid']?.toString().trim() ?? '').isEmpty) {
    throw const FormatException('--wid is required.');
  }
  return _Command('world.locations', params);
}

_Command _agentWorldChatCommand(List<String> args) {
  final params = <String, Object?>{};
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--wid':
      case '--world-id':
        params['wid'] = _requiredOptionValue(args, ++index, arg);
        break;
      case '--location-id':
        params['locationId'] = _requiredOptionValue(args, ++index, arg);
        break;
      case '--count':
      case '--messages':
        params['count'] = int.parse(_requiredOptionValue(args, ++index, arg));
        break;
      case '--reply-timeout-seconds':
        params['replyTimeoutSeconds'] = int.parse(
          _requiredOptionValue(args, ++index, arg),
        );
        break;
      case '--seed-message':
        params['seedMessage'] = _requiredOptionValue(args, ++index, arg);
        break;
      default:
        throw FormatException('Unknown agent world-chat option: $arg');
    }
  }
  return _Command('agent.world_chat', params);
}

_Command _endpointCommand(List<String> args) {
  if (args.isEmpty) {
    throw const FormatException('Endpoint action is required.');
  }
  if (args.first == 'clear') {
    return const _Command('config.endpoint.clear', {});
  }
  if (args.first != 'set') {
    throw FormatException('Unknown endpoint action: ${args.first}');
  }
  final params = <String, Object?>{};
  for (var index = 1; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--api':
        params['api'] = _requiredOptionValue(args, ++index, arg);
        break;
      case '--gateway':
        params['gateway'] = _requiredOptionValue(args, ++index, arg);
        break;
      case '--chat-ws':
        params['chatWs'] = _requiredOptionValue(args, ++index, arg);
        break;
      default:
        throw FormatException('Unknown endpoint option: $arg');
    }
  }
  return _Command('config.endpoint.set', params);
}

_Command _cacheCommand(List<String> args) {
  final params = <String, Object?>{};
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--target':
        params['target'] = _requiredOptionValue(args, ++index, arg);
        break;
      default:
        throw FormatException('Unknown cache option: $arg');
    }
  }
  return _Command('cache.clear', params);
}

_CliOptions _effectiveOptions(_CliOptions options, _Command command) {
  if (command.method == 'agent.world_chat' && options.timeoutMs == 10000) {
    return options.withTimeoutMs(30 * 60 * 1000);
  }
  return options;
}

Future<bool> _runAgentWorldChatWithProgress(
  _CliOptions options,
  _Command command,
) async {
  const encoder = JsonEncoder.withIndent('  ');
  final rpcOptions = options.withTimeoutMs(10000);
  stdout.writeln('目标: 启动后台自动聊天任务');
  final start = await _rpc(
    rpcOptions,
    _Command('agent.world_chat.start', command.params),
  );
  if (start['ok'] != true) {
    stdout.writeln(encoder.convert(start));
    return false;
  }
  final startResult = _jsonMap(start['result']);
  final jobId = startResult['jobId']?.toString().trim() ?? '';
  if (jobId.isEmpty) {
    stdout.writeln(encoder.convert(start));
    return false;
  }
  stdout.writeln('任务: $jobId');

  var afterSeq = 0;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 2));
    final status = await _rpc(
      rpcOptions,
      _Command('agent.world_chat.status', {
        'jobId': jobId,
        'afterSeq': afterSeq,
      }),
    );
    if (status['ok'] != true) {
      stdout.writeln(encoder.convert(status));
      return false;
    }
    final result = _jsonMap(status['result']);
    final logs = result['logs'];
    if (logs is List) {
      for (final item in logs) {
        final log = _jsonMap(item);
        final seq = _intValue(log['seq']);
        if (seq > afterSeq) afterSeq = seq;
        final goal = log['goal']?.toString() ?? '';
        final details = log['details'];
        final detailText = details is Map && details.isNotEmpty
            ? ' ${jsonEncode(details)}'
            : '';
        stdout.writeln('[$seq] 目标: $goal$detailText');
      }
    }

    final state = result['status']?.toString() ?? '';
    if (state == 'completed') {
      stdout.writeln('目标: 自动聊天任务完成');
      stdout.writeln(encoder.convert(result['result'] ?? result));
      return true;
    }
    if (state == 'failed') {
      stdout.writeln('目标: 自动聊天任务失败');
      stdout.writeln(encoder.convert(result['error'] ?? result));
      return false;
    }
  }
}

Future<Map<String, Object?>> _rpc(_CliOptions options, _Command command) async {
  final client = HttpClient();
  try {
    final uri = Uri(
      scheme: 'http',
      host: options.host,
      port: options.port,
      path: '/rpc',
    );
    final request = await client
        .postUrl(uri)
        .timeout(Duration(milliseconds: options.timeoutMs));
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${options.token}',
    );
    request.write(
      jsonEncode({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'method': command.method,
        'params': command.params,
        'timeoutMs': options.timeoutMs,
        'dryRun': options.dryRun,
      }),
    );
    final response = await request.close().timeout(
      Duration(milliseconds: options.timeoutMs),
    );
    final body = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw FormatException('Unexpected response: $body');
    }
    return Map<String, Object?>.from(decoded);
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?> _jsonMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, Object?>{};
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _requiredOptionValue(List<String> args, int index, String option) {
  if (index >= args.length) {
    throw FormatException('Missing value for $option.');
  }
  final value = args[index];
  if (value.startsWith('--')) {
    throw FormatException('Missing value for $option.');
  }
  return value;
}

void _printUsage() {
  stdout.writeln('''
Usage:
  dart run tool/genesisctl.dart [options] app ping
  dart run tool/genesisctl.dart [options] app state
  dart run tool/genesisctl.dart [options] app navigate /route [--arg key=value] [--replace] [--clear-stack]
  dart run tool/genesisctl.dart [options] app back
  dart run tool/genesisctl.dart [options] auth state
  dart run tool/genesisctl.dart [options] auth clear
  dart run tool/genesisctl.dart [options] world locations --wid <wid>
  dart run tool/genesisctl.dart [options] agent world-chat [--wid <wid>] [--location-id <id>] [--count 100]
  dart run tool/genesisctl.dart [options] config endpoint set --api dev.hushie.ai [--gateway dev.hushie.ai] [--chat-ws dev.hushie.ai]
  dart run tool/genesisctl.dart [options] config endpoint clear
  dart run tool/genesisctl.dart [options] cache clear [--target all|image|directMessage]
  dart run tool/genesisctl.dart [options] diagnostics snapshot

Options:
  --host <host>          Default: 127.0.0.1
  --port <port>          Default: 17317
  --token <token>        Defaults to GENESIS_AGENT_CONTROL_TOKEN
  --timeout-ms <ms>      Default: 10000
  --dry-run             Validate command without mutating app state
''');
}
