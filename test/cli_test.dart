import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

import '../bin/free_llm_router.dart' as cli;

void main() {
  test('chat --model provider/model routes through CLI to provider', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final provider = _RequestAwareProvider();

    final code = await cli.run(
      ['chat', '--model', 'streamer/special-model', 'hello'],
      stdout: out,
      stderr: err,
      clientFactory: _clientFactory(provider),
    );

    expect(code, 0);
    expect(out.toString(), 'special-model:hello\n');
    expect(provider.seenRequest?.model, 'special-model');
    expect(err.toString(), isEmpty);
  });

  test('chat --stream writes stream chunks instead of completion', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final provider = _StreamOnlyProvider();

    final code = await cli.run(
      ['chat', '--stream', 'hello'],
      stdout: out,
      stderr: err,
      clientFactory: _clientFactory(provider),
    );

    expect(code, 0);
    expect(out.toString(), 'streamed\n');
    expect(err.toString(), isEmpty);
  });

  test('chat --stream reports stream errors', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final provider = _StreamOnlyProvider(streamError: StateError('offline'));

    final code = await cli.run(
      ['chat', '--stream', 'hello'],
      stdout: out,
      stderr: err,
      clientFactory: _clientFactory(provider),
    );

    expect(code, 1);
    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('free_llm_router:'));
    expect(err.toString(), contains('offline'));
  });
}

FreeLlmRouterClient Function({Duration perAttemptTimeout, bool raceMode})
_clientFactory(Provider provider) {
  return ({perAttemptTimeout = const Duration(seconds: 60), raceMode = false}) {
    return FreeLlmRouterClient(
      registry: Registry([
        ProviderInfo(name: provider.name, provider: provider),
      ]),
      perAttemptTimeout: perAttemptTimeout,
      raceMode: raceMode,
    );
  };
}

class _RequestAwareProvider implements RequestProvider {
  ChatRequest? seenRequest;

  @override
  String get name => 'streamer';

  @override
  List<String> get supportedModels => const ['auto'];

  @override
  Future<CompletionResponse> complete(List<Message> messages) {
    throw StateError('request path should be used');
  }

  @override
  Future<CompletionResponse> completeRequest(ChatRequest request) async {
    seenRequest = request;
    return CompletionResponse(
      choices: [
        Choice(
          index: 0,
          message: Message(
            role: 'assistant',
            content: '${request.model}:${request.messages.single.content}',
          ),
        ),
      ],
    );
  }

  @override
  Stream<String> stream(List<Message> messages) => Stream.value('unused');

  @override
  Stream<String> streamRequest(ChatRequest request) => Stream.value('unused');
}

class _StreamOnlyProvider implements Provider {
  _StreamOnlyProvider({this.streamError});

  final Object? streamError;

  @override
  String get name => 'streamer';

  @override
  List<String> get supportedModels => const ['auto'];

  @override
  Future<CompletionResponse> complete(List<Message> messages) {
    throw StateError('completion path should not be used');
  }

  @override
  Stream<String> stream(List<Message> messages) {
    final error = streamError;
    if (error != null) return Stream.error(error);
    return Stream.fromIterable(['stream', 'ed']);
  }
}
