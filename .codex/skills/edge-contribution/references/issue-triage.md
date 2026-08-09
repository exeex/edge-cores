# Central issue triage

Use `https://github.com/exeex/edge-cores/issues` as the single community issue
tracker. Do not redirect reporters to `src/edge-rv`, `src/edge-e3enc`, test, or
third-party submodule trackers. Record the affected submodule or component as
issue metadata while keeping discussion in edge-cores.

## Prepare an actionable issue

Require enough information to reproduce or evaluate the request:

- concise problem or proposal;
- affected component and exact edge-cores commit/tag;
- minimal reproduction steps or motivating use case;
- observed and expected behavior;
- host, simulator/toolchain, and relevant configuration;
- exact failing command and short log excerpt; and
- whether private or encrypted RTL was involved, without posting private
  source or symbol mappings.

Search for duplicates before filing. Link related PRs and issues in edge-cores.
For a security-sensitive report, avoid public disclosure and follow any
repository security-reporting channel when one is configured.

## Periodic agent review

For each new or updated issue, the review agent should:

1. Read the complete issue and linked edge-cores context.
2. Classify the affected surface and check for duplicates.
3. Verify referenced paths, commands, and revision against the repository.
4. Reproduce with the smallest safe public test when practical.
5. Reply with a concise status: reproducible, needs information, expected
   behavior, proposed work, fixed by a linked PR, or not currently actionable.
6. Ask only for missing information that would change the next action.
7. Link the resolving PR and confirm its validation before recommending close.

Never claim reproduction without running it. Never initialize private RTL,
expose confidential information, or make external changes beyond the user's
authorization. Keep unresolved technical disagreement visible rather than
closing the issue merely because an automated review cycle completed.

## Reply style

Lead with the current conclusion, then give evidence and the next concrete
step. Distinguish verified facts from hypotheses. When blocked, name the exact
missing log, command, revision, or decision instead of posting a generic status
message.
