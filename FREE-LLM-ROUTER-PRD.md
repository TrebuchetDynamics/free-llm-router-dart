# Free LLM Router Product Requirements Document

> **Project:** `free-llm-router-dart`
> **Type:** Dart package and CLI
> **Package:** `free_llm_router`
> **Primary consumers:** Dart and Flutter applications
> **Version target:** v0.1.0
> **Upstream reference:** [`xtekky/gpt4free`](https://github.com/xtekky/gpt4free) provider behavior at commit `798d8586b180cd8e6fc4b2b2a6a0c8a410de22ca`

## 1. Product

Free LLM Router routes chat-completion requests to free, no-auth LLM providers. It exposes a platform-neutral Dart API, a separate `dart:io` provider library, and a CLI. Provider failures are expected; deterministic selection, health tracking, and fallback hide that fragility from callers.

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

- `lib/free_llm_router.dart` — client, request/response types, provider contract, registry, selector, health, and errors.
- `lib/providers.dart` — `dart:io` provider adapters and default client/registry.
- `bin/free_llm_router.dart` — CLI.
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
- Routing strategies are priority, weighted, round-robin, random, least-used, and last-known-good.
- Explicit per-model fallback policies apply to completion and streaming.
- Each provider gets one attempt by default to avoid anonymous traffic amplification.
- Race mode is opt-in and returns the first success.
- Health records success, failure, recent latency, trend, cooldown, and last error.
- Degradation status records healthy, reduced, failed, and safe-default operation.

## 7. Current providers

| Provider       | Default | Status                                               |
| -------------- | ------- | ---------------------------------------------------- |
| PollinationsAI | yes     | Live no-auth OpenAI-shaped endpoint                  |
| WeWordle       | yes     | Live no-auth endpoint                                |
| GptFree        | yes     | Live Firebase-anonymous/SSE flow                     |
| Chatai         | no      | Legacy adapter; endpoint unavailable in latest probe |
| Yqcloud        | no      | Legacy adapter; endpoint unavailable in latest probe |

Provider claims and anonymous endpoints are untrusted. Prompts must not contain secrets or sensitive data.

## 8. Validation

Required gate:

```bash
dart pub get
dart format --set-exit-if-changed bin example lib test
dart analyze
dart test
dart run free_llm_router list
git diff --check
```

Tests cover imports, types, every exported routing strategy, per-model round-robin isolation, weighted fallback order, fallback policy behavior in completion and streaming, health history/trends/cooldown, degradation levels, registry routing, CLI behavior, provider request/response parsing, and live provider probes.

## 9. Delivery tracker

| Milestone                 | Status | Evidence                                                            |
| ------------------------- | ------ | ------------------------------------------------------------------- |
| Dart scaffold             | done   | Manifest, analysis config, CI, package exports                      |
| Core API                  | done   | Client, types, registry, selector, health, errors                   |
| Provider adapters         | done   | Five adapters with focused and live tests                           |
| CLI                       | done   | `chat`, `list`, `models`, streaming and model routing               |
| Release hardening         | done   | README, examples, ADRs, notices, validation                         |
| Single-language cleanup   | done   | Duplicate source/module/tests/CI removed; Dart remains              |
| OmniRoute core adaptation | done   | Six strategies, fallback policy, health, degradation, focused tests |

## 10. OmniRoute adaptation scope

Pinned reference: [`diegosouzapw/OmniRoute`](https://github.com/diegosouzapw/OmniRoute) commit `fc35dc248f46354e80fdcdaa551e6598abcf5124` (MIT).

Portable, dependency-free concepts adapted for Dart:

- strategy names and semantics from `src/shared/constants/routingStrategies.ts`;
- per-route round-robin state from `open-sse/services/combo/rrState.ts`;
- weighted fallback ordering from `open-sse/services/combo/targetSorters.ts`;
- in-memory fallback chains from `src/domain/fallbackPolicy.ts`;
- degradation status and safe-default handling from `src/domain/degradation.ts`.

The Dart package intentionally omits OmniRoute's server/dashboard, persistence, accounts and API-key rotation, paid-provider cost routing, quota/reset strategies, context/cache optimization, fusion, and pipelines. These do not fit a dependency-free anonymous-provider client. Detailed attribution and deviations are in `THIRD_PARTY_NOTICES.md`.

Next candidate: evaluate structured provider errors or separate first-chunk and stream-stall timeouts only when a concrete failure demonstrates the need.

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
