import 'dart:math';

import 'health.dart';
import 'provider.dart';
import 'registry.dart' show normalizeRegistryKey;

/// Routing strategies for provider selection.
///
/// Inspired by OmniRoute's multi-strategy routing engine, adapted for
/// free_llm_router's scope of free/no-auth providers where cost is not a factor.
enum RoutingStrategy {
  /// Ordered by priority — drain each before the next.
  priority,

  /// Weighted random selection by provider weight.
  weighted,

  /// Cycle through providers in order.
  roundRobin,

  /// Uniform random pick (deduplicated).
  random,

  /// Pick the provider with the fewest recorded uses.
  leastUsed,

  /// Last-Known-Good Path — sticky to the last successful provider.
  lkgp,
}

/// Configuration for strategy-specific behavior.
class StrategyOptions {
  const StrategyOptions({
    this.strategy = RoutingStrategy.priority,
    this.weights = const {},
    this.rng,
  });

  /// The routing strategy to use.
  final RoutingStrategy strategy;

  /// Per-provider weights for [RoutingStrategy.weighted].
  /// Keys are normalized provider names. Unlisted providers get weight 1.
  final Map<String, double> weights;

  /// Optional RNG for deterministic testing. Uses [Random] if null.
  final Random? rng;
}

/// Selects providers according to [StrategyOptions].
///
/// This is the strategy engine that replaces the single priority-based
/// ranking from the original [Selector]. Each strategy produces a
/// ranked list; the client tries providers in that order.
class StrategySelector {
  StrategySelector();

  final Map<String, int> _roundRobinCounters = {};

  /// Ranks [candidates] for the given [model] using [options.strategy].
  List<ProviderInfo> rank(
    String model,
    Iterable<ProviderInfo> candidates,
    Iterable<HealthSnapshot> health,
    StrategyOptions options,
  ) {
    final list = candidates.toList();
    if (list.length < 2) return List.unmodifiable(list);

    final healthByProvider = {
      for (final snapshot in health)
        normalizeRegistryKey(snapshot.provider): snapshot,
    };

    return switch (options.strategy) {
      RoutingStrategy.priority => _priorityRank(
        list,
        healthByProvider,
        options,
      ),
      RoutingStrategy.weighted => _weightedRank(
        list,
        healthByProvider,
        options,
      ),
      RoutingStrategy.roundRobin => _roundRobinRank(model, list),
      RoutingStrategy.random => _randomRank(list, options),
      RoutingStrategy.leastUsed => _leastUsedRank(list, healthByProvider),
      RoutingStrategy.lkgp => _lkgpRank(list, healthByProvider),
    };
  }

