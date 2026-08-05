# Contributing to Flower Agent

Thank you for helping improve Flower Agent.

## Before opening a change

1. Read `docs/PRODUCT.md` and `docs/ARCHITECTURE.md`.
2. Check `ROADMAP.md` to confirm the work fits the current phase.
3. Search existing issues and pull requests.
4. For a large or breaking change, open an issue before implementation.

## Development setup

Requirements:

- Dart SDK compatible with the root `pubspec.yaml`;
- Git;
- a Flutter project fixture when adding new detection behavior.

Install dependencies:

```bash
dart pub get
```

Run the CLI from source:

```bash
dart run packages/flower_cli/bin/flower.dart --help
```

## Required checks

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test packages/flower_core/test packages/flower_cli/test
```

## Pull requests

A pull request should:

- solve one focused problem;
- include tests for behavior changes;
- update user documentation when commands or output change;
- update the roadmap only for work that is actually complete;
- avoid unnecessary dependencies;
- preserve local-first and safe-write behavior.

## Adding detection rules

Every technology-detection rule must include:

- a fixture or temporary test project;
- a positive test;
- a negative or ambiguous-case test where relevant;
- a stable category and reported package name.

Prefer package metadata and analyzer data over fragile source-text matching.

## Commit messages

Use short conventional prefixes where practical:

```text
feat: add route detection
fix: preserve existing agent instructions
test: cover malformed pubspec
docs: explain snapshot schema
build: update CI matrix
```

## Reporting security problems

Do not publish sensitive vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md).
