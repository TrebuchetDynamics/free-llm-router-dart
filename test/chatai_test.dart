import 'dart:convert';
import 'dart:io';

import 'package:free_llm_router/free_llm_router.dart';
import 'package:free_llm_router/providers.dart';
import 'package:test/test.dart';

void main() {
  test('Chatai posts upstream shape and parses SSE deltas', () async {
    late Map<String, Object?> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, ContentType.json.mimeType);
      expect(
        request.headers.value(HttpHeaders.acceptHeader),
        'text/event-stream',
      );
      seen = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, Object?>();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('text', 'event-stream')
        ..write('data: {"choices":[{"delta":{"content":"hello"}}]}\n\n')
        ..write('event: ignored\n\n')
        ..write('data: {"choices":[{"delta":{"content":" world"}}]}\n\n')
        ..write('data: [DONE]\n\n');
      await request.response.close();
    });

    try {
      final provider = Chatai(
        endpoint: 'http://${server.address.host}:${server.port}',
        token: 'test-token',
      );
      final response = await provider.complete(const [
        Message(role: 'user', content: 'hi'),
      ]);
      await serverDone;

      expect(seen['machineId'], isNotEmpty);
      expect(seen['token'], 'test-token');
      expect(seen['type'], 1);
      expect((seen['msg'] as List).single['content'], 'hi');
      expect(response.provider, chataiName);
      expect(response.model, chataiDefaultModel);
      expect(response.choices.single.message.content, 'hello world');
    } finally {
      await server.close(force: true);
    }
  });
}
