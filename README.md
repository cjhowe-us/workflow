# cjhowe-us/workflow — Claude Code Marketplace

Claude Code plugin marketplace containing two plugins that power the development workflow for the
Harmonius game engine.

## Plugins

| Plugin | Purpose |
|--------|---------|
| [`rumdl`](./rumdl) | Markdown LSP + PostToolUse formatter hook + `markdown` coding-standard skill |
| [`harmonize`](./harmonize) | Full ideate-design-implement-release lifecycle: skills, templates, and supervisor agents |

`harmonize` depends on `rumdl` for Markdown linting and auto-formatting of the documents its agents
author. Install both.

**Cursor:** install from [`.cursor-plugin/marketplace.json`](./.cursor-plugin/marketplace.json). See
[`harmonize/docs/cursor-host.md`](./harmonize/docs/cursor-host.md) for how **`Task`** maps to the
harmonize playbooks.

## Install

```bash
# Add the marketplace (once)
claude plugin marketplace add cjhowe-us/workflow

# Install rumdl first (harmonize depends on it)
claude plugin install rumdl@cjhowe-us-workflow
claude plugin install harmonize@cjhowe-us-workflow
```

## Update

```bash
claude plugin update rumdl@cjhowe-us-workflow
claude plugin update harmonize@cjhowe-us-workflow
```

## Uninstall

```bash
claude plugin uninstall harmonize
claude plugin uninstall rumdl
```

## Prerequisites

`rumdl` plugin requires the `rumdl` binary on `PATH`. See [`rumdl/README.md`](./rumdl/README.md) for
install instructions and `.rumdl.toml` configuration.

## License

Apache-2.0
