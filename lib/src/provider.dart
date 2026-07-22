import 'types.dart';

/// Common contract implemented by every anonymous/free LLM provider.
abstract interface class Provider {
  /// Stable registry name for this provider.
  String get name;

  /// Model aliases or provider names supported by this provider.
  List<String> get supportedModels;

  /// Returns one non-streaming chat completion for [messages].
  Future<CompletionResponse> complete(List<Message> messages);

  /// Returns text chunks for [messages]. Providers without native streaming may
  /// emit one full-response chunk.
  Stream<String> stream(List<Message> messages);
}

/// Optional richer provider contract for adapters that need request metadata.
abstract interface class RequestProvider implements Provider {
  /// Returns one non-streaming chat completion for the whole [request].
  Future<CompletionResponse> completeRequest(ChatRequest request);

  /// Returns text chunks for the whole [request].
  Stream<String> streamRequest(ChatRequest request);
}

/// Provider registration metadata used by the client selector.
class ProviderInfo {
  ProviderInfo({
    required this.name,
    required this.provider,
    Iterable<String> supportedModels = const [],
    this.defaultPriority = 0,
  }) : supportedModels = List.unmodifiable(supportedModels);

  final String name;
  final Provider provider;
  final List<String> supportedModels;
  final int defaultPriority;

  ProviderInfo copyWith({String? name, List<String>? supportedModels}) {
    return ProviderInfo(
      name: name ?? this.name,
      provider: provider,
      supportedModels: supportedModels ?? this.supportedModels,
      defaultPriority: defaultPriority,
    );
  }
}

/// A known model alias and providers that can handle it.
class ModelInfo {
  const ModelInfo({required this.alias, required this.providers});

  final String alias;
  final List<String> providers;
}
