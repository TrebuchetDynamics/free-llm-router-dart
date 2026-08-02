import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

void main() {
  test(
    'client falls back to the next ranked provider and records health',
    () async {
      final failing = _FakeProvider('failing', error: StateError('offline'));
      final succeeding = _FakeProvider('succeeding', text: 'hello from dart');
      final registry = Registry([
        ProviderInfo(name: failing.name, provider: failing, defaultPriority: 1),
        ProviderInfo(
          name: succeeding.name,
          provider: succeeding,
          defaultPriority: 2,
        ),
      ]);
      final client = FreeLlmRouterClient(registry: registry, maxRetries: 0);

      final response = await client.chatCompletion(
        const ChatRequest(
          model: 'auto',
          messages: [Message(role: 'user', content: 'hello')],
        ),
      );

      expect(response.provider, 'succeeding');
      expect(response.model, 'auto');
      expect(response.choices.single.message.content, 'hello from dart');
      expect(client.health().map((snap) => snap.provider), [
        'failing',
        'succeeding',
      ]);
      expect(client.health().first.failures, 1);
      expect(
        client.degradationRegistry.getStatus('failing')?.level,
        DegradationLevel.failed,
      );
      expect(
        client.degradationRegistry.getStatus('succeeding')?.level,
        DegradationLevel.healthy,
      );
    },
  );

  test('client stream emits provider-labelled chunks', () async {
    final provider = _FakeProvider('streamer', text: 'chunk');
    final client = FreeLlmRouterClient(
      registry: Registry([
        ProviderInfo(name: provider.name, provider: provider),
      ]),
    );

    final chunks = await client
        .chatCompletionStream(
          const ChatRequest(
            messages: [Message(role: 'user', content: 'hello')],
          ),
        )
        .toList();

    expect(chunks.single.content, 'chunk');
    expect(chunks.single.provider, 'streamer');
  });

  test('client completion respects the configured fallback policy', () async {
    final first = _FakeProvider('first', text: 'first');
    final second = _FakeProvider('second', text: 'second');
    final policy = FallbackPolicy()
      ..register('auto', const [FallbackEntry(provider: 'second')]);
    final client = FreeLlmRouterClient(
      registry: Registry([
        ProviderInfo(name: first.name, provider: first, defaultPriority: 1),
        ProviderInfo(name: second.name, provider: second, defaultPriority: 2),
      ]),
      fallbackPolicy: policy,
    );

    final response = await client.chatCompletion(
      const ChatRequest(
        messages: [Message(role: 'user', content: 'hello')],
      ),
    );

    expect(response.provider, 'second');
    expect(response.choices.single.message.content, 'second');
    expect(first.completeCalls, 0);
  });

  test('client stream respects the configured fallback policy', () async {
    final first = _FakeProvider('first', text: 'first');
    final second = _FakeProvider('second', text: 'second');
    final policy = FallbackPolicy()
      ..register('auto', const [FallbackEntry(provider: 'second')]);
    final client = FreeLlmRouterClient(
      registry: Registry([
        ProviderInfo(name: first.name, provider: first, defaultPriority: 1),
        ProviderInfo(name: second.name, provider: second, defaultPriority: 2),
      ]),
      fallbackPolicy: policy,
    );

    final chunks = await client
        .chatCompletionStream(
          const ChatRequest(
            messages: [Message(role: 'user', content: 'hello')],
          ),
        )
        .toList();

    expect(chunks.single.provider, 'second');
    expect(chunks.single.content, 'second');
    expect(first.streamCalls, 0);
  });

  test('provider-qualified models route only to that provider', () async {
    final first = _RequestAwareProvider('first', text: 'wrong');
    final second = _RequestAwareProvider('second', text: 'right');
    final client = FreeLlmRouterClient(
      registry: Registry([
        ProviderInfo(name: first.name, provider: first, defaultPriority: 1),
        ProviderInfo(name: second.name, provider: second, defaultPriority: 2),
      ]),
    );

    final response = await client.chatCompletion(
      const ChatRequest(
        model: 'second/custom-model',
        messages: [Message(role: 'user', content: 'hello')],
      ),
    );

    expect(first.completeCalls, 0);
    expect(second.completeCalls, 1);
    expect(second.seenRequest?.model, 'custom-model');
    expect(response.provider, 'second');
    expect(response.model, 'custom-model');
    expect(response.choices.single.message.content, 'right');
  });

  test('provider-qualified stream passes upstream model', () async {
    final provider = _RequestAwareProvider('streamer', text: 'chunk');
    final client = FreeLlmRouterClient(
      registry: Registry([
        ProviderInfo(name: provider.name, provider: provider),
      ]),
    );

    final chunks = await client
        .chatCompletionStream(
          const ChatRequest(
            model: 'streamer/special-model',
            messages: [Message(role: 'user', content: 'hello')],
          ),
        )
        .toList();

    expect(provider.seenRequest?.model, 'special-model');
    expect(chunks.single.model, 'special-model');
    expect(chunks.single.content, 'chunk');
  });

  test('maxRetries zero attempts a failing provider once', () async {
    final failing = _FakeProvider('failing', error: StateError('offline'));
    final succeeding = _FakeProvider('succeeding', text: 'ok');
    final client = FreeLlmRouterClient(
      registry: _fallbackRegistry(failing, succeeding),
      maxRetries: 0,
    );

    await client.chatCompletion(
      const ChatRequest(
        messages: [Message(role: 'user', content: 'hello')],
      ),
    );

    expect(failing.completeCalls, 1);
    expect(succeeding.completeCalls, 1);
  });

  test('maxRetries controls per-provider retry count', () async {
    final failing = _FakeProvider('failing', error: StateError('offline'));
    final succeeding = _FakeProvider('succeeding', text: 'ok');
    final client = FreeLlmRouterClient(
      registry: _fallbackRegistry(failing, succeeding),
      maxRetries: 1,
    );

    await client.chatCompletion(
      const ChatRequest(
        messages: [Message(role: 'user', content: 'hello')],
      ),
    );

    expect(failing.completeCalls, 2);
    expect(succeeding.completeCalls, 1);
  });

  test('negative maxRetries is treated as zero retries', () async {
    final failing = _FakeProvider('failing', error: StateError('offline'));
    final succeeding = _FakeProvider('succeeding', text: 'ok');
    final client = FreeLlmRouterClient(
      registry: _fallbackRegistry(failing, succeeding),
      maxRetries: -1,
    );

    await client.chatCompletion(
      const ChatRequest(
        messages: [Message(role: 'user', content: 'hello')],
      ),
    );

    expect(failing.completeCalls, 1);
    expect(succeeding.completeCalls, 1);
  });

  test('maxRetries is capped to avoid accidental retry storms', () async {
    final failing = _FakeProvider('failing', error: StateError('offline'));
    final succeeding = _FakeProvider('succeeding', text: 'ok');
    final client = FreeLlmRouterClient(
      registry: _fallbackRegistry(failing, succeeding),
      maxRetries: 99,
    );

    await client.chatCompletion(
      const ChatRequest(
        messages: [Message(role: 'user', content: 'hello')],
      ),
    );

    expect(failing.completeCalls, 4);
    expect(succeeding.completeCalls, 1);
  });
}

