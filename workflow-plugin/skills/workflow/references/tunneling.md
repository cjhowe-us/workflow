# tunneling

A tunnel is a short-lived pipe between the user and one specific worker teammate. Default routing is
orchestrator-mediated: user → orchestrator → worker, worker → orchestrator → user. Tunneling
collapses that to user ↔ worker directly.

## Opening

```text
/workflow tunnel <worker-id>
```

The routing skill sends `{"kind":"tunnel","open":true}` to the named worker. From that point until
close:

- User turns are forwarded to the worker as plain prose in the `body` field of the next envelope
  (still strict JSON: `{"kind":"user","body":"..."}`).
- Worker replies are rendered verbatim to the user; the orchestrator passthrough is suppressed.

## Closing

Two paths:

1. **Worker initiates** — sends `{"kind":"tunnel","open":false,"reason":"..."}`. Preferred; lets the
   worker decide when the interactive moment is over.
2. **User force-close** — `/workflow untunnel`. Stamps `tunnel_force_closed_at` on the execution's
   artifact so the history is auditable.

## While tunneled

The orchestrator still monitors global state but suppresses dashboard injections during the tunnel.
Other workers continue in the background; their progress accumulates on their own artifacts as
normal.

## Notes

- One tunnel at a time per session. Opening a second tunnel implicitly closes the first.
- Tunnels do not affect artifact locks. A worker that was refusing to write because of an assignee
  mismatch still refuses inside a tunnel.
- Tunnels do not bypass the `pretooluse-no-self-edit.sh` hook. Plugin files stay immutable even from
  tunneled conversations.
