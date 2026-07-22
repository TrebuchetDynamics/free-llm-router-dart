import 'dart:io';

import 'package:gollmfree/gollmfree.dart';
import 'package:gollmfree/providers.dart';

Future<void> main() async {
  final client = defaultClient();
  final response = await client.chatCompletion(
    const ChatRequest(
      messages: [Message(role: 'user', content: 'Say hello in one sentence.')],
    ),
  );

  if (response.choices.isEmpty) {
    stdout.writeln('No response.');
    return;
  }
  stdout.writeln(response.choices.first.message.content);
}
