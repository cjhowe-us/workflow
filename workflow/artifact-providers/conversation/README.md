# conversation provider

Persists AI conversations as append-only JSONL files. Each turn is one line:
`{at, role, content, tool_calls?, metadata?}`.

## Backend mapping

| Field   | Backed by                                              |
|---------|--------------------------------------------------------|
| uri     | `conversation:<slug>`                                  |
| storage | `$XDG_STATE_HOME/workflow/conversations/<slug>.jsonl`  |
| status  | `running` while any recent turn exists; `complete` once `ended_at` is set in metadata |

## Subcommand semantics

- `get --uri U` — returns all turns + header metadata.
- `create --data F` — initializes a new conversation file; `data.slug` becomes the URI suffix.
  `data.metadata` is stored as the first line.
- `update --uri U --patch F` — appends a turn (`patch.turn`) or updates header metadata
  (`patch.metadata_merge`).
- `list` — enumerates all stored conversations.
- `status` — `running` if last turn is within N minutes, `complete` if metadata has `ended_at`, else
  `unknown`.
- `progress` — returns the turn log.

## Scope

Local-only by design. Conversations are developer-private artifacts. Cross-machine sharing isn't
supported; a different provider (e.g. future `gh-gist-conversation`) would be needed for that.
