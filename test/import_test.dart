import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

void main() {
  test('core package can be imported by Dart and Flutter apps', () {
    final registry = Registry();
    final client = FreeLlmRouterClient(registry: registry);

    expect(client.health(), isEmpty);
  });
}
