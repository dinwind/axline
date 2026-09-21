# Project Status

## Current Phase

Build environment bootstrapped on Windows x64; first full compilation succeeded.

## Active Goals

- [x] Bootstrap AxLines (code-oss-dev v1.139.0) build environment on Windows x64
- [x] Fix Cokodo protocol lint errors (273/273 pass)
- [x] Create reusable build script and achieve first successful compilation

## Recently Completed

- [x] Rename workspace folder from `C:\ai_work\axline agents\axline` to `C:\ai_work\axlines` (proper move; git remote + history intact, remote is `github.com/dinwind/axlines.git`)
- [x] Fix upstream space-in-path bug in build/npm/preinstall.ts (quote node-gyp.cmd path for shell:true on Windows)
- [x] Create scripts/build.bat (install/compile/rebuild/run/watch/clean) with VS 2026 vcvars detection and delayed-expansion path handling
- [x] Bootstrap AxLines build environment: installed VS 2026 Spectre libs, upgraded Node to 24.21.0, fixed MSB8040 native-module build (native-watchdog/native-is-elevated .node produced), achieved first full compile (63 tasks, 0 errors)
- [x] Fix fake logged-in state after failed AxGate login: restore/login no longer fabricate UUID-only identities; webview keeps sign-in form until a verified profile exists
- [x] Pull Axline 0.4.98 (ALPHA) from AuthNexus share link, extract to `.build/builtInExtensions/axline.axline`, update `product.json` version+sha256
- [x] Wire `axlineStartup.contribution.ts` to invoke `axline.openChatPanel` (0.4.98 `WebviewPanel` support) instead of the splash editor; removed redundant `AxlineChatEditor`/`AxlineChatEditorInput`/`axlineChatEditor.contribution.ts`

## Blockers

None.

## Session Context

- Workspace folder renamed from `C:\ai_work\axline agents\axline` to `C:\ai_work\axlines` (2026-09-16). Old dir `C:\ai_work\axline agents` still exists with only a stale `.vscode` folder (not a git repo) and can be deleted safely.
- Rebrand commit `00502dee` is still 1 ahead of `origin/main` (unpushed).
- First compile and dev run both succeeded (gulp `compile` 1.05 min, 63 tasks with 0 errors; out/ has 10900 files).
- `.gitignore` updated to exclude 36 root-level built-in extension install dirs and `build/config.gypi`.
- `.build/electron` is not yet downloaded; first `scripts\build.bat run` fetches it via preLaunch.
- Local-only change vs upstream: build/npm/preinstall.ts path-quoting fix must be carried across future upstream rebases.
