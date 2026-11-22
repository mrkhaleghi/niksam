# AI-assisted workflow

## Tools and division of work

I used Codex with GPT-6.1 Sol at medium reasoning, according to my session
configuration. The repository's `AGENTS.md` supplied architecture, persistence,
style, and verification conventions. I set scope, chose feature boundaries and
state owners, supplied an existing local project as the UI reference, and reviewed
the generated implementation. Codex read sources, implemented layers, ran
authorized checks, and created incremental commits. I explicitly deferred tests
and documentation initially, then authorized focused tests as a separate stage.

Work was split into domain contracts, SQLite persistence, BLoC/Cubit state,
screen UI, composition, and tests. Commits preserve those stages without
squashing. This was staged work in one Codex chat, not parallel subagent work.

## Key prompts

These summarize my instructions rather than claiming verbatim quotations:

- Build two screen-owned features; use BLoC for the list and Cubit for create/edit,
  keep clean boundaries, and use `package:niksam/...` imports.
- Match the reference project's texts, colors, and layout. Make coherent commits
  and stop if a commit fails. Initially do not run the app, analyze, write tests,
  or edit the deliverable documents.
- Then test real SQLite rollback/no-op writes, rapid completion transitions,
  current search/filter preservation, errors/retries, and duplicate form saves.
  Afterwards run analysis and attempt emulator verification.

## Corrections and review decisions

These examples distinguish early design decisions challenged during review from
issues discovered in the implemented app.

1. **In-memory filtering:** Codex initially loaded all tasks and applied search
   and filters in memory. I required filtering to move into SQLite through
   repository query criteria. Codex replaced the in-memory filtering with
   parameterized SQL combining title, priority, and completion, while retaining
   stale-response protection in the BLoC. Real SQLite tests verified matching
   behavior, and asynchronous BLoC tests verified that older results or failures
   could not replace the latest state.
2. **Cubit for both screens:** an early proposal used Cubit for both. I chose
   list events in a BLoC because reloads, query/filter changes, mutations, and
   retries interact; the form kept a Cubit. Cubit itself was not invalid, but the
   split made the event flow clearer. I also rejected grouping both screens in
   one entity-oriented feature.
3. **Missing date initialization:** running the app exposed a `LocaleDataException`
   in `TaskCard`. I supplied the stack trace. Codex added bundled English
   `initializeDateFormatting('en')` before `runApp`. This was a runtime omission
   that source review and the state/data tests had not detected.

## Verification and lessons

My direct checks included reviewing imports and architecture choices, supplying
the UI reference, and running the app far enough to catch the date exception.

The main lesson was to make `AGENTS.md` and the initial prompt more explicit about
screen ownership, imports and the BLoC/Cubit. Better
instructions reduce rework but do not replace code review or device checks.