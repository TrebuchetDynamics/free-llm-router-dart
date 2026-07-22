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

`gollmfree` reimplements selected provider behavior, model aliases, request shaping, selector/fallback ideas, and compatibility notes from `g4f` in Dart with tests. Python source from `g4f` must not be vendored into this repository.

When a provider or selector behavior is ported, record in `GOLLMFREE-PRD.md`:

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

`gollmfree` studies 9Router architecture and routing ideas, then reimplements only small Dart-specific behavior with tests. No 9Router source is vendored into this repository.

Users are responsible for complying with third-party provider terms and applicable law. This file is an engineering notice, not legal advice.
