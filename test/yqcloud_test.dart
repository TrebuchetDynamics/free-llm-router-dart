import 'dart:convert';
import 'dart:io';

import 'package:gollmfree/gollmfree.dart';
import 'package:gollmfree/providers.dart';
import 'package:test/test.dart';

void main() {
  test('Yqcloud posts last user prompt and parses plain text stream', () async {
    late Map<String, Object?> seen;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverDone = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, ContentType.json.mimeType);
      expect(request.headers.value('Origin'), 'https://chat9.yqcloud.top');
      seen = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, Object?>();
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.text
        ..write('hello\nfrom yqcloud');
      await request.response.close();
    });

    try {
      final provider = Yqcloud(
        endpoint: 'http://${server.address.host}:${server.port}',
      );
      final response = await provider.complete(const [
        Message(role: 'system', content: 'be helpful'),
        Message(role: 'user', content: 'first'),
        Message(role: 'assistant', content: 'ok'),
        Message(role: 'user', content: 'second'),
      ]);
      await serverDone;

      expect(seen['prompt'], 'second');
      expect(seen['userId'], 'gollmfree');
      expect(seen['network'], isTrue);
      expect(response.provider, yqcloudName);
      expect(response.choices.single.message.content, 'hellofrom yqcloud');
    } finally {
      await server.close(force: true);
    }
  });

  test('yqcloudBuildPrompt falls back to the final message', () {
    expect(
      yqcloudBuildPrompt(const [Message(role: 'assistant', content: 'last')]),
      'last',
    );
  });
}
