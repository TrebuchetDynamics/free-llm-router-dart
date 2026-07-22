/// Point-in-time copy of provider health state.
class HealthSnapshot {
  const HealthSnapshot({
    required this.provider,
    this.successes = 0,
    this.failures = 0,
    this.consecutiveFailures = 0,
    this.lastLatency = Duration.zero,
    this.lastSuccess,
    this.lastError = '',
    this.cooldownUntil,
  });

  final String provider;
  final int successes;
  final int failures;
  final int consecutiveFailures;
  final Duration lastLatency;
  final DateTime? lastSuccess;
  final String lastError;
  final DateTime? cooldownUntil;

  HealthSnapshot copyWith({
    int? successes,
    int? failures,
    int? consecutiveFailures,
    Duration? lastLatency,
    DateTime? lastSuccess,
    String? lastError,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
  }) {
    return HealthSnapshot(
      provider: provider,
      successes: successes ?? this.successes,
      failures: failures ?? this.failures,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastLatency: lastLatency ?? this.lastLatency,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      lastError: lastError ?? this.lastError,
      cooldownUntil: clearCooldown ? null : cooldownUntil ?? this.cooldownUntil,
    );
  }
}

/// Records provider success/failure health.
class HealthStore {
  HealthStore({
    int cooldownThreshold = 3,
    Duration cooldownDuration = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _cooldownThreshold = cooldownThreshold < 1 ? 1 : cooldownThreshold,
       _cooldownDuration = cooldownDuration.isNegative
           ? Duration.zero
           : cooldownDuration,
       _clock = clock ?? DateTime.now;

  final int _cooldownThreshold;
  final Duration _cooldownDuration;
  final DateTime Function() _clock;
  final Map<String, HealthSnapshot> _byProvider = {};

  void recordSuccess(String provider, Duration latency) {
    if (provider.isEmpty) return;
    final snap = _byProvider[provider] ?? HealthSnapshot(provider: provider);
    _byProvider[provider] = snap.copyWith(
      successes: snap.successes + 1,
      consecutiveFailures: 0,
      lastLatency: latency,
      lastSuccess: _clock(),
      lastError: '',
      clearCooldown: true,
    );
  }

  void recordFailure(String provider, Duration latency, Object error) {
    if (provider.isEmpty) return;
    final snap = _byProvider[provider] ?? HealthSnapshot(provider: provider);
    final consecutiveFailures = snap.consecutiveFailures + 1;
    _byProvider[provider] = snap.copyWith(
      failures: snap.failures + 1,
      consecutiveFailures: consecutiveFailures,
      lastLatency: latency,
      lastError: error.toString(),
      cooldownUntil:
          consecutiveFailures >= _cooldownThreshold &&
              _cooldownDuration > Duration.zero
          ? _clock().add(_cooldownDuration)
          : snap.cooldownUntil,
    );
  }

  List<HealthSnapshot> snapshot() {
    final out = _byProvider.values.toList()
      ..sort((left, right) => left.provider.compareTo(right.provider));
    return List.unmodifiable(out);
  }
}