  List<ProviderInfo> _roundRobinRank(
    String model,
    List<ProviderInfo> candidates,
  ) {
    final counter = _roundRobinCounters[model] ?? 0;
    _roundRobinCounters[model] = (counter + 1) % candidates.length;
    final start = counter % candidates.length;
    return List.unmodifiable([
      ...candidates.sublist(start),
      ...candidates.sublist(0, start),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Strategy implementations
// ---------------------------------------------------------------------------

List<ProviderInfo> _priorityRank(
  List<ProviderInfo> candidates,
  Map<String, HealthSnapshot> healthByProvider,
  StrategyOptions options,
) {
  final ranked = List<ProviderInfo>.from(candidates);
  final now = DateTime.now();
  ranked.sort((left, right) {
    final leftKey = normalizeRegistryKey(left.name);
    final rightKey = normalizeRegistryKey(right.name);

    final leftHealth = healthByProvider[leftKey];
    final rightHealth = healthByProvider[rightKey];
    final leftCooldown = _activeCooldown(leftHealth, now);
    final rightCooldown = _activeCooldown(rightHealth, now);
    if (leftCooldown != rightCooldown) return leftCooldown ? 1 : -1;

    final priorityCompare = left.defaultPriority.compareTo(
      right.defaultPriority,
    );
    if (priorityCompare != 0) return priorityCompare;

    final failureCompare = (leftHealth?.consecutiveFailures ?? 0).compareTo(
      rightHealth?.consecutiveFailures ?? 0,
    );
    if (failureCompare != 0) return failureCompare;

    return leftKey.compareTo(rightKey);
  });
  return List.unmodifiable(ranked);
}

List<ProviderInfo> _weightedRank(
  List<ProviderInfo> candidates,
  Map<String, HealthSnapshot> healthByProvider,
  StrategyOptions options,
) {
  final now = DateTime.now();
  final rng = options.rng ?? Random();

  // Build weight list: exclude providers on cooldown
  final entries = <({ProviderInfo provider, double weight})>[];
  for (final provider in candidates) {
    final key = normalizeRegistryKey(provider.name);
    final health = healthByProvider[key];
    if (_activeCooldown(health, now)) continue;

    final weight = options.weights[key] ?? 1.0;
    if (weight > 0) {
      entries.add((provider: provider, weight: weight));
    }
  }

  if (entries.isEmpty) {
    // All on cooldown — fall back to priority ranking
    return _priorityRank(candidates, healthByProvider, options);
  }

  // Weighted random selection: pick one, then put the rest in priority order
  final totalWeight = entries.fold(0.0, (sum, e) => sum + e.weight);
  var pick = rng.nextDouble() * totalWeight;
  ProviderInfo? selected;
  for (final entry in entries) {
    pick -= entry.weight;
    if (pick <= 0) {
      selected = entry.provider;
      break;
    }
  }
  selected ??= entries.last.provider;

  // Keep stronger weighted choices ahead in the fallback sequence.
  final remaining =
      entries.where((entry) => entry.provider.name != selected!.name).toList()
        ..sort((left, right) {
          final weightCompare = right.weight.compareTo(left.weight);
          if (weightCompare != 0) return weightCompare;
          return left.provider.defaultPriority.compareTo(
            right.provider.defaultPriority,
          );
        });

  return [selected, ...remaining.map((entry) => entry.provider)];
}

List<ProviderInfo> _randomRank(
  List<ProviderInfo> candidates,
  StrategyOptions options,
) {
  final rng = options.rng ?? Random();
  final shuffled = List<ProviderInfo>.from(candidates)..shuffle(rng);
  return List.unmodifiable(shuffled);
}

List<ProviderInfo> _leastUsedRank(
  List<ProviderInfo> candidates,
  Map<String, HealthSnapshot> healthByProvider,
) {
  final ranked = List<ProviderInfo>.from(candidates);
  ranked.sort((left, right) {
    final leftKey = normalizeRegistryKey(left.name);
    final rightKey = normalizeRegistryKey(right.name);
    final leftUses =
        (healthByProvider[leftKey]?.successes ?? 0) +
        (healthByProvider[leftKey]?.failures ?? 0);
    final rightUses =
        (healthByProvider[rightKey]?.successes ?? 0) +
        (healthByProvider[rightKey]?.failures ?? 0);
    if (leftUses != rightUses) return leftUses.compareTo(rightUses);
    return left.defaultPriority.compareTo(right.defaultPriority);
  });
  return List.unmodifiable(ranked);
}

List<ProviderInfo> _lkgpRank(
  List<ProviderInfo> candidates,
  Map<String, HealthSnapshot> healthByProvider,
) {
  final now = DateTime.now();

  // Find the provider with the most recent success
  ProviderInfo? lastGood;
  DateTime? lastGoodTime;

  for (final provider in candidates) {
    final key = normalizeRegistryKey(provider.name);
    final health = healthByProvider[key];
    final lastSuccess = health?.lastSuccess;
    if (lastSuccess != null &&
        !lastSuccess.isAfter(now) &&
        !_activeCooldown(health, now)) {
      if (lastGoodTime == null || lastSuccess.isAfter(lastGoodTime)) {
        lastGoodTime = lastSuccess;
        lastGood = provider;
      }
    }
  }

  if (lastGood == null) {
    // No known good provider — fall back to priority
    return _priorityRank(candidates, healthByProvider, const StrategyOptions());
  }

  // Put last-good first, then the rest by priority
  final rest = candidates.where((p) => p.name != lastGood!.name).toList()
    ..sort((a, b) => a.defaultPriority.compareTo(b.defaultPriority));

  return [lastGood, ...rest];
}

bool _activeCooldown(HealthSnapshot? snapshot, DateTime now) {
  final cooldownUntil = snapshot?.cooldownUntil;
  return cooldownUntil != null && cooldownUntil.isAfter(now);
}
