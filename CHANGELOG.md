# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-08-22

### Changed

- **Lowered the supported ActiveRecord/ActiveSupport floor from `>= 7.1` to
  `>= 6.1`.** No library code changed: a full scan of `lib/poly/*.rb` found no
  Rails 7.1+ APIs, and the only ActiveRecord internals Poly touches
  (`arel_table`, `reflect_on_all_associations`, `reflect_on_association`,
  `base_class`) have been stable since well before 6.1. The previous floor was
  an end-of-life policy choice, not a technical constraint. Lowered so
  hellodancerrails (Rails 6.1.7.10 / Ruby 3.3.11) can adopt Midas, which
  depends on Poly.
- CI gains a `6.1` cell on both the SQLite and PostgreSQL lanes, pinned to Ruby
  3.3 -- the pairing hellodancerrails actually runs. 6.1 predates Ruby 3.4
  entirely, so that combination is excluded.

### Fixed

- The PostgreSQL CI lane's `ruby/setup-ruby` step in `.gitea/workflows/ci.yml`
  hardcoded `ruby-version: '3.4'` instead of reading `${{ matrix.ruby }}`, so
  the matrix's Ruby axis was ignored on that lane.
- `spec/models/poly/migration_spec.rb` hardcoded
  `ActiveRecord::Migration[7.1]`, which raises `Unknown migration version` on
  Rails 6.1. Test migrations now build against `POLY_MIGRATION_VERSION`,
  derived from the ActiveRecord actually under test.
- Shortened the `where:`-passthrough spec's table name, whose generated index
  name (`index_poly_migration_where_indexes_on_resource_type_and_resource_id`,
  67 chars) exceeded Rails 6.1's SQLite 64-character limit -- and PostgreSQL's
  63-character limit on every version.

### Development

- The `6.1` bundle lane pins `concurrent-ruby < 1.3.5` (1.3.5 dropped the
  implicit `require 'logger'` that ActiveSupport 6.1 relies on) and
  `sqlite3 ~> 1.4` (Rails 6.1's SQLite3Adapter requires it; sqlite3 2.x needs
  Rails 7.2+). Both are Gemfile-only -- neither is a runtime requirement of the
  gem.

## [1.2.0] - 2026-08-16

### Added

- `Poly::PolymorphicJoinError` (`lib/poly/polymorphic_join_error.rb`) — the
  join-validation error raised from `lib/poly/joins.rb` is now namespaced
  under `Poly`. The bare top-level `PolymorphicJoinError` constant remains as
  a deprecated alias, so existing `rescue PolymorphicJoinError` call sites
  keep working.
- CI now covers a database axis (SQLite and PostgreSQL, the latter via a GitHub
  Actions `services:` Postgres container) and an ActiveRecord/Rails version axis
  (7.1, 7.2, 8.x), each matrix cell pinning the loaded AR version via the new
  `ACTIVERECORD_VERSION` env var consumed by the `Gemfile`.
- `spec/spec_helper.rb`'s database adapter is now parameterized via
  `POLY_TEST_ADAPTER` (`sqlite3` default, or `postgresql`) instead of
  hardcoding an in-memory SQLite connection.
- README "Supported Databases" section documenting that MySQL is explicitly
  unsupported (`AbstractMysqlAdapter` doesn't implement `supports_partial_index?`,
  silently degrading `poly_prime_index` to a full-table unique index).
- README and new specs (`spec/models/poly/stack_spec.rb`) documenting
  `Poly::Stack`'s concurrency boundary — the `poly_stack_seize_prime`
  demote-then-insert sequence in `lib/poly/stack.rb`, and the
  `ActiveRecord::RecordNotUnique` failure mode it can hit under concurrent
  writers. No new public API was added.

### Fixed

- README §5 ("Poly::Stack")'s "append-only" wording corrected: the contract
  is immutable payload with mutable linkage/index metadata (`is_prime`,
  `superseded_by_id` are mutated in place on supersession), not literally
  immutable/append-only rows.

## [1.1.0] - 2026-07-07

### Added

- `Poly::Stack` — polymorphic, role-discriminated append-only history with a single
  "prime" (golden-child) card per `(resource, role)`, enforced by a database-level
  partial unique index. Payload-agnostic: manages only the prime marker
  (`is_prime`) and audit edge (`superseded_by_id`); the payload column, actor, and
  reason belong to the consuming model.
- `where:` option on `poly_resource_index` and `poly_owner_index` migration
  helpers — passes a partial-index condition through to `add_index`.

### Changed

- `poly_prime_index` is now implemented as sugar on top of `poly_resource_index`
  (`where: 'is_prime'`) instead of duplicating its own `add_index` call. The
  generated index name (`index_<table>_prime`) and indexed columns are
  unchanged, so this is not a breaking change for existing schemas.

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

[1.2.0]: https://github.com/whittakertech/poly/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/whittakertech/poly/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/whittakertech/poly/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/whittakertech/poly/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/whittakertech/poly/releases/tag/v0.1.0
