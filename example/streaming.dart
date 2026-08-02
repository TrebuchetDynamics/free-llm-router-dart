import 'dart:io';

import 'package:free_llm_router/free_llm_router.dart';
import 'package:free_llm_router/providers.dart';

Future<void> main() async {
  final client = defaultClient();
  await for (final chunk in client.chatCompletionStream(
    const ChatRequest(
      stream: true,
      messages: [Message(role: 'user', content: 'Write one short line.')],
    ),
  )) {
    stdout.write(chunk.content);
    await stdout.flush();
  }
  stdout.writeln();
}
