# Flower Agent Repository Instructions

These instructions apply to every coding agent and contributor working in this repository.

## Product boundary

Flower Agent is a local-first project intelligence and architecture governance toolkit for Flutter coding agents.

Do not turn Flower into:

- a state-management framework;
- a router or service locator;
- a hosted AI chat product;
- an abstraction that replaces the official Dart and Flutter tooling;
- a product that requires source code to leave the developer's machine.

## Architecture

- `packages/flower_core` owns models and deterministic project analysis.
- `packages/flower_cli` owns argument parsing, terminal output, and command orchestration.
- Core code must not depend on CLI code.
- Domain models must not depend on terminal formatting.
- File writes must be safe by default and must not overwrite user files silently.
- Keep MCP transport and third-party integrations behind adapters.

## Engineering rules

1. Prefer deterministic analysis over LLM calls.
2. Use public Dart APIs where practical; isolate unstable analyzer or MCP APIs.
3. Keep JSON output backward compatible within a published minor version.
4. Add tests for every detection rule and every file-writing behavior.
5. Include actionable errors with the affected path and a suggested fix.
6. Support Windows, macOS, and Linux paths.
7. Do not add a dependency without documenting why the standard library is insufficient.
8. Never claim a roadmap item is complete until code and tests exist.

## Required checks

Run from the repository root:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test packages/flower_core/test packages/flower_cli/test
```

## Documentation

When behavior changes:

- update `README.md` when user-facing commands change;
- update `ROADMAP.md` when a milestone progresses;
- update `CHANGELOG.md` for release-relevant changes;
- record architectural decisions in `docs/` until the Flower ADR command exists.

## Commit scope

Keep commits focused. Do not mix generated output, unrelated cleanup, and feature work in the same change.
