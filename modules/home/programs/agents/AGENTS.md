# Leon's Agent Instructions

## General Guidelines

These are general instructions for Leon's agents across all scenarios.

- Never use the em dash "—". Use plain dash "-" instead
- When writing or substantially editing long Markdown files, put each sentence
  on its own line.
  Preserve normal Markdown structure, but avoid wrapping multiple sentences into
  one physical line

## Coding Guidelines 

These are instructions for Leon's agents across coding scenarios.

- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as
  auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term
  maintainability.
- Avoid overengineering. Prefer the simplest solution that fully satisfies the
  current requirements. Do not add abstractions, extensibility, configurability,
  or infrastructure for hypothetical future needs.
- When doing bug fixes, start with reproducing the bug in an E2E setting as
  closely aligned with how an end user would encounter it.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product's UI, be picky about the UI you see and be
  obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you
  are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures,
  and test flakiness.
  If you see one, even if it is not caused by what you are working on right now,
  still get it fixed.
- When you start a process such as using `npm run dev` during a command, make
  sure you terminate it once you are done with the current task. Do not leave
  any of these processes live when it is not obvious you are still using them.
- Keep comments and documentation concise and current-state: explain functionally
  non-obvious invariants or operational facts, never implementation history,
  rejected alternatives, work-package narration, or mini design documents inside
  source files.
- When deleting a feature, remove its associated code, documentation, and tests.
  Do not leave tombstone tests or explanatory notes about removed functionality
  unless the absence or failure itself is a current API, security, or persistence
  contract.
