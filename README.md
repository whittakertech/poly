# Poly

Type-safe joins, role identity, and owner identity for polymorphic `belongs_to` associations in Rails.

## Installation

Add to your Gemfile:

```ruby
gem 'poly'
```

Then run `bundle install`.

## Requirements

- Ruby >= 3.2
- ActiveRecord >= 7.1

## Usage

### Poly::Joins

Generates type-safe `INNER JOIN` methods for polymorphic associations. Include the module in a model that has a polymorphic `belongs_to`, and it will define a `joins_<association>` class method for each one.

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true

  include Poly::Joins
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class User < ApplicationRecord
  has_many :comments, as: :commentable
end
```

Now you can join through the polymorphic association by passing the target class:

```ruby
# Join comments to the posts table
Comment.joins_commentable(Post)
# => SELECT "comments".* FROM "comments"
#    INNER JOIN "posts"
#    ON "comments"."commentable_id" = "posts"."id"
#    AND "comments"."commentable_type" = 'Post'

# Chainable with other scopes
Comment.joins_commentable(Post).where(posts: { title: 'Hello' })

# Join to a different target type
Comment.joins_commentable(User).where(users: { name: 'Lee' })
```

**Safety:** The target class must declare the reverse association (`has_many` or `has_one` with `as: :commentable`). If it doesn't, a `PolymorphicJoinError` is raised:

```ruby
Comment.joins_commentable(Unrelated)
# => PolymorphicJoinError: Unrelated must declare has_one/has_many as: :commentable
```

### Poly::Role

Adds a validated role column to a polymorphic association. This is useful when a single polymorphic relationship needs to distinguish between different roles or categories.

Your table needs a `<association>_role` string column:

```ruby
create_table :taggings do |t|
  t.references :taggable, polymorphic: true, null: false
  t.string :taggable_role, null: false
  t.timestamps
end

# Index: composite on (taggable_type, taggable_id, taggable_role) if uniqueness is required
add_index :taggings, [:taggable_type, :taggable_id, :taggable_role], unique: true
```

Then include the module and declare the role-enabled association:

```ruby
class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  include Poly::Role

  poly_role :taggable
  # optionally:
  # poly_role :taggable, max_length: 128
  # poly_role :taggable, immutable: true
end
```

This gives you:

- **Normalization** — roles are stripped and downcased before validation and before `for_role` queries
- **Validation** — roles must match `/\A[a-z0-9_]+\z/` and be at most 64 characters (configurable via `max_length:`)
- **Scope** — `for_role` queries by role, normalizing the input automatically
- **Immutability** — `immutable: true` adds an `on: :update` validation that prevents role changes after create

```ruby
tagging = Tagging.new(taggable: post, taggable_role: '  Primary  ')
tagging.valid?
tagging.taggable_role # => "primary"

Tagging.for_role('  PRIMARY  ')
# => normalizes to 'primary' before querying
```

### Poly::Owners

Stamps `owner_type`/`owner_id` columns before validation. Useful for recording data ownership at write time without coupling the model to tenancy or policy logic.

Your table needs `owner_type` and `owner_id` columns (in addition to your polymorphic resource columns):

```ruby
create_table :coins do |t|
  t.references :ledger, null: false
  t.references :resource, polymorphic: true, null: false
  t.string :resource_role, null: false
  t.string :owner_type
  t.integer :owner_id
  t.timestamps
end

# Index: always composite — never index owner_type and owner_id separately
add_index :coins, [:owner_type, :owner_id]
```

Then declare how the owner should be resolved:

```ruby
class Coin < ApplicationRecord
  belongs_to :ledger
  belongs_to :resource, polymorphic: true

  include Poly::Owners

  poly_owner :resource, owner: -> { ledger&.account }
  # optionally:
  # poly_owner :resource, owner: -> { ledger&.account }, allow_nil: false
  # poly_owner :resource, owner: -> { ledger&.account }, immutable: true
end
```

**`owner` resolution** — can be a `Proc` (evaluated in instance context), a `Symbol`/`String` (method name called on the record), or a direct `ActiveRecord::Base` instance. The owner must be persisted; an `ArgumentError` is raised otherwise.

**Options:**

| Option | Default | Description |
|---|---|---|
| `type_column:` | `:owner_type` | Column to store the owner class name |
| `id_column:` | `:owner_id` | Column to store the owner id |
| `allow_nil:` | `true` | When `false`, raises if the owner resolves to `nil` |
| `immutable:` | `false` | When `true`, prevents owner changes after create via `on: :update` validation |

### Poly::Migration

Adds migration helpers so polymorphic resource/role/owner columns are declared consistently.

Use it in your migration base class:

```ruby
class ApplicationMigration < ActiveRecord::Migration[7.1]
  include Poly::Migration
end
```

Supported styles:

- `create_table` / `change_table` via a table builder (`t`)
- direct existing-table operations via `add_column` style (pass table name)

#### Create Table / Change Table

```ruby
class CreateCoins < ApplicationMigration
  def change
    create_table :coins do |t|
      poly_resource t, :resource, null: false
      poly_role t, :resource, null: false
      poly_owner t, null: false
      t.timestamps
    end

    poly_resource_index :coins, :resource
    poly_owner_index :coins
  end
end
```

#### Existing Table (add_column style)

```ruby
class AddPolyColumnsToCoins < ApplicationMigration
  def change
    poly_resource :coins, :resource, null: false
    poly_role :coins, :resource, null: false
    poly_owner :coins, null: false

    poly_resource_index :coins, :resource
    poly_owner_index :coins
  end
end
```

#### Helper Reference

| Helper | Purpose |
|---|---|
| `poly_resource(table_or_builder, name, null: true, id_type: :string)` | Adds `<name>_type` and `<name>_id` |
| `poly_role(table_or_builder, name, null: true)` | Adds `<name>_role` |
| `poly_owner(table_or_builder, type_column: :owner_type, id_column: :owner_id, id_type: :string, null: true)` | Adds owner type/id columns |
| `poly_resource_index(table, name, unique: false)` | Adds index on `<name>_type`, `<name>_id` |
| `poly_owner_index(table, type_column: :owner_type, id_column: :owner_id, unique: false)` | Adds index on owner columns |

`id_type` defaults to `:string` so owner/resource IDs can store bigint, UUID, ULID, or other identifier formats consistently.

## Development

```bash
bundle install              # Install dependencies
bundle exec rspec           # Run tests
bundle exec rubocop         # Lint
COVERAGE=true bundle exec rspec  # Run tests with coverage report
```

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).