Registry _fallbackRegistry(Provider failing, Provider succeeding) {
  return Registry([
    ProviderInfo(name: failing.name, provider: failing, defaultPriority: 1),
    ProviderInfo(
      name: succeeding.name,
      provider: succeeding,
      defaultPriority: 2,
    ),
  ]);
}

class _RequestAwareProvider extends _FakeProvider implements RequestProvider {
  _RequestAwareProvider(super.name, {super.text});

  ChatRequest? seenRequest;

  @override
  Future<CompletionResponse> completeRequest(ChatRequest request) {
    seenRequest = request;
    return complete(request.messages);
  }

  @override
  Stream<String> streamRequest(ChatRequest request) {
    seenRequest = request;
    return stream(request.messages);
  }
}

class _FakeProvider implements Provider {
  _FakeProvider(this.name, {this.text = 'ok', this.error});

  @override
  final String name;

  final String text;
  final Object? error;
  var completeCalls = 0;
  var streamCalls = 0;

  @override
  List<String> get supportedModels => const ['auto'];

  @override
  Future<CompletionResponse> complete(List<Message> messages) async {
    completeCalls++;
    final error = this.error;
    if (error != null) throw error;
    return CompletionResponse(
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: text),
        ),
      ],
    );
  }

  @override
  Stream<String> stream(List<Message> messages) {
    streamCalls++;
    final error = this.error;
    if (error != null) throw error;
    return Stream.value(text);
  }
}
