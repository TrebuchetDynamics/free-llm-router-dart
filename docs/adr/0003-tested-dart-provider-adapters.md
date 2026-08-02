# ADR-0003: Port provider behavior as tested Dart adapters

## Status

Accepted — 2026-07-01; updated — 2026-07-05

## What this is

Provider integrations are hand-written Dart adapters with request-shape tests and real e2e checks for default live providers. Start here before adding, removing, or changing provider endpoints, aliases, parsing, or default registry order.

## Context

The default Dart registry now contains live free providers only: PollinationsAI, WeWordle, and GptFree, in priority order (`lib/src/providers/default_registry.dart`). Chatai and Yqcloud remain exported legacy adapters, but are not default because real e2e attempts showed Chatai DNS failure and Yqcloud IP rejection from this runner.

Each provider owns its endpoint, aliases, request shape, response parsing, and error behavior:

- PollinationsAI posts OpenAI-shaped JSON with `model`, `messages`, and `stream: false`, and can honor request-level model/options via `RequestProvider`.
- WeWordle posts current `llmproxy.org` SSE JSON and accumulates `choices[].delta.content` chunks.
- GptFree performs the anonymous Firebase sign-up needed by `gptfree.com`, then posts to its SSE result endpoint.
- Chatai and Yqcloud keep local adapter coverage as legacy references while their endpoints are not live-default.

Tests verify adapter contracts with local `HttpServer` instances and run real free-provider e2e for every default provider in `test/e2e_test.dart`.

## Decision

Port providers as hand-written, source-shaped Dart adapters.

For current providers:

- Export PollinationsAI, WeWordle, GptFree, Chatai, and Yqcloud from `package:free_llm_router/providers.dart`.
- Keep only live free providers in `defaultRegistry()`.
- Keep local request/parse tests for adapter behavior.
- Keep real e2e tests for every default provider.
- Keep provider labels and model aliases as routing hints, not guarantees of model authenticity.

## Consequences

- `defaultClient()` avoids known-dead providers while still preserving legacy adapter code for reference.
- Local tests catch request/parse regressions; e2e catches live provider drift.
- Adding a default provider means adding its adapter, export, registry entry, local shape tests, and real e2e coverage.

## Update triggers

Revisit this ADR if:

- A provider endpoint, payload shape, stream format, or alias list changes.
- Default registry membership or priority changes.
- A legacy provider becomes live again or a default provider stops being free/live.
- A shared provider abstraction replaces hand-written adapters.
