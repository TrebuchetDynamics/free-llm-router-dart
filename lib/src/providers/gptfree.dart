import 'dart:convert';
import 'dart:io';

import '../provider.dart';
import '../types.dart';

const gptFreeName = 'gptfree';
const gptFreeEndpoint =
    'https://us-central1-gptfree-2.cloudfunctions.net/agent_stream';
const gptFreeAuthEndpoint =
    'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyBdU-Np8RSh1tPSsPOWg3qIm6PnVK5PQb4';

/// No-auth provider backed by gptfree.com.
class GptFree implements Provider {
  GptFree({
    String endpoint = gptFreeEndpoint,
    String authEndpoint = gptFreeAuthEndpoint,
    HttpClient? httpClient,
  }) : _endpoint = Uri.parse(endpoint),
       _authEndpoint = Uri.parse(authEndpoint),
       _httpClient = httpClient ?? HttpClient();

  final Uri _endpoint;
  final Uri _authEndpoint;
  final HttpClient _httpClient;

  @override
  String get name => gptFreeName;

  @override
  List<String> get supportedModels => const [gptFreeName];

  @override
  Future<CompletionResponse> complete(List<Message> messages) async {
    final token = await _idToken();
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set('Origin', 'https://gptfree.com');
    request.headers.set(HttpHeaders.refererHeader, 'https://gptfree.com/');
    request.write(jsonEncode(_payload(messages)));

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
      model: gptFreeName,
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

  Future<String> _idToken() async {
    final request = await _httpClient.postUrl(_authEndpoint);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'returnSecureToken': true}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '$name auth: unexpected status ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['idToken'] is! String) {
      throw FormatException('$name auth: missing idToken');
    }
    return decoded['idToken'] as String;
  }
}

Map<String, Object?> _payload(List<Message> messages) {
  final history = <Map<String, String>>[];
  var current = '';
  for (final message in messages) {
    if (message.role == 'assistant') {
      history.add({'type': 'agent', 'content': message.content});
    } else {
      current = message.content;
      history.add({'type': 'user', 'content': message.content});
    }
  }
  if (history.isNotEmpty && history.last['type'] == 'user') {
    history.removeLast();
  }
  return {
    'message': current.isEmpty ? 'Hello' : current,
    'images': [],
    'history': history,
  };
}

String _readSse(String body) {
  final buffer = StringBuffer();
  for (final raw in const LineSplitter().convert(body)) {
    if (!raw.startsWith('data: ')) continue;
    final payload = raw.substring('data: '.length);
    if (payload == '{}') continue;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) buffer.write(decoded['response'] as String? ?? '');
    } on FormatException {
      // Ignore keepalive/comment lines.
    }
  }
  return buffer.toString();
}
