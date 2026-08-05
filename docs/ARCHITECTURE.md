# Architecture

## Overview

Flower Agent starts as a Dart workspace with a strict dependency direction:

```text
flower_cli ───────→ flower_core
                       ↑
                 future adapters
```

The CLI is an interface. Project intelligence belongs in reusable packages so it can later serve MCP, CI, IDE, and DevTools integrations without shelling out to the CLI.

## Packages

### `flower_core`

Responsibilities:

- immutable project snapshot models;
- project inspection;
- technology and feature detection;
- safe project initialization;
- stable serialization for machine consumers.

It must not know about terminal colors, exit codes, command parsers, or MCP transport.

### `flower_cli`

Responsibilities:

- command and option parsing;
- human-readable and JSON rendering;
- mapping failures to exit codes;
- invoking core application services.

It should remain thin. New analysis behavior belongs in core.

## Planned package boundaries

Packages will be split only when the boundary provides independent value:

```text
flower_core       models and orchestration contracts
flower_analyzer   analyzer-backed symbols and dependency graph
flower_rules      deterministic architecture rule engine
flower_index      persistent project index and cache
flower_mcp        MCP transport adapter
flower_reporter   HTML and machine-readable reports
```

Premature package splitting is avoided during the first vertical slice.

## Snapshot contract

`ProjectSnapshot` is the first machine-readable contract. Its JSON keys are explicit rather than generated so accidental serializer changes do not silently break agents and scripts.

A snapshot includes:

- schema version;
- normalized project root;
- package name and description;
- Flutter detection;
- source and test counts;
- feature names;
- detected technologies;
- actionable warnings.

Breaking snapshot changes require a schema-version increment and migration notes.

## Inspection strategy

The MVP uses deterministic sources that are cheap and reliable:

1. `pubspec.yaml` for package and dependency information;
2. directory structure for feature detection;
3. file names for source, generated-code, and test counts.

Later milestones add analyzer-backed symbols and imports. File-pattern detection remains useful as a fast fallback and for incomplete repositories.

## Safe initialization

`flower init` follows create-only semantics:

- inspect before writing;
- create `.flower/flower.yaml` only when absent;
- create `.flower/context/project.md` only when absent;
- create `AGENTS.md` only when absent;
- report skipped files explicitly.

Future synchronization commands must parse and merge supported managed sections rather than replacing complete user files.

## Error model

Core throws typed Flower exceptions for user-correctable failures such as a missing or malformed pubspec. Interfaces convert them into their own representation, such as CLI exit codes or MCP errors.

Unexpected exceptions are not presented as successful partial analysis.

## Compatibility policy

- Support current stable Dart with an explicit lower bound.
- Keep CLI flags backward compatible during a minor release line.
- Keep JSON output stable within a schema version.
- Isolate experimental analyzer and MCP APIs behind adapters.
- Avoid importing Flutter SDK libraries into the core inspection layer unless runtime inspection genuinely requires them.
