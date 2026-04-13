---
name: rust
description: >
  Rust coding standard for the Harmonius engine. Use this skill whenever
  reading, writing, editing, reviewing, or creating any `.rs` file. Also
  use when discussing Rust code style, naming conventions, linting, or
  project-specific Rust rules. Trigger on any interaction with Rust source
  files — even quick edits or single-line changes must follow this standard.
---

# Rust Coding Standard

## Scope

Primary engine language for all Harmonius systems. Rust stable only — no nightly features.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Crate | `snake_case` | `core_runtime` |
| Module | `snake_case` | `spatial_index` |
| Type (struct, enum, trait) | `PascalCase` | `ArchetypeStorage` |
| Function / method | `snake_case` | `query_entities` |
| Constant | `SCREAMING_SNAKE` | `MAX_ENTITIES` |
| Type parameter | Single uppercase or `PascalCase` | `T`, `Component` |
| Lifetime | Short lowercase | `'a`, `'w` |
| Feature flag | `kebab-case` | `metal-backend` |

## File Organization

- One module per file; `mod.rs` only for re-exports
- Group by domain: `src/{domain}/{module}.rs`
- Public API at crate root via `pub use`
- Tests in `#[cfg(test)] mod tests` at bottom of file
- Integration tests in `tests/` directory

## Formatting Rules

- 100-character line limit
- 4-space indentation
- `rustfmt` with default settings
- Trailing commas in multi-line expressions
- Blank line between `fn` definitions

## Linting Rules

- All `cargo clippy` warnings treated as errors
- `#![deny(clippy::all)]` at crate root
- `#![deny(missing_docs)]` for public API crates
- `#![deny(unsafe_code)]` unless crate requires FFI

## Type Checking

- `cargo check` must pass with zero warnings
- All public types must implement `Debug`
- Prefer concrete types over `impl Trait` in return position for public APIs

## How to Check and Fix

| Validation | Check command | Fix command |
|------------|--------------|-------------|
| Format | `cargo fmt --check` | `cargo fmt` |
| Lint | `cargo clippy` | `cargo clippy --fix --allow-dirty --allow-staged` |
| Type-check | `cargo check` | (manual) |
| Test | `cargo test` | (manual) |

## Project-Specific Rules

These rules derive from constraints.md:

1. **No stdlib file I/O** — use `tokio::fs` for file I/O and `tokio::net` for network I/O via the
   Tokio `current_thread` runtime
2. **Tokio `current_thread` is the sole async runtime** — all async I/O via Tokio
3. **No winit** — custom platform-native windowing
4. **Static dispatch preferred** — no `dyn` unless justified
5. **100% ECS-based** — all simulation data as components, all logic as systems
6. **No C++** — no C++ source anywhere; Windows via `windows-rs`
7. **`windows-rs` for Windows** — all D3D12, DXC, Win32, DXGI via `windows-rs` COM
8. **`unsafe` requires `// SAFETY:` comment** — explain the invariant being upheld
9. **`Result<T, E>` everywhere** — no `.unwrap()` in library code; `?` propagation preferred
10. **No `Arc`, `Rc`, `Cell`, `RefCell`** — use owned values, generational indices, or scoped
    borrows

## Cache-Friendly Patterns

- **Archetype storage** — store components in contiguous arrays per archetype, not per entity
- **Structs of arrays (SoA)** — when iterating over a single field across many entities
- **Arrays of structs (AoS)** — when accessing multiple fields of one entity together
- **Hot/cold splitting** — separate frequently accessed fields from rarely accessed ones into
  different components
- **Generational indices** — `Handle<T>` for indirect references without pointer chasing
- **Immutable by default** — all `let` bindings, all struct fields; `mut` only when required
- **Pure transform functions** — `fn(Input) -> Output` with no side effects for data pipelines
- **Batch processing** — process arrays, not individual items; enables SIMD and prefetching
- **Arena allocation** — allocate from contiguous arenas for cache-line locality

## Testing

1. **Test-driven development** — write tests first, driven by requirements (R-X.Y.Z), features
   (F-X.Y.Z), and user stories (US-X.Y.Z)
2. **Testability in design** — consider testability during the design phase, not after
   implementation
3. **Use real dependencies** — always prefer real objects over fakes; only use fakes when no other
   option exists
4. **NO MOCKING** — mocking is explicitly forbidden; no `mockall` or similar crates
5. **Fakes only when necessary** — write a full fake that emulates real behavior; implement the same
   trait
6. **Traits for contracts** — define traits at module boundaries for testability and substitution
7. **Enums for state** — prefer enums over booleans or stringly-typed state
8. **Pure functions** — maximize pure functions that take input and return output with no side
   effects
9. **Immutable test data** — use `const` or `static` test fixtures; never mutate shared test state
10. **`#[cfg(test)] mod tests`** — unit tests live in the same file as the code they test

## Best Practices

1. Prefer `enum` dispatch over `dyn Trait` for polymorphism
2. Use `#[must_use]` on functions returning `Result` or important values
3. Derive `Clone`, `Debug`, `PartialEq` where sensible
4. Use `newtype` pattern for type safety (`struct EntityId(u32)`)
5. Prefer slice parameters (`&[T]`) over `&Vec<T>`
6. Use `into_iter()` to consume, `iter()` to borrow
7. Prefer `Default` implementation over manual constructors when all fields have defaults
8. Group related constants in `const` blocks or `mod constants`
9. Use `cfg` attributes for platform-specific code
10. Document all public items with `///` doc comments

## Anti-Patterns

1. **Global mutable state** — no `static mut`, no `lazy_static` with interior mutability
2. **Stringly-typed APIs** — use enums, newtypes, or typed IDs instead of `String`
3. **Deep nesting** — extract to named functions at 3+ levels of indentation
4. **Ignoring errors** — no `let _ = fallible()`; handle or propagate
5. **Large functions** — keep functions under 50 lines; extract logical units
6. **Runtime type checks** — use generics and associated types instead of `TypeId` checks
7. **Cloning to satisfy the borrow checker** — redesign ownership instead
8. **`Box<dyn Any>`** — use concrete types or enums
9. **Blocking in async context** — use `AsyncMutex`/`AsyncRwLock` for contended locks
10. **Premature optimization** — profile before optimizing; use `#[bench]` and criterion
