# Third-Party Notices

This project uses upstream projects as implementation references. Do not vendor or copy third-party source into this repository unless the corresponding license obligations are reviewed and this notice is updated.

## xtekky/gpt4free (`g4f`)

- Repository: <https://github.com/xtekky/gpt4free>
- Local reference cache: `.upstream/gpt4free` (ignored by git; not vendored)
- Upstream commits inspected: `798d8586b180cd8e6fc4b2b2a6a0c8a410de22ca`; latest provider refresh checked `614d8a8cd393d1063407d1319361761d5542fd84`
- License file inspected: `LICENSE`
- License identified from upstream: GNU General Public License v3.0 only (`GPL-3.0`)
- Legal notice inspected: `LEGAL_NOTICE.md`
- Latest provider files inspected for live free e2e refresh: `g4f/Provider/PollinationsAI.py`, `g4f/Provider/WeWordle.py`, `g4f/Provider/GptFree.py`, `g4f/Provider/Yqcloud.py`

`free_llm_router` reimplements selected provider behavior, model aliases, request shaping, selector/fallback ideas, and compatibility notes from `g4f` in Dart with tests. Python source from `g4f` must not be vendored into this repository.

When a provider or selector behavior is ported, record in `FREE-LLM-ROUTER-PRD.md`:

1. the upstream commit SHA and exact files inspected;
2. request URL/method/headers/payload and response parsing/streaming/error behavior;
3. what was ported, omitted, postponed, or redesigned for Dart;
4. attribution and license-impact notes.

## decolua/9router

- Repository: <https://github.com/decolua/9router>
- Local reference cache: `.upstream/9router` (ignored by git; not vendored)
- Upstream commit inspected: `7f436e2792be4fa5a4d1c4d6b8e9bc85eaaa6a3d`
- License file inspected: `LICENSE`
- License identified from upstream: MIT License
- Files inspected for Dart routing improvement: `README.md`, `docs/ARCHITECTURE.md`, `open-sse/services/model.js`, `open-sse/handlers/chatCore.js`, `open-sse/providers/schema.js`, `open-sse/providers/index.js`, `open-sse/services/accountFallback.js`, `open-sse/utils/error.js`, and `open-sse/config/runtimeConfig.js`.

`free_llm_router` studies 9Router architecture and routing ideas, then reimplements only small Dart-specific behavior with tests. No 9Router source is vendored into this repository.

## diegosouzapw/OmniRoute

- Repository: <https://github.com/diegosouzapw/OmniRoute>
- Local reference cache: `.upstream/OmniRoute` (ignored by git; not vendored)
- Upstream commit inspected: `fc35dc248f46354e80fdcdaa551e6598abcf5124`
- License file inspected: `LICENSE`
- License identified from upstream: MIT License
- Files inspected for the Dart routing adaptation: `src/shared/constants/routingStrategies.ts`, `src/domain/fallbackPolicy.ts`, `src/domain/degradation.ts`, `open-sse/services/combo/targetSorters.ts`, and `open-sse/services/combo/rrState.ts`.

`free_llm_router` reimplements a dependency-free subset suited to anonymous providers: priority, weighted, round-robin, random, least-used, and last-known-good routing; in-memory fallback policies; provider health/cooldown tracking; and degradation reporting. Round-robin state is scoped per Dart client and model, mirroring OmniRoute's per-combo counters. Weighted fallback order follows descending weight after the selected provider.

OmniRoute's server, dashboard, persistence, account/key rotation, paid-provider cost routing, quota/reset routing, context/cache optimization, fusion, and pipeline features are intentionally not copied. No OmniRoute source is vendored into this repository.

OmniRoute MIT notice:

```text
MIT License

Copyright (c) 2026 diegosouzapw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Users are responsible for complying with third-party provider terms and applicable law. This file is an engineering notice, not legal advice.
