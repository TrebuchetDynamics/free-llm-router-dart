import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

void main() {
  test('health latency history keeps the newest samples', () {
    final health = HealthStore(latencyHistorySize: 3);

    for (final milliseconds in [10, 20, 30, 40]) {
      health.recordSuccess('provider', Duration(milliseconds: milliseconds));
    }

    expect(health.snapshot().single.recentLatencies, const [
      Duration(milliseconds: 20),
      Duration(milliseconds: 30),
      Duration(milliseconds: 40),
    ]);
  });

  test(
    'health enters cooldown after consecutive failures and resets on success',
    () {
      final now = DateTime.utc(2026, 1, 1);
      final health = HealthStore(
        cooldownThreshold: 2,
        cooldownDuration: const Duration(minutes: 5),
        clock: () => now,
      );

      health.recordFailure('provider', Duration.zero, StateError('first'));
      expect(health.snapshot().single.isOnCooldown(now), isFalse);

      health.recordFailure('provider', Duration.zero, StateError('second'));
      expect(health.snapshot().single.isOnCooldown(now), isTrue);

      health.recordSuccess('provider', Duration.zero);
      expect(health.snapshot().single.isOnCooldown(now), isFalse);
      expect(health.snapshot().single.consecutiveFailures, 0);
    },
  );

  test('health trend includes the newest latency sample', () {
    final health = HealthStore();

    for (final milliseconds in [100, 100, 100, 10]) {
      health.recordSuccess('provider', Duration(milliseconds: milliseconds));
    }

    expect(health.snapshot().single.trend, HealthTrend.improving);
  });
}
