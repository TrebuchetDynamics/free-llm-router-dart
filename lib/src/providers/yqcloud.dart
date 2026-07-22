import 'dart:convert';
import 'dart:io';

import '../provider.dart';
import '../types.dart';

const yqcloudName = 'yqcloud';
const yqcloudDefaultModel = 'gpt-3.5-turbo';
const yqcloudEndpoint = 'https://api.aichatos.cloud/api/generateStream';

/// No-auth plain-stream provider backed by the Yqcloud API.
class Yqcloud implements Provider {
  Yqcloud({String endpoint = yqcloudEndpoint, HttpClient? httpClient})
    : _endpoint = Uri.parse(endpoint),
      _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final HttpClient _httpClient;

  @override
  String get name => yqcloudName;

  @override
  List<String> get supportedModels => const [
    yqcloudName,
    'gpt-3.5-turbo-yqcloud',
  ];

  @override
  Future<CompletionResponse> complete(List<Message> messages) async {
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    request.headers.set('Origin', 'https://chat9.yqcloud.top');
    request.headers.set(
      HttpHeaders.refererHeader,
      'https://chat9.yqcloud.top/',
    );
    request.write(
      jsonEncode({
        'prompt': yqcloudBuildPrompt(messages),
        'userId': 'gollmfree',
        'network': true,
        'system': '',
        'withGPT': false,
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
      model: yqcloudDefaultModel,
      provider: name,
      choices: [
        Choice(
          index: 0,
          message: Message(role: 'assistant', content: body.split('\n').join()),
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

/// Flattens messages into the last user prompt expected by the Yqcloud API.
String yqcloudBuildPrompt(List<Message> messages) {
  if (messages.isEmpty) return '';
  for (var index = messages.length - 1; index >= 0; index--) {
    if (messages[index].role == 'user') return messages[index].content;
  }
  return messages.last.content;
}
