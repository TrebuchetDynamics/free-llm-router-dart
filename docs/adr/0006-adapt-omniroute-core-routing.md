# ADR-0006: Adapt OmniRoute's portable routing core

- Status: accepted
- Date: 2026-08-02

## Context

OmniRoute is a full LLM gateway with server, dashboard, persistence, account, quota, cost, context, and pipeline features. `free_llm_router` is instead a dependency-free Dart client for anonymous providers. Copying OmniRoute wholesale would violate the package's scope, but its small routing-domain concepts improve provider selection and failure handling.

The reference examined was [`diegosouzapw/OmniRoute`](https://github.com/diegosouzapw/OmniRoute) commit [`fc35dc248f46354e80fdcdaa551e6598abcf5124`](https://github.com/diegosouzapw/OmniRoute/tree/fc35dc248f46354e80fdcdaa551e6598abcf5124), licensed under MIT.

## Decision

Reimplement only the portable concepts relevant to a local Dart client:

- priority, weighted, round-robin, random, least-used, and last-known-good routing;
- per-model round-robin counters owned by each Dart client selector;
- descending-weight fallback order after weighted selection;
- in-memory, per-model fallback chains;
- provider health history, trends, cooldown, and degradation status;
- the same fallback policy for completion and streaming.

The source references are:

- [`src/shared/constants/routingStrategies.ts`](https://github.com/diegosouzapw/OmniRoute/blob/fc35dc248f46354e80fdcdaa551e6598abcf5124/src/shared/constants/routingStrategies.ts)
- [`open-sse/services/combo/rrState.ts`](https://github.com/diegosouzapw/OmniRoute/blob/fc35dc248f46354e80fdcdaa551e6598abcf5124/open-sse/services/combo/rrState.ts)
- [`open-sse/services/combo/targetSorters.ts`](https://github.com/diegosouzapw/OmniRoute/blob/fc35dc248f46354e80fdcdaa551e6598abcf5124/open-sse/services/combo/targetSorters.ts)
- [`src/domain/fallbackPolicy.ts`](https://github.com/diegosouzapw/OmniRoute/blob/fc35dc248f46354e80fdcdaa551e6598abcf5124/src/domain/fallbackPolicy.ts)
- [`src/domain/degradation.ts`](https://github.com/diegosouzapw/OmniRoute/blob/fc35dc248f46354e80fdcdaa551e6598abcf5124/src/domain/degradation.ts)

No upstream source is vendored. Dart behavior is independently implemented and tested.

## Consequences

- The core remains safe for Flutter web and has no runtime package dependencies.
- Routing state is process-local and resets with the client; there is no database persistence.
- Paid-provider cost routing, quota/reset strategies, account rotation, context/cache optimization, fusion, pipelines, server APIs, and dashboard features remain out of scope.
- Focused tests must cover every exported strategy, fallback ordering in completion and streaming, health retention/trends/cooldown, and degradation levels.
