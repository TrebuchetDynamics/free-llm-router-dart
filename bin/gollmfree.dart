import 'dart:convert';
import 'dart:io' as io;

import 'package:gollmfree/gollmfree.dart';
import 'package:gollmfree/providers.dart';

const _usageText = '''gollmfree <command> [flags] [args]

Commands:
  chat    Send a message and print the reply
  list    Print registered providers and health summary
  models  Print model aliases and provider coverage

Run 'gollmfree <command> -help' for per-command flags.
''';

Future<void> main(List<String> args) async {
  final code = await run(args, stdout: io.stdout, stderr: io.stderr);
  io.exitCode = code;
}

Future<int> run(
  List<String> args, {
  StringSink? stdout,
  StringSink? stderr,
  GollmfreeClient Function({Duration perAttemptTimeout, bool raceMode})?
  clientFactory,
}) async {
  final out = stdout ?? io.stdout;
  final err = stderr ?? io.stderr;
  if (args.isEmpty) {
    err.write(_usageText);
    return 2;
  }
  switch (args.first) {
    case 'chat':
      return _cmdChat(
        args.skip(1).toList(),
        stdout: out,
        stderr: err,
        clientFactory: clientFactory,
      );
    case 'list':
      return _cmdList(args.skip(1).toList(), stdout: out, stderr: err);
    case 'models':
      return _cmdModels(args.skip(1).toList(), stdout: out, stderr: err);
    default:
      err.write('gollmfree: unknown command "${args.first}"\n\n$_usageText');
      return 2;
  }
}

Future<int> _cmdChat(
  List<String> args, {
  required StringSink stdout,
  required StringSink stderr,
  GollmfreeClient Function({Duration perAttemptTimeout, bool raceMode})?
  clientFactory,
}) async {
  var model = 'auto';
  var timeout = const Duration(seconds: 60);
  var race = false;
  var stream = false;
  final promptParts = <String>[];

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '-help' || arg == '--help') {
      stderr.writeln(
        'Usage: gollmfree chat [-model auto] [-timeout 60s] [-race] [-stream] <prompt>',
      );
      return 2;
    } else if (arg == '-model' || arg == '--model') {
      if (++index >= args.length) {
        return _flagError(stderr, 'missing value for $arg');
      }
      model = args[index];
    } else if (arg == '-timeout' || arg == '--timeout') {
      if (++index >= args.length) {
        return _flagError(stderr, 'missing value for $arg');
      }
      timeout = _parseDuration(args[index]) ?? timeout;
    } else if (arg == '-race' || arg == '--race') {
      race = true;
    } else if (arg == '-stream' || arg == '--stream') {
      stream = true;
    } else {
      promptParts.add(arg);
    }
  }

  if (promptParts.isEmpty) {
    stderr.writeln('gollmfree chat: prompt argument required');
    return 2;
  }

  try {
    final client = (clientFactory ?? defaultClient)(
      perAttemptTimeout: timeout,
      raceMode: race,
    );
    final request = ChatRequest(
      model: model,
      messages: [Message(role: 'user', content: promptParts.join(' '))],
      stream: stream,
    );
    if (stream) {
      await for (final chunk in client.chatCompletionStream(request)) {
        stdout.write(chunk.content);
        if (stdout is io.IOSink) await stdout.flush();
      }
      stdout.writeln();
      return 0;
    }

    final response = await client.chatCompletion(request);
    if (response.choices.isNotEmpty) {
      final text = response.choices.first.message.content;
      stdout.write(text);
      if (!text.endsWith('\n')) stdout.writeln();
    }
    return 0;
  } catch (error) {
    stderr.writeln('gollmfree: $error');
    return 1;
  }
}

Future<int> _cmdList(
  List<String> args, {
  required StringSink stdout,
  required StringSink stderr,
}) async {
  final asJson = args.contains('-json') || args.contains('--json');
  final registry = defaultRegistry();
  if (asJson) {
    stdout.writeln(
      jsonEncode(registry.providers.map(_providerInfoJson).toList()),
    );
    return 0;
  }
  for (final provider in registry.providers) {
    stdout.writeln(
      '${provider.name.padRight(16)}  priority=${provider.defaultPriority.toString().padRight(3)}  models=${provider.supportedModels.join(',')}',
    );
  }
  return 0;
}

Future<int> _cmdModels(
  List<String> args, {
  required StringSink stdout,
  required StringSink stderr,
}) async {
  final asJson = args.contains('-json') || args.contains('--json');
  final models = defaultRegistry().models();
  if (asJson) {
    stdout.writeln(jsonEncode(models.map(_modelInfoJson).toList()));
    return 0;
  }
  for (final model in models) {
    stdout.writeln(
      '${model.alias.padRight(30)}  providers=${model.providers.join(',')}',
    );
  }
  return 0;
}

int _flagError(StringSink stderr, String message) {
  stderr.writeln('gollmfree: $message');
  return 2;
}

Duration? _parseDuration(String value) {
  final match = RegExp(r'^(\d+)(ms|s|m)?$').firstMatch(value.trim());
  if (match == null) return null;
  final amount = int.parse(match.group(1)!);
  return switch (match.group(2)) {
    'ms' => Duration(milliseconds: amount),
    'm' => Duration(minutes: amount),
    _ => Duration(seconds: amount),
  };
}

Map<String, Object?> _providerInfoJson(ProviderInfo info) => {
  'name': info.name,
  'supportedModels': info.supportedModels,
  'defaultPriority': info.defaultPriority,
};

Map<String, Object?> _modelInfoJson(ModelInfo info) => {
  'alias': info.alias,
  'providers': info.providers,
};
