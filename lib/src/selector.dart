import 'health.dart';
import 'provider.dart';
import 'registry.dart';

/// Ranks provider candidates for a requested model.
class Selector {
  const Selector({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;

  List<ProviderInfo> rank(
    String model,
    Iterable<ProviderInfo> candidates,
    Iterable<HealthSnapshot> health,
    ClientSelectionOptions options,
  ) {
    final ranked = candidates.toList();
    if (ranked.length < 2) return List.unmodifiable(ranked);

    final now = (_clock ?? DateTime.now)();
    final healthByProvider = {
      for (final snapshot in health)
        normalizeRegistryKey(snapshot.provider): snapshot,
    };
    final priority = _priorityIndex(
      options.providerPriority[normalizeRegistryKey(model)] ?? const [],
    );

    ranked.sort((left, right) {
      final leftKey = normalizeRegistryKey(left.name);
      final rightKey = normalizeRegistryKey(right.name);
      final leftOverride = priority[leftKey];
      final rightOverride = priority[rightKey];
      if ((leftOverride == null) != (rightOverride == null)) {
        return leftOverride == null ? 1 : -1;
      }
      if (leftOverride != null &&
          rightOverride != null &&
          leftOverride != rightOverride) {
        return leftOverride.compareTo(rightOverride);
      }

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

      final leftLatency = leftHealth?.lastLatency ?? Duration.zero;
      final rightLatency = rightHealth?.lastLatency ?? Duration.zero;
      if (leftLatency > Duration.zero &&
          rightLatency > Duration.zero &&
          leftLatency != rightLatency) {
        return leftLatency.compareTo(rightLatency);
      }
      return leftKey.compareTo(rightKey);
    });
    return List.unmodifiable(ranked);
  }
}

/// Selection-specific client options used by [Selector].
class ClientSelectionOptions {
  const ClientSelectionOptions({this.providerPriority = const {}});

  final Map<String, List<String>> providerPriority;
}

Map<String, int> _priorityIndex(Iterable<String> providers) {
  final out = <String, int>{};
  var index = 0;
  for (final provider in providers.map(normalizeRegistryKey)) {
    if (provider.isEmpty || out.containsKey(provider)) continue;
    out[provider] = index++;
  }
  return out;
}

bool _activeCooldown(HealthSnapshot? snapshot, DateTime now) {
  final cooldownUntil = snapshot?.cooldownUntil;
  return cooldownUntil != null && cooldownUntil.isAfter(now);
}
