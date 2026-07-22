# gollmfree

`gollmfree` is a Dart package and CLI for routing chat-completion requests to free/no-auth LLM providers. It is structured so Flutter apps such as `../navivox-app` can import the core API with a local path dependency.

## Add to a Flutter/Dart app

```yaml
dependencies:
  gollmfree:
    path: ../gollmfree
```

Then import the core API:

```dart
import 'package:gollmfree/gollmfree.dart';
```

The core library has no `dart:io` import, so it is safe for Flutter web compilation. I/O backed providers are exported separately:

```dart
import 'package:gollmfree/providers.dart'; // dart:io targets only
```

## Dart quick start

```dart
import 'package:gollmfree/gollmfree.dart';
import 'package:gollmfree/providers.dart';

Future<void> main() async {
  final pollinations = PollinationsAI();
  final registry = Registry([
    ProviderInfo(
      name: pollinations.name,
      provider: pollinations,
      supportedModels: pollinations.supportedModels,
      defaultPriority: 1,
    ),
  ]);
  final client = GollmfreeClient(registry: registry);

  final response = await client.chatCompletion(
    const ChatRequest(
      messages: [Message(role: 'user', content: 'Hello')],
    ),
  );

  print(response.choices.first.message.content);
}
```

For a mobile/desktop/server default client with all ported providers:

```dart
import 'package:gollmfree/providers.dart';

final client = defaultClient();
```

## CLI

```bash
dart run gollmfree chat "what is 2+2?"
dart run gollmfree chat --stream "write one short line"
dart run gollmfree chat --model pollinationsai/openai-fast "one sentence"
dart run gollmfree list
dart run gollmfree models
```

Optional local CLI activation from this checkout:

```bash
dart pub global activate --source path .
gollmfree list
```

If Dart's pub-cache bin directory is not on your `PATH`, use `dart pub global run gollmfree list`. Global activation snapshots the checkout, so re-run activation after changing it.

## Package layout

- `lib/gollmfree.dart` — platform-neutral core API: client, types, registry, selector, health, errors. Model strings may be aliases such as `auto`/`gpt-4.1-nano` or provider-qualified routes such as `pollinationsai/openai-fast`.
- `lib/providers.dart` — `dart:io` provider implementations and default registry/client helpers.
- `bin/gollmfree.dart` — Dart CLI.
- `example/` — minimal Dart completion and streaming examples.
- `test/` — Dart package tests covering importability, registry routing, fallback, streaming, CLI/default registry, provider request shaping, and real free-provider e2e.

## Provider status

| Provider | Dart status | Notes |
| --- | --- | --- |
| PollinationsAI | live/default | No-auth OpenAI-shaped endpoint via `dart:io`; covered by real e2e. |
| WeWordle | live/default | No-auth SSE endpoint via `llmproxy.org`; covered by real e2e. |
| GptFree | live/default | No-auth Firebase-anonymous flow plus SSE result endpoint; covered by real e2e. |
| Chatai | legacy adapter | Endpoint DNS failed in real e2e; not in default registry. |
| Yqcloud | legacy adapter | Current endpoint rejected this runner IP in real e2e; not in default registry. |

## Validation

```bash
dart pub get
dart format --set-exit-if-changed bin example lib test
dart analyze
dart test  # includes real e2e for all exported providers: live defaults answer; legacy Chatai/Yqcloud are probed unavailable
dart run gollmfree list
```

## Privacy and provider caveats

Prompts are sent to third-party anonymous providers that this project does not control. Do not send secrets, credentials, private data, or sensitive production information. Provider labels are treated as provider claims, not guarantees about the actual underlying model.

The default Dart client tries each provider once before sequential fallback; `raceMode` may contact multiple providers concurrently and uses one attempt per raced provider. Pass `maxRetries` to `defaultClient()` only if extra per-provider anonymous traffic is acceptable.

## Upstream reference

This project studies provider behavior from [`xtekky/gpt4free`](https://github.com/xtekky/gpt4free) at commit `798d8586b180cd8e6fc4b2b2a6a0c8a410de22ca`. The Dart router also studies ideas from [`decolua/9router`](https://github.com/decolua/9router), including provider-qualified model routing. Upstream license and attribution notes remain in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
