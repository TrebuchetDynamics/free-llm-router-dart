import 'package:gollmfree/gollmfree.dart';
import 'package:test/test.dart';

void main() {
  test('core package can be imported by Dart and Flutter apps', () {
    final registry = Registry();
    final client = GollmfreeClient(registry: registry);

    expect(client.health(), isEmpty);
  });
}
