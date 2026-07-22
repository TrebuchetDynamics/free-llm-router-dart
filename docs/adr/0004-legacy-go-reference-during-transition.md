# ADR-0004: Remove the legacy Go implementation

## Status

Accepted — 2026-07-10 (supersedes the 2026-07-01 transition decision)

## Context

Dart is the active package and CLI surface. Keeping a second, hand-written implementation duplicated provider, routing, health, CLI, and test behavior without sharing runtime code. No current sibling application imports the legacy implementation.

## Decision

Remove the Go module, source, tests, CLI, CI job, and artifact ignores. Maintain one Dart implementation under `lib/`, `bin/`, and `test/`.

## Consequences

- Provider behavior has one source of truth.
- CI validates only the supported Dart surface.
- Restoring another language implementation requires a new ADR and a demonstrated consumer.
