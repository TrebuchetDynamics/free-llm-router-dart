import 'dart:convert';
import 'dart:io';

import 'package:free_llm_router/free_llm_router.dart';
import 'package:free_llm_router/providers.dart';
import 'package:test/test.dart';

void main() {
  test('GptFree signs up anonymously and parses SSE result', () async {
    late Map<String, Object?> seen;
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.take(2).listen((request) async {
      requests++;
      if (requests == 1) {
        await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'idToken': 'token-123'}));
      } else {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer token-123',
        );
        seen = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
            .cast<String, Object?>();
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType('text', 'event-stream')
          ..write('event: result\n')
          ..write('data: ${jsonEncode({'response': 'pong'})}\n\n');
      }
      await request.response.close();
    }).asFuture<void>();

    try {
      final url = 'http://${server.address.host}:${server.port}';
      final provider = GptFree(endpoint: url, authEndpoint: url);
      final response = await provider.complete(const [
        Message(role: 'system', content: 'brief'),
        Message(role: 'user', content: 'ping'),
      ]);
      await serverDone.timeout(const Duration(seconds: 1));

      expect(seen['message'], 'ping');
      expect(seen['images'], isEmpty);
      expect(response.provider, gptFreeName);
      expect(response.choices.single.message.content, 'pong');
    } finally {
      await server.close(force: true);
    }
  });
}
