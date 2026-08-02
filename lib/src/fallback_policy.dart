/// Configurable per-model fallback policy.
///
/// Inspired by OmniRoute's fallback chain system, this allows users to
/// define explicit fallback chains per model. When the primary provider
/// fails, the client follows the configured chain.
library;

/// A single entry in a fallback chain.
class FallbackEntry {
  const FallbackEntry({
    required this.provider,
    this.priority = 0,
    this.enabled = true,
  });

  /// Provider name to try.
  final String provider;

  /// Lower = higher priority (tried first).
  final int priority;

  /// Whether this entry is active.
  final bool enabled;
}

/// A fallback chain for a specific model.
class FallbackChain {
  const FallbackChain(this.entries);

  /// Ordered list of fallback entries.
  final List<FallbackEntry> entries;

  /// Get the active providers sorted by priority.
  List<FallbackEntry> get active =>
      entries.where((e) => e.enabled).toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
}

/// Manages per-model fallback chains.
class FallbackPolicy {
  FallbackPolicy();

  final Map<String, FallbackChain> _chains = {};

  /// Register a fallback chain for a model.
  void register(String model, List<FallbackEntry> chain) {
    final sorted = List<FallbackEntry>.from(chain)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    _chains[model] = FallbackChain(sorted);
  }

  /// Resolve the fallback chain for a model, excluding specified providers.
  List<String> resolve(String model, {List<String> exclude = const []}) {
    final chain = _chains[model];
    if (chain == null) return const [];

    final excludeSet = Set<String>.from(exclude);
    return chain.active
        .where((e) => !excludeSet.contains(e.provider))
        .map((e) => e.provider)
        .toList();
  }

  /// Get the next provider in the fallback chain.
  String? next(String model, {List<String> exclude = const []}) {
    final chain = resolve(model, exclude: exclude);
    return chain.isEmpty ? null : chain.first;
  }

  /// Check if a model has any fallback providers configured.
  bool hasFallback(String model) {
    final chain = _chains[model];
    return chain != null && chain.active.isNotEmpty;
  }

  /// Remove a fallback chain for a model.
  bool remove(String model) => _chains.remove(model) != null;

  /// Get all registered fallback chains.
  Map<String, FallbackChain> get all => Map.unmodifiable(_chains);

  /// Reset all chains.
  void reset() => _chains.clear();
}
