import 'dart:convert';
import 'dart:io';

import '../provider.dart';
import '../types.dart';

const pollinationsName = 'pollinationsai';
const pollinationsDefaultModel = 'openai-fast';
const pollinationsTextEndpoint = 'https://text.pollinations.ai/openai';

/// No-auth PollinationsAI text provider.
class PollinationsAI implements RequestProvider {
  PollinationsAI({
    String endpoint = pollinationsTextEndpoint,
    HttpClient? httpClient,
  }) : _endpoint = Uri.parse(endpoint),
       _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final HttpClient _httpClient;

  @override
  String get name => pollinationsName;

  @override
  List<String> get supportedModels => const [
    'auto',
    'best',
    pollinationsName,
    pollinationsDefaultModel,
    'gpt-4.1-nano',
  ];

  @override
  Future<CompletionResponse> complete(List<Message> messages) {
    return completeRequest(
      ChatRequest(model: pollinationsDefaultModel, messages: messages),
    );
  }

  @override
  Future<CompletionResponse> completeRequest(ChatRequest chatRequest) async {
    final providerModel = _providerModel(chatRequest.model);
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    final requestBody =
        chatRequest.copyWith(model: providerModel, stream: false).toJson()
          ..['stream'] = false;
    request.write(jsonEncode(requestBody));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final snippet = body.trim();
      throw HttpException(
        snippet.isEmpty
            ? '$name: unexpected status ${response.statusCode}'
            : '$name: unexpected status ${response.statusCode}: $snippet',
        uri: _endpoint,
      );
    }

    final Map<String, Object?> decoded;
    try {
      final json = jsonDecode(body);
      if (json is! Map) throw const FormatException('expected JSON object');
      decoded = json.cast<String, Object?>();
    } on FormatException catch (error) {
      throw FormatException('$name: decode response: ${error.message}');
    }
    final completion = CompletionResponse.fromJson(decoded);
    return completion.copyWith(
      provider: completion.provider ?? name,
      model: completion.model ?? providerModel,
    );
  }

  @override
  Stream<String> stream(List<Message> messages) {
    return streamRequest(
      ChatRequest(model: pollinationsDefaultModel, messages: messages),
    );
  }

  @override
  Stream<String> streamRequest(ChatRequest request) async* {
    final completion = await completeRequest(request);
    if (completion.choices.isNotEmpty) {
      yield completion.choices.first.message.content;
    }
  }
}

String _providerModel(String model) {
  final normalized = model.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'auto' ||
      normalized == 'best' ||
      normalized == pollinationsName ||
      normalized == 'gpt-4.1-nano') {
    return pollinationsDefaultModel;
  }
  return model.trim();
}
