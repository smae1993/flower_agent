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

The repository is in active early development. The first vertical slice provides:

- `flower inspect` — detect Flutter technologies, feature folders, source files, generated files, and tests;
- `flower init` — create a project-local `.flower` workspace and agent bootstrap instructions;
- human-readable and JSON output suitable for both developers and AI tools;
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

The initialization command creates files only when they do not already exist. It does not overwrite an existing `AGENTS.md` or Flower configuration.

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
├── flower_core/    # Project models, inspection and initialization
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
