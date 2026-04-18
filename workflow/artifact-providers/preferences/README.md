# preferences provider

Wraps workspace + user preferences files as artifacts.

| URI                       | Path                                          |
|---------------------------|-----------------------------------------------|
| `preferences:workspace`   | `$REPO/.claude/workflow.preferences.json`     |
| `preferences:user`        | `$HOME/.claude/workflow.preferences.json`     |

Both files are small JSON documents with arbitrary keys. Known keys:

- `orchestrator` — override the default orchestrator workflow name.
- `wip.per_developer` / `wip.per_machine` / `wip.per_execution` — caps.
- `polling.min_poll_interval_s` — global default for providers without their own.
- `tutor.completed` — boolean; `default` uses this to skip the tutor once the user has seen it.

Merge order at resolution: user ← workspace (workspace wins on key clashes). The orchestrator merges
and caches on turn start.

## Subcommands

- `get --uri U` — returns the full JSON doc (or `{}` if missing).
- `create` / `update` — merge semantics against the existing file.
- `list` — enumerates the two URIs.
- `lock/release` — file-level flock on the target path.
- `status` — always `complete` (preferences files are steady-state).
- `progress` — null; progress is not meaningful for preferences.
