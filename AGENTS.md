# Lean workflow and delegation

- For status, usage, and explanation requests, inspect existing evidence, answer, and stop. Do not start tests, fixes, or audits unless requested. Already-running work may be observed, not restarted.
- Delegate only bounded, independently reviewable work when it replaces primary work and the benefit outweighs coordination and review overhead. Handle small tasks directly; do not repeat a worker's investigation.
- Use the global Astra/Muse routing: Astra owns planning, difficult decisions, review, and integration; Muse handles delegated investigation and implementation. Do not automatically fall back to Sol/Terra/Luna or native `explorer`/`mechanical` workers. Follow global `jev-context` guidance for broad reads.
- Keep planning, architecture, ambiguous debugging, security decisions, migrations, concurrency, integration, and final verification with the primary agent, which owns user communication and the final answer.
- Before implementation, state the done condition and smallest relevant existing check. Expand verification only for a specific failure, affected dependency, risk, or required gate; state why. Reuse valid results for unchanged code, preserve required checks, and avoid routine full suites or redundant tests.
- Run at most three workers; no recursive delegation. Use linked Git worktrees for Muse edits.
- Give each subagent the necessary context, scope, constraints, expected result, and explicit read-only or file-edit ownership. Parallel edits must have non-overlapping ownership; tell subagents they share the workspace and must preserve others' changes.
- Request short handoffs: changes/findings, check results, unresolved issues, and references. Read additional logs only for a concrete question; no routine transcript review or mandatory scorecards.
- Wait for required worker results, review relevant source and tracked/untracked diffs against the request, and verify the integrated result proportionately before reporting completion. After two failed fixes, reassess evidence and approach before continuing.
