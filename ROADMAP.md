# Flower Agent Roadmap

This roadmap is the source of truth for implementation order. A checked item must exist in code or documentation on `main` and must not describe aspirational behavior as completed.

## Product goal

Flower Agent helps AI coding agents understand, navigate, and protect the architecture of Flutter projects without requiring an LLM API key or sending source code to a cloud service.

## Phase 0 — Foundation

Target: establish a maintainable public Dart workspace and a clear product boundary.

- [x] Define Flower as project intelligence and governance, not another state manager.
- [x] Establish local-first and deterministic product principles.
- [x] Create a Dart Pub workspace.
- [x] Split the first implementation into `flower_core` and `flower_cli`.
- [x] Add formatting, analysis, and test CI.
- [x] Add architecture, product, contribution, security, and agent documentation.
- [x] Add an MIT license and initial changelog.

## Phase 1 — Project Intelligence MVP

Target: inspect an existing Flutter project and create Flower's project-local workspace.

### 1.1 Project inspection

- [x] Read and validate `pubspec.yaml`.
- [x] Detect whether the target is a Flutter project.
- [x] Detect common state-management packages.
- [x] Detect router, networking, database, code-generation, and DI packages.
- [x] Count Dart source, generated, unit-test, and integration-test files.
- [x] Detect feature directories under common feature-first layouts.
- [x] Provide human-readable output.
- [x] Provide stable JSON output for agents and scripts.
- [x] Replace file-pattern inspection with analyzer-backed symbol indexing where useful.
- [x] Detect routes and route names for supported router constructors.
- [x] Detect repositories, services, providers, controllers, and data sources.
- [ ] Detect monorepos and nested Flutter packages.

### 1.2 Project initialization

- [x] Add `flower init`.
- [x] Create `.flower/flower.yaml` without overwriting existing configuration.
- [x] Create `.flower/context/project.md` from the inspection snapshot.
- [x] Create a minimal `AGENTS.md` only when one does not exist.
- [ ] Add adapters for Claude, Cursor, OpenCode, Copilot, and Gemini instruction files.
- [ ] Add `flower agents sync` with safe merge behavior.
- [ ] Add configuration schema validation and actionable errors.

### 1.3 Project map

- [x] Define stable project-map JSON schema.
- [x] Build import and package dependency graphs.
- [x] Export Mermaid diagrams.
- [x] Detect dependency cycles.
- [x] Add `flower map` and feature-scoped map output.
- [ ] Cache maps and invalidate only affected files.

### 1.4 Symbol index

- [x] Define a stable architecture-symbol JSON schema.
- [x] Detect class roles from names and supertypes.
- [x] Detect top-level provider declarations and `@riverpod` functions.
- [x] Extract supported route constructors and metadata.
- [x] Add `flower symbols` with kind and feature filtering.
- [x] Include architecture summaries in inspection and initialized context.
- [ ] Add configurable role aliases for project-specific naming conventions.
- [ ] Add symbol references and declaration-to-file dependency links.

## Phase 2 — Context Engine

Target: give an agent the smallest trustworthy context needed for a task.

- [x] Add `flower context "task description"`.
- [x] Rank files by symbols, imports, feature proximity, routes, and file paths.
- [ ] Include relevant architecture decisions and conventions.
- [x] Explain why each file was selected.
- [x] Add a configurable file-count context budget.
- [x] Support Markdown and JSON output.
- [x] Support English identifiers and initial Persian task aliases.
- [ ] Add project-defined task aliases and terminology.
- [ ] Include relevant tests and non-`lib` project files.
- [ ] Measure context precision on real Flower dogfood projects.

Exit criteria:

- [ ] A task-specific context is materially smaller than broad repository scanning on production projects.
- [x] Every selected file includes a deterministic reason.
- [x] Context generation works without network access.

## Phase 3 — Architecture Guard

Target: reject changes that violate project-specific rules.

