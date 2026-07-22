# Architecture Decision Records

## What this is

This folder records the decisions that shape `gollmfree` as a Dart package and CLI. Start here when changing package shape, provider wiring, or validation.

## Start here

- [ADR-0001: Make Dart the active package surface](0001-dart-active-package-surface.md)
- [ADR-0002: Split platform-neutral core API from `dart:io` providers](0002-platform-neutral-core-and-io-providers.md)
- [ADR-0003: Port provider behavior as tested Dart adapters](0003-tested-dart-provider-adapters.md)
- [ADR-0004: Remove the legacy Go implementation](0004-legacy-go-reference-during-transition.md)
- [ADR-0005: Support provider-qualified model routing](0005-provider-qualified-model-routing.md)

## Source-backed project facts

- The package manifest names the Dart package `gollmfree`, pins SDK compatibility to `^3.10.0`, and keeps runtime dependencies empty (`pubspec.yaml:1`, `pubspec.yaml:7`, `pubspec.yaml:9`).
- `package:gollmfree/gollmfree.dart` exports the core client, errors, health, provider contract, registry, selector, and types (`lib/gollmfree.dart:7`).
- `package:gollmfree/providers.dart` exports the `dart:io` provider layer and default registry helpers (`lib/providers.dart:7`); the default registry contains live free PollinationsAI, WeWordle, and GptFree providers.
- The CLI is a Dart executable with `chat`, `list`, and `models` commands (`bin/gollmfree.dart:7`, `bin/gollmfree.dart:33`).
- The client supports provider-qualified model routing such as `pollinationsai/openai-fast`, and request-aware providers receive the resolved upstream model (`lib/src/client.dart:190`, `lib/src/provider.dart:19`).
- CI runs Dart dependency resolution, formatting, analysis, tests, and CLI checks (`.github/workflows/test.yml:17`).

## Update triggers

Revisit these ADRs when:

- `pubspec.yaml` package identity, SDK constraint, dependency policy, or publish policy changes.
- `lib/gollmfree.dart` or `lib/providers.dart` exports change.
- Provider classes, endpoints, request shapes, or default registry membership change.
- `bin/gollmfree.dart` command semantics change.
- Another language implementation is proposed.
