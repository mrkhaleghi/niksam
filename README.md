# Niksam

An offline Flutter task manager built for a technical assignment. Tasks and
activity are stored locally in SQLite; no account, backend, or API is required.

## Features

- Search titles and combine priority and completion filters directly through parameterized SQLite queries.
- Create/edit tasks with a required title, optional description, and priority.
- Complete, reopen, and delete tasks, including their associated history.
- View timestamped creation, priority-change, completion, and reopening events.
- Reload after successful changes while keeping the current search and filters.

## Setup

Developed with **Flutter 3.44.0 / Dart 3.12.0**. The Dart SDK constraint is
`^3.12.0`. With Flutter and Android tooling installed:

```sh
flutter pub get
flutter devices
flutter run
```

Installing dependencies may need internet; app operation does not. Android is the current verification target.
Other generated platform folders do not imply verified support; web and Windows
database initialization is not configured.

## Packages and rationale

| Package | Why it is here |
| --- | --- |
| `flutter_bloc` | BLoC events for the list and Cubit for the form. The assignment requires BLoC or Cubit. |
| `sqflite` | Explicit SQLite transactions and a small schema without a generation step. Drift's typed queries and migration tooling were considered, but its generation workflow was unnecessary at this scale. |
| `get_it` | Familiar registration of the shared database and feature repositories. Screen state owners are supplied through `BlocProvider`. |
| `flutter_localizations` | Declared Flutter SDK dependency; multilingual resources and localization delegates are not implemented in this English-only app. |
| `sqflite_common_ffi` (dev) | Real SQLite persistence tests on the host. |

## Reproduce write failures

Run normally and create a task first. Stop that run, then launch:

```sh
flutter run -d emulator-5554 --dart-define=FAIL_WRITES=true
```

Try creating a task, editing an existing priority, completing/reopening a task,
and deleting one. An exception is injected after the task mutation inside its
transaction. Both task and history changes roll back. The list reloads stored
values and shows an error with Retry; the form retains its unsaved draft for
another Save attempt. Leaving the form discards that draft.

Every actual write fails while this flag is enabled, including retries. Stop and
relaunch without the flag to restore writes; hot reload cannot change this
compile-time setting. No-op saves still succeed without writing. Automated tests
also cover recovery when a failure is removed.

## Verification and limitations

```sh
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
```

The last full test run passed **29 tests**: 15 SQLite persistence tests,
8 list BLoC tests, and 6 form Cubit tests. Coverage includes rollback,
reopen persistence, no-op writes, ordered events, concurrent mutations,
SQL search and combined filters, literal wildcard handling, stale query
results and failures, retry states, and duplicate-save protection.

`flutter analyze` completed with no issues. The formatting check passed
without changes.

Schema v1 is implemented; future versions require explicit migrations.

## Work sessions

Work took place in two separate sessions: 23:30–01:00 and 06:30–08:00
the following morning, totaling approximately **3 hours**
of active work, excluding the break.



See [DESIGN.md](DESIGN.md), including the architecture diagram,
[AI_WORKFLOW.md](AI_WORKFLOW.md), and the coding instructions in [AGENTS.md](AGENTS.md).
