# workflow-plugin

Claude Code plugin shipping the glibre workflow: seven role-based agents and three workflow skills
for issue-driven, spec-first Rust development on GitHub.

Provides:

- **Agents** — `chore`, `code`, `design`, `plan`, `product`, `review`, `test`
- **Skills** — `think`, `work`, `review-respond`

## Install

In Claude Code:

```text
/plugin marketplace add cjhowe-us/workflow-plugin
/plugin install workflow-plugin@workflow-plugin
```

The first command registers this repo as a single-plugin marketplace; the
second installs the plugin from it.

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `chore` | haiku | Mechanical 1-2 file edit worker (bumps, renames, typos, label tweaks). |
| `code` | sonnet | Implementation role for one `type:plan` leaf — branches, codes, tests, opens PR. |
| `design` | opus | Authors / updates `specs/<ctx>/SPEC.md` and ADRs under `specs/decisions/`. |
| `plan` | opus | Decomposes specs into user-stories, leaf plans, and E2E `.glibre-trace` files. |
| `product` | opus | Owns `[INITIATIVE]` / `[EPIC]` framing — outcomes, success metrics, scope. |
| `review` | opus | Reviewer role on someone else's PR. Posts inline comments, sets approve/changes. |
| `test` | sonnet | TDD test author — drafts the failing tests the `code` role then makes pass. |

## Skills

| Skill | Purpose |
|-------|---------|
| `think` | Structured reasoning skill for hard problems (decompose → analyze → synthesize). |
| `work` | Author-side work loop driver — picks the next leaf, runs the role, lands the PR. |
| `review-respond` | Author-respond cycle on your own PR — triage comments, fix, push, request re-review. |

## Storage contract

These agents assume:

- **Plans live in GitHub Issues** — `[INITIATIVE]`, `[EPIC]`, `[STORY]`, `[PLAN]`, `[SPIKE]`.
- **Designs live in the repo** under `specs/<ctx>/SPEC.md` and `specs/decisions/*.md`.
- **Code lives in Rust workspaces** — `cargo build|test|clippy|fmt`.

Adapt the agent prompts if your project uses a different substrate.

## License

Apache-2.0
