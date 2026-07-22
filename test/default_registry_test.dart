import 'package:gollmfree/providers.dart';
import 'package:test/test.dart';

void main() {
  test(
    'default registry contains every Dart-ported provider and auto alias',
    () {
      final registry = defaultRegistry();
      expect(registry.providers.map((provider) => provider.name), [
        pollinationsName,
        wewordleName,
        gptFreeName,
      ]);
      expect(registry.models().map((model) => model.alias), contains('auto'));
    },
  );
}
