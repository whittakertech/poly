# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-02-18

### Added

- `Poly::Migration` — helpers for declaring polymorphic resource/role/owner columns and indexes
  consistently across `create_table`, `change_table`, and `add_column`-style migrations.
  Helpers: `poly_resource`, `poly_role`, `poly_owner`, `poly_resource_index`, `poly_owner_index`.
- `Poly::Owners` — stamps `owner_type`/`owner_id` (or custom columns) before validation.
  Supports proc/method/object owner resolution, `allow_nil`, and `immutable` options.
  Validates that the named association is a polymorphic `belongs_to` and that the owner
  is a persisted `ActiveRecord::Base` instance.
- `poly_role immutable: true` option — raises on update if the role has already been set,
  preventing role changes after create.
- `poly_resource_index` and `poly_owner_index` migration helpers for consistent index naming
  and uniqueness declarations on polymorphic column pairs.

### Changed

- `Poly::Label` renamed to `Poly::Role`; the role column (e.g. `commentable_role`) replaces
  the former label column (`commentable_label`).
- `poly_role` now enforces lowercase alphanumeric/underscore format (`/\A[a-z0-9_]+\z/`)
  and normalises values (strip + downcase) before validation and in `for_role` queries.
- Ruby requirement raised to `>= 3.2.0`.

### Removed

- `Poly::Label` — fully replaced by `Poly::Role`. Update column names and any
  `for_label` / `poly_label` references to `for_role` / `poly_role` accordingly.

## [0.2.0] - 2024

### Added

- `Poly::Role` (originally shipped as `Poly::Label`) — role validation, normalization,
  and `for_role` scope for polymorphic associations.

## [0.1.0] - 2024

### Added

- `Poly::Joins` — type-safe polymorphic `INNER JOIN` generation via `define_polymorphic_joins!`.
  Creates methods like `joins_commentable(ClassName)` that validate the reverse
  `has_many`/`has_one` association before building the join SQL.

[Unreleased]: https://github.com/leewhittaker/poly/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/leewhittaker/poly/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/leewhittaker/poly/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/leewhittaker/poly/releases/tag/v0.1.0
