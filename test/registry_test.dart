import 'package:gollmfree/gollmfree.dart';
import 'package:test/test.dart';

void main() {
  test('registry normalizes names and aliases for candidates', () {
    final provider = _FakeProvider(
      'PollinationsAI',
      models: [' GPT-4.1-Nano ', 'auto'],
    );
    final registry = Registry([
      ProviderInfo(
        name: provider.name,
        provider: provider,
        supportedModels: provider.supportedModels,
        defaultPriority: 1,
      ),
    ]);

    expect(registry.provider(' pollinationsai ')?.name, 'PollinationsAI');
    expect(registry.candidates('gpt-4.1-nano'), hasLength(1));
    expect(registry.candidates('best'), hasLength(1));
    expect(
      registry.models().map((model) => model.alias),
      contains('pollinationsai'),
    );
  });
}

class _FakeProvider implements Provider {
  _FakeProvider(this.name, {this.models = const []});

  @override
  final String name;

  final List<String> models;

  @override
  List<String> get supportedModels => models;

  @override
  Future<CompletionResponse> complete(List<Message> messages) async {
    return const CompletionResponse(
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: 'ok'),
        ),
      ],
    );
  }

  @override
  Stream<String> stream(List<Message> messages) => Stream.value('ok');
}
