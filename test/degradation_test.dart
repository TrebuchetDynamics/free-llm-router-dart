import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

void main() {
  test('fallback success is reported as degraded', () async {
    final degradation = DegradationRegistry();

    final result = await degradation.withDegradation(
      'chat',
      () async => throw StateError('primary offline'),
      () async => 'fallback response',
      'unavailable',
    );

    expect(result.result, 'fallback response');
    expect(result.status.level, DegradationLevel.degraded);
    expect(result.status.reason, contains('primary offline'));
  });

  test('safe default is reported at the default degradation level', () async {
    final degradation = DegradationRegistry();

    final result = await degradation.withDegradation(
      'chat',
      () async => throw StateError('primary offline'),
      () async => throw StateError('fallback offline'),
      'unavailable',
    );

    expect(result.result, 'unavailable');
    expect(result.status.level, DegradationLevel.default_);
    expect(degradation.hasAnyDegradation(), isTrue);
  });
}
