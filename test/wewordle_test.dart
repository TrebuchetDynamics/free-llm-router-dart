import 'dart:convert';
import 'dart:io';

import 'package:free_llm_router/free_llm_router.dart';
import 'package:free_llm_router/providers.dart';
import 'package:test/test.dart';

void main() {
  test('WeWordle posts current SSE shape and parses content deltas', () async {
    late Map<String, Object?> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, ContentType.json.mimeType);
      seen = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, Object?>();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('text', 'event-stream')
        ..write('data: {"credits":29}\n\n')
        ..write(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'hello'},
              },
            ],
          })}\n\n',
        )
        ..write(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': ' from wewordle'},
              },
            ],
          })}\n\n',
        )
        ..write('data: [DONE]\n\n');
      await request.response.close();
    });

    try {
      final provider = WeWordle(
        endpoint: 'http://${server.address.host}:${server.port}',
      );
      final response = await provider.complete(const [
        Message(role: 'system', content: 'be helpful'),
        Message(role: 'user', content: 'what is 2+2?'),
      ]);
      await serverDone;

      expect(seen['model'], wewordleDefaultModel);
      expect(seen['cost'], 1);
      expect(seen['stream'], isTrue);
      expect(seen['web_search'], isFalse);
      final messages = seen['messages'] as List;
      expect(messages, hasLength(2));
      expect(messages.first['role'], 'system');
      expect(messages.last['content'], 'what is 2+2?');
      expect(response.provider, wewordleName);
      expect(response.choices.single.message.content, 'hello from wewordle');
    } finally {
      await server.close(force: true);
    }
  });
}
