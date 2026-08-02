# ADR-0002: Split platform-neutral core API from `dart:io` providers

## Status

Accepted — 2026-07-01

## What this is

The Dart package has two public libraries: a Flutter-safe core import and a separate provider import for network-backed implementations. Start here before moving exports, adding provider dependencies, or changing web/mobile compatibility.

## Context

`lib/free_llm_router.dart` states that the core library is safe to import from Flutter apps including web builds, and exports only internal core modules: client, errors, health, provider contract, registry, selector, and types (`lib/free_llm_router.dart:1`, `lib/free_llm_router.dart:7`). It does not export provider implementations.

`lib/providers.dart` explicitly documents `dart:io` provider implementations for mobile, desktop, server, or CLI targets and exports Chatai, default registry helpers, PollinationsAI, WeWordle, and Yqcloud (`lib/providers.dart:1`, `lib/providers.dart:7`). The provider implementations import `dart:io` directly for HTTP work (`lib/src/providers/pollinations_ai.dart:1`, `lib/src/providers/chatai.dart:1`, `lib/src/providers/yqcloud.dart:1`, `lib/src/providers/wewordle.dart:1`).

The README mirrors this split: app code imports `package:free_llm_router/free_llm_router.dart`, while provider-backed targets import `package:free_llm_router/providers.dart` (`README.md:15`, `README.md:21`).

## Decision

Keep the public Dart API split into:

- `package:free_llm_router/free_llm_router.dart` — platform-neutral core API.
- `package:free_llm_router/providers.dart` — `dart:io` provider implementations and default wiring.

Do not export `dart:io` providers from the core library.

## Consequences

- Flutter web and app code can import the core types/client abstractions without pulling in `dart:io`.
- Provider-backed use remains available through one explicit import.
- The default registry/client helpers live with providers because they instantiate `dart:io` network providers (`lib/src/providers/default_registry.dart:9`, `lib/src/providers/default_registry.dart:23`).
- New browser-compatible providers need either a core-safe implementation or a new compatibility decision before export.

## Alternatives considered

- **Single `free_llm_router.dart` export for everything.** Rejected: it would make `dart:io` part of the default import and weaken Flutter web compatibility.
- **One library per provider only.** Rejected: too much ceremony for current users; `providers.dart` is enough.
- **Add an HTTP abstraction dependency.** Rejected for now: `pubspec.yaml` has no runtime dependencies, and current providers work with stdlib `dart:io` (`pubspec.yaml:9`).

## Update triggers

Revisit this ADR if:

- `lib/free_llm_router.dart` starts exporting provider code.
- Provider implementations stop using `dart:io`.
- A Flutter-web-compatible HTTP/provider layer is added.
- Runtime dependencies are added to `pubspec.yaml` to support cross-platform HTTP.