- [ ] Define rule configuration and violation schemas.
- [ ] Enforce allowed and forbidden layer imports.
- [ ] Detect Flutter dependencies inside pure domain layers.
- [ ] Detect business logic placed in widgets.
- [ ] Detect raw colors, spacing, and typography outside configured design tokens.
- [ ] Add RTL-aware rules for directional padding and alignment.
- [ ] Detect missing tests for configured change categories.
- [ ] Add `flower guard` with human, JSON, and CI output.
- [ ] Support rule suppression with explicit justification.
- [ ] Provide a plugin API for third-party rules.

Exit criteria:

- Rules are deterministic and independently testable.
- CI can fail on configurable severity levels.
- Suppressions are visible and auditable.

## Phase 4 — Decision Memory

Target: preserve architectural decisions and make them available to agents.

- [ ] Add Architecture Decision Record schema.
- [ ] Add `flower decision add/list/show`.
- [ ] Link decisions to features, packages, and rules.
- [ ] Detect changes that conflict with accepted decisions.
- [ ] Include relevant decisions in task context.
- [ ] Add migration support for decision schema versions.

## Phase 5 — Change Planning

Target: estimate the impact of a requested change before code is edited.

- [ ] Add `flower plan "task description"`.
- [ ] Identify affected features and layers.
- [ ] Identify likely tests, routes, database migrations, and API contracts.
- [ ] Report architectural and compatibility risks.
- [ ] Produce a machine-readable change contract for coding agents.
- [ ] Validate completed changes against the original plan.

## Phase 6 — MCP Integration

Target: expose Flower intelligence to any MCP-compatible coding agent.

- [ ] Add `flower mcp` over stdio.
- [ ] Expose project summary and feature tools.
- [ ] Expose relevant-file and project-rule tools.
- [ ] Expose planning and validation tools.
- [ ] Keep the MCP transport behind an adapter to isolate experimental API changes.
- [ ] Publish setup guides for Codex, OpenCode, Claude Code, Cursor, and Copilot.

Initial tool set:

```text
flower_project_summary
flower_list_features
flower_get_feature
flower_find_relevant_files
flower_get_project_rules
flower_get_decisions
flower_plan_change
flower_validate_change
flower_update_project_map
```

## Phase 7 — Generators and UI Audit

Target: add high-value workflows after the intelligence layer is reliable.

- [ ] Architecture-aware feature scaffolding.
- [ ] Page, repository, service, and model generators.
- [ ] Responsive and RTL UI audit.
- [ ] Dark-mode and text-scale audit.
- [ ] Screenshot-based HTML reports.
- [ ] Optional Flutter DevTools extension.

## Release milestones

### `0.1.0-dev.1`

- Workspace foundation
- `flower inspect`
- `flower init`
- CI and public documentation

### `0.2.0-dev.1`

- Analyzer-backed project map
- `flower map`

### `0.2.0-dev.2`

- Analyzer-backed architecture symbol index
- Route and architecture-role detection
- `flower symbols`
- Enriched inspection and initialized project context

### `0.2.0-dev.3`

- Agent instruction adapters
- Monorepo and nested package detection
- Project map caching

### `0.3.0-dev.1`

- Deterministic task-specific context engine
- `flower context`
- Markdown and JSON context contracts
- File-count context budget and selection explanations

### `0.3.0-dev.2`

- Project terminology and task aliases
- Test and configuration-file context
- Production-project context evaluation

### `0.4.0-dev.1`

- Rule engine
- `flower guard`

### `0.5.0-beta.1`

- Decision memory
- Change planning
- MCP server

### `1.0.0`

- Stable schemas and CLI behavior
- Validated on multiple production Flutter repositories
- Complete documentation and migration policy
- Published packages on pub.dev

## Non-goals before 1.0

- A Flower state-management library
- A Flower router or dependency-injection container
- A hosted AI chat service
- Requiring OpenAI, Anthropic, or another model provider
- Uploading private source code to Flower servers
- Replacing the official Dart and Flutter MCP server
