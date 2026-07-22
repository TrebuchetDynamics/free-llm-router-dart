# Gollmfree Product Requirements Document

> **Project:** `gollmfree`
> **Type:** Dart package and CLI
> **Package:** `gollmfree`
> **Primary consumers:** Dart and Flutter applications
> **Version target:** v0.1.0
> **Upstream reference:** [`xtekky/gpt4free`](https://github.com/xtekky/gpt4free) provider behavior at commit `798d8586b180cd8e6fc4b2b2a6a0c8a410de22ca`

## 1. Product

Gollmfree routes chat-completion requests to free, no-auth LLM providers. It exposes a platform-neutral Dart API, a separate `dart:io` provider library, and a CLI. Provider failures are expected; deterministic selection, health tracking, and fallback hide that fragility from callers.

Dart is the only supported implementation. ADR-0004 records removal of the former duplicate implementation.

## 2. Goals

- Import directly from Dart and Flutter applications.
- Require no API keys or runtime package dependencies.
- Support completion and streaming APIs.
- Route explicit `provider/model` requests.
- Rank providers and fall back when one fails.
- Keep provider-specific HTTP behavior isolated and tested.
- Expose `chat`, `list`, and `models` CLI commands.
- Compile the core API for Flutter web without importing `dart:io`.

## 3. Non-goals

- Hosted gateway or OpenAI-compatible server.
- Accounts, paid keys, OAuth, browser automation, or Docker.
- Guaranteeing permanent provider availability or model-label authenticity.
- Maintaining duplicate implementations in other languages without a demonstrated consumer and a new ADR.

## 4. Public surfaces

- `lib/gollmfree.dart` — client, request/response types, provider contract, registry, selector, health, and errors.
- `lib/providers.dart` — `dart:io` provider adapters and default client/registry.
- `bin/gollmfree.dart` — CLI.
- `example/` — completion and streaming examples.

## 5. Provider contract

Each provider supplies:

- a stable provider name;
- supported model names;
- completion behavior;
- streaming behavior;
- cancellation and timeout handling;
- provider-qualified errors that do not leak prompt content.

Request-aware providers receive the upstream model resolved from `provider/model`. Providers without native streaming may emit one complete chunk.

## 6. Selection and fallback

- `auto` and unqualified model names use ranked candidates.
- `provider/model` forces the named provider and passes `model` upstream.
- Sequential fallback is the default.
- Each provider gets one attempt by default to avoid anonymous traffic amplification.
- Race mode is opt-in and returns the first success.
- Health records success, failure, latency, cooldown, and last error.

## 7. Current providers

| Provider | Default | Status |
| --- | --- | --- |
| PollinationsAI | yes | Live no-auth OpenAI-shaped endpoint |
| WeWordle | yes | Live no-auth endpoint |
| GptFree | yes | Live Firebase-anonymous/SSE flow |
| Chatai | no | Legacy adapter; endpoint unavailable in latest probe |
| Yqcloud | no | Legacy adapter; endpoint unavailable in latest probe |

Provider claims and anonymous endpoints are untrusted. Prompts must not contain secrets or sensitive data.

## 8. Validation

Required gate:

```bash
dart pub get
dart format --set-exit-if-changed bin example lib test
dart analyze
dart test
dart run gollmfree list
git diff --check
```

Tests cover imports, types, registry routing, selector behavior, fallback, streaming, CLI behavior, provider request/response parsing, and live provider probes.

## 9. Delivery tracker

| Milestone | Status | Evidence |
| --- | --- | --- |
| Dart scaffold | done | Manifest, analysis config, CI, package exports |
| Core API | done | Client, types, registry, selector, health, errors |
| Provider adapters | done | Five adapters with focused and live tests |
| CLI | done | `chat`, `list`, `models`, streaming and model routing |
| Release hardening | done | README, examples, ADRs, notices, validation |
| Single-language cleanup | done | Duplicate source/module/tests/CI removed; Dart remains |

## 10. Next candidate

Evaluate structured provider errors or separate first-chunk and stream-stall timeouts only when a concrete failure demonstrates the need.

## 11. Change discipline

For behavior changes:

1. Add one failing test through a public seam.
2. Implement the smallest passing change.
3. Run focused tests, then the full validation gate.
4. Update this PRD and README when behavior, provider status, or public usage changes.
5. Record upstream commit/files and deviations for provider ports.

## 12. Release criteria

- Dart API and CLI documentation match implementation.
- Default providers have honest status and runnable coverage.
- Core remains web-importable.
- No credentials or private prompts are logged.
- Formatting, analysis, tests, CLI smoke, and diff hygiene pass.
