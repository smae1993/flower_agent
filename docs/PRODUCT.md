# Product Definition

## Positioning

Flower Agent is the project intelligence and governance layer for Flutter coding agents.

```text
AI coding agent       = reasoning and code generation
Dart & Flutter MCP    = analyzer, runtime, tests, DevTools
Flower Agent          = project memory, architecture map, rules and governance
```

## Primary users

- Flutter developers who use coding agents on existing applications.
- Teams that need agents to respect a shared architecture and design system.
- Maintainers who want deterministic CI checks for agent-generated changes.
- Developers with large repositories where broad context loading is slow or expensive.

## Core jobs

1. Understand the repository quickly.
2. Find the files and decisions relevant to a task.
3. Plan the likely impact of a change.
4. Validate the result against project-specific rules.
5. Preserve architectural knowledge between developers and agents.

## Product principles

### Local-first

Project inspection and governance run on the developer's machine. Flower does not require a cloud account or model API key.

### Deterministic first

ASTs, imports, package metadata, file structure, configuration, and explicit rules should answer a question before probabilistic inference is considered.

### Agent-neutral

The same project intelligence should be consumable by Codex, OpenCode, Claude Code, Cursor, Copilot, Gemini, scripts, and CI.

### Official-tooling friendly

Flower complements the Dart analyzer, Flutter tooling, DevTools, and the official MCP server. It does not duplicate them without a project-specific reason.

### Safe writes

Initialization and synchronization commands never silently replace user-authored configuration.

## Initial success metrics

- A new user can inspect a project in under one minute.
- JSON inspection output is stable and scriptable.
- Initializing Flower does not destroy or overwrite existing project instructions.
- A project snapshot correctly identifies the most common Flutter technology choices.
- The architecture permits adding context, guard, plan, and MCP capabilities without coupling them to CLI output.

## Deliberate exclusions

Before the intelligence layer is proven, Flower will not build its own state manager, router, DI container, storage engine, hosted chat, or proprietary model gateway.
