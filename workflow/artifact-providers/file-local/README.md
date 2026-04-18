# file-local provider

The simplest artifact provider: reads and writes files in the current git worktree. URIs are
`file-local:<path>` where path is relative to the worktree root.

## Backend mapping

| Artifact field | Backed by                                  |
|----------------|---------------------------------------------|
| uri            | `file-local:<relative-path>`                |
| status         | file existence + `.status` sidecar          |
| content        | the file itself                             |
| lock           | `flock(2)` on `<path>.lock`                 |
| progress       | append-only `<path>.progress.jsonl`          |

## Subcommand semantics

- `get --uri U` — `{"uri":U, "content":"<contents>", "exists":true}`.
- `create --data F` — writes `F.path` with `F.content`. Creates parents.
- `update --uri U --patch F` — merges `F.patch` into an existing file (JSON/YAML awareness for those
  extensions; raw-replace for text).
- `list --filter F` — glob or regex over the worktree.
- `lock / release` — `flock(2)` on a sibling `.lock` file. Provider-level exclusivity within one
  machine; cross-machine coordination isn't meaningful for local files (different machines,
  different filesystems).
- `status --uri U` — `complete` if file exists, `unknown` otherwise.
- `progress --uri U [--append F]` — JSONL log in `<path>.progress.jsonl`.

## Notes

- All paths resolve against `git rev-parse --show-toplevel`. Absolute or parent-escape paths are
  rejected.
- Hook `pretooluse-no-self-edit.sh` still applies: writes under any plugin root are blocked.
- This provider is not intended for cross-developer coordination. Use `document`
  (workflow-documents) or a backend-specific provider for that.
