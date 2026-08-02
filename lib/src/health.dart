/// Health trend direction for a provider.
enum HealthTrend {
  /// Recent latency is improving.
  improving,

  /// No significant change.
  stable,

  /// Latency degrading or success rate declining.
  declining,
}

/// Point-in-time copy of provider health state.
///
/// Enhanced with trend tracking and latency statistics inspired by
/// OmniRoute's health monitoring system.
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
    this.trend = HealthTrend.stable,
    this.recentLatencies = const [],
  });

  final String provider;
  final int successes;
  final int failures;
  final int consecutiveFailures;
  final Duration lastLatency;
  final DateTime? lastSuccess;
  final String lastError;
  final DateTime? cooldownUntil;

  /// Current health trend direction.
  final HealthTrend trend;

  /// Recent latency samples (most recent last), capped at 10.
  final List<Duration> recentLatencies;

  /// Success rate as a fraction [0.0, 1.0].
  double get successRate {
    final total = successes + failures;
    return total == 0 ? 1.0 : successes / total;
  }

  /// Average latency of recent samples.
  Duration get averageLatency {
    if (recentLatencies.isEmpty) return lastLatency;
    final totalUs = recentLatencies.fold<int>(
      0,
      (s, d) => s + d.inMicroseconds,
    );
    return Duration(microseconds: totalUs ~/ recentLatencies.length);
  }

  /// Whether this provider is currently on cooldown.
  bool isOnCooldown([DateTime? now]) {
    if (cooldownUntil == null) return false;
    return cooldownUntil!.isAfter(now ?? DateTime.now());
  }

  HealthSnapshot copyWith({
    int? successes,
    int? failures,
    int? consecutiveFailures,
    Duration? lastLatency,
    DateTime? lastSuccess,
    String? lastError,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
    HealthTrend? trend,
    List<Duration>? recentLatencies,
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
      trend: trend ?? this.trend,
      recentLatencies: recentLatencies ?? this.recentLatencies,
    );
  }
}

/// Records provider success/failure health with trend tracking.
///
/// Tracks latency history and computes health trends (improving/stable/declining)
/// inspired by OmniRoute's health monitoring.
class HealthStore {
  HealthStore({
    int cooldownThreshold = 3,
    Duration cooldownDuration = const Duration(minutes: 5),
    DateTime Function()? clock,
    int latencyHistorySize = 10,
  }) : _cooldownThreshold = cooldownThreshold < 1 ? 1 : cooldownThreshold,
       _cooldownDuration = cooldownDuration.isNegative
           ? Duration.zero
           : cooldownDuration,
       _clock = clock ?? DateTime.now,
       _latencyHistorySize = latencyHistorySize < 1 ? 1 : latencyHistorySize;

  final int _cooldownThreshold;
  final Duration _cooldownDuration;
  final DateTime Function() _clock;
  final int _latencyHistorySize;
  final Map<String, HealthSnapshot> _byProvider = {};

  void recordSuccess(String provider, Duration latency) {
    if (provider.isEmpty) return;
    final snap = _byProvider[provider] ?? HealthSnapshot(provider: provider);
    final updatedLatencies = _appendLatency(snap.recentLatencies, latency);
    final trend = _computeTrend(updatedLatencies);
    _byProvider[provider] = snap.copyWith(
      successes: snap.successes + 1,
      consecutiveFailures: 0,
      lastLatency: latency,
      lastSuccess: _clock(),
      lastError: '',
      clearCooldown: true,
      trend: trend,
      recentLatencies: updatedLatencies,
    );
  }

  void recordFailure(String provider, Duration latency, Object error) {
    if (provider.isEmpty) return;
    final snap = _byProvider[provider] ?? HealthSnapshot(provider: provider);
    final consecutiveFailures = snap.consecutiveFailures + 1;
    final updatedLatencies = _appendLatency(snap.recentLatencies, latency);
    final trend = _computeTrend(updatedLatencies);
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
      trend: trend,
      recentLatencies: updatedLatencies,
    );
  }

  List<HealthSnapshot> snapshot() {
    final out = _byProvider.values.toList()
      ..sort((left, right) => left.provider.compareTo(right.provider));
    return List.unmodifiable(out);
  }

  /// Reset all tracked health state.
  void reset() {
    _byProvider.clear();
  }

  List<Duration> _appendLatency(List<Duration> current, Duration latency) {
    final updated = [...current, latency];
    final overflow = updated.length - _latencyHistorySize;
    return overflow > 0 ? updated.sublist(overflow) : updated;
  }

  HealthTrend _computeTrend(List<Duration> latencies) {
    if (latencies.length < 4) return HealthTrend.stable;

    // Compare recent half vs older half average latency
    final mid = latencies.length ~/ 2;
    final older = latencies.sublist(0, mid);
    final newer = latencies.sublist(mid);

    final olderAvg =
        older.fold<int>(0, (s, d) => s + d.inMicroseconds) / older.length;
    final newerAvg =
        newer.fold<int>(0, (s, d) => s + d.inMicroseconds) / newer.length;

    // 10% threshold for trend change
    if (olderAvg == 0) return HealthTrend.stable;
    final delta = (newerAvg - olderAvg) / olderAvg;
    if (delta < -0.10) return HealthTrend.improving;
    if (delta > 0.10) return HealthTrend.declining;

    return HealthTrend.stable;
  }
}
