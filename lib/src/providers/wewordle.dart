import 'dart:convert';
import 'dart:io';

import '../provider.dart';
import '../types.dart';

const wewordleName = 'wewordle';
const wewordleDefaultModel = 'v3';
const wewordleEndpoint = 'https://llmproxy.org/api/chat.php';

/// No-auth SSE provider backed by llmproxy.org.
class WeWordle implements Provider {
  WeWordle({String endpoint = wewordleEndpoint, HttpClient? httpClient})
    : _endpoint = Uri.parse(endpoint),
      _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final HttpClient _httpClient;

  @override
  String get name => wewordleName;

  @override
  List<String> get supportedModels => const [
    wewordleName,
    wewordleDefaultModel,
    'gpt-4',
    'gpt-4o',
    'gpt-4o-mini',
    'deepseek',
  ];

  @override
  Future<CompletionResponse> complete(List<Message> messages) async {
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.headers.set('Origin', 'https://chat-gpt.com');
    request.headers.set(HttpHeaders.refererHeader, 'https://chat-gpt.com/');
    request.write(
      jsonEncode({
        'messages': messages.map((message) => message.toJson()).toList(),
        'model': wewordleDefaultModel,
        'cost': 1,
        'stream': true,
        'web_search': false,
      }),
    );

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

    return CompletionResponse(
      model: wewordleDefaultModel,
      provider: name,
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: _readSse(body)),
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
}

String _readSse(String body) {
  final buffer = StringBuffer();
  for (final raw in const LineSplitter().convert(body)) {
    if (!raw.startsWith('data: ')) continue;
    final payload = raw.substring('data: '.length);
    if (payload == '[DONE]') break;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) continue;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }
      final delta = (choices.first as Map)['delta'];
      if (delta is Map) buffer.write(delta['content'] as String? ?? '');
    } on FormatException {
      // Provider sends credit/comment lines too; ignore non-JSON SSE payloads.
    }
  }
  return buffer.toString();
}
