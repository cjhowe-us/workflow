# multi-dev

Two layers of coordination: presence (cross-machine, informational) and artifact locks (per-artifact, authoritative).

## Identity

`gh auth status` is the sole source of identity. No login dialog. If the user runs `/workflow` without being
authenticated, the `default` tutor instructs them to:

```bash
gh auth login
```

and reopen. That's the entire onboarding handoff.

## Presence artifact

Presence is a first-class artifact under the `presence` scheme, stored by the `presence-gh-gist` storage as a private
gist named `workflow-user-lock-<gh-user-id>`. URI shape: `presence|presence-gh-gist/<gh-user-id>`. The scheme's content
model (`PresenceContent`) is the canonical source; this reference documents the on-disk JSON shape the gist carries.

Every active session registers an entry. Shape:

```json
{
  "active_machines": [
    {
      "machine_id":     "alice-mbp.local",
      "session_id":     "sess-01HXX...",
      "started_at":     "2026-04-18T09:02:00Z",
      "last_heartbeat": "2026-04-18T09:14:10Z",
      "pid":            12345
    }
  ],
  "previous_machines": [
    {
      "machine_id": "alice-mbp.local",
      "session_id": "sess-01HWW...",
      "started_at": "2026-04-17T14:00:00Z",
      "ended_at":   "2026-04-17T18:30:00Z"
    }
  ]
}
```

Operations:

- **Register** on session start — append current session to `active_machines` (after pruning stale entries past
  `lock_stale_minutes`, default 10).
- **Heartbeat** every 2 min — update `last_heartbeat` on this session's entry.
- **Retire** on clean exit — remove this entry from `active_machines`, append a summary to `previous_machines` (trimmed
  to last 50).
- **Reap stale** entries on any session's next register.

Multiple machines active at once is expected. The gist records presence, not ownership. Coordination across machines
happens via artifact locks.

## Artifact locks

Before any write, the worker consults the artifact provider's `lock --check --uri U --owner <session>`. Mismatch →
refuse the write with a plain blocker message; the user must resolve at the backend (e.g.
`gh pr edit <N> --add-assignee @me`).

No auto-transfer. No lock stealing. Ownership changes are human-driven, always.

## Per-machine orchestrator flock

A separate per-machine flock at `$XDG_STATE_HOME/workflow/orchestrator.lock` limits the machine to one orchestrator
session at a time. Different machines for the same GH user coexist; same machine for the same user does not.

## Labels are not used

Ownership is never indicated by a label. The backend's native owner signal (GH PR assignee, Jira assignee, Confluence
page owner) is the lock. Labels would be another thing to keep in sync; the provider already has one.
