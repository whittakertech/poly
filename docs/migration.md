---
description: Reference for Poly::Migration, the migration helpers that keep polymorphic resource, role, owner, and stack column/index topology consistent across create_table, change_table, and add_column-style migrations.
---

# Migration

## The mechanism

`Poly::Migration` is a plain module (not an `ActiveSupport::Concern`) meant to
be `include`d into a migration class. It provides seven helper methods that
add the columns and indexes the rest of Poly relies on — `poly_resource`,
`poly_role`, `poly_owner`, and `poly_stack` for columns; `poly_resource_index`,
`poly_owner_index`, and `poly_prime_index` for indexes:

```ruby
class ApplicationMigration < ActiveRecord::Migration[7.1]
  include Poly::Migration
end
```

## Helpers

| Helper | Purpose |
|--------|----------|
| `poly_resource(table_or_builder, name, null: true, id_type: :string)` | Adds `<name>_type` + `<name>_id` |
| `poly_role(table_or_builder, name, null: true)` | Adds `<name>_role` |
| `poly_owner(table_or_builder, type_column: :owner_type, id_column: :owner_id, id_type: :string, null: true)` | Adds owner type/id columns |
| `poly_stack(table_or_builder, id_type: :string)` | Adds `is_prime` + `superseded_by_id` |
| `poly_resource_index(table, name, unique: false, where: nil, index_name: nil, columns: nil)` | Composite resource index |
| `poly_owner_index(table, type_column: :owner_type, id_column: :owner_id, unique: false, where: nil, index_name: nil)` | Composite owner index |
| `poly_prime_index(table, name = :resource)` | Partial unique index (one prime per resource/role); sugar for `poly_resource_index` with `unique: true, where: 'is_prime'` |

## Table-builder vs. direct form

Every one of the seven methods branches internally on a private
`table_builder?(value)` check (`value.respond_to?(:references)`,
`lib/poly/migration.rb`), which decides how it writes columns:

- **Table-builder form** — called inside a `create_table`/`change_table`
  block, passing the block variable as the first argument (e.g. `poly_resource
  t, :resource`). Columns are built via `t.references`, `t.string`,
  `t.boolean`, or `t.public_send(id_type, ...)`.
- **Direct form** — called with a table name/symbol against an existing
  table (e.g. `poly_resource :coins, :resource`), outside any block. Columns
  are built via `add_column`.

Both forms exist so the same helper works whether you're standing up a new
table or altering one that already exists.

### `poly_resource`, `poly_role`, `poly_owner` — table-builder form

