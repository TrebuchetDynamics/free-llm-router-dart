import 'dart:async';

import 'degradation.dart';
import 'errors.dart';
import 'fallback_policy.dart';
import 'health.dart';
import 'provider.dart';
import 'registry.dart';
import 'routing_strategy.dart';
import 'types.dart';

/// Public entry point for chat completions.
///
/// Supports multi-strategy routing, graceful degradation, and configurable
/// fallback policies inspired by OmniRoute's routing engine.
class FreeLlmRouterClient {
  FreeLlmRouterClient({
    Registry? registry,
    StrategySelector? selector,
    String defaultModel = 'auto',
    Duration perAttemptTimeout = const Duration(seconds: 15),
    int maxRetries = 0,
    bool raceMode = false,
    int raceWidth = 2,
    StrategyOptions strategyOptions = const StrategyOptions(),
    FallbackPolicy? fallbackPolicy,
  }) : _registry = registry ?? Registry(),
       _selector = selector ?? StrategySelector(),
       _defaultModel = defaultModel.trim().isEmpty ? 'auto' : defaultModel,
       _perAttemptTimeout = perAttemptTimeout <= Duration.zero
           ? const Duration(seconds: 15)
           : perAttemptTimeout,
       _maxRetries = maxRetries < 0
           ? 0
           : maxRetries > _maxRetriesCap
           ? _maxRetriesCap
           : maxRetries,
       _raceMode = raceMode,
       _raceWidth = raceWidth < 1 ? 1 : raceWidth,
       _strategyOptions = strategyOptions,
       _fallbackPolicy = fallbackPolicy;

  final Registry _registry;
  final StrategySelector _selector;
  final HealthStore _health = HealthStore();
  final DegradationRegistry _degradation = DegradationRegistry();
  final String _defaultModel;
  final Duration _perAttemptTimeout;
  final int _maxRetries;
  final bool _raceMode;
  final int _raceWidth;
  final StrategyOptions _strategyOptions;
  final FallbackPolicy? _fallbackPolicy;

  /// Attempts ranked providers until one returns a completion.
  ///
  /// Uses the configured routing strategy and respects fallback policies.
  Future<CompletionResponse> chatCompletion(ChatRequest request) async {
    final route = _resolveModelRoute(request.model);
    final candidates = _candidatesFor(route);
    if (candidates.isEmpty) {
      throw StateError(
        'free_llm_router: no providers for model "${route.requested}"',
      );
    }
    final ranked = _selector.rank(
      route.providerModel,
      candidates,
      _health.snapshot(),
      _strategyOptions,
    );
    if (_raceMode && ranked.length > 1) {
      return _raceCompletion(route.providerModel, request, ranked);
    }

    final attempts = <AttemptException>[];
    final excluded = <String>[];

    // Try configured fallback chain first, then strategy-ranked providers
    final fallbackProviders = _fallbackPolicy?.resolve(
      route.lookupModel,
      exclude: excluded,
    );
    final orderedProviders = fallbackProviders != null
        ? _mergeWithRanked(fallbackProviders, ranked)
        : ranked;

    for (final candidate in orderedProviders) {
      for (var attempt = 1; attempt <= _maxRetries + 1; attempt++) {
        try {
          final result = await _completeWith(
            candidate,
            request,
            route.providerModel,
            attempt,
          );
          return result;
        } on AttemptException catch (error) {
          attempts.add(error);
          excluded.add(candidate.name);
        }
      }
    }
    throw CombinedException(List.unmodifiable(attempts));
  }

  /// Streams text chunks from the first ranked provider that starts successfully.
  Stream<StreamChunk> chatCompletionStream(ChatRequest request) async* {
    final route = _resolveModelRoute(request.model);
    final candidates = _candidatesFor(route);
    if (candidates.isEmpty) {
      throw StateError(
        'free_llm_router: no providers for model "${route.requested}"',
      );
    }
    final ranked = _selector.rank(
      route.providerModel,
      candidates,
      _health.snapshot(),
      _strategyOptions,
    );
    final fallbackProviders = _fallbackPolicy?.resolve(route.lookupModel);
    final orderedProviders = fallbackProviders != null
        ? _mergeWithRanked(fallbackProviders, ranked)
        : ranked;
    final attempts = <AttemptException>[];
    for (final candidate in orderedProviders) {
      final stopwatch = Stopwatch()..start();
      try {
        final requestForProvider = request.copyWith(model: route.providerModel);
        final chunks = switch (candidate.provider) {
          final RequestProvider provider => provider.streamRequest(
            requestForProvider,
          ),
          final provider => provider.stream(request.messages),
        };
        await for (final chunk in chunks.timeout(_perAttemptTimeout)) {
          yield StreamChunk(
            content: chunk,
            provider: candidate.name,
            model: route.providerModel,
          );
        }
        _recordSuccess(candidate.name, stopwatch.elapsed);
        return;
      } catch (error) {
        _recordFailure(candidate.name, stopwatch.elapsed, error);
        attempts.add(
          AttemptException(provider: candidate.name, attempt: 1, error: error),
        );
      }
    }
    throw CombinedException(List.unmodifiable(attempts));
  }

