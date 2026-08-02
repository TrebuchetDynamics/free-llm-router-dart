import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

void main() {
  test('fallback policy resolves enabled providers by priority', () {
    final policy = FallbackPolicy()
      ..register('auto', const [
        FallbackEntry(provider: 'third', priority: 3),
        FallbackEntry(provider: 'disabled', priority: 1, enabled: false),
        FallbackEntry(provider: 'first', priority: 0),
        FallbackEntry(provider: 'second', priority: 2),
      ]);

    expect(policy.resolve('auto'), ['first', 'second', 'third']);
    expect(policy.resolve('auto', exclude: ['first']), ['second', 'third']);
    expect(policy.next('auto', exclude: ['first']), 'second');
  });
}
