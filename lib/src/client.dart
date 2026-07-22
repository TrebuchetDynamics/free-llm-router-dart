import 'dart:async';

import 'errors.dart';
import 'health.dart';
import 'provider.dart';
import 'registry.dart';
import 'selector.dart';
import 'types.dart';

/// Public entry point for chat completions.
class GollmfreeClient {
  GollmfreeClient({
    Registry? registry,
    Selector selector = const Selector(),
    String defaultModel = 'auto',
    Duration perAttemptTimeout = const Duration(seconds: 15),
    int maxRetries = 0,
    bool raceMode = false,
    int raceWidth = 2,
    Map<String, List<String>> providerPriority = const {},
  }) : _registry = registry ?? Registry(),
       _selector = selector,
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
       _providerPriority = _normalizeProviderPriority(providerPriority);

  final Registry _registry;
  final Selector _selector;
  final HealthStore _health = HealthStore();
  final String _defaultModel;
  final Duration _perAttemptTimeout;
  final int _maxRetries;
  final bool _raceMode;
  final int _raceWidth;
  final Map<String, List<String>> _providerPriority;

  /// Attempts ranked providers until one returns a completion.
  Future<CompletionResponse> chatCompletion(ChatRequest request) async {
    final route = _resolveModelRoute(request.model);
    final candidates = _candidatesFor(route);
    if (candidates.isEmpty) {
      throw StateError(
        'gollmfree: no providers for model "${route.requested}"',
      );
    }
    final ranked = _selector.rank(
      route.providerModel,
      candidates,
      _health.snapshot(),
      ClientSelectionOptions(providerPriority: _providerPriority),
    );
    if (_raceMode && ranked.length > 1) {
      return _raceCompletion(route.providerModel, request, ranked);
    }

    final attempts = <AttemptException>[];
    for (final candidate in ranked) {
      for (var attempt = 1; attempt <= _maxRetries + 1; attempt++) {
        try {
          return await _completeWith(
            candidate,
            request,
            route.providerModel,
            attempt,
          );
        } on AttemptException catch (error) {
          attempts.add(error);
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
        'gollmfree: no providers for model "${route.requested}"',
      );
    }
    final ranked = _selector.rank(
      route.providerModel,
      candidates,
      _health.snapshot(),
      ClientSelectionOptions(providerPriority: _providerPriority),
    );
    final attempts = <AttemptException>[];
    for (final candidate in ranked) {
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
        _health.recordSuccess(candidate.name, stopwatch.elapsed);
        return;
      } catch (error) {
        _health.recordFailure(candidate.name, stopwatch.elapsed, error);
        attempts.add(
          AttemptException(provider: candidate.name, attempt: 1, error: error),
        );
      }
    }
    throw CombinedException(List.unmodifiable(attempts));
  }

  /// Current provider health snapshots.
  List<HealthSnapshot> health() => _health.snapshot();

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
      _health.recordSuccess(candidate.name, stopwatch.elapsed);
      return response.copyWith(
        provider: response.provider ?? candidate.name,
        model: response.model ?? model,
      );
    } catch (error) {
      _health.recordFailure(candidate.name, stopwatch.elapsed, error);
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

/// Backward-friendly alias for the package client.
typedef Client = GollmfreeClient;

Map<String, List<String>> _normalizeProviderPriority(
  Map<String, List<String>> input,
) {
  final out = <String, List<String>>{};
  for (final entry in input.entries) {
    final model = normalizeRegistryKey(entry.key);
    if (model.isEmpty) continue;
    final providers = normalizeModelAliases(entry.value);
    if (providers.isNotEmpty) out[model] = providers;
  }
  return Map.unmodifiable(out);
}
