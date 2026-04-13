---
name: json
description: >
  JSON coding standard for the Harmonius project. Use this skill whenever
  reading, writing, editing, reviewing, or creating any `.json` file. Also
  use when discussing JSON formatting, key sorting, indentation, or
  configuration file structure. Trigger on any interaction with JSON files
  — even small edits must follow sorted-key and 2-space indent rules.
---

# JSON Coding Standard

## Scope

Configuration files throughout the Harmonius project. Includes `.claude/settings.json`,
`package.json`, `tsconfig.json`, and other tool configurations.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Object key | `camelCase` | `enabledPlugins` |
| File name | `kebab-case.json` | `project-config.json` |

## File Organization

- JSON files at project or package root
- Tool-specific configs follow tool conventions
- Schema references where available (`$schema`)

## Formatting Rules

- 100-character line limit (where practical)
- 2-space indentation
- Keys sorted lexicographically in all objects
- Arrays are NOT sorted (order may be significant)
- Trailing commas not allowed (invalid JSON)
- No comments (use JSONC only when tool supports it)

## Linting Rules

- Valid JSON (parseable by `json.tool`)
- All object keys sorted lexicographically
- No duplicate keys

## Type Checking

Not applicable for JSON.

## How to Check and Fix

| Validation | Check command | Fix command |
|------------|--------------|-------------|
| Valid JSON | `jq . < file.json` | (manual) |
| Sorted keys | (manual review) | (manual) |

## Project-Specific Rules

1. **Sorted keys** — all JSON objects must have keys in lexicographical order
2. **No sorted arrays** — array element order is preserved as-is
3. **2-space indent** — consistent across all JSON
4. **No comments** — JSON does not support comments; use JSONC extension only when the tool requires
   it

## Cache-Friendly Patterns

Not applicable for JSON.

## Testing

1. **CI validation** — validate JSON files parse correctly
2. **Schema validation** — use JSON Schema where available for tool configs

## Best Practices

1. Use meaningful, descriptive key names
2. Keep nesting shallow (3 levels max)
3. Use arrays for ordered collections
4. Use objects for named properties
5. Include `$schema` reference when available
6. Use `null` explicitly for absent values
7. Keep files under 500 lines
8. Group related keys together (within sort order)

## Anti-Patterns

1. **Unsorted keys** — always sort lexicographically
2. **Comments in JSON** — use JSONC if tool allows, otherwise document externally
3. **Deeply nested objects** — flatten structure
4. **Duplicate keys** — later values silently override
5. **Trailing commas** — invalid JSON; tools may reject
6. **Large inline data** — extract to separate files
7. **Magic values** — document the meaning of each value
8. **Inconsistent indentation** — always 2 spaces
