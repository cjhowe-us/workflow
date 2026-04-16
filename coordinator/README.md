# coordinator

Interactive orchestrator plugin for Claude Code. Dispatches up to 3 background worker teammates to
work in parallel on GitHub pull requests whose Project v2 dependencies are resolved. Multiple users
— each on their own machine, each running their own orchestrator — coordinate through GitHub itself.
No shared filesystem needed.

## What it does

- Scans a GitHub Project v2 for **draft pull requests**. PRs are the only unit of work; there are no
  issues, tasks, or cards in this model. Every phase of software work (specify / design / plan /
  implement / release / docs) is a PR. See `skills/pr-phases/SKILL.md` for the full model.
- Reads Project v2 `blocked by` item-relationships between PRs to build the dependency DAG. A
  dependent PR only becomes a dispatch candidate once every blocker PR is merged.
- For every PR in the unblocked frontier, dispatches a worker (agent-teams teammate) that acquires a
  single Project v2 lock on that PR, works in an isolated git worktree on the PR's branch,
  heartbeats the lock, then releases on finish or crash. Workers never create or update issues.
- Workers run as **background** teammates and cannot prompt the user directly. They `SendMessage`
  the orchestrator with any blocking question; the orchestrator calls `AskUserQuestion` on its own
  interactive turn and relays the answer back.

## Relationship to the `harmonize` plugin

`coordinator` replaces harmonize's SDLC + dispatch layer with a GitHub-native, PR-only model.
`harmonize` kept state on disk (`docs/plans/`, `locks.md`, `in-flight.md`, `worktree-state.json`)
and was single-machine; `coordinator` keeps every byte of coordination state in GitHub so it works
across machines, across contributors, and across contexts (work, personal, group projects, OSS). See
`skills/pr-phases/SKILL.md` for the side-by-side comparison.

## Requirements

- Claude Code with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set.
  **Required — the plugin's `SessionStart` hook blocks the session with exit 2 if this is not set.**
  Use the bundled installer — it detects your shell and persists the variable the right way for your
  platform.

  Bash / zsh / fish / sh:

  ```bash
  ./coordinator/scripts/ensure-agent-teams-env.sh
  ```

  PowerShell (Windows / macOS / Linux):

  ```powershell
  pwsh -NoProfile -File ./coordinator/scripts/ensure-agent-teams-env.ps1
  ```

  The installer writes to the appropriate target for your shell and OS:

  - **zsh** → `~/.zshrc` (`export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
  - **bash** → `~/.bash_profile` or `~/.bashrc` (`export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
  - **fish** → `~/.config/fish/config.fish` (`set -gx CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 1`)
  - **sh / ksh** → `~/.profile` (`export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
  - **PowerShell on Windows** → user-scope registry `HKCU:\Environment` via
    `[Environment]::SetEnvironmentVariable(..., 'User')`, which broadcasts `WM_SETTINGCHANGE` so
    every new process (PowerShell, cmd, Git Bash, GUI apps) inherits the variable. Preferred over
    `$PROFILE` because `$PROFILE` only affects PowerShell sessions.
  - **PowerShell on macOS / Linux** → `$PROFILE` (`$env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = '1'`)

Both installers are idempotent; re-running is a no-op. Pass `--dry-run` (bash) or `-DryRun`
(PowerShell) to see the detected target without writing anything.

- `gh` CLI authenticated with `read:project`, `project`, and `repo` scopes.
- A GitHub Project v2 containing the PRs in scope.
- GitHub Pro or Team tier (Project v2 is available to all, custom fields on items are available
  everywhere; no gating).
- Two custom fields on the Project (one-time setup — see below).

## One-time Project setup

Create these two custom fields on your Project v2:

| Field name        | Type | Purpose                                                              |
|-------------------|------|----------------------------------------------------------------------|
| `lock_owner`      | Text | `<machine-id>:<orchestrator-session-id>:<worker-agent-id>`. Empty = unlocked. |
| `lock_expires_at` | Text | ISO-8601 UTC timestamp, e.g. `2026-04-16T18:45:00Z`. Lexicographic `< now` = stale, reclaimable. Must be Text (not Date) — Project v2 Date is day-granular, too coarse for real-time locks. |

The plugin's first-run check verifies both fields exist and errors out cleanly if missing.

## Configuration

Per-user local config at `.claude/coordinator.local.md`:

```markdown
---
project_id: PVT_kwDOxxxxxxxxxxx  # Project v2 node ID
project_owner: my-org             # or user login
project_number: 42                # Project number
default_lease_minutes: 15         # lock lease for new work
---
```

## Usage

```text
claude --agent coordinator
```

Or invoke the `/coordinator` skill from within a Claude Code session.

The orchestrator runs as an **interactive-only** agent (`disable-model-invocation: true`) — it cannot be spawned automatically by other agents.

## Environment overrides

| Variable                                    | Default | Purpose                                                        |
|---------------------------------------------|---------|----------------------------------------------------------------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`      | —       | Must be `1`. Enables agent-teams worker dispatch.              |
| `COORDINATOR_UNBLOCK_HOOK_DEBOUNCE_SEC`     | `30`    | Debounce window for the unblock-scan hook to avoid thrash.     |

## Testing

**Script parity (cross-platform):**

```bash
pwsh -NoProfile -File coordinator/tests/test-parity.ps1
```

Fails CI when a `.sh` lacks a sibling `.ps1` (or vice versa) or a `.ps1` has a syntax error.

**Script smoke tests:**

```bash
cd coordinator/tests
python3 -m pytest -v
```

These run entirely inside the current Claude conversation — no external SDK, no API key, no network.
A Python shim on `PATH` fakes `gh api graphql` so the real `lock-acquire.sh`, `lock-release.sh`,
`lock-heartbeat.sh`, and `project-query.sh` scripts can be exercised against an in-memory Project
v2.

End-to-end behavior of the orchestrator is verified the same way users run it: start a Claude Code
session with `claude --agent coordinator`, point it at a test Project, and observe the dispatch
directly in that conversation.

See `/Users/cjhowe/.claude/plans/the-idea-is-that-delightful-fiddle.md` for the overall verification
plan.
