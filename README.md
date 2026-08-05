# Flower Agent

> Make your AI agent understand your Flutter project before it changes it.

[![CI](https://github.com/smae1993/flower_agent/actions/workflows/ci.yml/badge.svg)](https://github.com/smae1993/flower_agent/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flower Agent is a **local-first project intelligence and architecture governance toolkit** for Flutter coding agents.

It is designed to work alongside Codex, OpenCode, Claude Code, Cursor, GitHub Copilot, and the official Dart & Flutter MCP server. The official server gives agents access to Dart and Flutter tooling; Flower adds project-specific memory, architecture rules, focused context, and deterministic validation.

## Why Flower?

Coding agents can read and edit Flutter code, but they often do not know:

- where a change belongs in this specific project;
- which layers may depend on each other;
- which architectural decisions have already been accepted;
- which files, routes, models, tests, and migrations a task affects;
- whether a generated change follows the project's UI and testing conventions.

Flower turns a Flutter repository into structured project intelligence that agents can query before and after making changes.

## Current milestone

The repository is in active early development. The current vertical slice provides:

- `flower inspect` — detect Flutter technologies, features, source files, tests, architecture roles, and routes;
- `flower init` — create a project-local `.flower` workspace and agent bootstrap instructions;
- `flower map` — build an analyzer-backed internal dependency graph, find cycles, and export JSON or Mermaid;
- `flower symbols` — index repositories, services, providers, controllers, data sources, and routes;
- `flower context` — select a compact task-specific set of files with deterministic scores and reasons;
- feature-scoped project maps and symbol indexes for focused agent context;
- deterministic, local-only analysis with no API key or cloud service.

## Quick start

Until the first pub.dev release, activate Flower directly from GitHub:

```bash
dart pub global activate --source git https://github.com/smae1993/flower_agent.git --git-path packages/flower_cli
```

Inspect a Flutter project:

```bash
flower inspect --path /path/to/flutter/project
flower inspect --path . --json
```

Initialize Flower inside a project:

```bash
cd /path/to/flutter/project
flower init
```

Build the project dependency map:

```bash
flower map
flower map --json
flower map --mermaid
flower map --feature invoices --json
```

Index architecture symbols and routes:

```bash
flower symbols
flower symbols --json
flower symbols --kind repository --json
flower symbols --feature invoices --json
```

Generate task-specific context:

```bash
flower context "add invoice filtering"
flower context "add invoice filtering" --limit 8
flower context "add invoice filtering" --json
flower context "تخفیف فاکتور را اضافه کن" --json
```

The default context output is Markdown so it can be passed directly to a coding agent. JSON output is intended for MCP adapters, scripts, and future IDE integrations.

## How context selection works

Flower does not send the task or source code to an LLM. It deterministically ranks project files using:

- feature-name and file-path matches;
- architecture symbols such as repositories, controllers, providers, and data sources;
- route names, paths, and declarations;
- direct imports and direct dependents from the project graph;
- deterministic entry-point fallbacks when no lexical match is found.

Every selected file includes a numeric score and human-readable reasons. The `--limit` option controls the maximum number of files returned and accepts values from 1 to 50.

The tokenizer supports English identifiers, camelCase and snake_case names, Persian task text, and a small built-in set of common Persian-to-English project aliases. Project-defined aliases are planned for a later milestone.

## Supported project intelligence

Supported symbol roles currently include:

- repositories and repository implementations;
- services;
- providers, including top-level provider declarations and `@riverpod` functions;
- controllers, cubits, blocs, notifiers, and view models;
- data sources and DAOs.

Supported route constructors currently include GoRouter `GoRoute`, AutoRoute `AutoRoute` and `RouteConfig`, and GetX `GetPage`.

`flower map` parses Dart directives with the Dart analyzer. It resolves same-package imports, exports, and parts, reports external packages per file, marks generated files, detects feature-first paths, and identifies strongly connected dependency cycles.

The initialization command creates files only when they do not already exist. It does not overwrite an existing `AGENTS.md` or Flower configuration.

## Machine-readable contracts

Project map JSON uses a versioned schema:

```json
{
  "schemaVersion": "1.0.0",
  "packageName": "example_app",
  "nodes": [],
  "edges": [],
  "cycles": []
}
```

Symbol index JSON is also versioned:

```json
{
  "schemaVersion": "1.0.0",
  "packageName": "example_app",
  "counts": {
    "repository": 0,
    "service": 0,
    "provider": 0,
    "controller": 0,
    "dataSource": 0
  },
  "symbols": [],
  "routes": []
}
```

Task context JSON includes the normalized query, selected files, scores, reasons, symbols, direct dependencies, direct dependents, relevant routes, and warnings:

```json
{
  "schemaVersion": "1.0.0",
  "task": "add invoice filtering",
  "packageName": "example_app",
  "limit": 12,
  "queryTerms": ["invoice", "filtering"],
  "matchedFeatures": ["invoices"],
  "files": [],
  "routes": [],
  "warnings": []
}
```

Mermaid output can be pasted directly into GitHub Markdown or Mermaid-compatible documentation:

```bash
flower map --mermaid > architecture.mmd
```

## Product direction

```text
AI coding agent       = reasoning and code generation
Dart & Flutter MCP    = analyzer, runtime, tests, DevTools
Flower Agent          = project memory, architecture map, rules and governance
```

Flower will grow around four capabilities:

1. **Inspect** — understand a project's structure and technology choices.
2. **Context** — provide only the files, rules, and decisions relevant to a task.
3. **Guard** — validate architecture, UI, testing, and project conventions.
4. **Plan** — estimate change impact before an agent edits the codebase.

See [ROADMAP.md](ROADMAP.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Repository structure

```text
packages/
├── flower_core/    # Project models, inspection, maps, symbols, context, and initialization
└── flower_cli/     # The `flower` command-line application

docs/               # Product and architecture documentation
```

The repository uses Dart Pub workspaces and targets modern Dart versions.

## Principles

- Local-first and privacy-preserving
- Deterministic before probabilistic
- Compatible with every coding agent
- Complementary to official Dart and Flutter tooling
- Architecture-aware, not framework-opinionated
- Safe by default: never silently overwrite project files

## Contributing

Flower Agent is being developed in public. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

Flower Agent is available under the [MIT License](LICENSE).
