/// One chat message exchanged with a provider.
class Message {
  const Message({required this.role, required this.content});

  factory Message.fromJson(Map<String, Object?> json) {
    return Message(
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  final String role;
  final String content;

  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

/// OpenAI-shaped chat completion request.
class ChatRequest {
  const ChatRequest({
    this.model = 'auto',
    required this.messages,
    this.stream = false,
    this.temperature,
    this.maxTokens,
  });

  final String model;
  final List<Message> messages;
  final bool stream;
  final double? temperature;
  final int? maxTokens;

  ChatRequest copyWith({
    String? model,
    List<Message>? messages,
    bool? stream,
    double? temperature,
    int? maxTokens,
  }) {
    return ChatRequest(
      model: model ?? this.model,
      messages: messages ?? this.messages,
      stream: stream ?? this.stream,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  Map<String, Object?> toJson() => {
    'model': model,
    'messages': messages.map((message) => message.toJson()).toList(),
    if (stream) 'stream': true,
    if (temperature != null) 'temperature': temperature,
    if (maxTokens != null) 'max_tokens': maxTokens,
  };
}

/// Provider response normalized into an OpenAI-shaped completion payload.
class CompletionResponse {
  const CompletionResponse({
    this.id,
    this.object,
    this.created,
    this.model,
    this.provider,
    required this.choices,
  });

  factory CompletionResponse.fromJson(Map<String, Object?> json) {
    final choicesJson = json['choices'];
    return CompletionResponse(
      id: json['id'] as String?,
      object: json['object'] as String?,
      created: switch (json['created']) {
        final int value => value,
        final num value => value.toInt(),
        _ => null,
      },
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      choices: choicesJson is List
          ? choicesJson
                .whereType<Map>()
                .map(
                  (choice) => Choice.fromJson(choice.cast<String, Object?>()),
                )
                .toList()
          : const [],
    );
  }

  final String? id;
  final String? object;
  final int? created;
  final String? model;
  final String? provider;
  final List<Choice> choices;

  CompletionResponse copyWith({String? model, String? provider}) {
    return CompletionResponse(
      id: id,
      object: object,
      created: created,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      choices: choices,
    );
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    if (object != null) 'object': object,
    if (created != null) 'created': created,
    if (model != null) 'model': model,
    if (provider != null) 'provider': provider,
    'choices': choices.map((choice) => choice.toJson()).toList(),
  };
}

/// One completion alternative.
class Choice {
  const Choice({required this.index, required this.message, this.finishReason});

  factory Choice.fromJson(Map<String, Object?> json) {
    final messageJson = json['message'];
    return Choice(
      index: switch (json['index']) {
        final int value => value,
        final num value => value.toInt(),
        _ => 0,
      },
      message: messageJson is Map
          ? Message.fromJson(messageJson.cast<String, Object?>())
          : const Message(role: '', content: ''),
      finishReason: json['finish_reason'] as String?,
    );
  }

  final int index;
  final Message message;
  final String? finishReason;

  Map<String, Object?> toJson() => {
    'index': index,
    'message': message.toJson(),
    if (finishReason != null) 'finish_reason': finishReason,
  };
}

/// Text fragment returned by [FreeLlmRouterClient.chatCompletionStream].
class StreamChunk {
  const StreamChunk({required this.content, this.provider, this.model});

  final String content;
  final String? provider;
  final String? model;
}
