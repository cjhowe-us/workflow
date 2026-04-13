---
name: toml
description: >
  TOML coding standard for the Harmonius project. Use this skill whenever
  reading, writing, editing, reviewing, or creating any `.toml` file. Also
  use when discussing Cargo.toml structure, taplo formatting, TOML key
  sorting, or dependency management. Trigger on any interaction with TOML
  files — even adding a single dependency must follow this standard.
---

# TOML Coding Standard

## Scope

Configuration files using TOML format. Includes `Cargo.toml`, `.rumdl.toml`, and other Rust
ecosystem tool configurations.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Section | `[kebab-case]` | `[dependencies]` |
| Key | `kebab-case` | `line-length` |
| File name | Tool-specific | `Cargo.toml` |

## File Organization

### Cargo.toml section order

1. `[package]`
2. `[features]`
3. `[dependencies]`
4. `[dev-dependencies]`
5. `[build-dependencies]`
6. `[[bin]]` / `[[example]]`
7. `[profile.*]`
8. `[workspace]`

### Other TOML files

- Follow tool-specific conventions
- Group related keys under sections
- Document non-obvious values with comments

## Formatting Rules

- 100-character line limit
- Keys sorted within each section
- Blank line between sections
- Inline tables only for short entries

## Linting Rules

- `taplo` for validation and formatting
- Valid TOML syntax
- No duplicate keys within a section

## Type Checking

Not applicable for TOML.

## How to Check and Fix

| Validation | Check command | Fix command |
|------------|--------------|-------------|
| Valid TOML | `taplo check` | `taplo fmt` |

## Project-Specific Rules

1. **Cargo.toml section order** — follow the order listed above
2. **Version specifiers** — use exact versions or caret ranges in dependencies
3. **Feature flags** — document each feature with inline comments

## Cache-Friendly Patterns

Not applicable for TOML.

## Testing

1. **CI validation** — `taplo check` in CI pipeline
2. **Cargo check** — validates `Cargo.toml` correctness

## Best Practices

1. Use comments to explain non-obvious configuration
2. Keep inline tables to one line
3. Sort dependencies alphabetically
4. Use workspace dependencies for shared versions
5. Specify minimum supported Rust version (MSRV) in `[package]`
6. Use `[workspace.dependencies]` for version management
7. Keep `[features]` section documented

## Anti-Patterns

1. **Unsorted dependencies** — sort alphabetically
2. **Wildcard versions (`*`)** — use explicit ranges
3. **Large inline tables** — use standard table syntax
4. **Missing version constraints** — always specify
5. **Undocumented features** — add comment per feature
6. **Duplicate keys** — TOML does not allow them
