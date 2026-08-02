import 'dart:convert';
import 'dart:io';

import 'package:free_llm_router/free_llm_router.dart';
import 'package:free_llm_router/providers.dart';
import 'package:test/test.dart';

void main() {
  test(
    'PollinationsAI posts OpenAI-shaped request and parses completion',
    () async {
      late Map<String, Object?> seen;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverDone = server.first.then((request) async {
        expect(request.method, 'POST');
        expect(
          request.headers.contentType?.mimeType,
          ContentType.json.mimeType,
        );
        seen = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
            .cast<String, Object?>();
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'id': 'chatcmpl-test',
              'model': 'openai-fast',
              'choices': [
                {
                  'index': 0,
                  'message': {'role': 'assistant', 'content': 'pong'},
                  'finish_reason': 'stop',
                },
              ],
            }),
          );
        await request.response.close();
      });

      try {
        final provider = PollinationsAI(
          endpoint: 'http://${server.address.host}:${server.port}',
        );
        final response = await provider.complete(const [
          Message(role: 'user', content: 'ping'),
        ]);
        await serverDone;

        expect(seen['model'], pollinationsDefaultModel);
        expect(seen['stream'], isFalse);
        expect(response.provider, pollinationsName);
        expect(response.choices.single.message.content, 'pong');
      } finally {
        await server.close(force: true);
      }
    },
  );

  test('PollinationsAI honors explicit request model options', () async {
    late Map<String, Object?> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.first.then((request) async {
      seen = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, Object?>();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'pong'},
              },
            ],
          }),
        );
      await request.response.close();
    });

    try {
      final provider = PollinationsAI(
        endpoint: 'http://${server.address.host}:${server.port}',
      );
      final response = await provider.completeRequest(
        const ChatRequest(
          model: 'gpt-4.1-nano',
          messages: [Message(role: 'user', content: 'ping')],
          stream: true,
          temperature: 0.2,
          maxTokens: 32,
        ),
      );
      await serverDone;

      expect(seen['model'], pollinationsDefaultModel);
      expect(seen['stream'], isFalse);
      expect(seen['temperature'], 0.2);
      expect(seen['max_tokens'], 32);
      expect(response.model, pollinationsDefaultModel);
    } finally {
      await server.close(force: true);
    }
  });
}
