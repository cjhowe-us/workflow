---
name: yaml
description: >
  YAML coding standard for the Harmonius project. Use this skill whenever
  reading, writing, editing, reviewing, or creating any `.yml` or `.yaml`
  file. Also use when discussing GitHub Actions workflows, YAML formatting,
  yamllint rules, or CI/CD configuration. Trigger on any interaction with
  YAML files — even small workflow edits must follow this standard.
---

# YAML Coding Standard

## Scope

GitHub Actions workflows only. YAML is used exclusively for CI/CD configuration in
`.github/workflows/`.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Workflow file | `kebab-case.yml` | `markdown.yml` |
| Job name | `kebab-case` | `lint-and-format` |
| Step name | Sentence case | `Check Markdown` |
| Environment variable | `SCREAMING_SNAKE` | `RUST_LOG` |
| Secret | `SCREAMING_SNAKE` | `DEPLOY_TOKEN` |

## File Organization

- All workflows in `.github/workflows/`
- `.yml` extension (not `.yaml`)
- One workflow per file
- Reusable workflows in `.github/workflows/` with `workflow_call` trigger

## Formatting Rules

- 100-character line limit
- 2-space indentation
- No tabs
- Use block scalars (`|` or `>`) for multi-line strings
- Quote strings containing special YAML characters

## Linting Rules

- `yamllint` for validation
- No duplicate keys
- Consistent quoting style

## Type Checking

Not applicable for YAML.

## How to Check and Fix

| Validation | Check command | Fix command |
|------------|--------------|-------------|
| Valid YAML | `yamllint` | (manual) |

## Project-Specific Rules

1. **GitHub Actions only** — no other YAML usage
2. **Pin action versions** — use SHA or major version tag (`@v4`), not `@main`
3. **Explicit permissions** — set minimum `permissions` per workflow

## Cache-Friendly Patterns

Not applicable for YAML.

## Testing

1. **Act** — test workflows locally with `act` where possible
2. **Dry run** — review workflow syntax before pushing
3. **Branch protection** — require status checks to pass before merge

## Best Practices

1. Pin all action versions to SHA or major tag
2. Set explicit `permissions` block
3. Use `concurrency` to cancel redundant runs
4. Cache dependencies with `actions/cache`
5. Use `if` conditions to skip unnecessary steps
6. Keep workflows focused on one purpose
7. Use reusable workflows for shared logic
8. Set timeouts on jobs (`timeout-minutes`)
9. Use environment files over `set-output`
10. Document triggers with inline comments

## Anti-Patterns

1. **Unpinned actions (`@main`)** — supply chain risk
2. **Broad permissions** — use least-privilege
3. **Inline scripts over 5 lines** — extract to a shell script
4. **Secrets in logs** — mask with `add-mask`
5. **No concurrency control** — leads to race conditions
6. **Hardcoded values** — use inputs and variables
7. **Missing timeouts** — jobs can run indefinitely
8. **`continue-on-error: true`** — hides failures
