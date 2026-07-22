import 'dart:io';

import 'package:gollmfree/gollmfree.dart';
import 'package:gollmfree/providers.dart';
import 'package:test/test.dart';

void main() {
  test(
    'all live free providers answer through the real CLI',
    () async {
      await _expectCliPong('pollinationsai/openai-fast');
      await _expectCliPong('wewordle/v3');
      await _expectCliPong('gptfree/gptfree');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'live free PollinationsAI works through stream, alias, client, and provider paths',
    () async {
      await _expectCliPong('pollinationsai/gpt-4.1-nano');
      await _expectCliPong('pollinationsai/openai-fast', stream: true);

      final response = await defaultClient(
        perAttemptTimeout: const Duration(seconds: 90),
      ).chatCompletion(_pongRequest('pollinationsai/openai-fast'));
      _expectPongResponse(response, pollinationsName);

      final provider = PollinationsAI();
      _expectPongResponse(
        await provider.completeRequest(_pongRequest('openai-fast')),
        pollinationsName,
      );
      expect(
        (await provider.streamRequest(_pongRequest('gpt-4.1-nano')).join())
            .toLowerCase(),
        contains('pong'),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'live free provider adapters answer directly',
    () async {
      _expectPongResponse(
        await WeWordle().complete(_pongRequest('v3').messages),
        wewordleName,
      );
      _expectPongResponse(
        await GptFree().complete(_pongRequest('gptfree').messages),
        gptFreeName,
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'legacy exported providers are real-probed and reported unavailable',
    () async {
      await _expectCliUnavailable('chatai/gpt-4o-mini', 'chatai');
      await _expectCliUnavailable('yqcloud/gpt-3.5-turbo', 'yqcloud');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

ChatRequest _pongRequest(String model) {
  return ChatRequest(
    model: model,
    messages: const [
      Message(role: 'user', content: 'Reply with exactly one word: pong'),
    ],
    temperature: 0,
    maxTokens: 8,
  );
}

void _expectPongResponse(CompletionResponse response, String provider) {
  expect(response.provider, provider);
  expect(
    response.choices.single.message.content.toLowerCase(),
    contains('pong'),
  );
}

Future<void> _expectCliPong(String model, {bool stream = false}) async {
  final result = await _runCli(model, stream: stream);
  expect(
    result.exitCode,
    0,
    reason:
        'model: $model\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
  );
  expect((result.stdout as String).trim().toLowerCase(), contains('pong'));
}

Future<void> _expectCliUnavailable(String model, String provider) async {
  final result = await _runCli(model);
  expect(result.exitCode, isNot(0));
  expect(
    '${result.stdout}\n${result.stderr}'.toLowerCase(),
    contains(provider),
  );
}

Future<ProcessResult> _runCli(String model, {bool stream = false}) {
  return Process.run(Platform.resolvedExecutable, [
    'run',
    'gollmfree',
    'chat',
    if (stream) '--stream',
    '--model',
    model,
    '--timeout',
    '90s',
    'Reply with exactly one word: pong',
  ]);
}
