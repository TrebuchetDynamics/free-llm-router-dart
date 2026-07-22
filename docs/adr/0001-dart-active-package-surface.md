# ADR-0001: Make Dart the active package surface

## Status

Accepted — 2026-07-01

## What this is

`gollmfree` is being steered from a Go-first project into a Dart package that Flutter/Dart apps can import. Start here before changing the package manifest, public library exports, CLI entry point, or README installation guidance.

## Context

The project needs to be importable by the Navivox Flutter app context. The live manifest now declares a Dart package named `gollmfree`, SDK `^3.10.0`, no runtime package dependencies, and private publishing (`pubspec.yaml:1`, `pubspec.yaml:4`, `pubspec.yaml:7`, `pubspec.yaml:9`). The README documents a local path dependency and `package:gollmfree/gollmfree.dart` import for Flutter/Dart apps (`README.md:7`, `README.md:15`).

The package now has a platform-neutral public core library (`lib/gollmfree.dart:1`) and a Dart CLI executable whose usage exposes `chat`, `list`, and `models` (`bin/gollmfree.dart:7`). CI validates the Dart surface with `dart pub get`, formatting, analysis, tests, and CLI smoke (`.github/workflows/test.yml:17`).

## Decision

Dart is the active package and integration surface for `gollmfree`.

Concretely:

- Keep `pubspec.yaml` as the source of package identity.
- Treat `lib/gollmfree.dart` as the primary import for app code.
- Treat `bin/gollmfree.dart` as the primary CLI entry point.
- Keep README installation and examples Dart-first.
- Keep Dart validation in CI as the first project gate.

## Consequences

- Navivox-style Flutter apps can depend on the repository with `path: ../gollmfree` and import `package:gollmfree/gollmfree.dart`.
- New public APIs should be designed for Dart callers, not as direct Go API mirrors.
- Any future non-Dart implementation should be documented as reference, tooling, or compatibility unless this ADR is replaced.

## Alternatives considered

- **Keep Go as the active surface and add Dart bindings later.** Rejected: it leaves Flutter importability unresolved.
- **Generate Dart from Go.** Rejected: no existing generator is present, and the package surface is small enough to port directly.
- **Split into a new repo.** Rejected: path import from the current sibling repository is the immediate integration need.

## Update triggers

Revisit this ADR if:

- The package name, SDK constraint, or publish policy in `pubspec.yaml` changes.
- Navivox stops using a local path dependency.
- A generated binding or multi-language packaging strategy replaces the hand-written Dart surface.
- Dart CI stops being the first validation gate.
