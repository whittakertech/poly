---
description: Install Poly, meet its requirements, and combine migration helpers, roles, and joins on a single model.
---

# Getting Started

## Installation

Add Poly to your Gemfile:

```ruby
gem "poly"
```

Then install it:

```bash
bundle install
```

## Requirements

- Ruby >= 3.2
- ActiveRecord >= 7.1

## Supported Databases

Poly is tested in CI against **SQLite** and **PostgreSQL**.

**MySQL is explicitly not supported.** `Poly::Migration#poly_prime_index`
relies on a partial/conditional unique index --
`add_index table, [...], unique: true, where: 'is_prime'` -- to enforce
"exactly one prime row per resource+role, many non-primes allowed."
PostgreSQL's and SQLite3's ActiveRecord adapters both override
`supports_partial_index?` to `true`; `ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter`
does not override it, so it inherits the abstract adapter's default of
`false`. Because `schema_creation.rb` only emits the index's `WHERE` clause
when `supports_partial_index?` is true, MySQL silently drops the clause
instead of raising -- producing a full-table unique index instead of a
partial one, and quietly breaking the single-prime-per-role invariant.
This is a silent correctness bug, not just reduced support, so running
Poly against MySQL is unsupported rather than merely uncautioned-against.

## A Combined Example

The example below walks through a single model, `Tagging`, that uses all
three of Poly's core building blocks together: `Poly::Migration` to build
the schema, `Poly::Role` to give the polymorphic association semantic
meaning, and `Poly::Joins` to generate a type-safe join back to the
resources it tags.

### Migration

```ruby
class CreateTaggings < ActiveRecord::Migration[7.1]
  include Poly::Migration

  def change
    create_table :taggings do |t|
      poly_resource t, :taggable, null: false, id_type: :integer
      poly_role     t, :taggable, null: false
      t.timestamps
    end

    poly_resource_index :taggings, :taggable
  end
end
```

`poly_resource` adds the `taggable_type`/`taggable_id` columns, `poly_role`
adds `taggable_role`, and `poly_resource_index` adds a composite index on
the resource columns. (`id_type: :integer` matches this example's `posts`
table, which uses ActiveRecord's default integer primary key -- pick
whichever `id_type` matches your own resource tables' primary keys.)

### Model

```ruby
class Post < ApplicationRecord
  has_many :taggings, as: :taggable
end

class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  include Poly::Role
  include Poly::Joins

  poly_role :taggable
end
```

`poly_role :taggable` validates and normalizes `taggable_role` (presence,
lowercase, `a-z0-9_` only). Including `Poly::Joins` generates a
`joins_taggable` class method for every resource class that declares the
matching reverse association -- here, `Post`'s `has_many :taggings, as:
:taggable`.

### Using it

```ruby
post = Post.create!(title: "Hello World")

tagging = Tagging.create!(taggable: post, taggable_role: "Primary")
tagging.taggable_role # => "primary" (normalized on validation)

Tagging.joins_taggable(Post).where(posts: { title: "Hello World" })
# SELECT "taggings".* FROM "taggings"
#   INNER JOIN "posts"
#     ON "taggings"."taggable_id" = "posts"."id"
#    AND "taggings"."taggable_type" = 'Post'
#  WHERE "posts"."title" = 'Hello World'
```

## Next Steps

Continue with [Joins](./joins) to see the full range of what
`Poly::Joins` can generate.

[Home](./)
