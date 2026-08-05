# Changelog

All notable changes to Flower Agent will be documented in this file.

The project follows Semantic Versioning once a stable public API is published.

## Unreleased

### Added

- Analyzer-backed Dart file dependency maps.
- Versioned project-map JSON output.
- Mermaid dependency graph export.
- Import, export, and part relationship detection.
- External package reporting per Dart file.
- Generated-file and feature-first metadata.
- Strongly connected dependency-cycle detection.
- `flower map` with human-readable, JSON, Mermaid, and feature-scoped output.
- Analyzer-backed architecture symbol indexing.
- Repository, service, provider, controller, data-source, and DAO detection.
- GoRouter, AutoRoute, and GetX route extraction.
- `flower symbols` with role and feature filtering.
- Architecture summaries in `flower inspect`, `flower init`, and generated project context.
- Versioned symbol-index JSON output.
- Deterministic task-specific context ranking from paths, features, symbols, routes, imports, and dependents.
- `flower context` with Markdown and versioned JSON output.
- Per-file context scores, selection reasons, architecture symbols, dependencies, and dependents.
- Configurable file-count context limits.
- Initial Persian task aliases for common project terminology.
- Deterministic entry-point fallback when a task has no lexical match.

### Changed

- Project snapshot JSON schema advanced to version 2 to include architecture data.
- Development package versions advanced to `0.3.0-dev.1`.

## 0.1.0-dev.1

### Added

- Dart Pub workspace with separate core and CLI packages.
- `flower inspect` for deterministic Flutter project inspection.
- `flower init` for safe project-local Flower initialization.
- Human-readable and JSON inspection reports.
- Initial roadmap, product principles, architecture documentation, and CI.
