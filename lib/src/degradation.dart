/// Graceful degradation framework for provider operations.
///
/// Inspired by OmniRoute's degradation system, this provides a standardized
/// pattern for handling provider failures with escalating fallback levels.
///
/// Hierarchy: Healthy → Degraded → Failed → Safe Default
library;

/// Degradation level for a provider or operation.
enum DegradationLevel {
  /// Provider is fully operational.
  healthy,

  /// Provider is partially operational (some failures, fallback active).
  degraded,

  /// Provider is non-operational but may recover.
  failed,

  /// All providers unavailable; using safe default behavior.
  default_,
}

/// Status report for a degraded operation.
class DegradationStatus {
  const DegradationStatus({
    required this.level,
    required this.feature,
    required this.capability,
    this.reason = '',
    required this.since,
  });

  /// Current degradation level.
  final DegradationLevel level;

  /// Name of the feature or provider.
  final String feature;

  /// Human-readable description of current capability.
  final String capability;

  /// Why the service is degraded (empty if healthy).
  final String reason;

  /// Timestamp of last status change.
  final DateTime since;
}

/// Result wrapper that includes degradation info.
class DegradedResult<T> {
  const DegradedResult({required this.result, required this.status});

  /// The actual result (from primary, fallback, or default).
  final T result;

  /// Degradation status.
  final DegradationStatus status;
}

/// Global degradation registry tracking all provider states.
class DegradationRegistry {
  DegradationRegistry();

  final Map<String, DegradationStatus> _registry = {};

  /// Execute an operation with graceful degradation.
  ///
  /// Tries [primary] first. If it fails, tries [fallback].
  /// If both fail, returns [safeDefault]. All transitions are tracked.
  Future<DegradedResult<T>> withDegradation<T>(
    String feature,
    Future<T> Function() primary,
    Future<T> Function() fallback,
    T safeDefault, {
    String? fullCapability,
    String? reducedCapability,
    String? defaultCapability,
    void Function(DegradationStatus)? onDegrade,
  }) async {
    final now = DateTime.now();

    // Try primary
    try {
      final result = await primary();
      final status = DegradationStatus(
        level: DegradationLevel.healthy,
        feature: feature,
        capability: fullCapability ?? 'Full capability',
        since: _lastSince(feature, now, DegradationLevel.healthy),
      );
      _update(feature, status);
      return DegradedResult(result: result, status: status);
    } catch (primaryError) {
      // Primary failed, try fallback
      try {
        final result = await fallback();
        final status = DegradationStatus(
          level: DegradationLevel.degraded,
          feature: feature,
          capability:
              reducedCapability ?? 'Reduced capability (fallback active)',
          reason: primaryError.toString(),
          since: _lastSince(feature, now, DegradationLevel.degraded),
        );
        _update(feature, status);
        onDegrade?.call(status);
        return DegradedResult(result: result, status: status);
      } catch (fallbackError) {
        // Both failed
        final reason = '$primaryError → $fallbackError';
        final status = DegradationStatus(
          level: DegradationLevel.default_,
          feature: feature,
          capability:
              defaultCapability ?? 'Safe default (all backends unavailable)',
          reason: reason,
          since: _lastSince(feature, now, DegradationLevel.failed),
        );
        _update(feature, status);
        onDegrade?.call(status);
        return DegradedResult(result: safeDefault, status: status);
      }
    }
  }

  /// Record a status observed outside [withDegradation].
  void record(
    String feature,
    DegradationLevel level, {
    String? capability,
    String reason = '',
  }) {
    final now = DateTime.now();
    _update(
      feature,
      DegradationStatus(
        level: level,
        feature: feature,
        capability: capability ?? _defaultCapability(level),
        reason: reason,
        since: _lastSince(feature, now, level),
      ),
    );
  }

  /// Get degradation status for a specific feature.
  DegradationStatus? getStatus(String feature) => _registry[feature];

  /// Get all tracked degradation statuses.
  List<DegradationStatus> getAll() =>
      _registry.values.toList()
        ..sort((a, b) => a.level.index.compareTo(b.level.index));

  /// Check if any feature is degraded or worse.
  bool hasAnyDegradation() =>
      _registry.values.any((s) => s.level != DegradationLevel.healthy);

  /// Get count of features at each degradation level.
  Map<DegradationLevel, int> getSummary() {
    final summary = {for (final level in DegradationLevel.values) level: 0};
    for (final status in _registry.values) {
      summary[status.level] = (summary[status.level] ?? 0) + 1;
    }
    return summary;
  }

  /// Reset the registry.
  void reset() => _registry.clear();

  DateTime _lastSince(String feature, DateTime now, DegradationLevel newLevel) {
    final existing = _registry[feature];
    if (existing != null && existing.level == newLevel) {
      return existing.since;
    }
    return now;
  }

  void _update(String feature, DegradationStatus status) {
    _registry[feature] = status;
  }

  String _defaultCapability(DegradationLevel level) => switch (level) {
    DegradationLevel.healthy => 'Full capability',
    DegradationLevel.degraded => 'Reduced capability (fallback active)',
    DegradationLevel.failed => 'Provider unavailable',
    DegradationLevel.default_ => 'Safe default (all backends unavailable)',
  };
}
