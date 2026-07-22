# ADR-0005: Support provider-qualified model routing

## Status

Accepted — 2026-07-05

## What this is

The Dart client now accepts model strings in `provider/model` form, inspired by 9Router's model parser and resolver. Start here before changing model parsing, provider alias handling, or request-aware provider adapters.

## Context

9Router resolves model strings such as `alias/model` by splitting the provider alias from the upstream model, resolving the alias to a provider ID, and sending the upstream model to the selected provider (`.upstream/9router/open-sse/services/model.js` at commit `7f436e2792be4fa5a4d1c4d6b8e9bc85eaaa6a3d`). Its chat core then writes the resolved upstream model into the provider request (`.upstream/9router/open-sse/handlers/chatCore.js`).

Before this change, `gollmfree` could route by provider name or model alias, but a Dart request such as `pollinationsai/openai-fast` had no registry candidates and provider adapters did not receive the full `ChatRequest` metadata.

## Decision

Support provider-qualified model strings in the Dart client:

- `provider/model` forces routing to that provider when the provider exists in the registry.
- The suffix is passed to request-aware providers as the upstream model.
- Existing simple `Provider.complete(List<Message>)` adapters remain compatible.
- `RequestProvider` is an optional richer interface for adapters that need `model`, `stream`, `temperature`, or `maxTokens`.
- PollinationsAI implements `RequestProvider` and posts the requested model/options while mapping `auto`, `best`, the provider name, and the legacy `gpt-4.1-nano` alias to its default `openai-fast` model.

## Consequences

- CLI and library callers can explicitly target a provider/model pair with `--model pollinationsai/openai-fast`.
- The core provider contract stays backward-compatible for tests and external fake providers.
- Additional providers can opt into request-aware behavior without changing all adapters at once.

## Update triggers

Revisit this ADR if:

- Provider aliases become configurable outside the registry.
- All providers are migrated to a request-aware contract and the legacy `Provider` methods become unnecessary.
- The package adds 9Router-style user-defined aliases or combo/fallback model sequences.
