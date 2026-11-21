# Flutter and Dart Project Guide

## Project Overview

Build a local-first Flutter task management app. The current product must work
fully offline and persist tasks and their activity history on the device.
Keep the data and UI boundaries clear so a future request can add remote
synchronization without moving networking concerns into widgets or making the
local data model depend on a specific server.

Treat the user's task description as the source of product requirements. This
guide sets implementation conventions; it does not replace the requested
features or justify adding unrequested functionality.

## Tech Stack and Dependencies

- Use the Flutter and Dart versions required by the installed toolchain and
  declared in `pubspec.yaml`.
- Use Flutter and Dart capabilities or dependencies already in the project
  before adding a package. Add a dependency only when it materially simplifies
  the requested behavior, and keep it compatible with offline use.
- Choose one state-management approach per state owner. Follow the project's
  established package when one is configured. For a new state owner, use the
  approach that best fits its interactions; do not add multiple state systems
  by default.
- Keep persistence behind feature-owned repository contracts. The local
  implementation is the only data source required by the current offline
  scope. Do not add network, authentication, or backend dependencies unless a
  later product request explicitly calls for them.

## Project Structure

Organize code by feature. Add only the layers and directories that a feature
needs; this tree is a template, not a checklist of directories to create.

```text
.
├── lib/
│   ├── main.dart                 # App startup and top-level composition
│   ├── core/                     # Infrastructure shared by multiple features
│   │   ├── database/             # Database opening, schema, migrations
│   │   ├── di/                   # Dependency registration, if needed
│   │   └── theme/                # Shared design tokens, if needed
│   ├── features/
│   │   └── <feature_name>/
│   │       ├── data/             # Local sources and repository implementations
│   │       ├── domain/           # Feature entities and repository contracts
│   │       └── presentation/     # State owners, pages, and widgets
│   └── l10n/                     # Localization sources and generated output
├── test/                         # Tests organized to match lib/features/
├── pubspec.yaml
└── analysis_options.yaml
```

- Keep feature-specific entities, queries, repository contracts, and
  implementations inside their owning feature.
- Put only genuinely shared infrastructure in `lib/core/`. Avoid creating
  generic `utils`, `services`, or `shared` directories until multiple features
  have a real need for them.
- Do not make one feature depend on another feature's presentation layer.
  Compose navigation and cross-feature data mapping at the app composition
  point, normally in `main.dart`.
- Keep persistence models and SQL details at the data boundary. Expose domain
  values through repository contracts rather than leaking database rows into
  presentation code.

## Architecture and State

- Keep widgets focused on rendering, layout, and forwarding user actions.
  Put state transitions and product rules in the state owner or domain/data
  layer that owns them.
- Use immutable state and a clear one-way flow: user action, state owner,
  repository, persisted result, updated state, UI.
- Give each Cubit or BLoC a clear state responsibility. Represent loading,
  empty, success, and failure states wherever the screen needs to distinguish
  them. Keep rebuilds scoped to widgets that use the changed state.
- Add a use case only when it captures meaningful domain policy, coordinates
  multiple repositories, or is reused. Do not add a class for every pass-through
  repository call.
- Dispose controllers, subscriptions, and other resources owned by widgets or
  state objects.

## Local Data and Consistency

- Persist task records and activity history so they survive app restarts.
- Store each logical task change and its corresponding activity event in one
  database transaction. A failure must roll back both records.
- Detect no-op updates before opening a write transaction; do not create
  duplicate activity for a save that changes nothing.
- Use persisted state as the source of truth when stale UI state could produce
  an incorrect mutation. Serialize conflicting mutations when ordering matters.
- Order activity deterministically by timestamp and a stable tie-breaker such
  as the row ID.
- Preserve active search and filter criteria when reloading the task list.
  Ensure a slower search result cannot replace results for a newer query.
- Version the database schema and add explicit migrations when its shape
  changes. Keep local persistence behind repositories so a future sync layer
  can be introduced without coupling the UI to a server or transport format.
- Keep deletion behavior for related activity explicit and consistent with
  the product requirements.

## Code Style

- Follow `analysis_options.yaml` and the formatting used in nearby Dart code.
- Prefer descriptive names, small focused methods, and `const` constructors
  where applicable.
- Add comments for non-obvious decisions, not for code that explains itself.
- Avoid speculative abstractions, empty folders, and unrequested features.

## Testing and Verification

- Read the relevant implementation and tests before changing behavior.
- Add focused tests for changed behavior. Prioritize state transitions,
  persistence atomicity, no-op writes, failures, and concurrency where relevant.
- Prefer testing logic at its owning layer. Use a real local database for
  transaction and migration behavior that an in-memory repository cannot
  verify.
- Run the applicable checks when practical:

  ```sh
  dart format --output=none --set-exit-if-changed .
  flutter analyze
  flutter test
  ```

- Do not claim a check passed unless it completed successfully. If a relevant
  check could not be run, state that clearly in the task summary.
