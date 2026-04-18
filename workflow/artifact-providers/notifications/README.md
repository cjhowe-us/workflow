# notifications provider

A small, ephemeral ring buffer of status-line notifications. Not durable — dropped at session end.

## Backend

- URI: `notifications:session` (only one URI per session).
- Storage: `${XDG_RUNTIME_DIR:-/tmp}/workflow-$$/notifications.jsonl` (`$$` = orchestrator PID).
- Cap: last 64 entries; older entries trimmed on append.

## Subcommands

- `get` — current entries as an array.
- `create` — initializes the buffer (idempotent).
- `update` — no-op; notifications are append-only.
- `list` — single-URI provider; always returns `[{uri:"notifications:session"}]`.
- `lock/release` — always succeeds (session-local).
- `status` — always `running`.
- `progress [--append]` — read or append entries.

Typical entries:

```json
{"at":"...","level":"info","source":"discover","message":"registered 3 new workflows"}
{"at":"...","level":"warn","source":"env-check","message":"gh not authenticated"}
{"at":"...","level":"error","source":"lock","message":"assignee mismatch on owner/repo#42"}
```

The `userpromptsubmit-status.sh` hook reads the last few entries on each turn and injects them into
the status line.
