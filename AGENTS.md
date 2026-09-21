# Delegation

- Automatically delegate bounded, independent work when the benefit outweighs coordination and review overhead. Handle small tasks directly.
- Use `explorer` for read-only investigation and `mechanical` for fully specified, deterministic edits.
- Keep planning, architecture, ambiguous debugging, security decisions, migrations, concurrency, integration, and final verification with the primary agent, which owns user communication and the final answer.
- Run at most three subagents concurrently unless the user requests more. Subagents must not re-delegate without the primary agent's instruction.
- Give each subagent the necessary context, scope, constraints, expected result, and explicit read-only or file-edit ownership. Parallel edits must have non-overlapping ownership; tell subagents they share the workspace and must preserve others' changes.
- Require concise results with relevant paths, checks run, and unresolved assumptions or questions.
- Wait for required subagent results, review their evidence and diffs against the request, and validate the integrated result before reporting completion.