Sourced verbatim (renamed to a `change` block) from `migration_spec.rb`'s
"table builder helpers" describe block ("adds resource, role, owner columns
and indexes in create_table"):

```ruby
class CreatePolyMigrationBuilders < ActiveRecord::Migration[7.1]
  include Poly::Migration

  def change
    create_table :poly_migration_builders do |t|
      poly_resource t, :resource, null: false
      poly_role t, :resource, null: false
      poly_owner t, null: false
    end

    poly_resource_index :poly_migration_builders, :resource, unique: true
    poly_owner_index :poly_migration_builders
  end
end
```

This produces a non-nullable `resource_type`/`resource_id` pair (`resource_id`
typed `:string`, the `id_type:` default), a non-nullable `resource_role`, and
a non-nullable `owner_type`/`owner_id` pair, plus a unique composite index on
`[resource_type, resource_id]` and a non-unique composite index on
`[owner_type, owner_id]`.

### `poly_resource`, `poly_role`, `poly_owner` — direct (`add_column`) form

Sourced verbatim (renamed to a `change` block) from `migration_spec.rb`'s
"add_column helpers" describe block ("adds resource, role, owner columns and
indexes to an existing table"):

```ruby
class AddPolySubjectToExisting < ActiveRecord::Migration[7.1]
  include Poly::Migration

  def change
    poly_resource :poly_migration_add_columns, :subject, null: false
    poly_role :poly_migration_add_columns, :subject, null: false
    poly_owner :poly_migration_add_columns, null: false

    poly_resource_index :poly_migration_add_columns, :subject
    poly_owner_index :poly_migration_add_columns, unique: true
  end
end
```

Same resulting columns as the table-builder example above, but written via
`add_column` against a table (`poly_migration_add_columns`) that already
exists — this is the form to reach for in a follow-up migration against a
table Poly wasn't wired into at `create_table` time.

## `poly_stack` (columns)

`poly_stack(table_or_builder, id_type: :string)` adds the two columns
`Poly::Stack`'s golden-child/audit-trail mechanism depends on: `is_prime`
(`boolean, null: false, default: false`) and `superseded_by_id` (typed by
`id_type:`, nullable). Both forms follow the same table-builder/direct split
as the other helpers:

```ruby
# Table-builder form, inside create_table/change_table:
poly_stack t

# Direct form, against an existing table:
poly_stack :statuses
```

This matches the dummy schema's `statuses` table (`spec/spec_helper.rb`),
which is what `Poly::Stack`'s `prime` scope and supersession callbacks read
and write (see [Stack](./stack)).

> [!IMPORTANT]
> **`poly_stack` names two different methods.** `Poly::Migration#poly_stack`
> — documented on this page — is a *migration-context* method: it adds the
> `is_prime`/`superseded_by_id` *columns* to a table, and is called by
> `include`ing `Poly::Migration` into a migration class. The **model-level**
> `poly_stack` documented on the [Stack](./stack) page is a completely
> different method: a class macro from `Poly::Stack` (`lib/poly/stack.rb`),
> called by `include`ing `Poly::Stack` into an `ActiveRecord` model, which
> sets up the `prime` scope and the `before_create`/`after_create` callbacks
> that seize and chain the prime card. They share a name because they share a
> concept (stack columns in the schema, stack behavior on the model) but they
> are defined in different modules, included into different kinds of classes
> (a migration vs. a model), and do different things. Adding the columns via
> `Poly::Migration#poly_stack` does not give a model the `prime` scope or
> callbacks — that requires separately `include Poly::Stack` and call the
> model-level `poly_stack` macro on the model itself.

## `id_type:` flexibility

`id_type:` defaults to `:string` on every helper that accepts it
(`poly_resource`, `poly_owner`, `poly_stack`). Passing a different type is
supported because the value is forwarded straight through to
`t.public_send(id_type, ...)` (table-builder form) or `add_column ...,
id_type, ...` (direct form) — whatever ActiveRecord's schema DSL accepts for a
column type, `id_type:` accepts.

A genuine non-default example, sourced verbatim (renamed to a `change` block)
from `migration_spec.rb`'s "supports custom id and owner columns in
add_column style" example:

```ruby
class AddLedgerableAndTenantColumns < ActiveRecord::Migration[7.1]
  include Poly::Migration

  def change
    poly_resource :poly_migration_add_columns, :ledgerable, id_type: :integer
    poly_owner :poly_migration_add_columns,
               type_column: :tenant_type,
               id_column: :tenant_id,
               id_type: :integer
  end
end
```

This produces an integer `ledgerable_id` column (instead of the default
string) and an integer `tenant_id` column alongside a string `tenant_type` —
`type_column` is always written as `:string` regardless of `id_type:`, only
the `*_id`/`superseded_by_id` column follows `id_type:`.

Application code can also pass `id_type: :uuid`, `id_type: :ulid`, or
`id_type: :bigint` — these are supported because `t.public_send(id_type,
...)`/`add_column` accept any column type ActiveRecord's schema DSL supports,
not because `Poly::Migration` special-cases them. Unlike the `:integer`
example above, there is no spec in `migration_spec.rb` that exercises `:uuid`,
`:ulid`, or `:bigint` specifically, so treat those three as supported types
you can pass through, not as independently spec-verified examples.

## Index helpers

`poly_resource_index` and `poly_owner_index` both wrap `add_index`, forwarding
`unique:`, `where:`, and `index_name:` (as `name:`) straight through.
`poly_prime_index` is sugar over `poly_resource_index` with `unique: true,
where: 'is_prime'` and an `index_#{table}_prime` name, adding the resource's
role column to the index — it's what enforces "exactly one prime row per
`(resource, role)`."

Sourced verbatim (renamed to `change` blocks) from `migration_spec.rb`'s
"where: passthrough on index helpers" and "poly_prime_index" describe blocks:

```ruby
class AddPolyMigrationIndexes < ActiveRecord::Migration[7.1]
  include Poly::Migration

  def change
    # where:, unique:, and index_name: all pass through poly_resource_index:
    poly_resource_index :poly_migration_where_indexes, :resource,
                        unique: true, where: 'is_prime', index_name: 'index_custom_prime'

    # poly_prime_index is sugar for the same shape, with a fixed name/where/unique:
    poly_prime_index :poly_migration_prime, :resource
  end
end
```

The first call produces a unique partial index named `index_custom_prime` on
`[resource_type, resource_id]`, restricted to rows `where is_prime`. The
second, `poly_prime_index :poly_migration_prime, :resource`, produces a
unique partial index named `index_poly_migration_prime_prime` on
`[resource_type, resource_id, resource_role]`, also restricted `where
is_prime` — this is the exact index `Poly::Stack` relies on to enforce "at
most one prime per `(resource, role)`" under a race (see
[Stack](./stack)'s "Concurrency Boundary" section).

`poly_prime_index`'s partial index is also the reason MySQL isn't supported —
see [Getting Started](./getting-started)'s "Supported Databases" section for
why MySQL silently drops the `where:` clause instead of raising.

## Next Steps

This is the last of Poly's guides. For the full method-by-method API surface,
see the [YARD API reference](/api/).

[Home](./) · Back to [Stack](./stack)