  /// Current provider health snapshots.
  List<HealthSnapshot> health() => _health.snapshot();

  /// Current degradation status for all tracked features.
  List<DegradationStatus> degradation() => _degradation.getAll();

  /// The degradation registry for direct access if needed.
  DegradationRegistry get degradationRegistry => _degradation;

  void _recordSuccess(String provider, Duration latency) {
    _health.recordSuccess(provider, latency);
    _degradation.record(provider, DegradationLevel.healthy);
  }

  void _recordFailure(String provider, Duration latency, Object error) {
    _health.recordFailure(provider, latency, error);
    _degradation.record(
      provider,
      DegradationLevel.failed,
      reason: error.toString(),
    );
  }

  Future<CompletionResponse> _completeWith(
    ProviderInfo candidate,
    ChatRequest request,
    String model,
    int attempt,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final requestForProvider = request.copyWith(model: model);
      final completion = switch (candidate.provider) {
        final RequestProvider provider => provider.completeRequest(
          requestForProvider,
        ),
        final provider => provider.complete(request.messages),
      };
      final response = await completion.timeout(_perAttemptTimeout);
      _recordSuccess(candidate.name, stopwatch.elapsed);
      return response.copyWith(
        provider: response.provider ?? candidate.name,
        model: response.model ?? model,
      );
    } catch (error) {
      _recordFailure(candidate.name, stopwatch.elapsed, error);
      throw AttemptException(
        provider: candidate.name,
        attempt: attempt,
        error: error,
      );
    }
  }

  Future<CompletionResponse> _raceCompletion(
    String model,
    ChatRequest request,
    List<ProviderInfo> ranked,
  ) {
    final width = _raceWidth > ranked.length ? ranked.length : _raceWidth;
    final completer = Completer<CompletionResponse>();
    final attempts = <AttemptException>[];
    var remaining = width;

    for (final candidate in ranked.take(width)) {
      _completeWith(candidate, request, model, 1)
          .then((response) {
            if (!completer.isCompleted) completer.complete(response);
          })
          .catchError((Object error) {
            if (error is AttemptException) attempts.add(error);
            remaining--;
            if (remaining == 0 && !completer.isCompleted) {
              completer.completeError(
                CombinedException(List.unmodifiable(attempts)),
              );
            }
          });
    }
    return completer.future;
  }

  _ModelRoute _resolveModelRoute(String rawModel) {
    final requested = normalizeRegistryKey(rawModel).isEmpty
        ? _defaultModel
        : rawModel.trim();
    final slash = requested.indexOf('/');
    if (slash > 0 && slash < requested.length - 1) {
      final provider = normalizeRegistryKey(requested.substring(0, slash));
      final providerModel = requested.substring(slash + 1).trim();
      if (provider.isNotEmpty && providerModel.isNotEmpty) {
        return _ModelRoute(
          requested: requested,
          lookupModel: provider,
          providerModel: providerModel,
          forcedProvider: provider,
        );
      }
    }
    final lookup = normalizeRegistryKey(requested);
    return _ModelRoute(
      requested: requested,
      lookupModel: lookup,
      providerModel: lookup,
    );
  }

  List<ProviderInfo> _candidatesFor(_ModelRoute route) {
    final forcedProvider = route.forcedProvider;
    if (forcedProvider != null) {
      final provider = _registry.provider(forcedProvider);
      return provider == null ? const [] : [provider];
    }
    return _registry.candidates(route.lookupModel);
  }
}

class _ModelRoute {
  const _ModelRoute({
    required this.requested,
    required this.lookupModel,
    required this.providerModel,
    this.forcedProvider,
  });

  final String requested;
  final String lookupModel;
  final String providerModel;
  final String? forcedProvider;
}

const _maxRetriesCap = 3;

/// Backward-compatible alias for the package client.
typedef Client = FreeLlmRouterClient;

/// Merges explicitly configured fallback providers with strategy-ranked
/// providers, deduplicating while preserving fallback order first.
List<ProviderInfo> _mergeWithRanked(
  List<String> fallbackProviders,
  List<ProviderInfo> ranked,
) {
  final result = <ProviderInfo>[];
  final seen = <String>{};

  // Add fallback providers first (in their configured order)
  for (final name in fallbackProviders) {
    final key = normalizeRegistryKey(name);
    if (seen.add(key)) {
      final info = ranked.where((p) => normalizeRegistryKey(p.name) == key);
      if (info.isNotEmpty) result.add(info.first);
    }
  }

  // Add remaining ranked providers
  for (final provider in ranked) {
    final key = normalizeRegistryKey(provider.name);
    if (seen.add(key)) {
      result.add(provider);
    }
  }

  return List.unmodifiable(result);
}
