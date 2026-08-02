# Architecture Decision Records

## What this is

This folder records the decisions that shape `free_llm_router` as a Dart package and CLI. Start here when changing package shape, provider wiring, or validation.

## Start here

- [ADR-0001: Make Dart the active package surface](0001-dart-active-package-surface.md)
- [ADR-0002: Split platform-neutral core API from `dart:io` providers](0002-platform-neutral-core-and-io-providers.md)
- [ADR-0003: Port provider behavior as tested Dart adapters](0003-tested-dart-provider-adapters.md)
- [ADR-0004: Remove the legacy Go implementation](0004-legacy-go-reference-during-transition.md)
- [ADR-0005: Support provider-qualified model routing](0005-provider-qualified-model-routing.md)
- [ADR-0006: Adapt OmniRoute's portable routing core](0006-adapt-omniroute-core-routing.md)

## Source-backed project facts

- The package manifest names the Dart package `free_llm_router`, pins SDK compatibility to `^3.10.0`, and keeps runtime dependencies empty (`pubspec.yaml:1`, `pubspec.yaml:7`, `pubspec.yaml:9`).
- `package:free_llm_router/free_llm_router.dart` exports the core client, degradation and fallback policy, health, provider contract, registry, routing strategies, and types (`lib/free_llm_router.dart:7`).
- `package:free_llm_router/providers.dart` exports the `dart:io` provider layer and default registry helpers (`lib/providers.dart:7`); the default registry contains live free PollinationsAI, WeWordle, and GptFree providers.
- The CLI is a Dart executable with `chat`, `list`, and `models` commands (`bin/free_llm_router.dart:7`, `bin/free_llm_router.dart:33`).
- The client supports provider-qualified model routing such as `pollinationsai/openai-fast`, and request-aware providers receive the resolved upstream model (`lib/src/client.dart`, `lib/src/provider.dart`).
- OmniRoute-inspired routing state is in-memory and scoped per Dart selector and model; fallback policies apply to both completion and streaming (`lib/src/routing_strategy.dart`, `lib/src/client.dart`).
- CI runs Dart dependency resolution, formatting, analysis, tests, and CLI checks (`.github/workflows/test.yml:17`).

## Update triggers

Revisit these ADRs when:

- `pubspec.yaml` package identity, SDK constraint, dependency policy, or publish policy changes.
- `lib/free_llm_router.dart` or `lib/providers.dart` exports change.
- Provider classes, endpoints, request shapes, or default registry membership change.
- `bin/free_llm_router.dart` command semantics change.
- Another language implementation is proposed.
