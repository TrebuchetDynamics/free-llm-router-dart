import 'dart:convert';
import 'dart:io';

import '../provider.dart';
import '../types.dart';

const chataiName = 'chatai';
const chataiDefaultModel = 'gpt-4o-mini';
const chataiEndpoint = 'https://chatai.ren/api/chat';
const chataiStaticToken = 'ddnon5svtivajdspg7rscqw5';

/// No-auth SSE provider backed by chatai.ren.
class Chatai implements Provider {
  Chatai({
    String endpoint = chataiEndpoint,
    String token = chataiStaticToken,
    HttpClient? httpClient,
  }) : _endpoint = Uri.parse(endpoint),
       _token = token,
       _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final String _token;
  final HttpClient _httpClient;

  @override
  String get name => chataiName;

  @override
  List<String> get supportedModels => const [
    chataiName,
    chataiDefaultModel,
    'gpt-4o-mini-chatai',
  ];

  @override
  Future<CompletionResponse> complete(List<Message> messages) async {
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.write(
      jsonEncode({
        'machineId': 'gollmfree',
        'msg': messages.map((message) => message.toJson()).toList(),
        'token': _token,
        'type': 1,
      }),
    );

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.transform(utf8.decoder).join();
      throw HttpException(
        _statusMessage(response.statusCode, body),
        uri: _endpoint,
      );
    }

    final text = await _readSse(response.transform(utf8.decoder));
    return CompletionResponse(
      model: chataiDefaultModel,
      provider: name,
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: text),
          finishReason: 'stop',
        ),
      ],
    );
  }

  @override
  Stream<String> stream(List<Message> messages) async* {
    final completion = await complete(messages);
    if (completion.choices.isNotEmpty) {
      yield completion.choices.first.message.content;
    }
  }

  String _statusMessage(int statusCode, String body) {
    final snippet = body.trim();
    return snippet.isEmpty
        ? '$name: unexpected status $statusCode'
        : '$name: unexpected status $statusCode: $snippet';
  }

  Future<String> _readSse(Stream<String> lines) async {
    final buffer = StringBuffer();
    await for (final raw in lines.transform(const LineSplitter())) {
      if (!raw.startsWith('data: ')) continue;
      final payload = raw.substring('data: '.length);
      if (payload == '[DONE]') break;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final choices = decoded['choices'];
          if (choices is List && choices.isNotEmpty && choices.first is Map) {
            final delta = (choices.first as Map)['delta'];
            if (delta is Map) buffer.write(delta['content'] as String? ?? '');
          }
        }
      } on FormatException {
        // Match the Go port: skip malformed SSE data lines.
      }
    }
    return buffer.toString();
  }
}
