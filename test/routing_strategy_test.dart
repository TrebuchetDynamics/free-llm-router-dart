import 'dart:math';

import 'package:free_llm_router/free_llm_router.dart';
import 'package:test/test.dart';

void main() {
  test('round robin state is independent per model', () {
    final selector = StrategySelector();
    final providers = [_provider('first', 1), _provider('second', 2)];

    expect(
      selector
          .rank(
            'model-a',
            providers,
            const [],
            const StrategyOptions(strategy: RoutingStrategy.roundRobin),
          )
          .first
          .name,
      'first',
    );
    expect(
      selector
          .rank(
            'model-b',
            providers,
            const [],
            const StrategyOptions(strategy: RoutingStrategy.roundRobin),
          )
          .first
          .name,
      'first',
    );
  });

  test('weighted routing orders fallback providers by descending weight', () {
    final selector = StrategySelector();
    final providers = [
      _provider('selected', 1),
      _provider('lighter', 2),
      _provider('heavier', 3),
    ];

    final ranked = selector.rank(
      'auto',
      providers,
      const [],
      StrategyOptions(
        strategy: RoutingStrategy.weighted,
        weights: const {'selected': 1, 'lighter': 2, 'heavier': 3},
        rng: _ZeroRandom(),
      ),
    );

    expect(ranked.map((provider) => provider.name), [
      'selected',
      'heavier',
      'lighter',
    ]);
  });

  test('priority routing moves cooling providers behind available ones', () {
    final now = DateTime.now();
    final selector = StrategySelector();
    final providers = [_provider('cooling', 1), _provider('available', 2)];

    final ranked = selector.rank('auto', providers, [
      HealthSnapshot(
        provider: 'cooling',
        cooldownUntil: now.add(const Duration(hours: 1)),
      ),
    ], const StrategyOptions());

    expect(ranked.map((provider) => provider.name), ['available', 'cooling']);
  });

  test('least-used routing prefers the provider with fewer attempts', () {
    final selector = StrategySelector();
    final providers = [_provider('busy', 1), _provider('idle', 2)];

    final ranked = selector.rank('auto', providers, const [
      HealthSnapshot(provider: 'busy', successes: 4, failures: 1),
    ], const StrategyOptions(strategy: RoutingStrategy.leastUsed));

    expect(ranked.first.name, 'idle');
  });

  test('random routing returns each candidate exactly once', () {
    final selector = StrategySelector();
    final providers = [
      _provider('first', 1),
      _provider('second', 2),
      _provider('third', 3),
    ];

    final ranked = selector.rank(
      'auto',
      providers,
      const [],
      StrategyOptions(strategy: RoutingStrategy.random, rng: _ZeroRandom()),
    );

    expect(ranked.map((provider) => provider.name).toSet(), {
      'first',
      'second',
      'third',
    });
    expect(ranked, hasLength(3));
  });

  test('last-known-good routing skips a provider on cooldown', () {
    final now = DateTime.now();
    final selector = StrategySelector();
    final providers = [_provider('cooling', 1), _provider('available', 2)];

    final ranked = selector.rank('auto', providers, [
      HealthSnapshot(
        provider: 'cooling',
        lastSuccess: now.subtract(const Duration(minutes: 1)),
        cooldownUntil: now.add(const Duration(hours: 1)),
      ),
      HealthSnapshot(
        provider: 'available',
        lastSuccess: now.subtract(const Duration(minutes: 2)),
      ),
    ], const StrategyOptions(strategy: RoutingStrategy.lkgp));

    expect(ranked.first.name, 'available');
  });
}

ProviderInfo _provider(String name, int priority) => ProviderInfo(
  name: name,
  provider: _FakeProvider(name),
  defaultPriority: priority,
);

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

class _FakeProvider implements Provider {
  const _FakeProvider(this.name);

  @override
  final String name;

  @override
  List<String> get supportedModels => const ['auto'];

  @override
  Future<CompletionResponse> complete(List<Message> messages) =>
      throw UnimplementedError();

  @override
  Stream<String> stream(List<Message> messages) => const Stream.empty();
}
