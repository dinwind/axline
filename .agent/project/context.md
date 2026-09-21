# Project Context

## Overview

AxLines is a fork of Microsoft VS Code (code-oss-dev), version 1.139.0.
Forked from https://github.com/dinwind/axlines.git.

## Purpose

Custom VS Code distribution with modifications for specific use cases.

## Key Files

- Build script: `scripts/build.bat`
- Launcher: `scripts/code.bat`
- Product config: `product.json`
- Build config: `.npmrc`

## Platform

- **Target**: Windows x64
- **Build env**: Visual Studio 2026 Community + Windows SDK 10.0.28000.0
- **Node**: 24.x (see .nvmrc)

## Agent Working Rules

### 1. Minimum fix first, refactor later

When a bug is found:
- First, apply the smallest possible fix (e.g. copy the correct file, change one line).
- Verify the fix works.
- Only then decide whether the surrounding tooling/infrastructure needs refactoring.

Do NOT start building new tools, frameworks, or complex generators before proving the minimal fix is sufficient.

### 2. Evaluate scope before coding

Before writing any new tool, script, or generator:
- Ask: can this be done with an existing one-liner (shell command, library call)?
- If a library already handles the work (e.g. Pillow for image resize), use it; do not reimplement the same algorithm from scratch.
- Estimate the effort and compare with the task's actual priority. Do not let tool-building become the main task.
